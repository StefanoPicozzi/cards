# edgible-cards skill evals, 2026-10-18

0 of 1 held-out prompts pass. Skill from card-kit `97da7ad`, `claude` 2.1.296 (Claude Code). Answering sessions: read-only, MCP tools: edgible find and describe.

| Prompt | Result | Skill loaded | expect | must_not broken | Principles missed |
| --- | --- | --- | --- | --- | --- |
| s3-members-area | FAIL | no (WRONG) | 1/3 | 0 | 2 |

## Details

### s3-members-area: FAIL
- Missed: asks who signs in - invited people or the public. The closing questions ask about page-level vs data-level restriction, CloudFront use, and social login. None asks who the users are (invited vs public).
- Missed: offers AWS-native, hosted, and self-hosted (the accounts card) options. It offers AWS-native options (Cognito, CloudFront) and managed hosts (Amplify, Netlify/Vercel with Auth0/Clerk). It offers no self-hosted accounts option and says nothing about the upkeep of self-hosting.
- Principle missed: Gives honest options side by side, including hosted ones where they fit, and states the upkeep of self-hosting.. It gives a side-by-side table and includes hosted options (Option 4), but it never states the upkeep of self-hosting.
- Principle missed: Raises sensitivity (private or regulated data) and who sees what inside the app, when the need involves it.. It does not ask how sensitive the 'restricted content and offerings' are, and it does not raise per-user or role-based access beyond a passing mention of personalized offers.
- Would be better: The answer should ask who signs in (invited people or the public) and how sensitive the content is, then lay out AWS-native, hosted, and self-hosted account options side by side with the upkeep of each.

## What would make answers better

- s3-members-area: The answer should ask who signs in (invited people or the public) and how sensitive the content is, then lay out AWS-native, hosted, and self-hosted account options side by side with the upkeep of each.
