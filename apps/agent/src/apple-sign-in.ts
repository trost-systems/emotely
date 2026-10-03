import { decodeJwt, importPKCS8, type JWTPayload, SignJWT } from "jose";

/**
 * The Sign in with Apple key (#193): the .p8 private key created under
 * Certificates, Identifiers & Profiles → Keys on team VCZSHMZY25, with the
 * identifiers that go into every client secret. Only the private key is a
 * secret; it lives in the agent's Vercel environment and nowhere else. The
 * release-app skill's signing reference says how to create and rotate it.
 */
export type AppleSignInKey = {
  /** The .p8 file's contents: an ES256 (P-256) key in PKCS #8 PEM. */
  privateKey: string;
  /** The key's 10-character id, the client secret's `kid`. */
  keyId: string;
  /** The team's 10-character id, the client secret's `iss`. */
  teamId: string;
  /**
   * The App ID's bundle identifier. A native app's authorization code is
   * issued to the App ID, not to a Services ID, so this is `client_id` and
   * the secret's `sub`.
   */
  clientId: string;
};

const APPLE = "https://appleid.apple.com";
const TOKEN_URL = `${APPLE}/auth/token`;
const REVOKE_URL = `${APPLE}/auth/revoke`;

/**
 * How long a client secret lives. Apple accepts up to six months; one is
 * minted per request instead, so there is nothing to rotate and a secret
 * that leaks is dead within minutes.
 */
const CLIENT_SECRET_LIFETIME_S = 300;

/**
 * Apple's `error` values, the whole closed set its error response may carry
 * (Sign in with Apple REST API, `ErrorResponse`). Only these reach a report;
 * anything else Apple sends becomes `unknown`.
 */
const APPLE_ERRORS: ReadonlySet<string> = new Set([
  "invalid_request",
  "invalid_client",
  "invalid_grant",
  "unauthorized_client",
  "unsupported_grant_type",
  "invalid_scope",
]);

/**
 * Apple refused, or could not be reached, at [step]. Its message is built
 * only from the step, the status and Apple's closed `error` vocabulary, so
 * error tracking forwards it as it stands (ADR 0005): it can never hold a
 * token, a code or an address.
 */
export class AppleRequestError extends Error {
  override readonly name = "AppleRequestError";

  constructor(step: "token" | "revoke", status?: number, appleError?: string) {
    super(
      status === undefined
        ? `${step} unreachable`
        : `${step} ${status} ${
            appleError !== undefined && APPLE_ERRORS.has(appleError)
              ? appleError
              : "unknown"
          }`,
    );
  }
}

type Fetch = (url: string, init: RequestInit) => Promise<Response>;

export type AppleClient = {
  /**
   * Trades a native authorization code for tokens: the refresh token to
   * revoke, and the Apple ID ([subject]) the code was issued for.
   */
  exchange: (
    code: string,
  ) => Promise<{ refreshToken: string; subject: string }>;
  /** Revokes [refreshToken], and with it the user's grant to this app. */
  revoke: (refreshToken: string) => Promise<void>;
};

/** A client secret for one request: ES256, signed with the .p8 key. */
async function clientSecret(key: AppleSignInKey): Promise<string> {
  const privateKey = await importPKCS8(key.privateKey, "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: key.keyId })
    .setIssuer(key.teamId)
    .setSubject(key.clientId)
    .setAudience(APPLE)
    .setIssuedAt()
    .setExpirationTime(`${CLIENT_SECRET_LIFETIME_S}s`)
    .sign(privateKey);
}

/** Apple's `error` code from a refusal's body, if it sent one. */
async function errorCodeOf(response: Response): Promise<string | undefined> {
  try {
    const body: unknown = await response.json();
    const code: unknown = (body as { error?: unknown }).error;
    return typeof code === "string" ? code : undefined;
  } catch {
    // Not JSON: an edge answered, not Apple. The status says enough.
  }
}

/**
 * The refresh token and the Apple ID from a `/auth/token` answer, or
 * `undefined` when it is not one Apple issued for [clientId].
 *
 * The id_token is not signature-checked: it is Apple's answer, over TLS, to
 * a request only this key could authenticate, so nobody else could have put
 * it there. Its issuer and audience still have to be Apple and this app
 * before its subject is believed.
 */
function tokensOf(
  body: unknown,
  clientId: string,
): { refreshToken: string; subject: string } | undefined {
  const { refresh_token: refreshToken, id_token: idToken } = body as {
    refresh_token?: unknown;
    id_token?: unknown;
  };
  if (typeof refreshToken !== "string" || typeof idToken !== "string") {
    return;
  }
  let claims: JWTPayload;
  try {
    claims = decodeJwt(idToken);
  } catch {
    // Not a JWT at all: no subject to believe.
    return;
  }
  if (
    claims.iss !== APPLE ||
    claims.aud !== clientId ||
    typeof claims.sub !== "string"
  ) {
    return;
  }
  return { refreshToken, subject: claims.sub };
}

/**
 * Apple's Sign in with Apple REST API, as far as revocation needs it.
 * [fetchImpl] is the seam a test scripts; production passes `fetch`.
 */
export function createAppleClient(
  key: AppleSignInKey,
  fetchImpl: Fetch = fetch,
): AppleClient {
  async function post(
    step: "token" | "revoke",
    url: string,
    form: Record<string, string>,
  ): Promise<Response> {
    const body = new URLSearchParams({
      client_id: key.clientId,
      client_secret: await clientSecret(key),
      ...form,
    }).toString();
    let response: Response;
    try {
      response = await fetchImpl(url, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body,
      });
    } catch {
      // A transport error says nothing Apple-specific worth keeping.
      throw new AppleRequestError(step);
    }
    if (!response.ok) {
      throw new AppleRequestError(
        step,
        response.status,
        await errorCodeOf(response),
      );
    }
    return response;
  }

  return {
    async exchange(code) {
      // A native app's code carries no redirect URI, so none is sent.
      const response = await post("token", TOKEN_URL, {
        code,
        grant_type: "authorization_code",
      });
      return (
        tokensOf(await response.json(), key.clientId) ??
        Promise.reject(new AppleRequestError("token", response.status))
      );
    },
    async revoke(refreshToken) {
      await post("revoke", REVOKE_URL, {
        token: refreshToken,
        token_type_hint: "refresh_token",
      });
    },
  };
}
