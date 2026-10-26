# Engineering process

How Dentory tickets go from "To do" to "Feature QA". It started with the previous Claude project (MS-101 to MS-106, 2026-10-15 and 16) and was last changed on 2026-10-23 (models and a fresh context per ticket, section 1a); it is written for a thread that picks up the next ticket. `CLAUDE.md` and the `dentory-ios` skill hold the rules; this file holds the reasons and the details.

## 1. Roles

- **Grigor** owns the product. He confirms decisions, tries merged tickets, types passwords and makes changes on his side (GitHub settings, Supabase dashboard, Apple Developer, App Store). He does not want to be asked for anything Claude is allowed to do.
- **The project chat** (coordinator) routes asks. Engineering asks go to the build thread; marketing, sales and other asks each get their own thread.
- **The build thread** runs on Grigor's Mac through Remote Control and coordinates: it picks the ticket, moves the Notion card, starts a builder, runs the reviewer, replies in the thread and takes the next ticket without stopping.
- **The ticket builder** (`.claude/agents/ticket-builder.md`) builds one ticket in a fresh context, from reading the issue to an open PR with green CI, and fixes the reviewer's findings when the thread resumes it.
- **The reviewer agent** (`.claude/agents/pr-reviewer.md`) reviews every PR and merges it when nothing blocks. The developer never merges its own PR by hand.

## 1a. Models and context (Grigor, 2026-10-23)

| Work | Model | Why |
|---|---|---|
| The build thread and `ticket-builder` | Opus 5.5 (`claude-opus-5-5`) | Builds and fixes; the project default for new threads. |
| `pr-reviewer` | Sonnet 5.5 (`claude-sonnet-5-5`) | Reviews read and check more than they write; the cheaper model is enough. |
| Product decisions the PRD and MS-100 leave open, and a ticket judged too hard for Opus | Fable 5.1 (`claude-fable-5-1`) | Kept for judgement calls. The thread says so in the thread, then runs that work as an Agent call with `model: "fable"`: a decision agent with the options, or the `ticket-builder` started on Fable. The thread's own model changes only when Grigor asks for it (its `switch_model` tool is for his requests). |

**A fresh context per ticket.** Until 2026-10-20 one thread built ticket after ticket in a single context, which grew until it had to be compacted again and again, and every step re-sent all of it. Now the build thread starts one `ticket-builder` per ticket or fix with the Agent tool; the builder reads `CLAUDE.md`, the skill, `mac-tooling.md`, the issue and `build-state.md`, and returns a short report. The thread keeps only coordination: the ticket picked, the PR, the verdicts. On `CHANGES_REQUESTED` the thread resumes the same builder (SendMessage to its id) with the findings, so a ticket's context lives as long as the ticket and no longer. Reviewers are likewise one agent per PR, resumed for its later rounds.

When the builder (or a reviewer, or a CI wait) is the only work running, the thread waits on it inside its open turn, as a foreground Agent call, so Grigor sees the thread working (his request of 2026-10-23: "always show some animation that you are working on something"); work that runs beside other work goes in the background, which keeps Bash, Read, Edit and Write.

What the thread gives a builder: the issue number (or the fix and the review it comes from), a scratch directory under its scratchpad, the PR attribution block and commit trailer, and any decision already taken in the thread. One builder at a time: they share the local Supabase stack and the test simulator `7A14DBA5-…`; reviewers use a fresh simulator and never touch the stack.

Every Agent call also names the model (`model: "opus"` for the builder, `"sonnet"` for the reviewer): a session loads agent definitions when it starts, so a definition changed since then would otherwise run on its old model. A definition added since the session started (as `ticket-builder.md` was on 2026-10-23) is not available as an agent type until the next session; until then the thread starts a `general-purpose` agent with the same model and the file's body as the brief.

