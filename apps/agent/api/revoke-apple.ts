import process from "node:process";
import { waitUntil } from "@vercel/functions";
import { createAppleClient } from "../src/apple-sign-in.ts";
import { createRevokeAppleHandler } from "../src/http-revoke-apple.ts";
import { createLinkedAppleIds } from "../src/linked-identities.ts";
import { createCallerVerifier, supabaseAuth } from "../src/request-auth.ts";
import {
  flushTelemetry,
  initTelemetry,
  reportError,
} from "../src/telemetry.ts";

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}

// Public by design (both are in the app too): the project whose users may
// call, and the key its gateway asks of every request.
const supabaseUrl = required("SUPABASE_URL");
const publishableKey = required("SUPABASE_PUBLISHABLE_KEY");

// The Sign in with Apple key (#193). Only APPLE_SIGN_IN_KEY is a secret; the
// release-app skill's signing reference says how it is created, stored and
// rotated. A PEM pasted as one line with literal "\n"s is read as the file.
const apple = createAppleClient({
  privateKey: required("APPLE_SIGN_IN_KEY").replaceAll(String.raw`\n`, "\n"),
  keyId: required("APPLE_SIGN_IN_KEY_ID"),
  teamId: required("APPLE_TEAM_ID"),
  clientId: required("APPLE_CLIENT_ID"),
});

const posthogKey = process.env["POSTHOG_KEY"];
const posthogHost = process.env["POSTHOG_HOST"];
if (posthogKey && !posthogHost) {
  throw new Error("POSTHOG_KEY is set but POSTHOG_HOST is not — set both.");
}
initTelemetry(
  posthogKey && posthogHost
    ? { posthog: { projectToken: posthogKey, host: posthogHost } }
    : {},
);

const handler = createRevokeAppleHandler({
  verifyCaller: createCallerVerifier(supabaseAuth(supabaseUrl)),
  linkedAppleIds: createLinkedAppleIds({ supabaseUrl, publishableKey }),
  apple,
  // A refusal leaves a grant in place that the user then has to remove by
  // hand; a run of them means the key or Apple is broken for everyone.
  onFailure: (error) => {
    reportError(error, { step: "apple_revocation" });
  },
});

export function POST(request: Request): Promise<Response> {
  const response = handler(request);
  waitUntil(response.then(() => flushTelemetry()));
  return response;
}
