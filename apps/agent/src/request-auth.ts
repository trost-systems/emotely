import {
  createRemoteJWKSet,
  type JWTPayload,
  type JWTVerifyGetKey,
  jwtVerify,
} from "jose";

/** A signed-in Supabase user, as proven by the JWT on the request. */
export type Caller = { userId: string };

export type VerifyCaller = (request: Request) => Promise<Caller | undefined>;

const BEARER = "Bearer ";

/**
 * The bearer token on [request], as sent. Only meaningful once
 * `VerifyCaller` accepted the request: then it is the caller's live token,
 * fit to act as them towards Supabase.
 */
export function bearerToken(request: Request): string | undefined {
  const header = request.headers.get("authorization") ?? "";
  return header.startsWith(BEARER) ? header.slice(BEARER.length) : undefined;
}

/**
 * Who is calling: the Supabase user whose access token rides in the
 * Authorization header, verified locally against the project's public signing
 * keys (asymmetric JWT, so no round trip to Supabase and no shared secret in
 * this codebase). Anything short of a live token for a real, non-anonymous
 * user is `undefined`; the handler turns that into a 401 (ADR 0010).
 */
export function createCallerVerifier(opts: {
  keys: JWTVerifyGetKey;
  issuer: string;
}): VerifyCaller {
  return async (request) => {
    const token = bearerToken(request);
    if (token === undefined) {
      return;
    }
    // Malformed, expired, wrong key: all the same to the caller — 401.
    const payload: JWTPayload | undefined = await jwtVerify(token, opts.keys, {
      issuer: opts.issuer,
      audience: "authenticated",
    }).then(
      (verified) => verified.payload,
      () => undefined,
    );
    if (
      payload?.sub === undefined ||
      payload["role"] !== "authenticated" ||
      payload["is_anonymous"] === true
    ) {
      return;
    }
    return { userId: payload.sub };
  };
}

/**
 * The project's key set and issuer, derived from its URL. `jose` caches the
 * keys and refetches on an unknown `kid`, which is how rotation works
 * without a deploy.
 */
export function supabaseAuth(supabaseUrl: string): {
  keys: JWTVerifyGetKey;
  issuer: string;
} {
  return {
    keys: createRemoteJWKSet(
      new URL("/auth/v1/.well-known/jwks.json", supabaseUrl),
    ),
    issuer: new URL("/auth/v1", supabaseUrl).href,
  };
}
