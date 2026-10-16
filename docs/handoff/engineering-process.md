# Engineering process

How MediSave tickets go from "To do" to "Feature QA". This is the process the previous Claude project ran from 2026-10-15 to 2026-10-16 for MS-101 to MS-106; it is written for a thread that picks up the next ticket.

## 1. Roles

- **Grigor** owns the product. He confirms decisions, tries merged tickets, types passwords and makes changes on his side (GitHub settings, Supabase dashboard, Apple Developer, App Store). He does not want to be asked for anything Claude is allowed to do.
- **The project chat** (coordinator) routes asks. Engineering asks go to the build thread; marketing, sales and other asks each get their own thread.
- **The build thread** runs on Grigor's Mac through Remote Control. One long-lived thread builds ticket after ticket; it does not stop between tickets.
- **The reviewer agent** (`.claude/agents/pr-reviewer.md`) reviews every PR and merges it when nothing blocks. The developer never merges its own PR by hand.

## 2. Tools and places

| What | Where | Notes |
|---|---|---|
| Code | https://github.com/grigorhello/MediSave | Default branch `claude/project-thread-ocu7tf` until Grigor renames it to `main`. |
| Tickets | GitHub issues #71 to #125, titled `MS-1NN · …` | Each issue is self-contained: build step, blockers, frames, PRD section, element ids, acceptance criteria, out of scope. |
| Order | `docs/BUILD-ORDER.md` | Topological order with ties broken by milestone then priority. 55 steps. |
| Board | Notion "MediSave · Product board" | One card per issue. Status moves with the ticket. |
| Rules | `CLAUDE.md`, `.claude/skills/medisave-ios/SKILL.md` | Read both at the start of every ticket. |
| Decisions | Issue MS-100 (#71) | Overrides the PRD. When frame and PRD disagree and MS-100 is silent: layout and copy follow the frame, business rules follow the PRD. |
| Spec | `design/PRD-v1.1.md`, `design/frames/fNN.png` | Appendix B element ids are used verbatim as accessibility identifiers and analytics names. |
| Machine | Grigor's Mac, folder `/Users/grigorgrigoryan/Documents/Personal/MediSave` | Xcode 26, simulators iPhone 16 and iPad Pro 11-inch (M4), Docker Desktop, Supabase CLI, `gh` as `grigorhello`. |
| CI | `.github/workflows/ci.yml` | Runs on every PR: iOS job (`make project lint build test WARNINGS_AS_ERRORS=YES`) and database job (`make db-reset db-test`, `make functions-check`). |

## 3. The ticket loop

1. **Pick the ticket.** The next step in `docs/BUILD-ORDER.md` whose blockers are all merged. Check GitHub (issues and PRs), not memory, for what is really merged.
2. **Move the Notion card to In progress** and post the thread checklist (reading the ticket, writing, PR and review loop).
3. **Read** `CLAUDE.md`, the skill, the issue, every frame it lists, its prototype screen key and the PRD section. Read MS-100 for decisions that touch the ticket.
4. **Branch** `ms-1NN-short-name` from the default branch. One ticket, one branch, one PR.
5. **Build** per the skill: feature folder, view model tests first (Swift Testing), then view model, then view; repository protocol plus Supabase implementation; design-system tokens only; Appendix B ids on every interactive element. Database tickets: one timestamped migration via `supabase migration new <name>`, a pgTAP test next to it, `make db-reset db-test` locally.
6. **Verify locally** before pushing: `make lint`, `make test`, build for iPhone 16 and iPad Pro 11-inch (`SIM_NAME="iPad Pro 11-inch (M4)"`), `make db-reset db-test` for database changes. Run the `swiftui-pro` review on the diff for SwiftUI code and fix genuine findings. CI fails on any compiler warning.
7. **Open the PR** with `gh pr create`: title `MS-1NN · <issue title>`, body `Closes #N`, simulator screenshots next to the frames for UI changes, a note for any place the frame was followed over the PRD. Assign it to Grigor (`gh pr edit N --add-assignee grigorhello`; a review request is impossible because the PR comes from his own account). Move the Notion card to PR review. Post one reply in the thread with the PR link.
8. **Wait for CI** with a status refresh first ("Waiting for CI"). Fix red CI on the same branch; never skip or disable a test to get green.
9. **Run the reviewer**: the `pr-reviewer` agent with the PR number. It checks CI, blockers, scope against the issue, the skill checklist, correctness, tests and the PR body, then either squash-merges (`gh pr merge --squash --delete-branch`) or posts numbered findings.
10. **On changes requested**: fix every finding on the same branch, push, wait for CI, run the reviewer again. At most 3 rounds; after 3 rounds without a merge, or on `NEEDS_OWNER`, stop and ask Grigor with the question in one line. Every ticket so far merged within 3 rounds.
11. **After the merge**: the issue closes through `Closes #N`; move the Notion card to Feature QA; post one reply in the thread (what the PR delivers, what the reviewer caught, anything Grigor must do). Then take the next ticket at once (rule of 2026-10-16). Update `docs/handoff/build-state.md` with the merged ticket, either in the next PR or in a small docs PR.
12. **Database tickets only**: after the merge, push the migrations to the hosted staging project (`supabase db push` in a terminal tab; Grigor types the database password). So far this is batched: the thread asks Grigor to say "push now" and he decides when.

## 4. What the reviewer looks for (so the developer can pre-empt it)

Rounds so far were lost on: simulator names in test commands, unlocked package versions, a UI test failing on iPad (MS-101); skeleton animation, VoiceOver labels, loading-button styling, segment transitions (MS-102); `TRUNCATE` bypassing the ledger trigger, references not locked to the clinic (MS-104); an Admin able to set the clinic subscription active, a last-admin race, thin tests (MS-105); undo of an upward adjustment crashing, receiving a product whose To buy line was never marked ordered (MS-106). The pattern: everyday paths, clinic isolation, anything that touches billing or the ledger, and tests that prove the rule rather than the happy path.

## 5. Database and Supabase

- Local stack: `make db-start` (Studio at http://127.0.0.1:54323), `make db-reset` applies `supabase/migrations` then `supabase/seed.sql`, `make db-test` runs pgTAP. Debug builds talk to it with fixed local keys in `Config/Debug.xcconfig`; nothing secret.
- Every migration has a pgTAP test; 290 assertions existed after MS-106. The ledger (`transactions`) is append-only with triggers against update, delete and truncate. Products are archived. Every foreign reference is locked to the clinic. RLS is on every table; Staff is refused on admin-only actions with a clear error; the stock changes only through the eleven engine RPCs (receive, procedure start/edit/cancel, count, adjust, dispose, batch add/edit, bottle open/finish, undo within 10 seconds, all idempotent with a key).
- Hosted: staging project "MediSave" (us-east-2, Postgres 17), linked from the Mac on 2026-10-16. Push after database merges with `supabase db push`. Prod is created before TestFlight (MS-152) and pushed by hand, never from CI. Release builds read the hosted URL and anon key from the git-ignored `Config/Secrets.xcconfig`.

## 6. Communication rules the previous threads learned

- One reply when the PR is up (link, what it does, "nothing is needed from you" when true), one when it is merged. Everything else goes in the thread checklist.
- Before any wait longer than a minute (CI, builds, tests, the reviewer) refresh the checklist naming what is running.
- A question to Grigor is one line with the options on short lines and the recommended one marked. It never blocks work that does not depend on the answer.
- Results that Grigor acts on carry evidence: the PR link, the number of assertions, the finding fixed.
- Never ask Grigor to do a step Claude is permitted to do (merge, move a card, push a branch).

## 7. Changing a ticket

Sources are in `docs/handoff/ticket-sources/` (one Markdown file per milestone group; each ticket is a `## MS-1NN · title` section with a `meta:` line for milestone, priority, points, frames and dependencies). `build.py <commit-sha>` rebuilds the per-ticket files, `tickets.json`, `all-tickets.md` and `BUILD-ORDER.md` with frame links pinned to that commit; its paths at the top point at the previous project's shared folder and must be edited to the new location before running. After a rebuild, update the GitHub issue body and the Notion card (page ids in `notion_ids.txt`). A decision change goes into MS-100 and into every ticket it names.

## 8. Onboarding a new build thread

Brief: "Build the next MediSave ticket in build order on Grigor's Mac. Read docs/handoff/build-state.md and docs/handoff/engineering-process.md first, then CLAUDE.md and the skill. Check GitHub for the real current state. Do not stop after a merge." Start a Remote Control session on the approved folder; it starts with no prompt when the folder is already approved for the project.
