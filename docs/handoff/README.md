# Dentory handoff pack

Dentory was called MediSave until 2026-10-17; the ticket ids keep the `MS-` prefix.

Written 2026-10-16 (15:30 UTC) by the Claude project "Dentory" so that a new Claude project can pick up the work from this exact point, and so that marketing, sales and other chats in that project can use the product knowledge without reading the code.

The same files live in two places: `docs/handoff/` in the repository (this copy travels with the repo) and `/mnt/project-files/handoff/` in the original project's shared folder. The repository copy is the one to keep current.

Nothing in this pack is secret. Supabase keys, database passwords, Stripe or Resend keys and Apple credentials stay where they are (the git-ignored `Config/Secrets*.xcconfig`, the Supabase dashboard, the Mac keychain) and are never pasted into a chat, a memory or a file.

## What is in the pack

| File | Read it when |
|---|---|
| [project-instructions.md](project-instructions.md) | Setting up the new project: paste its contents into Project settings as the project instructions. |
| [memory-seed.md](memory-seed.md) | Setting up the new project: give it to Claude in the first message so it saves the facts to the project memory. |
| [engineering-process.md](engineering-process.md) | Any thread that builds, reviews or ships a ticket. The full process, from picking the ticket to moving the Notion card, and the reasons behind `CLAUDE.md`. |
| [ios-architecture.md](ios-architecture.md) | Understanding the `dentory-ios` skill: the folder tree, the layers, SOLID and a worked example. |
| [mac-tooling.md](mac-tooling.md) | Building, testing or screenshotting on Grigor's Mac: commands from a clone, simulators, and what CI rejects that the Mac accepts. |
| [build-state.md](build-state.md) | Continuing the build: what is merged, what is in progress, what comes next, what Grigor still owes. |
| [product-knowledge.md](product-knowledge.md) | Marketing, sales, pitch, landing page, support or pricing chats. What Dentory is and is not, in plain words. |
| [decisions-log.md](decisions-log.md) | Checking why something is the way it is. Dated decisions from the first day to now. |
| [pilot-audit.md](pilot-audit.md) | Checking how the app compares with the frames and the copy rules: MS-136's audit, each finding with its status. |
| [ticket-sources/](ticket-sources/) | Changing a ticket: the Markdown sources of the 58 tickets and the script that regenerates the issues, the ticket list and the build order. |

Sources of truth that the pack points at, in the order a new thread should read them:

1. `CLAUDE.md` in the repo root: the build rules every ticket follows.
2. `.claude/skills/dentory-ios/SKILL.md`: architecture and coding standard, test and PR checklist.
3. `.claude/agents/ticket-builder.md` and `.claude/agents/pr-reviewer.md`: the builder that builds one ticket in a fresh context, and the reviewer that merges pull requests.
4. `docs/BUILD-ORDER.md`: the 58 tickets in dependency order.
5. `design/PRD-v1.1.md` and `design/frames/`: the product specification and every screen.
6. GitHub issue MS-100 (#71): decisions that override or fill gaps in the PRD.
7. The GitHub issues #71 to #125 and #143 to #145 (one per ticket), #152 to #156 (the brand tickets, outside the build order) and the Notion board "Dentory · Product board".

## Setting up the new project, step by step

1. **Create the project.** In claude.ai, create a new project named Dentory with the visibility you want (the original is private, which is why it cannot be reused for other chats). Topic: the same one-paragraph goal as the original (it is the first paragraph of [product-knowledge.md](product-knowledge.md)).
2. **Attach the repository.** Project settings, Resources: add `https://github.com/grigorhello/Dentory`. GitHub must be connected to your claude.ai account (`https://claude.ai/connect-github`) and the Claude GitHub App installed on the repository (it already is for the original project; if a thread reports no access, install it at `https://github.com/apps/claude/installations/select_target`).
3. **Connect Notion.** Settings, Connectors: Notion. The board "Dentory · Product board" and the "Dentory tickets" database are in your workspace; threads move the cards.
4. **Set the model.** Project settings: default model `claude-opus-5-5` for new threads (the token plan of 2026-10-23: Opus 5.5 builds, Sonnet 5.5 reviews, Fable 5.1 only for product decisions; `engineering-process.md`, section 1a).
5. **Paste the project instructions.** Project settings, Instructions: the whole of [project-instructions.md](project-instructions.md).
6. **Seed the memory.** First message in the project chat: upload or paste [memory-seed.md](memory-seed.md) and say "save this to project memory as the starting point". Claude keeps one memory file per subject from it.
7. **Approve the Mac folder.** When the first build thread starts, it asks for Remote Control on `/Users/grigorgrigoryan/Documents/Personal/Dentory`. Allow it once; the Claude desktop app remembers the approval for the new project. The repository is already cloned there, Xcode, Docker Desktop and the Supabase CLI are installed, the repo is linked to the hosted Supabase project, and the active GitHub CLI account is `grigorhello` (check with `gh auth status`).
8. **Keep the Claude Code permission rules on the Mac.** They are in the Claude Code settings on the Mac, not in the repository, so they carry over: allow `gh pr merge`, `git checkout`, writes under `.claude/agents`, edits to `CLAUDE.md` and `.claude/skills`. If a thread asks you to press Merge yourself, the rule is missing; add it with `/permissions` in a Claude Code session in that folder.
9. **Copy the plan files (optional).** `/mnt/project-files/medisave-plan-v2/` in the original project holds the generated ticket files and `all-tickets.md`. The sources are in [ticket-sources/](ticket-sources/), and the issues on GitHub are the live copy, so this step is only for convenience.
10. **Start the build.** In the new project chat write: "Continue the Dentory build from docs/handoff/build-state.md on my Mac." The thread reads the state file, checks GitHub for the real current state, and takes the next ticket in build order.

## Keeping the pack current

- A thread that merges a ticket updates [build-state.md](build-state.md) in the same PR or in the next one, and adds a line to [decisions-log.md](decisions-log.md) when a product or process decision was made.
- A thread that changes a ticket edits the source under [ticket-sources/](ticket-sources/), runs `build.py` as described in its header, and updates the GitHub issue and the Notion card.
- [product-knowledge.md](product-knowledge.md) changes only when the product does (a PRD change or a decision in MS-100).
