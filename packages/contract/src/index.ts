import { z } from "zod";

const nonemptyString = z.string().min(1);

export const answerValueSchemas = {
  color: z.array(z.string().regex(/^#[0-9A-Fa-f]{6}$/)).nonempty(),
  emoji: z.array(nonemptyString).nonempty(),
  longtext: nonemptyString,
  rating: z.int().min(1).max(10),
  text_list: z.array(nonemptyString).nonempty(),
};

export const answerTypes = [
  "color",
  "emoji",
  "longtext",
  "rating",
  "text_list",
] as const;
export type AnswerType = (typeof answerTypes)[number];

const answerVariant = <T extends AnswerType>(t: T) =>
  z.object({
    answer_type: z.literal(t),
    value: answerValueSchemas[t],
  });

// Nested under `answer` (not a top-level union): some providers reject tool
// schemas whose root is not type "object" (hit live with Bedrock via gateway).
export const answer = z.discriminatedUnion("answer_type", [
  answerVariant("color"),
  answerVariant("emoji"),
  answerVariant("longtext"),
  answerVariant("rating"),
  answerVariant("text_list"),
]);
export type Answer = z.infer<typeof answer>;

export const recordAnswerInput = z.object({
  question_id: nonemptyString,
  answer,
});
export type RecordAnswerInput = z.infer<typeof recordAnswerInput>;

export const askQuestionInput = z.object({
  question_id: nonemptyString,
  question: nonemptyString,
  answer_type: z.enum(answerTypes),
});
export type AskQuestionInput = z.infer<typeof askQuestionInput>;

export const completeSessionInput = z.object({
  summary: nonemptyString,
});
export type CompleteSessionInput = z.infer<typeof completeSessionInput>;

// The HTTP envelope of `POST /api/advance-session`. Wire keys are snake_case
// end to end, like the tool payloads above; the agent (producer) and the app
// (consumer) both pin against the JSON Schema emitted from these.
const jsonValue = z.json();

// Bare semver (`pubspec.yaml` `version` without the build number): the app
// reports it, the server gates on it and names the minimum it still serves.
const appVersion = z.string().regex(/^\d+\.\d+\.\d+$/);

// The longest answer the agent accepts: `JSON.stringify(value).length`, in
// UTF-16 code units, so escapes, quotes, list punctuation and the second half
// of every emoji count. The app caps its inputs to it, so an answer it sends
// always fits; JSON Schema cannot state a length of an encoding, so it is
// emitted beside the shapes under `limits`. Installed apps enforce the value
// they were built with: lowering it needs a minimum-app-version bump with it
// (ADR 0008).
export const maxAnswerLength = 4096;

// The longest display name the agent takes, after trimming, in Unicode code
// points — Dart's `runes.length` and the `profiles` table's check, so a name
// the profile holds is always one the agent takes. zod counts code points
// for a string's `max` (JSON Schema's `maxLength` means the same), so forty
// emoji fit. Emitted under `limits` for the app to cap its name field with.
export const maxDisplayNameLength = 40;

// A BCP 47 language tag as Flutter's `Locale.toLanguageTag()` writes it: a
// language, then an optional script and an optional region ("de", "de-AT",
// "zh-Hant-TW", "es-419"). No variants or extensions: the app never has one.
const languageTag =
  /^[A-Za-z]{2,3}(?:-[A-Za-z]{4})?(?:-(?:[A-Za-z]{2}|\d{3}))?$/;

// Who the session is for, beyond the signed-in user id: what the companion may
// know about the person it talks to (#204). Every member is optional so the
// object grows without breaking anyone — `local_date` and `time_zone` are
// expected next, each added here as one more optional key. What reaches the
// model provider is listed in the app-privacy notice, and personal data among
// it is named by the journal consent wording (`consent_text.dart`).
export const userContext = z.object({
  // What the user wants to be called: the name they typed, or the playful
  // placeholder emotely picked when they preferred not to give one. Any
  // script; one line, so it can only ever be a name in the prompt, never a
  // layout of its own: no control character (Cc), no line or paragraph
  // separator (U+2028, U+2029, which JSON.stringify leaves unescaped) and no
  // bidirectional embedding, override or isolate (U+202A–U+202E,
  // U+2066–U+2069), which would reorder the text around the name. Other
  // invisible format characters stay allowed — ZWJ builds emoji, ZWNJ spells
  // Persian and Indic names — the same rule as the `profiles` table's checks
  // and Dart's `DisplayName.check` (#214).
  display_name: z
    .string()
    .trim()
    .min(1)
    .max(maxDisplayNameLength)
    .regex(/^[^\p{Cc}\u2028\u2029\u202A-\u202E\u2066-\u2069]*$/u)
    .optional(),
  // True when `display_name` is that placeholder rather than a real name.
  name_is_placeholder: z.boolean().optional(),
  // The language the app shows (#228): the locale it resolved from the
  // device's preferences against the ones it ships, not the device's own
  // list, so the companion speaks what the screen does. Today that is a
  // bare language ("en", "de"), since the app ships no regional variant;
  // the agent reads the language subtag and speaks English for any it does
  // not know. One it cannot read is dropped on its own, not with the whole
  // context: the round runs in English and still knows the user's name.
  locale: z.string().regex(languageTag).optional().catch(undefined),
});
export type UserContextWire = z.infer<typeof userContext>;

export const advanceSessionRequest = z.object({
  transcript: z.array(z.unknown()).optional(),
  signature: z.string().optional(),
  answer: z
    .object({ tool_call_id: nonemptyString, value: jsonValue })
    .optional(),
  // Optional on the wire so clients that predate it keep working (additive
  // change); the app always sends it.
  app_version: appVersion.optional(),
  // Optional for the same reason (ADR 0009 rule 1): apps that predate it
  // omit it, and so does an app that knows nothing about the user yet. One
  // that does not validate is dropped rather than refused: a name is a
  // nicety, and a session is not worth failing over one — the round runs as
  // if the app had sent nothing, which is what an older app does anyway.
  user_context: userContext.optional().catch(undefined),
});
export type AdvanceSessionRequest = z.infer<typeof advanceSessionRequest>;

const advanceSessionBase = {
  transcript: z.array(z.unknown()),
  signature: nonemptyString,
  prompt_id: nonemptyString,
};

export const advanceSessionResponse = z.discriminatedUnion("status", [
  z.object({
    status: z.literal("awaiting_answer"),
    ...advanceSessionBase,
    pending: z.object({
      tool_call_id: nonemptyString,
      question: askQuestionInput,
    }),
  }),
  z.object({
    status: z.literal("completed"),
    ...advanceSessionBase,
    entry: z.object({
      summary: nonemptyString,
      answers: z.record(nonemptyString, answer),
    }),
  }),
]);
export type AdvanceSessionResponse = z.infer<typeof advanceSessionResponse>;

// Every non-200 answer of the agent. `code` is what the app acts on and turns
// into its own, localized copy; `error` is English for logs and for apps that
// predate `code`, and never reaches a screen once the app reads `code`. The set
// is closed: a new failure is a new code, added before the app that reads it
// (ADR 0009 rule 3).
export const errorCodes = [
  // No live sign-in on the request: the app renews its token and resends.
  "unauthorized",
  // The transcript is not one this server signed: the session cannot go on.
  "invalid_signature",
  // Past the message cap: the session cannot go on either.
  "transcript_too_long",
  "answer_too_large",
  "answer_mismatch",
  "malformed_request",
  "method_not_allowed",
  // The gateway refused the round; waiting is what helps.
  "model_unavailable",
] as const;

export const errorResponse = z.object({
  code: z.enum(errorCodes),
  error: z.string(),
});
export type ErrorResponse = z.infer<typeof errorResponse>;
export type ErrorCode = ErrorResponse["code"];

// The startup config the app fetches once, before its first session
// (`GET /api/config`). It carries what the app must know before it may run and
// what no session round should have to repeat: the force-update threshold and
// where to go when it trips. Held apart from the session envelope so the
// version gate is not a session concern (#49) and so this stays cacheable at
// the edge — it is the same for every caller and needs no auth.
export const configResponse = z.object({
  // Below this the app must update before it may start a session; compared
  // against the `app_version` it reports on every session request.
  min_app_version: appVersion,
  // Where the force-update screen sends the user. Server-controlled so the
  // store link can change without an app release — which matters most for the
  // users who cannot get one, since they are the ones being sent there.
  // http(s) only: the app hands this to the platform URL launcher.
  store_url: z.url({ protocol: /^https?$/ }),
});
export type ConfigResponse = z.infer<typeof configResponse>;
