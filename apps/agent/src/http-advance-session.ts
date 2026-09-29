import {
  type AdvanceSessionRequest,
  type AdvanceSessionResponse,
  advanceSessionRequest,
  type ErrorCode,
  type ErrorResponse,
  maxAnswerLength,
  type UserContextWire,
} from "@emotely/contract";
import { classifyModelFailure } from "./error-tracking.ts";
import type { VerifyCaller } from "./request-auth.ts";
import type {
  AdvanceResult,
  SessionAnswer,
  UserContext,
} from "./session-core.ts";
import { signTranscript, verifyTranscript } from "./transcript-auth.ts";

const MAX_TRANSCRIPT_MESSAGES = 200;
const HTTP_OK = 200;
const HTTP_BAD_REQUEST = 400;
const HTTP_UNAUTHORIZED = 401;
const HTTP_METHOD_NOT_ALLOWED = 405;
const HTTP_PAYLOAD_TOO_LARGE = 413;

// The wire envelope (snake_case keys) is owned by packages/contract; the
// TypeScript-side types stay camelCase.
type Advance = (input: {
  messages: unknown[];
  answer?: SessionAnswer;
  /** The signed-in user the round runs for. */
  userId: string;
  /** Who that user is, when the app said and it validated (#204). */
  userContext?: UserContext;
}) => Promise<AdvanceResult>;

/**
 * The wire's `user_context` in the agent's own casing. The contract has
 * already trimmed and validated it, or dropped it when it did not validate.
 */
function userContextOf(wire: UserContextWire): UserContext {
  return {
    ...(wire.display_name === undefined
      ? {}
      : { displayName: wire.display_name }),
    ...(wire.name_is_placeholder === undefined
      ? {}
      : { nameIsPlaceholder: wire.name_is_placeholder }),
    ...(wire.locale === undefined ? {} : { locale: wire.locale }),
  };
}

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

function validate(
  parsed: AdvanceSessionRequest,
  secret: string,
  previousSecret: string | undefined,
): { error: Response } | { error?: never; transcript: unknown[] } {
  const { transcript, signature, answer } = parsed;
  if (transcript === undefined) {
    return { transcript: [] };
  }
  if (
    signature === undefined ||
    !verifyTranscript(transcript, signature, secret, previousSecret)
  ) {
    return {
      error: fail(HTTP_UNAUTHORIZED, "invalid_signature", "invalid signature"),
    };
  }
  if (transcript.length > MAX_TRANSCRIPT_MESSAGES) {
    return {
      error: fail(
        HTTP_PAYLOAD_TOO_LARGE,
        "transcript_too_long",
        "transcript too long",
      ),
    };
  }
  if (
    answer !== undefined &&
    JSON.stringify(answer.value).length > maxAnswerLength
  ) {
    return {
      error: fail(HTTP_BAD_REQUEST, "answer_too_large", "answer too large"),
    };
  }
  return { transcript };
}

async function runAdvance(opts: {
  advance: Advance;
  transcript: unknown[];
  parsed: AdvanceSessionRequest;
  userId: string;
  onFailure: ((error: unknown) => void) | undefined;
}): Promise<AdvanceResult | Response> {
  const { parsed } = opts;
  try {
    return await opts.advance({
      messages: opts.transcript,
      userId: opts.userId,
      ...(parsed.user_context === undefined
        ? {}
        : { userContext: userContextOf(parsed.user_context) }),
      ...(parsed.answer === undefined
        ? {}
        : {
            answer: {
              toolCallId: parsed.answer.tool_call_id,
              value: parsed.answer.value,
            } as SessionAnswer,
          }),
    });
  } catch (error) {
    if (
      error instanceof Error &&
      error.message.includes("does not match the pending question")
    ) {
      return fail(HTTP_BAD_REQUEST, "answer_mismatch", "answer mismatch");
    }
    // The gateway refused the round — most sharply when no provider satisfies
    // the fail-closed privacy filters, which breaks *every* session rather
    // than this one (ADR 0003 amendment). That must not look like a generic
    // 500: it gets its own status and its own reported signal, so the alarm
    // is the report rather than the nightly smoke a day later.
    const failure = classifyModelFailure(error);
    if (failure === undefined) {
      throw error;
    }
    opts.onFailure?.(error);
    // The gateway's message stays server-side: it names models and providers
    // the client has no business seeing, and the client only ever needed to
    // know the round is not retryable by resending.
    return fail(failure.status, "model_unavailable", "model unavailable");
  }
}

/**
 * The stateless session endpoint: the client echoes the signed transcript and
 * its widget answer; the server advances to the next question or the entry.
 * Caller-first, then signature-first: only a signed-in user gets a body read,
 * and nothing reaches the model unless this server produced it.
 */
export function createAdvanceSessionHandler(deps: {
  /** Signs every response; the only secret that verifies outside a rotation. */
  secret: string;
  /**
   * The secret being retired, set only for the grace window of a rotation
   * (ADR 0009 rule 5). Transcripts signed with it still verify and come back
   * signed with `secret`, so an in-flight session migrates on its next round.
   */
  previousSecret?: string;
  advance: Advance;
  /** Who is calling; `undefined` is a 401 (ADR 0010). */
  verifyCaller: VerifyCaller;
  /**
   * Called with the raw error when the gateway refuses a round, before the
   * 502 goes out. Wired to PostHog error tracking in `api/advance-session.ts`;
   * left unset in tests and the CLI. It must not throw — the reporter it is
   * given swallows its own failures (ADR 0004).
   */
  onFailure?: (error: unknown) => void;
}) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return fail(HTTP_METHOD_NOT_ALLOWED, "method_not_allowed", "POST only");
    }
    const caller = await deps.verifyCaller(request);
    if (caller === undefined) {
      return fail(HTTP_UNAUTHORIZED, "unauthorized", "unauthorized");
    }
    let parsed: AdvanceSessionRequest;
    try {
      parsed = advanceSessionRequest.parse(await request.json());
    } catch {
      return fail(HTTP_BAD_REQUEST, "malformed_request", "malformed request");
    }
    // A fresh session must not smuggle an oversized answer either.
    if (
      parsed.answer !== undefined &&
      JSON.stringify(parsed.answer.value).length > maxAnswerLength
    ) {
      return fail(HTTP_BAD_REQUEST, "answer_too_large", "answer too large");
    }
    const checked = validate(parsed, deps.secret, deps.previousSecret);
    if (checked.error) {
      return checked.error;
    }

    const outcome = await runAdvance({
      advance: deps.advance,
      transcript: checked.transcript,
      parsed,
      userId: caller.userId,
      onFailure: deps.onFailure,
    });
    if (outcome instanceof Response) {
      return outcome;
    }
    const result = outcome;

    const base = {
      transcript: result.messages,
      signature: signTranscript(result.messages, deps.secret),
      prompt_id: result.promptId,
    };
    if (result.status === "completed") {
      return json(HTTP_OK, {
        status: "completed",
        ...base,
        entry: result.entry,
      } satisfies AdvanceSessionResponse);
    }
    return json(HTTP_OK, {
      status: "awaiting_answer",
      ...base,
      pending: {
        tool_call_id: result.pending.toolCallId,
        question: result.pending.input,
      },
    } satisfies AdvanceSessionResponse);
  };
}
