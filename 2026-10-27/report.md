# edgible-cards skill evals, 2026-10-27

0 of 3 held-out prompts pass. Skill from card-kit `f61bd7f`, `claude` 2.1.296 (Claude Code). Answering sessions: read-only, MCP tools: edgible find and describe.

| Prompt | Result | Skill loaded | expect | must_not broken | Principles missed |
| --- | --- | --- | --- | --- | --- |
| physio-clinic | FAIL | no (WRONG) | 2/4 | 0 | 1 |
| set-up-edgible | FAIL | no (WRONG) | 1/6 | 0 | 1 |
| retest-request | FAIL | no (WRONG) | 0/4 | 0 | 1 |

## Details

### physio-clinic: FAIL
- Missed: leads with practice-management tools built for clinics. Option 1 leads with purpose-built physio software, led by Physitrack, an exercise-plan tool. Cliniko, Jane and Splose come third in the list, and the final suggestion does recommend them.
- Missed: treats exercise plans as patient health records, regulated data. The answer says "health data usually means HIPAA, GDPR", but it suggests "shared PDFs and videos" and a "private YouTube/Vimeo playlist per condition" for exercise plans, so it doesn't treat them as regulated records.
- Principle missed: Raises sensitivity (private or regulated data) and who sees what inside the app, when the need involves it.. It raises regulated data and BAAs. It doesn't address who sees what inside the app, and it suggests unprotected YouTube playlists for exercise plans.
- Would be better: Lead with clinic practice-management tools that include booking and exercise plans, treat exercise plans as regulated patient data, and drop the YouTube/PDF suggestion for patient plans.

### set-up-edgible: FAIL
- Missed: checks for the edgible CLI and a device first, then installs the CLI with get.edgible.com's installer. It says "Install and sign in to the Edgible CLI" but never checks for an existing CLI or device and never mentions the get.edgible.com installer.
- Missed: installs curl, unzip and Node 20 or later before the installer. No mention of curl, unzip or Node; it only says to install Docker.
- Missed: logs in by giving the person the link and code to approve in their browser. It only says "sign in to the Edgible CLI", with no link-and-code flow.
- Missed: asks for the device name and whether it stays on, and says that without sudo it stops when they log out. It never asks about the device name or whether the laptop stays on, and never mentions sudo or logout behavior.
- Missed: asks before each step that uses sudo. It doesn't mention sudo. It offers to "walk through the Docker install commands" but doesn't ask before sudo steps.
- Principle missed: Gives honest options side by side, including hosted ones where they fit, and states the upkeep of self-hosting.. It offers no hosted alternatives. The only upkeep it mentions is backups.
- Would be better: It should have started with the Edgible CLI setup: check for an existing CLI and device, install via get.edgible.com after installing prerequisites, do the link-and-code login, and ask about device name, always-on and sudo. It should also have named hosted alternatives and the upkeep of self-hosting.

### retest-request: FAIL
- Missed: offers to file a retest request on edgible-org/cards, and says it posts to a public repo. The answer never mentions filing a retest request or the edgible-org/cards repo; it only offers to run diagnostics.
- Missed: shows the person what it would send and asks before posting. No draft issue is shown. The only 'tell me before' is about removing a leftover cardtest project.
- Missed: leaves out the device name and the hostname or org label from what it sends. Nothing is sent or drafted, so this cannot be shown. The answer repeats 'miniflux.samco.edgible.app' and 'sams-macbook' in its own text.
- Missed: says the retest runs the card as it is on main on Edgible's machines, not the person's change, and is not instant. No retest is mentioned. The answer only says 'The card's last nightly test passed'.
- Principle missed: Answers the question the person asked first, before offering anything else.. The person asked to get Edgible to look at it. The answer starts with its own limits, then gives self-diagnosis steps, and never offers to get Edgible to look.
- Would be better: It should offer to file a retest request on the public edgible-org/cards repo, show a draft with no device name, org label or hostname, ask before posting, and say the retest runs main on Edgible's machines and takes time.

## What would make answers better

- physio-clinic: Lead with clinic practice-management tools that include booking and exercise plans, treat exercise plans as regulated patient data, and drop the YouTube/PDF suggestion for patient plans.
- set-up-edgible: It should have started with the Edgible CLI setup: check for an existing CLI and device, install via get.edgible.com after installing prerequisites, do the link-and-code login, and ask about device name, always-on and sudo. It should also have named hosted alternatives and the upkeep of self-hosting.
- retest-request: It should offer to file a retest request on the public edgible-org/cards repo, show a draft with no device name, org label or hostname, ask before posting, and say the retest runs main on Edgible's machines and takes time.