The Mac checkout (`/Users/grigorgrigoryan/Documents/Personal/Dentory`) is where the build thread runs and where Claude Code loads `CLAUDE.md`, `.claude/agents` and the skills; it is also the one folder linked to the hosted Supabase project. Nobody builds or edits there any more, so after every merge the thread fast-forwards it (`/usr/bin/git -C … fetch` then `merge --ff-only origin/claude/project-thread-ocu7tf`; it stays on the default branch and clean apart from Grigor's own untracked files) and deletes the builder's scratch directory (clone and build output).

When the thread itself grows long (a compaction summary appears), the coordinator can start a fresh build thread with the brief in section 10; nothing is lost because the state is in `build-state.md`, GitHub and Notion.

## 2. Tools and places

| What | Where | Notes |
|---|---|---|
| Code | https://github.com/grigorhello/Dentory | Default branch `claude/project-thread-ocu7tf` until Grigor renames it to `main`. |
| Tickets | GitHub issues #71 to #125 and #143 to #145, titled `MS-1NN · …`; #152 to #156 are the brand tickets, outside the build order | Each issue is self-contained: build step, blockers, frames, PRD section, element ids, acceptance criteria, out of scope. |
| Order | `docs/BUILD-ORDER.md` | Topological order with ties broken by milestone then priority. 58 steps. |
| Board | Notion "Dentory · Product board" | One card per issue. Status moves with the ticket. |
| Rules | `CLAUDE.md`, `.claude/skills/dentory-ios/SKILL.md`, `.claude/agents/` | The builder reads the first two at the start of every ticket; the agents are the builder and the reviewer. `docs/handoff/ios-architecture.md` explains the skill; `docs/handoff/mac-tooling.md` holds the Mac and CI quirks. |
| Decisions | Issue MS-100 (#71) | Overrides the PRD. When frame and PRD disagree and MS-100 is silent: layout and copy follow the frame, business rules follow the PRD. |
| Spec | `design/PRD-v1.1.md`, `design/frames/fNN.png` | Appendix B element ids are used verbatim as accessibility identifiers and analytics names. |
| Machine | Grigor's Mac, folder `/Users/grigorgrigoryan/Documents/Personal/Dentory` (was `…/MediSave` until 2026-10-18) | Xcode 27, simulators iPhone 16 and iPad Pro 11-inch (M4), Docker Desktop (start it before `make db-start`), Supabase CLI, Deno, `gh` as `grigorhello` with Apple's git first on the PATH (`PATH=/usr/bin:$PATH`, see build-state.md). |
| CI | `.github/workflows/ci.yml` | Runs on every PR: iOS job (`make project lint build test WARNINGS_AS_ERRORS=YES`, which compiles the UI tests and the end-to-end flows without running them) and database job (`make db-reset db-test`, `make functions-check`). The end-to-end flows run on the Mac only (`make e2e`, section 5). |

## 3. The ticket loop

The thread does steps 1, 2, 7 (its reply), 9, 11 and 12; the `ticket-builder` it starts does steps 3 to 8 and the fixes in step 10.

1. **Pick the ticket.** The next step in `docs/BUILD-ORDER.md` whose blockers are all merged. Check GitHub (issues and PRs), not memory, for what is really merged.
2. **Move the Notion card to In progress**, post the thread checklist, and start a `ticket-builder` for the ticket (section 1a lists what it gets).
3. **Read** `CLAUDE.md`, the skill, the issue, every frame it lists, its prototype screen key and the PRD section. Read MS-100 for decisions that touch the ticket.
4. **Branch** `ms-1NN-short-name` from the default branch, in the builder's own clone. One ticket, one branch, one PR.
5. **Build** per the skill: feature folder, view model tests first (Swift Testing), then view model, then view; repository protocol plus Supabase implementation; design-system tokens only; Appendix B ids on every interactive element. Database tickets: one timestamped migration via `supabase migration new <name>`, a pgTAP test next to it.
6. **Verify locally** before pushing: `make lint`, `make test WARNINGS_AS_ERRORS=YES` (CI fails on any compiler warning, test code included), a build for iPhone 16 and iPad Pro 11-inch (`SIM_NAME="iPad Pro 11-inch (M4)"`), the UI flows the ticket touches (CI does not run XCUITest), `make e2e` when the ticket changes a journey the end-to-end flows walk (section 5), and for database changes `make db-reset db-test` then `make seed-demo db-test` (CI runs pgTAP after both, so a test that counts rows across the whole database must scope itself to its own ids). Run the `swiftui-pro` review on SwiftUI diffs and fix genuine findings.
7. **Open the PR** with `gh pr create`: title `MS-1NN · <issue title>`, the template's sections, `Closes #N`, simulator screenshots next to the frames for UI changes, a note for any place the frame was followed over the PRD. Assign it to Grigor (`gh pr edit N --add-assignee grigorhello`; a review request is impossible because the PR comes from his own account). The thread moves the Notion card to PR review and posts one reply with the PR link.
8. **Wait for CI**. Fix red CI on the same branch; never skip or disable a test to get green.
9. **Run the reviewer**: the `pr-reviewer` agent with the PR number and a scratch directory. It checks CI, blockers, scope against the issue, the skill checklist, correctness, tests and the PR body, then either squash-merges (`gh pr merge --squash --delete-branch --match-head-commit <sha>`) or posts numbered findings.
10. **On changes requested**: the thread resumes the builder with the findings; it fixes every one on the same branch, pushes and waits for CI; the thread resumes the reviewer. At most 2 rounds: after 2 rounds without a merge, or on `NEEDS_OWNER`, stop and ask Grigor with the question in one line. A re-run only because another PR merged first ("behind the default branch") does not count. The limit was 3 rounds until 2026-10-23; Grigor lowered it with the move to a cheaper reviewer.
11. **After the merge**: the issue closes through `Closes #N`; move the Notion card to Feature QA (Grigor moves it to Done after his QA, section 5); fast-forward the Mac checkout and delete the builder's scratch directory (section 1a); post one reply in the thread (what the PR delivers, what the reviewer caught, anything Grigor must do). Then take the next ticket at once (rule of 2026-10-16). The next builder adds the merged row to `docs/handoff/build-state.md` in its PR.
12. **Database tickets only**: after the merge, push the migrations to the hosted staging project (`supabase db push` in a terminal tab; Grigor types the database password). So far this is batched: the thread asks Grigor to say "push now" and he decides when. A migration that sorts before one already on staging needs `supabase db push --include-all`.

## 4. Board flow (Notion "Dentory · Product board")

One card per ticket, linked to its GitHub issue. The Status column is the only field that moves; Order stays the build step.

| Column | Meaning | Who moves a card in | When |
|---|---|---|---|
| Backlog | Not planned for the current milestones. | Grigor or the ticket thread | Only when a ticket is parked; nothing is there today. |
| Needs design | The ticket needs a screen that is not in the design board. | The thread that notices it | When a frame is missing (none today; every ticket has its frames). |
| Design review | Grigor's design is being checked against the PRD. | Claude | After Grigor shares new or changed designs; the thread checks them and writes or updates the tickets. |
| To do | Ready to build, in build order. | Claude | Default state of every open ticket. |
| In progress | A build thread is working on it. | The build thread | The moment it starts the ticket (step 1 of the loop). |
| PR review | The PR is open; CI and the reviewer agent are running. | The build thread | When `gh pr create` succeeds. |
| Feature QA | Merged; for Grigor to try. | The build thread | Right after the reviewer merges. |
| Done | Grigor tried it and is satisfied. | Grigor, or Claude when he says "done" or "works" about the ticket in a thread | After his QA (section 5). |

MS-100 (the decision ticket) went straight to Done when Grigor accepted it. A ticket that fails QA stays in Feature QA until the fix is merged (see section 5); it does not go back to In progress, because the fix is a new PR.

## 5. QA after merge

Automated checks run before the merge: CI on every PR (SwiftLint strict, Swift 6 build with warnings as errors, unit tests on the iPhone 16 simulator, migrations plus pgTAP tests, Edge Function type check) and the reviewer agent, which reads the diff against the issue's acceptance criteria, the skill checklist, correctness and tests. XCUITest flows (`make uitest`) run on the Mac for tickets that change a user journey, on the app's demo doubles.

The end-to-end flows (MS-136, `DentoryE2ETests`) drive the real app against the local stack: `make e2e` resets it, seeds the demo clinic (MS-109) and runs seven journeys on the iPhone 16 simulator, about five minutes on the Mac: sign-up → clinic → invite; receive an invoice → confirm (Northbridge's fixture PDF, which `extract_invoice` reads from its recorded answer on the local stack); start a procedure with Take new → Edit usage → Cancel procedure; Count stock → Apply count; To buy → Mark as ordered → Receive manually; Expiring soon → Mark disposed; Staff without the admin controls. They run on the Mac before a release build and after a ticket that changes one of those journeys, not in CI: GitHub's hosted macOS runners cannot run the Docker stack reliably (decisions log, 2026-10-26). `mac-tooling.md` has the details.

Human QA is Grigor's, on the cards in Feature QA:

1. **How he tries a ticket.** Until the app shell and sign-in exist (MS-103, MS-110), database tickets are tried through the pgTAP results and Studio on the local stack, and app tickets through the Debug build in the simulator on his Mac (`make project`, open the project, run). The design-system catalog is reachable by long-pressing the "Home" text on the Home tab. From M1 on, the Debug build against the local stack seeded with the demo clinic (MS-109) is the QA build; from MS-152 on, TestFlight builds against the hosted project.
2. **What he checks.** The acceptance criteria listed in the issue and the frames the issue embeds. The reviewer has already checked them against the code; his pass is for how it feels and for anything the ticket did not foresee.
3. **How he reports a problem.** One message in the build thread naming the ticket and what is wrong. The thread starts a `ticket-builder` for the fix, which reproduces it and fixes it on a new branch `ms-1NN-fix-short-name` with a PR that says `Refs #N` (the issue is already closed), through the same CI and reviewer loop. A problem that is a new requirement rather than a defect becomes a new issue, added to the build order where its dependencies put it, with a card in To do.
4. **When the card moves to Done.** When he says so (any clear "done", "works", "ok" about that ticket) or moves it himself. Claude moves it on his word and never on its own.
5. **Bundles are fine.** He can try several tickets at once and say "all good up to MS-106"; the thread moves every card named.

## 6. What the reviewer looks for (so the developer can pre-empt it)

Rounds so far were lost on: simulator names in test commands, unlocked package versions, a UI test failing on iPad (MS-101); skeleton animation, VoiceOver labels, loading-button styling, segment transitions (MS-102); `TRUNCATE` bypassing the ledger trigger, references not locked to the clinic (MS-104); an Admin able to set the clinic subscription active, a last-admin race, thin tests (MS-105); undo of an upward adjustment crashing, receiving a product whose To buy line was never marked ordered (MS-106). The pattern: everyday paths, clinic isolation, anything that touches billing or the ledger, and tests that prove the rule rather than the happy path.

## 7. Database and Supabase

- Local stack: `make db-start` (Docker; Studio at http://127.0.0.1:54323), `make db-stop`, `make db-reset` applies `supabase/migrations` then `supabase/seed.sql`, `make db-test` runs pgTAP, `make seed-demo` loads the demo clinic Smile Dental from the frames right after a reset (MS-109; logins in the root README). Debug builds talk to it with fixed local keys in `Config/Debug.xcconfig`; nothing secret. The local stack has no Resend key, so functions write their emails to the log (`make invite-links` prints the invitation links).
- Hosted keys for Release builds: copy `Config/Secrets.example.xcconfig` to the git-ignored `Config/Secrets.xcconfig`. Function secrets (`RESEND_API_KEY`, Stripe, APNs) go on the hosted project with `supabase secrets set`. Link a hosted project once with `supabase link --project-ref <ref>`.
- Every migration has a pgTAP test; 290 assertions existed after MS-106. The ledger (`transactions`) is append-only with triggers against update, delete and truncate. Products are archived. Every foreign reference is locked to the clinic. RLS is on every table; Staff is refused on admin-only actions with a clear error; the stock changes only through the eleven engine RPCs (receive, procedure start/edit/cancel, count, adjust, dispose, batch add/edit, bottle open/finish, undo within 10 seconds, all idempotent with a key).
- Hosted: staging project "Dentory" (us-east-2, Postgres 17), linked from the Mac on 2026-10-16. Push after database merges with `supabase db push`. Prod is created before TestFlight (MS-152) and pushed by hand, never from CI. Release builds read the hosted URL and anon key from the git-ignored `Config/Secrets.xcconfig`.

## 8. Communication rules the previous threads learned

- One reply when the PR is up (link, what it does, "nothing is needed from you" when true), one when it is merged. Everything else goes in the thread checklist.
- Before any wait longer than a minute (CI, builds, tests, the reviewer) refresh the checklist naming what is running.
- A question to Grigor is one line with the options on short lines and the recommended one marked. It never blocks work that does not depend on the answer.
- Results that Grigor acts on carry evidence: the PR link, the number of assertions, the finding fixed.
- Never ask Grigor to do a step Claude is permitted to do (merge, move a card, push a branch).

## 9. Changing a ticket

Sources are in `docs/handoff/ticket-sources/` (one Markdown file per milestone group; each ticket is a `## MS-1NN · title` section with a `meta:` line for milestone, priority, points, frames and dependencies). `build.py <commit-sha>` rebuilds the per-ticket files, `tickets.json`, `all-tickets.md` and `BUILD-ORDER.md` with frame links pinned to that commit; its paths at the top point at the previous project's shared folder and must be edited to the new location before running. After a rebuild, update the GitHub issue body and the Notion card (page ids in `notion_ids.txt`). A decision change goes into MS-100 and into every ticket it names. The brand tickets (MS-158 to MS-162) have their own source, `ticket-sources/brand/brand-assets.md`, and generator, `build_brand.py <commit-sha>`, which pins the links to the brand files; they stay out of `build.py` and of the build order on purpose.

## 10. Onboarding a new build thread

Brief: "Build the next Dentory ticket in build order on Grigor's Mac, one `ticket-builder` agent per ticket (engineering-process.md, section 1a). Read docs/handoff/build-state.md and docs/handoff/engineering-process.md first, then CLAUDE.md. Check GitHub for the real current state. Do not stop after a merge." The thread runs on Opus 5.5, the project default. Start a Remote Control session on the approved folder; it starts with no prompt when the folder is already approved for the project.
