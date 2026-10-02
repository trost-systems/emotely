# State management stays on bloc, with four conditions to revisit

The Flutter client keeps `flutter_bloc` for state management, at the
versions `apps/mobile/pubspec.lock` resolves: `flutter_bloc` 9.1.1 and
`bloc` 9.2.1. We weighed a move to Riverpod on 2026-09-22 and decided against
it for now. The decision is not permanent: it is revisited as soon as any one
of the four conditions below holds.

## Why the question came up

Agents build this app end to end, so a dependency that will not help agents
is a risk worth measuring. bloc's maintainer, Felix Angelov, has said
publicly that he will not ship agent tooling. In February 2025, asked about
AI tools at Shorebird, he said "We currently don't have plans to build any
AI tools". In March 2026 he opposed the Dart proposal to ship agent skills
inside pub packages: "Making LLM output less bad is NOT the responsibility
of package maintainers." That proposal shipped as the Skills CLI 1.0 on
2026-09-08. bloc ships no `skills/` directory, `AGENTS.md`, `llms.txt` or
MCP server, and we should not expect one.

That alone does not justify moving. Riverpod ships no skills either: the
request for them (rrousselGit/riverpod#4758, May 2026) has had no
maintainer reply, and the Riverpod skills that exist come from a third
party, Serverpod's `skills-registry`. Whatever skill we need for bloc, we
can write ourselves, the way we already did for freezed and our tests.

## Signals, as of 2026-09-22

Every number below was measured on 2026-09-22 from the sources listed at the
end. Download counts are pub.dev's 30-day window.

For Riverpod:

- **Adoption and release cadence.** Over the last 30 days `riverpod` had
  3.25M downloads against 2.0M for `bloc`, and `flutter_riverpod` 3.17M
  against 1.86M for `flutter_bloc`. Riverpod released 3.4.3 on 2026-09-03
  and releases roughly monthly. `flutter_bloc` has not released since
  2025-05-02.
- **bloc pull requests wait a long time for review.** 21 are open. They
  include community lint rules for `bloc_lint` (`avoid_async_emit`, since
  August 2025; `avoid_bloc_to_bloc_members`, since November 2025), a
  `bloc_concurrency` stream-closing fix (July 2026), and one PR open since
  2023. Recent commits are mostly dependency bumps and docs. If bloc
  breaks, assume we fix it ourselves.
- **Riverpod has features a journaling app could use:** automatic dispose
  and caching, retry, and pause and resume are stable. Offline persistence
  and mutations exist too, but are still experimental. With bloc we would
  build offline drafts by hand.
- **Switching will never be cheaper.** There are seven Blocs, all small.
  Only `AuthBloc` holds a stream subscription, and none uses an event
  transformer, so the unmerged `bloc_concurrency` fix does not affect us.

For bloc:

- **Riverpod's API keeps changing, and that costs agents.** The 3.0 line
  announced itself, in `3.0.0-dev.12` (2025-04-30), as "a transition
  version… quite possible that a 4.0.0 will be released relatively soon".
  The stable 3.0.0 followed on 2025-09-10. 3.2 deprecated
  `family.overrideWith`, 3.4 deprecated `SyncProviderTransformerMixin`, and
  offline persistence and mutations are "subject to breaking changes".
  `flutter_riverpod` loses 20 of pub.dev's static analysis points, partly
  for using its own deprecated API. Agents write the Riverpod they were
  trained on. Under `flutter analyze --fatal-infos` every deprecation is a
  failed loop, until someone writes a skill for it.
- **bloc barely changes, which helps agents.** A small, stable API that
  appears all over training data is the easiest case for an agent. Felix
  does favor deterministic tooling: "linters are deterministic and
  reliable". `bloc_lint` fits our deny-by-default lint rules.
- **Our architecture assumes bloc.** [ADR 0015](0015-lego-package-layering.md)
  relies on:
  - get_it as the single composition root;
  - Blocs as factories;
  - widgets touching the container only to create their bloc and resolve
    their navigator;
  - side effects modeled as bloc events.

  Riverpod would replace get_it, the registration functions and the
  `add-package` skill, not just seven classes. The real cost of a move is
  rewriting ADR 0015.
- **Explicit event classes suit agents and review.** Every state change is
  a named event that can be logged and tested. Riverpod's provider graph
  has more implicit behavior, such as auto-dispose timing and retry on by
  default. Agents get that wrong in code that compiles and passes review.
- **Code generation is not a deciding factor.** Riverpod pushes
  `riverpod_generator`, but we already run build_runner for freezed.

## Conditions to revisit

Any one of these reopens the decision:

1. **A Flutter or Dart release breaks `flutter_bloc`**, and no fix is
   released within about a month.
2. **A bloc bug that affects us sits unmerged**, and fixing it would mean
   forking.
3. **We need offline persistence or caching** that Riverpod has made stable,
   meaning no longer experimental, and that we would otherwise build by
   hand.
4. **Riverpod ships 4.0, and its API holds steady for about six months.**
   Moving before then risks migrating twice.

## Consequences

- Keep Blocs thin and logic in repositories, so a later move stays a change
  to the presentation layer only. ADR 0015's layering already pushes this
  way.
- Agent knowledge of bloc is our responsibility. A conventions skill or
  `bloc_lint` would sit on our side, not upstream.
- Whoever reopens this decision re-measures the signals above instead of
  trusting these numbers, which date from 2026-09-22.

## Sources

Measured on 2026-09-22:

- Felix Angelov's posts: [Bluesky profile](https://bsky.app/profile/felangel.bsky.social),
  read through the public `app.bsky.feed.getAuthorFeed` API.
- The Dart package-skills proposal he answered:
  [design doc](https://docs.google.com/document/d/1k_X-Sp4GQyZP6k9lvZ1Itj0GvzQZuWl3iKzi5AIa69Q/edit?tab=t.0);
  what shipped: [Skills CLI 1.0](https://dart.dev/blog/skills-cli-1-0-bundle-and-distribute-ai-agent-skills-for-your-packages).
- Downloads, versions and scores: the pub.dev API
  (`https://pub.dev/api/packages/<name>` and `/score`) for `bloc`,
  `flutter_bloc`, `riverpod` and `flutter_riverpod`, and the
  [flutter_riverpod score page](https://pub.dev/packages/flutter_riverpod/score).
- Changelogs: [riverpod](https://pub.dev/packages/riverpod/changelog),
  [bloc](https://pub.dev/packages/bloc/changelog).
- Open pull requests: [felangel/bloc](https://github.com/felangel/bloc/pulls?q=is%3Apr+is%3Aopen).
- Repository contents: [felangel/bloc](https://github.com/felangel/bloc),
  [rrousselGit/riverpod](https://github.com/rrousselGit/riverpod),
  [rrousselGit/riverpod#4758](https://github.com/rrousselGit/riverpod/issues/4758),
  [serverpod/skills-registry](https://github.com/serverpod/skills-registry).
