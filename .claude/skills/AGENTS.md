# .claude/skills — the project's skills

A skill covers one task, the one its name says. A step or fact that serves
another task belongs in that task's skill, a new one when none covers it:
how to open a pull request is `open-pr`, not `run-app`, even when a
`run-app` script does part of the work.

Skills use progressive disclosure. A `SKILL.md` is loaded whole on every
invocation, so it holds what every invocation needs: the steps, and the
facts each branch of the task relies on. Material that only some branches
reach — one provider's setup, a console's field-by-field answers, a rare
recovery — lives in `references/<topic>.md` beside it, behind a one-line
pointer in `SKILL.md` that opens with the situation calling for it:
"Changing X — read [references/x.md](references/x.md) first." Scripts a
skill runs live in `scripts/`.

Creating or updating a skill, place each new piece on that ladder before
writing it, and move a `SKILL.md` section down to `references/` once it
serves a single branch.
