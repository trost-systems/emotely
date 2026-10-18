const HTTP_UNAUTHORIZED = 401;
const HTTP_FORBIDDEN = 403;

/**
 * Supabase did not answer who the caller is linked to. Its message names
 * only the status, so error tracking may forward it (ADR 0005).
 */
export class IdentityLookupError extends Error {
  override readonly name = "IdentityLookupError";

  constructor(status?: number) {
    super(
      status === undefined ? "user unreachable" : `user ${status.toString()}`,
    );
  }
}

/**
 * The Apple IDs linked to the caller's account, or `"unauthorized"` when
 * Supabase no longer accepts the caller's token.
 */
export type LinkedAppleIds = (
  accessToken: string,
) => Promise<ReadonlySet<string> | "unauthorized">;

type Fetch = (url: string, init: RequestInit) => Promise<Response>;

/**
 * Reads the caller's identities from Supabase Auth (`GET /auth/v1/user`)
 * under the caller's own token: no service role, and the answer cannot be
 * forged by the caller. An identity's `id` is the provider's subject — for
 * Apple, the Apple ID the account signs in with. Not `user_metadata`, which
 * the user can edit.
 *
 * [publishableKey] is the project's public key, which Supabase's gateway
 * asks of every request; it grants nothing beyond the caller's token.
 */
export function createLinkedAppleIds(deps: {
  supabaseUrl: string;
  publishableKey: string;
  fetch?: Fetch;
}): LinkedAppleIds {
  const url = new URL("/auth/v1/user", deps.supabaseUrl).href;
  const fetchImpl = deps.fetch ?? fetch;
  return async (accessToken) => {
    let response: Response;
    try {
      response = await fetchImpl(url, {
        method: "GET",
        headers: {
          apikey: deps.publishableKey,
          authorization: `Bearer ${accessToken}`,
        },
      });
    } catch {
      throw new IdentityLookupError();
    }
    if (
      response.status === HTTP_UNAUTHORIZED ||
      response.status === HTTP_FORBIDDEN
    ) {
      return "unauthorized";
    }
    if (!response.ok) {
      throw new IdentityLookupError(response.status);
    }
    const body = (await response.json()) as { identities?: unknown };
    const identities = Array.isArray(body.identities) ? body.identities : [];
    return new Set(
      identities.flatMap((identity: unknown) => {
        const { provider, id } = identity as {
          provider?: unknown;
          id?: unknown;
        };
        return provider === "apple" && typeof id === "string" ? [id] : [];
      }),
    );
  };
}
