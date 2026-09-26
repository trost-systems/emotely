import process from "node:process";
import { waitUntil } from "@vercel/functions";
import { modelMessageSchema } from "ai";
import { z } from "zod";
import { defaultQuestionSet } from "../src/default-question-set.ts";
import { createAdvanceSessionHandler } from "../src/http-advance-session.ts";
import { createCallerVerifier, supabaseAuth } from "../src/request-auth.ts";
import { DEFAULT_MODEL } from "../src/session-config.ts";
import { advanceSession } from "../src/session-core.ts";
import {
  flushTelemetry,
  initTelemetry,
  reportError,
} from "../src/telemetry.ts";

const secret = process.env["SESSION_SIGNING_SECRET"];
if (!secret) {
  throw new Error("SESSION_SIGNING_SECRET is required");
}
// Set only for the grace window of a rotation (ADR 0009 rule 5; runbook in
// ../README.md). Unset in normal operation; the verifier treats "" as unset.
const previousSecret = process.env["SESSION_SIGNING_SECRET_PREVIOUS"];
// Public by design (it is in the app too): the project whose users may call.
const supabaseUrl = process.env["SUPABASE_URL"];
if (!supabaseUrl) {
  throw new Error("SUPABASE_URL is required");
}
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

const model = process.env["EMOTELY_MODEL"] ?? DEFAULT_MODEL;
const transcriptSchema = z.array(modelMessageSchema);

const handler = createAdvanceSessionHandler({
  secret,
  ...(previousSecret === undefined ? {} : { previousSecret }),
  verifyCaller: createCallerVerifier(supabaseAuth(supabaseUrl)),
  // A gateway refusal is the outage signal (issue #99): without it the only
  // alarm is the nightly smoke, so a model whose providers stop qualifying
  // takes the app down for up to a day unnoticed.
  onFailure: (error) => {
    reportError(error, { step: "session_round", model });
  },
  advance: ({ messages, answer, userContext }) =>
    advanceSession({
      questionSet: defaultQuestionSet,
      model,
      // Signature-verified, so a parse failure here is a server bug, not
      // client input — let it 500 loudly.
      messages: transcriptSchema.parse(messages),
      ...(answer === undefined ? {} : { answer }),
      ...(userContext === undefined ? {} : { userContext }),
    }),
});

export function POST(request: Request): Promise<Response> {
  const response = handler(request);
  waitUntil(response.then(() => flushTelemetry()));
  return response;
}
