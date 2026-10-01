import type { QuestionSet } from "./session.ts";

// The legacy app's built-in set ("Legacy Reflections"); question texts
// carried over, ids renamed to readable slugs (fresh backend, no migration).
// Each question is worded in every language the companion speaks (#228),
// and the client is shown that wording word for word, never the model's.
// The German follows CONTEXT.md — "du", never "Sie" — and keeps each
// question's meaning and count rather than its English phrasing. The ids
// never change with the wording: stored sessions and PostHog events name
// them.
export const defaultQuestionSet: QuestionSet = {
  id: "legacy-reflections",
  name: "Legacy Reflections",
  questions: [
    {
      id: "learned-today",
      text: {
        en: "What did you learn today?",
        de: "Was hast du heute gelernt?",
      },
      answer_type: "text_list",
    },
    {
      id: "best-thing",
      text: {
        en: "What was the best thing that happened today?",
        de: "Was war das Beste, das dir heute passiert ist?",
      },
      answer_type: "longtext",
    },
    {
      id: "day-colors",
      text: {
        en: "Which color(s) best describe your day?",
        de: "Welche Farbe(n) beschreiben deinen Tag am besten?",
      },
      answer_type: "color",
    },
    {
      id: "mood-emojis",
      text: {
        en: "Which emojis describe your mood during different parts of your day?",
        de: "Welche Emojis beschreiben deine Stimmung im Laufe des Tages?",
      },
      answer_type: "emoji",
    },
    {
      id: "productivity",
      text: {
        en: "How productive did you feel today?",
        de: "Wie produktiv hast du dich heute gefühlt?",
      },
      answer_type: "rating",
    },
    {
      id: "satisfaction",
      text: {
        en: "How satisfied are you with your day?",
        de: "Wie zufrieden bist du mit deinem Tag?",
      },
      answer_type: "rating",
    },
    {
      id: "appreciation",
      text: {
        en: "How much appreciation did you feel for the small victories or moments in your life today?",
        de: "Wie sehr hast du heute die kleinen Erfolge und Momente in deinem Leben wertgeschätzt?",
      },
      answer_type: "rating",
    },
    {
      id: "gratitude-list",
      text: {
        en: "List down at least 3 things that you're grateful for today.",
        de: "Nenne mindestens 3 Dinge, für die du heute dankbar bist.",
      },
      answer_type: "text_list",
      min_answers: 3,
    },
    {
      id: "goal-alignment",
      text: {
        en: "How well did your actions today align with the goals you want to achieve?",
        de: "Wie gut hat das, was du heute getan hast, zu den Zielen gepasst, die du erreichen willst?",
      },
      answer_type: "rating",
    },
    {
      id: "gratitude-person",
      text: {
        en: "Share about someone you're grateful for today and how they positively impact your life.",
        de: "Erzähl von jemandem, für den du heute dankbar bist, und wie diese Person dein Leben bereichert.",
      },
      answer_type: "longtext",
    },
  ],
};
