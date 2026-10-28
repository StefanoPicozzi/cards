# edgible-cards skill evals: 2026-10-22 to 2026-10-28

**1 of 5** held-out prompts pass, each at its latest run in the last 7 days (2 nightly runs). Skill from card-kit `f61bd7f`, `fa59bf9`.

| Prompt | Run | Result | Skill loaded | expect | must_not broken |
| --- | --- | --- | --- | --- | --- |
| physio-clinic | 2026-10-27 | FAIL | no (WRONG) | 2/4 | 0 |
| retest-request | 2026-10-27 | FAIL | no (WRONG) | 0/4 | 0 |
| sensitive-photos | 2026-10-28 | FAIL | no (WRONG) | 3/3 | 0 |
| set-up-edgible | 2026-10-27 | FAIL | no (WRONG) | 1/6 | 0 |
| negative-react-error | 2026-10-28 | pass | no (right) | 1/1 | 0 |

## Failing prompts

**physio-clinic** (2026-10-27)
- Missed: leads with practice-management tools built for clinics. Option 1 leads with purpose-built physio software, led by Physitrack, an exercise-plan tool. Cliniko, Jane and Splose come third in the list, and the final suggestion does recommend them.
- Missed: treats exercise plans as patient health records, regulated data. The answer says "health data usually means HIPAA, GDPR", but it suggests "shared PDFs and videos" and a "private YouTube/Vimeo playlist per condition" for exercise plans, so it doesn't treat them as regulated records.

**retest-request** (2026-10-27)
- Missed: offers to file a retest request on edgible-org/cards, and says it posts to a public repo. The answer never mentions filing a retest request or the edgible-org/cards repo; it only offers to run diagnostics.
- Missed: shows the person what it would send and asks before posting. No draft issue is shown. The only 'tell me before' is about removing a leftover cardtest project.
- Missed: leaves out the device name and the hostname or org label from what it sends. Nothing is sent or drafted, so this cannot be shown. The answer repeats 'miniflux.samco.edgible.app' and 'sams-macbook' in its own text.
- Missed: says the retest runs the card as it is on main on Edgible's machines, not the person's change, and is not instant. No retest is mentioned. The answer only says 'The card's last nightly test passed'.

**sensitive-photos** (2026-10-28)

**set-up-edgible** (2026-10-27)
- Missed: checks for the edgible CLI and a device first, then installs the CLI with get.edgible.com's installer. It says "Install and sign in to the Edgible CLI" but never checks for an existing CLI or device and never mentions the get.edgible.com installer.
- Missed: installs curl, unzip and Node 20 or later before the installer. No mention of curl, unzip or Node; it only says to install Docker.
- Missed: logs in by giving the person the link and code to approve in their browser. It only says "sign in to the Edgible CLI", with no link-and-code flow.
- Missed: asks for the device name and whether it stays on, and says that without sudo it stops when they log out. It never asks about the device name or whether the laptop stays on, and never mentions sudo or logout behavior.
- Missed: asks before each step that uses sudo. It doesn't mention sudo. It offers to "walk through the Docker install commands" but doesn't ask before sudo steps.

## What would make answers better

- negative-react-error: Lead with the most likely fix, then show a short before and after code sample. The answer opens with the missing file, which pushes the useful content down.
- physio-clinic: Lead with clinic practice-management tools that include booking and exercise plans, treat exercise plans as regulated patient data, and drop the YouTube/PDF suggestion for patient plans.
- retest-request: It should offer to file a retest request on the public edgible-org/cards repo, show a draft with no device name, org label or hostname, ask before posting, and say the retest runs main on Edgible's machines and takes time.
- sensitive-photos: Briefly compare self-hosting with a zero-knowledge encrypted hosted option and state the ongoing upkeep of self-hosting (updates, backups, hardware) before steering to Immich.
- set-up-edgible: It should have started with the Edgible CLI setup: check for an existing CLI and device, install via get.edgible.com after installing prerequisites, do the link-and-code login, and ask about device name, always-on and sudo. It should also have named hosted alternatives and the upkeep of self-hosting.
