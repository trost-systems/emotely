import {
  type ErrorCode,
  type ErrorResponse,
  type RevokeAppleRequest,
  type RevokeAppleResponse,
  revokeAppleRequest,
} from "@emotely/contract";
import { type AppleClient, AppleRequestError } from "./apple-sign-in.ts";
import {
  IdentityLookupError,
  type LinkedAppleIds,
} from "./linked-identities.ts";
import { bearerToken, type VerifyCaller } from "./request-auth.ts";

const HTTP_OK = 200;
const HTTP_BAD_REQUEST = 400;
const HTTP_UNAUTHORIZED = 401;
const HTTP_FORBIDDEN = 403;
const HTTP_METHOD_NOT_ALLOWED = 405;
const HTTP_BAD_GATEWAY = 502;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** An error response: the [code] the app acts on, [error] for logs only. */
function fail(status: number, code: ErrorCode, error: string): Response {
  return json(status, { code, error } satisfies ErrorResponse);
}

const mismatch = (): Response =>
  fail(HTTP_FORBIDDEN, "apple_identity_mismatch", "apple identity mismatch");

const unavailable = (): Response =>
  fail(
    HTTP_BAD_GATEWAY,
    "apple_revocation_unavailable",
    "apple revocation unavailable",
  );

async function parse(
  request: Request,
): Promise<RevokeAppleRequest | undefined> {
  try {
    return revokeAppleRequest.parse(await request.json());
  } catch {
    // Not JSON, or not the contract's shape: the caller gets a 400.
  }
}

/**
 * `POST /api/revoke-apple` (#193): revokes the caller's Sign in with Apple
 * grant before their account is deleted, as App Store Review Guideline
 * 5.1.1(v) asks. Supabase never does (supabase/auth#1308) and keeps no Apple
 * token, so the app asks Apple's sheet for a fresh authorization code and
 * sends it here; this trades it for a refresh token and revokes that at
 * once. No Apple token outlives the request.
 *
 * Cost order, like every endpoint here (ADR 0008): the caller's token is
 * checked locally first, the body second, and only then is anyone called —
 * Supabase for the Apple ID linked to the account, then Apple twice. A code
 * for any other Apple ID revokes nothing: the caller may only revoke the
 * grant their own account signs in with.
 *
 * Every answer but 200 leaves the grant in place, and the app deletes the
 * account regardless; it tells the user where to remove emotely themselves.
 */
export function createRevokeAppleHandler(deps: {
  /** Who is calling; `undefined` is a 401 (ADR 0010). */
  verifyCaller: VerifyCaller;
  /** The Apple IDs Supabase links to the caller's account. */
  linkedAppleIds: LinkedAppleIds;
  apple: AppleClient;
  /**
   * Called with the error when Apple or Supabase refused or could not be
   * reached, before the 502 goes out. Wired to PostHog error tracking in
   * `api/revoke-apple.ts`. It must not throw.
   */
  onFailure?: (error: unknown) => void;
}) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return fail(HTTP_METHOD_NOT_ALLOWED, "method_not_allowed", "POST only");
    }
    const caller = await deps.verifyCaller(request);
    const token = bearerToken(request);
    if (caller === undefined || token === undefined) {
      return fail(HTTP_UNAUTHORIZED, "unauthorized", "unauthorized");
    }
    const parsed = await parse(request);
    if (parsed === undefined) {
      return fail(HTTP_BAD_REQUEST, "malformed_request", "malformed request");
    }
    try {
      return await revokeLinked(deps, token, parsed.authorization_code);
    } catch (error) {
      // Only an upstream's refusal is absorbed; anything else (a key that
      // will not import, a bug) is the server's and 500s loudly.
      if (
        !(
          error instanceof AppleRequestError ||
          error instanceof IdentityLookupError
        )
      ) {
        throw error;
      }
      deps.onFailure?.(error);
      return unavailable();
    }
  };
}

/**
 * Revokes the grant [code] stands for, if it is the one the caller's
 * account is linked to; Supabase is asked first, so an account without an
 * Apple identity costs Apple nothing. Throws what an upstream refused.
 */
async function revokeLinked(
  deps: { linkedAppleIds: LinkedAppleIds; apple: AppleClient },
  token: string,
  code: string,
): Promise<Response> {
  const linked = await deps.linkedAppleIds(token);
  if (linked === "unauthorized") {
    return fail(HTTP_UNAUTHORIZED, "unauthorized", "unauthorized");
  }
  if (linked.size === 0) {
    return mismatch();
  }
  const { refreshToken, subject } = await deps.apple.exchange(code);
  if (!linked.has(subject)) {
    return mismatch();
  }
  await deps.apple.revoke(refreshToken);
  return json(HTTP_OK, { status: "revoked" } satisfies RevokeAppleResponse);
}
