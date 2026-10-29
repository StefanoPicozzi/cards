# Contributing a card

There are three ways to help: add a card, fix one, or ask for one. Each follows the format in [README.md](README.md#what-a-card-is) and in [edgible-org/card-kit](https://github.com/edgible-org/card-kit). What is written there wins over anything here.

## Ask for a card

Open an issue from one of the two templates:

- **App card request,** for one self-hosted app. Name the app and link it, ideally on [awesome-selfhosted](https://awesome-selfhosted.net). Say what you would use it for and who calls it: a browser, the app's own phone or desktop apps, or another machine. That decides the auth mode.
- **Pattern card request,** for several apps wired together. Say what the pattern is for, which apps it joins, and how they reach each other. Link each app's card if it has one.

If you tried to build it, say where you got stuck.

## Add a card

**Wrote the app yourself?** Start at [Add your app](https://www.edgible.ai/add-your-app/). The edgible-cards skill runs card-kit's `check-app` on your app, tells you what a card needs (required and nice to have), and helps you build what is missing before you write the card. You can run it yourself: `python3 ../card-kit/check-app.py <your app's folder> --image <name:tag> --steward <your GitHub name>`.

You need Docker. To test a card, which every app card must be, you also need an Edgible account with a serving device and the `edgible` CLI logged in. `test-card` runs the whole lifecycle on that device.

1. **Check the app and the name.** An app card's app must not be on the README's [What is not an app card](README.md#what-is-not-an-app-card) list. A 404 from this command means the name is free:

   ```bash
   gh api repos/edgible-org/cards/contents/<name> --jq .name
   ```

   If the name is taken, edit the card that is already there, or pick a name that says how yours differs, such as `n8n-sqlite`.

2. **Fork and clone,** with card-kit beside it. Work on a branch, never on `main`:

   ```bash
   gh repo fork edgible-org/cards --clone
   git clone https://github.com/edgible-org/card-kit
   cd cards && git checkout -b <name>
   ```

3. **Write the card.** Copy the card closest to yours and change the names, so every card reads the same way. Set `metadata.type` to `app` or `pattern`. The rules are in the README's [What a card is](README.md#what-a-card-is) and card-kit's [Conventions](https://github.com/edgible-org/card-kit#conventions). A pattern starts from the app cards of its apps. Write the README with `card-readme`:

   ```bash
   ../card-kit/run card-readme <name> <name>-readme.yml
   ```

   The `<name>-readme.yml` it reads holds the parts only you know. Keep it out of the commit.

4. **Test it** on your serving device until it passes, and commit the `test.yml` it writes. An app card must have one. A pattern does not have to, but a reviewer trusts one that does, and the nightly regression only tests cards that carry it. Put the values only a person may fill in `test/inputs.env`, and the card's own end-to-end checks in `test/<check>.sh`:

   ```bash
   python3 ../card-kit/test-card.py <name> --device <your-device>
   ../card-kit/run check-cards --fresh
   ```

   `check-cards --fresh` fails a card whose files changed after its `test.yml`, so test again after any change. A picture is optional: `../card-kit/run card-image <name>`. So is an icon, the app's own logo for the catalog site: `../card-kit/run card-icon <name>` fetches it from the open icon sets, and without one the site shows the Edgible symbol.

5. **Name a steward,** or leave it out. `metadata.steward` in card.yml is the GitHub user or organisation that will review changes to the card and fix it when its test fails. The site shows it on the card's page. A card with none is listed as having no steward, which is allowed, and is still tested every night.

6. **Check nothing private is left:** no device name, hostname, organization id, password, or your own domain, in any file.

7. **Open the pull request** from your fork. The template lists the review checklist: tick each item you checked.

## Fix a card

Use the same steps from 2: fork, branch, change, `test-card`, `check-cards --fresh`, pull request. Say what was wrong and how the test shows the fix. When the nightly test found the failure, the card has an issue already. Link to it.

## What happens next

A maintainer reviews the checklist and the parts a test cannot judge, then adds the label `run-fleet-test` to your pull request, which tests the card on Edgible's own devices at the commit they read (a comment says which). A pass adds `fleet-tested`. Any new push removes both labels, so they never cover a commit nobody tested. Lifecycle tests never run on a pull request. The merge is the publish. After it, the nightly `test-cards` run tests the card whenever it or Edgible changes. When it fails, it gets an issue.

## Made with an AI agent

That is welcome. The [edgible-cards skill](https://github.com/edgible-org/card-kit/tree/main/skills/edgible-cards) follows this file. Say in the pull request that an agent made it. You are still the one asking for the merge, so read what it wrote.

An agent working on its own for the person who wrote the app can do every step: `check-app --json` until `ready` is true, the card, `test-card` on the person's own device, then the pull request from a fork. It asks the person for what is theirs to decide: the licence, and who the steward is.

## Licence

This repository is [MIT](LICENSE). By contributing, you agree that your contribution is under the same licence. The apps a card runs keep their own licences.
