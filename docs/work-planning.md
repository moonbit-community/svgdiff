# Roadmap and Issue Tracker Workflow

Status: current planning policy

Last verified: 2026-07-14

The roadmap and Markdown issue tracker serve different purposes:

- [`roadmap.md`](../roadmap.md) is the exhaustive capability backlog, including unscheduled, deferred, and decision-needed work.
- [`issues/`](../issues/) contains only accepted implementation work and immutable execution history.

Do not create one issue for every unchecked roadmap line. That would duplicate the backlog, obscure the ready queue, and make unaccepted design ideas look scheduled.

## Admission criteria

A roadmap item may become an `ISS-###` file only when all of the following are true:

1. The item has been explicitly accepted for implementation, not merely recorded as desirable or deferred.
2. The expected outcome is bounded enough for one issue or a named epic with independently verifiable child slices.
3. Current-contract and design dependencies are known; unresolved **Decision** items receive an ADR or design issue before implementation work.
4. Acceptance criteria can be checked through behavior, tests, artifacts, or explicit documentation.
5. Priority, relevant labels, and hard dependencies can be stated without guessing.
6. The issue is not already represented by an unresolved or historical issue.

An item does not qualify merely because it is `P0`, appears early in a phase, or would be convenient to implement next.

## Duplicate check

Before assigning an ID:

1. search `issues/ISS-*.md` by capability, Diagnostic, package, and external reference;
2. inspect closed issues as well as unresolved issues;
3. decide whether the work extends an existing issue, is discovered from it, or is genuinely independent;
4. keep unscheduled detail only in the roadmap when no issue is admitted.

Never reuse an ID or delete an unresolved issue. The next issue after the current history is `ISS-024`.

## Creating an accepted issue

Use one `issues/ISS-###.md` file with the tracker template and include:

- imperative title;
- type, status, priority, labels, assignee, dates, and external reference;
- enough context for another agent to resume without the originating conversation;
- a short design with constraints and non-goals;
- observable acceptance criteria;
- `Depends on`, `Parent`, `Related`, and `Discovered from` relationships;
- a note identifying the source roadmap phase and item text.

Use vertical slices when one issue can produce independently useful, testable behavior. Use an epic only when several accepted child issues require a stable parent. Do not create empty placeholder children for unscheduled phases.

After creating or updating an issue, regenerate the derived index:

```sh
wasm=/path/to/markdown-issue-tracker/assets/derive-tracker.wasm
wasmtime run --dir ./issues::issues "$wasm" issues --write-index
```

`issues/README.md` is generated and must not be edited manually.

## Executing a roadmap item

For the one-item-per-commit workflow:

1. choose one accepted, dependency-ready item;
2. set its issue to `in_progress` if an issue exists;
3. read the linked current-contract, ADR, research, and dependency documents;
4. implement only that item and its necessary tests or documentation;
5. run the relevant targeted checks and the repository final gate;
6. mark every issue acceptance criterion complete and add concrete Close Notes;
7. set the issue to `closed` and regenerate `issues/README.md`;
8. check the one corresponding roadmap item;
9. commit implementation, tests, issue closure, generated index, and roadmap checkbox together as one item commit.

The roadmap checkbox records product capability completion. Creating or starting an issue does not check the roadmap item.

If work discovers a genuinely separate accepted task, create a new issue with `Discovered from`. If the discovered work is unscheduled, add or refine only the roadmap item and leave the tracker unchanged.

## Blocked and deferred items

- Use `blocked` only for a stated condition that prevents further progress and include the exact unblock condition.
- Use `deferred` when the capability is intentionally postponed.
- Keep the roadmap item unchecked in both cases.
- Link an external PR or release when it is the unblock condition.
- A conservative runtime fallback can make the current product safe without closing the blocked capability issue.

## Current tracker audit

The tracker derivation on 2026-07-14 reports no warnings and no ready issues. Its only unresolved records are:

- `ISS-002`: blocked on a released renderer precedence fix; the current Diagnostic fallback is implemented;
- `ISS-013`: deterministic font-dependent analysis, explicitly deferred.

Both are referenced by the roadmap. Closed `ISS-001` through `ISS-023` remain execution history and are not rewritten to match current terminology.
