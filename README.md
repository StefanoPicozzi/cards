# edgible-cards skill evals: 2026-10-12 to 2026-10-18

**2 of 8** held-out prompts pass, each at its latest run in the last 7 days (7 nightly runs). Skill from card-kit `97da7ad`, `988676e`, `a2dd494`, `b3a4fb1`.

| Prompt | Run | Result | Skill loaded | expect | must_not broken |
| --- | --- | --- | --- | --- | --- |
| maritime-law-firm | 2026-10-15 | FAIL | no (WRONG) | 5/5 | 0 |
| marketing-site-cost | 2026-10-17 | FAIL | no (WRONG) | 1/3 | 0 |
| physio-clinic | 2026-10-13 | FAIL | no (WRONG) | 2/4 | 1 |
| pocket-shutdown | 2026-10-16 | FAIL | no (WRONG) | 1/3 | 0 |
| s3-members-area | 2026-10-18 | FAIL | no (WRONG) | 1/3 | 0 |
| sensitive-photos | 2026-10-14 | FAIL | no (WRONG) | 3/3 | 0 |
| negative-landlord-email | 2026-10-14 | pass | no (right) | 1/1 | 0 |
| negative-react-error | 2026-10-13 | pass | no (right) | 1/1 | 0 |

## Failing prompts

**maritime-law-firm** (2026-10-15)

**marketing-site-cost** (2026-10-17)
- Missed: asks whether the site is static or edited in a CMS. It asks about 'how often the content changes, and who edits it' and page count, features, and comfort with code, but never directly asks whether the site is static or CMS-edited.
- Missed: the wordpress card on a small cloud server for a CMS, with the upkeep stated. It mentions 'WordPress.com or shared hosting: about $3 to $8/month. It's more flexible but needs more upkeep.' It doesn't propose WordPress on a small cloud server. The VPS option is mentioned only as self-hosting.

**physio-clinic** (2026-10-13)
- Missed: leads with practice-management tools built for clinics. Leads with 'Cheap hosted tools' listing physio-specific exercise platforms and general booking tools; it downplays all-in-one practice management as pricier, and doesn't lead with it.
- Missed: self-hosting at most for the parts without patient records. Suggests self-hosting booking (Cal.com, Easy!Appointments) and building a protected page per patient with video links for exercise plans, which are patient records; it warns of risk but still offers it.
- Broke: offer to self-host patient records on a clinic or home machine. 'You'd probably need to build something simple, such as a protected page per patient with video links' under self-hosting, and a DIY option of private pages/shared documents for each patient's plan.

**pocket-shutdown** (2026-10-16)
- Missed: two or three bookmark apps that keep page copies, with a recommendation. Only one app, linkding, is offered ('Edgible has one tested match'); it is link-only by default, with page copies only via the -plus image.
- Missed: asks about importing from Pocket. It explains the Pocket export/import and says 'I haven't tested it with a Pocket file', but it asks no question about importing. Its three questions cover page copies, phone use and hostname.

**s3-members-area** (2026-10-18)
- Missed: asks who signs in - invited people or the public. The closing questions ask about page-level vs data-level restriction, CloudFront use, and social login. None asks who the users are (invited vs public).
- Missed: offers AWS-native, hosted, and self-hosted (the accounts card) options. It offers AWS-native options (Cognito, CloudFront) and managed hosts (Amplify, Netlify/Vercel with Auth0/Clerk). It offers no self-hosted accounts option and says nothing about the upkeep of self-hosting.

**sensitive-photos** (2026-10-14)

## What would make answers better

- maritime-law-firm: Present a hosted option next to self-hosting, with the upkeep and cost of each, and cut the questions to the two or three that change the recommendation.
- marketing-site-cost: Ask up front whether the site is static or edited through a CMS, then give one clear path for each case, with free static hosting for static and WordPress on a small cloud server for CMS with its upkeep stated, instead of a long menu and checklist.
- negative-landlord-email: Nothing essential is missing; it could be slightly stronger by naming the two-week duration as a clear request deadline or mentioning tenant repair rights, but it fully answers the request.
- negative-react-error: It could have put the most likely fix first in a short reply, with the project-path request at the end, instead of listing four generic causes.
- physio-clinic: Lead with clinic-focused hosted practice-management or physio platforms that cover bookings and exercise plans and offer compliant data handling. Say plainly not to self-host or DIY patient exercise records, and ask the country up front.
- pocket-shutdown: Offer two or three self-hosted options that keep page copies (for example linkding-plus, Linkwarden, Wallabag) with a clear recommendation, and ask whether to import the Pocket export.
- s3-members-area: The answer should ask who signs in (invited people or the public) and how sensitive the content is, then lay out AWS-native, hosted, and self-hosted account options side by side with the upkeep of each.
- sensitive-photos: Present a short side-by-side of options, including a local-only approach with no server and an end-to-end-encrypted hosted service, and state the ongoing upkeep of self-hosting more plainly.
