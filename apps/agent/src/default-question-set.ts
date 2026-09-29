import type { QuestionSet } from "./session.ts";

// The legacy app's built-in set ("Legacy Reflections"); question texts
// carried over, ids renamed to readable slugs (fresh backend, no migration).
// The German texts (#228) are what a German app shows, word for word: the
// client is shown the set's wording, never the model's. They follow
// CONTEXT.md — "du", never "Sie" — and keep each question's meaning and
// count rather than its English phrasing. The ids never change with them:
// stored sessions and PostHog events name them.
export const defaultQuestionSet: QuestionSet = {
  id: "legacy-reflections",
  name: "Legacy Reflections",
  questions: [
    {
      id: "learned-today",
      text: "What did you learn today?",
      translations: { de: "Was hast du heute gelernt?" },
      answer_type: "text_list",
    },
    {
      id: "best-thing",
      text: "What was the best thing that happened today?",
      translations: { de: "Was war das Schönste, das dir heute passiert ist?" },
      answer_type: "longtext",
    },
    {
      id: "day-colors",
      text: "Which color(s) best describe your day?",
      translations: { de: "Welche Farbe(n) beschreiben deinen Tag am besten?" },
      answer_type: "color",
    },
    {
      id: "mood-emojis",
      text: "Which emojis describe your mood during different parts of your day?",
      translations: {
        de: "Welche Emojis beschreiben deine Stimmung im Laufe des Tages?",
      },
      answer_type: "emoji",
    },
    {
      id: "productivity",
      text: "How productive did you feel today?",
      translations: { de: "Wie produktiv hast du dich heute gefühlt?" },
      answer_type: "rating",
    },
    {
      id: "satisfaction",
      text: "How satisfied are you with your day?",
      translations: { de: "Wie zufrieden bist du mit deinem Tag?" },
      answer_type: "rating",
    },
    {
      id: "appreciation",
      text: "How much appreciation did you feel for the small victories or moments in your life today?",
      translations: {
        de: "Wie sehr hast du heute die kleinen Erfolge und Momente in deinem Leben wertgeschätzt?",
      },
      answer_type: "rating",
    },
    {
      id: "gratitude-list",
      text: "List down at least 3 things that you're grateful for today.",
      translations: {
        de: "Nenne mindestens 3 Dinge, für die du heute dankbar bist.",
      },
      answer_type: "text_list",
      min_answers: 3,
    },
    {
      id: "goal-alignment",
      text: "How well did your actions today align with the goals you want to achieve?",
      translations: {
        de: "Wie gut hat das, was du heute getan hast, zu den Zielen gepasst, die du erreichen willst?",
      },
      answer_type: "rating",
    },
    {
      id: "gratitude-person",
      text: "Share about someone you're grateful for today and how they positively impact your life.",
      translations: {
        de: "Erzähl von jemandem, für den du heute dankbar bist, und wie diese Person dein Leben bereichert.",
      },
      answer_type: "longtext",
    },
  ],
};
