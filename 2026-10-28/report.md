# edgible-cards skill evals, 2026-10-28

1 of 2 held-out prompts pass. Skill from card-kit `fa59bf9`, `claude` 2.1.296 (Claude Code). Answering sessions: read-only, MCP tools: edgible find and describe.

| Prompt | Result | Skill loaded | expect | must_not broken | Principles missed |
| --- | --- | --- | --- | --- | --- |
| sensitive-photos | FAIL | no (WRONG) | 3/3 | 0 | 1 |
| negative-react-error | pass | no (right) | 1/1 | 0 | 0 |

## Details

### sensitive-photos: FAIL
- Principle missed: Gives honest options side by side, including hosted ones where they fit, and states the upkeep of self-hosting.. Only self-hosted Immich is offered. Upkeep is mentioned only as "prompt updates" for the published option, and no hosted or end-to-end-encrypted alternatives are given.
- Would be better: Briefly compare self-hosting with a zero-knowledge encrypted hosted option and state the ongoing upkeep of self-hosting (updates, backups, hardware) before steering to Immich.

### negative-react-error: pass
- Would be better: Lead with the most likely fix, then show a short before and after code sample. The answer opens with the missing file, which pushes the useful content down.

## What would make answers better

- sensitive-photos: Briefly compare self-hosting with a zero-knowledge encrypted hosted option and state the ongoing upkeep of self-hosting (updates, backups, hardware) before steering to Immich.
- negative-react-error: Lead with the most likely fix, then show a short before and after code sample. The answer opens with the missing file, which pushes the useful content down.
