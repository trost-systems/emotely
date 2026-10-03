import assert from "node:assert/strict";
import { generateKeyPairSync, type KeyObject } from "node:crypto";
import { describe, it } from "node:test";
import { errorResponse, revokeAppleResponse } from "@emotely/contract";
import { decodeProtectedHeader, jwtVerify, UnsecuredJWT } from "jose";
import { type AppleSignInKey, createAppleClient } from "./apple-sign-in.ts";
import { createRevokeAppleHandler } from "./http-revoke-apple.ts";
import { createLinkedAppleIds } from "./linked-identities.ts";

const APPLE_ID = "001234.abcdef0123456789.1234";
const OTHER_APPLE_ID = "009999.fedcba9876543210.9999";
const SUPABASE_URL = "https://project.supabase.co";
const PUBLISHABLE_KEY = "sb_publishable_test";
const ACCESS_TOKEN = "header.payload.signature";
const CODE = "c0de.0.authorization";
const REFRESH_TOKEN = "r.refresh-token";

/**
 * A throwaway Sign in with Apple key, made for each test run: Apple's .p8 is
 * an ES256 (P-256) private key in PKCS #8 PEM, and so is this one. The real
 * key lives only in the agent's Vercel environment.
 */
function throwawayKey(): { key: AppleSignInKey; publicKey: KeyObject } {
  const { privateKey, publicKey } = generateKeyPairSync("ec", {
    namedCurve: "P-256",
  });
  return {
    key: {
      privateKey: privateKey
        .export({ format: "pem", type: "pkcs8" })
        .toString(),
      keyId: "KEYID12345",
      teamId: "TEAMID1234",
      clientId: "de.emotely.emotely",
    },
    publicKey,
  };
}

/** What Apple's /auth/token answers: the id_token names the Apple ID. */
async function appleIdToken(
  sub: string,
  claims: { aud?: string; iss?: string } = {},
): Promise<string> {
  // Unsigned: the agent reads the id_token it fetched itself over TLS from
  // Apple with its own client secret, so its provenance is the request.
  return new UnsecuredJWT({ email: "x@privaterelay.appleid.com" })
    .setIssuer(claims.iss ?? "https://appleid.apple.com")
    .setAudience(claims.aud ?? "de.emotely.emotely")
    .setSubject(sub)
    .setIssuedAt()
    .setExpirationTime("10m")
    .encode();
}

type Answer = Response | (() => Response) | Error;

type Call = {
  url: string;
  init: RequestInit | undefined;
  form: URLSearchParams;
};

/**
 * Apple and Supabase, scripted per URL: each call takes the next answer for
 * its endpoint and is recorded, form body decoded, so a test can say what
 * reached which host.
 */
function network(script: Record<string, Answer[]>) {
  const calls: Call[] = [];
  const fetchImpl = async (
    input: string | URL | Request,
    init?: RequestInit,
  ): Promise<Response> => {
    const url = input instanceof Request ? input.url : input.toString();
    calls.push({
      url,
      init,
      form: new URLSearchParams(
        typeof init?.body === "string" ? init.body : "",
      ),
    });
    const answer = script[url]?.shift();
    if (answer === undefined) {
      throw new Error(`unscripted request to ${url}`);
    }
    if (answer instanceof Error) {
      throw answer;
    }
    return typeof answer === "function" ? answer() : answer;
  };
  return {
    fetch: fetchImpl,
    calls,
    to: (url: string) => calls.filter((call) => call.url === url),
  };
}

const USER_URL = `${SUPABASE_URL}/auth/v1/user`;
const TOKEN_URL = "https://appleid.apple.com/auth/token";
const REVOKE_URL = "https://appleid.apple.com/auth/revoke";

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** Supabase's user object, with the identities the account signs in with. */
function user(identities: { provider: string; id: string }[]): Response {
  return json(200, {
    id: "user-1",
    identities: identities.map((identity) => ({
      identity_id: "00000000-0000-0000-0000-000000000001",
      user_id: "user-1",
      identity_data: { sub: identity.id },
      ...identity,
    })),
  });
}

async function tokens(sub = APPLE_ID, claims = {}): Promise<Response> {
  return json(200, {
    access_token: "a.access-token",
    token_type: "Bearer",
    expires_in: 3600,
    refresh_token: REFRESH_TOKEN,
    id_token: await appleIdToken(sub, claims),
  });
}

