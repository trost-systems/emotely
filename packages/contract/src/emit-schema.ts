import { writeFileSync } from "node:fs";
import { z } from "zod";
import {
  advanceSessionRequest,
  advanceSessionResponse,
  askQuestionInput,
  completeSessionInput,
  configResponse,
  errorResponse,
  maxAnswerLength,
  maxDisplayNameLength,
  recordAnswerInput,
} from "./index.ts";

// CI tripwire: the committed JSON Schema must match the zod source of truth.
// Regenerate with `pnpm --filter @emotely/contract schema`; a diff in CI means
// the TS contract changed without the Dart side (and this file) following.
const schema = {
  ask_question: z.toJSONSchema(askQuestionInput, { io: "input" }),
  record_answer: z.toJSONSchema(recordAnswerInput, { io: "input" }),
  complete_session: z.toJSONSchema(completeSessionInput, { io: "input" }),
  advance_session_request: z.toJSONSchema(advanceSessionRequest, {
    io: "input",
  }),
  advance_session_response: z.toJSONSchema(advanceSessionResponse, {
    io: "input",
  }),
  config_response: z.toJSONSchema(configResponse, { io: "input" }),
  error_response: z.toJSONSchema(errorResponse, { io: "input" }),
  limits: {
    max_answer_length: maxAnswerLength,
    max_display_name_length: maxDisplayNameLength,
  },
};

writeFileSync(
  new URL("../contract.schema.json", import.meta.url),
  `${JSON.stringify(schema, null, 2)}\n`,
);
