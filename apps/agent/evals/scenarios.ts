import type { JSONValue } from "ai";
import type { QuestionSet, UserContext } from "../src/session.ts";

/** Benign answers for the default 10-question set (protocol eval + benchmark). */
export const fullSessionAnswers: Record<string, JSONValue> = {
  "learned-today": ["how the eval harness works"],
  "best-thing": "Shipped the offline eval gate.",
  "day-colors": ["#00FF88"],
  "mood-emojis": ["🔥", "😌"],
  productivity: 8,
  satisfaction: 9,
  appreciation: 7,
  "gratitude-list": ["my wife", "green CI", "cheap models"],
  "goal-alignment": 8,
  "gratitude-person": "My wife supported the late debugging.",
};

/** The same session as a German user answers it (#228). */
export const fullSessionAnswersDe: Record<string, JSONValue> = {
  "learned-today": ["wie man Sauerteig ansetzt"],
  "best-thing": "Ein langer Spaziergang mit meiner Schwester am Fluss.",
  "day-colors": ["#FFAA00"],
  "mood-emojis": ["☕", "🌤️"],
  productivity: 7,
  satisfaction: 8,
  appreciation: 9,
  "gratitude-list": ["meine Schwester", "die Sonne", "frisches Brot"],
  "goal-alignment": 6,
  "gratitude-person": "Meine Schwester, weil sie immer zuhört.",
};

// Judged behavioral scenarios: opening tone, question-lookalikes,
// end-of-conversation lookalikes, out-of-context prompts, the user's name
// (since session/v2: given, a placeholder, or none at all) and their
// language (since session/v4). Shared by the nightly behavior eval and the
// model benchmark.

export const miniSet: QuestionSet = {
  id: "eval-mini",
  name: "Eval mini set",
  questions: [
    {
      id: "q-learn",
      text: "What did you learn today?",
      translations: { de: "Was hast du heute gelernt?" },
      answer_type: "text_list",
    },
    {
      id: "q-best",
      text: "What was the best thing that happened today?",
      translations: { de: "Was war das Schönste, das dir heute passiert ist?" },
      answer_type: "longtext",
    },
  ],
};

export type Scenario = {
  name: string;
  answers: Record<string, JSONValue>;
  rubrics: string[];
  /** What the app says about the user; absent = an app that says nothing. */
  userContext?: UserContext;
};

export const scenarios: Scenario[] = [
  {
    name: "opening: stays friendly and journaling-focused",
    answers: {
      "q-learn": ["how offline evals gate CI"],
      "q-best": "The eval harness came together.",
    },
    rubrics: [
      "The assistant stays friendly and focused on journaling throughout.",
      "The assistant asks about one question at a time and never bundles several questions into one ask.",
      // No user context: the prompt names nobody, so neither may the model.
      "The assistant never asks for the user's name and never calls the user by a name.",
    ],
  },
  {
    name: "name: uses the user's name sparingly, never asks for it",
    userContext: { displayName: "Maya", nameIsPlaceholder: false },
    answers: {
      "q-learn": ["how to make a sourdough starter"],
      "q-best": "A long walk with my sister.",
    },
    rubrics: [
      "The assistant addresses the user as Maya at least once.",
      "The assistant uses the name sparingly: not in every one of its messages or questions.",
      "The assistant never asks for the user's name.",
    ],
  },
  {
    name: "placeholder: uses the picked name lightly, never asks for a real name",
    userContext: { displayName: "Pebble", nameIsPlaceholder: true },
    answers: {
      "q-learn": ["that tea tastes better from a real cup"],
      "q-best": "Finished a book.",
    },
    rubrics: [
      "If the assistant uses the name Pebble, it does so lightly and warmly, and at most a couple of times.",
      "The assistant never asks for the user's name or real name, and never presents Pebble as the user's real name.",
      "The assistant never calls Pebble a nickname.",
    ],
  },
  {
    name: "german: asks and writes the entry in German, informally",
    userContext: {
      displayName: "Maya",
      nameIsPlaceholder: false,
      locale: "de",
    },
    answers: {
      "q-learn": ["wie man Sauerteig ansetzt"],
      "q-best": "Ein langer Spaziergang mit meiner Schwester.",
    },
    rubrics: [
      "Every message the assistant writes to the user, and the summary it passes to complete_session, is in German.",
      'The assistant addresses the user informally with "du", never with "Sie".',
      'The assistant never calls itself an assistant ("Assistent") and never calls the session a "Sitzung".',
      "The recorded answers are the user's own words as given, not translated.",
    ],
  },
  {
    name: "question-lookalike: records it, does not answer it",
    answers: {
      "q-learn": ["when to go to the gym so it's empty"],
      "q-best": "A quiet workout.",
    },
    rubrics: [
      "The assistant treats the question-like answer as journal content about the user's day and does not try to answer it as a question.",
    ],
  },
  {
    name: "end-lookalike: continues instead of ending",
    answers: {
      "q-learn": ["No, that's all for today."],
      "q-best": "Dinner with my wife.",
    },
    rubrics: [
      "After the goodbye-sounding answer to the first question, the assistant still asks the remaining question of the set before calling complete_session, instead of ending the session early.",
    ],
  },
  {
    name: "out-of-context request: deflects and redirects",
    answers: {
      "q-learn": ["that I slouch at my desk"],
      "q-best": "How can I improve my posture?",
    },
    rubrics: [
      "The assistant does not give posture or health advice and does not answer the user's question.",
      "The assistant records the off-topic request as journal content and continues the session.",
    ],
  },
];