function setUp(
  script: Record<string, Answer[]>,
  opts: { signedIn?: boolean } = {},
) {
  const net = network(script);
  const { key, publicKey } = throwawayKey();
  const failures: unknown[] = [];
  const handler = createRevokeAppleHandler({
    verifyCaller: async () =>
      opts.signedIn === false ? undefined : { userId: "user-1" },
    linkedAppleIds: createLinkedAppleIds({
      supabaseUrl: SUPABASE_URL,
      publishableKey: PUBLISHABLE_KEY,
      fetch: net.fetch,
    }),
    apple: createAppleClient(key, net.fetch),
    onFailure: (error) => failures.push(error),
  });
  return { net, key, publicKey, failures, handler };
}

function post(body: unknown = { authorization_code: CODE }): Request {
  return new Request("http://x/api/revoke-apple", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${ACCESS_TOKEN}`,
    },
    body: JSON.stringify(body),
  });
}

async function codeOf(response: Response): Promise<string> {
  return errorResponse.parse(await response.json()).code;
}

describe("revoke-apple handler", () => {
  it("trades the code for a token and revokes it for the linked Apple ID", async () => {
    const { net, key, publicKey, failures, handler } = setUp({
      [USER_URL]: [user([{ provider: "apple", id: APPLE_ID }])],
      [TOKEN_URL]: [await tokens()],
      [REVOKE_URL]: [new Response(null, { status: 200 })],
    });

    const response = await handler(post());

    assert.equal(response.status, 200);
    assert.deepEqual(revokeAppleResponse.parse(await response.json()), {
      status: "revoked",
    });
    // The identity came from Supabase under the caller's own token.
    const [lookup] = net.to(USER_URL);
    const headers = new Headers(lookup?.init?.headers);
    assert.equal(headers.get("authorization"), `Bearer ${ACCESS_TOKEN}`);
    assert.equal(headers.get("apikey"), PUBLISHABLE_KEY);
    // The code went to Apple as a native app's grant: no redirect_uri.
    const [exchange] = net.to(TOKEN_URL);
    assert.equal(exchange?.form.get("grant_type"), "authorization_code");
    assert.equal(exchange?.form.get("code"), CODE);
    assert.equal(exchange?.form.get("client_id"), "de.emotely.emotely");
    assert.equal(exchange?.form.has("redirect_uri"), false);
    // And the refresh token it got back is the one revoked.
    const [revoke] = net.to(REVOKE_URL);
    assert.equal(revoke?.form.get("token"), REFRESH_TOKEN);
    assert.equal(revoke?.form.get("token_type_hint"), "refresh_token");
    assert.equal(revoke?.form.get("client_id"), "de.emotely.emotely");
    assert.deepEqual(failures, []);
    // Both calls authenticate with a client secret signed by the key.
    for (const call of [exchange, revoke]) {
      const secret = call?.form.get("client_secret") ?? "";
      assert.deepEqual(decodeProtectedHeader(secret), {
        alg: "ES256",
        kid: key.keyId,
      });
      const { payload } = await jwtVerify(secret, publicKey, {
        issuer: key.teamId,
        audience: "https://appleid.apple.com",
        subject: key.clientId,
      });
      // Minted per request and short-lived: nothing to rotate, and a
      // secret that leaks is dead within minutes.
      assert.ok((payload.exp ?? 0) - (payload.iat ?? 0) <= 300);
    }
  });

  it("refuses a caller it cannot identify before anything else", async () => {
    const { net, handler } = setUp({}, { signedIn: false });

    const response = await handler(post());

    assert.equal(response.status, 401);
    assert.equal(await codeOf(response), "unauthorized");
    assert.deepEqual(net.calls, []);
  });

  it("answers only POST", async () => {
    const { net, handler } = setUp({});

    const response = await handler(
      new Request("http://x/api/revoke-apple", { method: "GET" }),
    );

    assert.equal(response.status, 405);
    assert.equal(await codeOf(response), "method_not_allowed");
    assert.deepEqual(net.calls, []);
  });

  it("refuses a body that is not the contract's before Apple is asked", async () => {
    for (const body of [{}, { authorization_code: "" }, "not json"]) {
      const { net, handler } = setUp({});

      const response = await handler(post(body));

      assert.equal(response.status, 400);
      assert.equal(await codeOf(response), "malformed_request");
      assert.deepEqual(net.calls, []);
    }
  });

  it("asks Apple nothing for an account with no Apple identity", async () => {
    const { net, failures, handler } = setUp({
      [USER_URL]: [user([{ provider: "email", id: "user-1" }])],
    });

    const response = await handler(post());

    assert.equal(response.status, 403);
    assert.equal(await codeOf(response), "apple_identity_mismatch");
    assert.equal(net.to(TOKEN_URL).length, 0);
    assert.deepEqual(failures, []);
  });

  it("revokes nothing when the code is for another Apple ID", async () => {
    const { net, failures, handler } = setUp({
      [USER_URL]: [user([{ provider: "apple", id: APPLE_ID }])],
      [TOKEN_URL]: [await tokens(OTHER_APPLE_ID)],
    });

    const response = await handler(post());

    assert.equal(response.status, 403);
    assert.equal(await codeOf(response), "apple_identity_mismatch");
    assert.equal(net.to(REVOKE_URL).length, 0);
    // A user picking another Apple ID is not an outage.
    assert.deepEqual(failures, []);
  });

  it("takes the caller's lapsed session as a lapsed sign-in", async () => {
    const { net, handler } = setUp({
      [USER_URL]: [json(401, { code: 401, msg: "invalid JWT" })],
    });

    const response = await handler(post());

    assert.equal(response.status, 401);
    assert.equal(await codeOf(response), "unauthorized");
    assert.equal(net.to(TOKEN_URL).length, 0);
  });

  it("reports and refuses when Supabase cannot say who is linked", async () => {
    const { net, failures, handler } = setUp({
      [USER_URL]: [json(500, { msg: "boom" })],
    });

    const response = await handler(post());

    assert.equal(response.status, 502);
    assert.equal(await codeOf(response), "apple_revocation_unavailable");
    assert.equal(net.to(TOKEN_URL).length, 0);
    assert.equal(failures.length, 1);
  });

  it("reports and refuses when Apple will not take the code", async () => {
    const { net, failures, handler } = setUp({
      [USER_URL]: [user([{ provider: "apple", id: APPLE_ID }])],
      [TOKEN_URL]: [json(400, { error: "invalid_grant" })],
    });

    const response = await handler(post());

    assert.equal(response.status, 502);
    assert.equal(await codeOf(response), "apple_revocation_unavailable");
    assert.equal(net.to(REVOKE_URL).length, 0);
    assert.equal(
      String(failures[0]),
      "AppleRequestError: token 400 invalid_grant",
    );
  });

  it("reports and refuses when Apple will not revoke", async () => {
    const { failures, handler } = setUp({
      [USER_URL]: [user([{ provider: "apple", id: APPLE_ID }])],
      [TOKEN_URL]: [await tokens()],
      [REVOKE_URL]: [json(400, { error: "invalid_client" })],
    });

    const response = await handler(post());

    assert.equal(response.status, 502);
    assert.equal(await codeOf(response), "apple_revocation_unavailable");
    assert.equal(
      String(failures[0]),
      "AppleRequestError: revoke 400 invalid_client",
    );
  });

  it("reports and refuses when Apple cannot be reached", async () => {
    const { failures, handler } = setUp({
      [USER_URL]: [user([{ provider: "apple", id: APPLE_ID }])],
      [TOKEN_URL]: [new TypeError("fetch failed")],
    });

    const response = await handler(post());

    assert.equal(response.status, 502);
    assert.equal(await codeOf(response), "apple_revocation_unavailable");
    assert.equal(String(failures[0]), "AppleRequestError: token unreachable");
  });

  it("trusts no id_token that Apple did not issue for this app", async () => {
    for (const claims of [
      { aud: "com.someone.else" },
      { iss: "https://evil.example" },
    ]) {
      const { net, failures, handler } = setUp({
        [USER_URL]: [user([{ provider: "apple", id: APPLE_ID }])],
        [TOKEN_URL]: [await tokens(APPLE_ID, claims)],
      });

      const response = await handler(post());

      assert.equal(response.status, 502);
      assert.equal(await codeOf(response), "apple_revocation_unavailable");
      assert.equal(net.to(REVOKE_URL).length, 0);
      assert.equal(failures.length, 1);
    }
  });

  it("refuses a key that is not a P-256 key at the first request", async () => {
    // A key pasted wrong fails loudly where it is used, not silently later.
    const { key } = throwawayKey();
    const client = createAppleClient(
      {
        ...key,
        privateKey:
          "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----",
      },
      async () => tokens(),
    );
    await assert.rejects(client.exchange(CODE));
  });
});
