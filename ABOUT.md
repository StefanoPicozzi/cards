# About cards

Say you want a website. You'll probably also want a decent CMS to edit it, some analytics, and something that tells you when it falls over. The default answer these days is a subscription for each of those, with your content and your visitors' data sitting on someone else's servers.

We think there's a better default: run it yourself. Your data stays on a machine you own, and nothing sensitive has to leave the building. Open-source tools on your own hardware don't change their price or their terms on you. And honestly, it's a lot easier than it used to be.

![The cards loop: get a setup working, write it down as a card, it is tested on a real machine, someone else runs it, makes it their own, and shares it back](about/loop.svg)

## Self-hosting doesn't have to be lonely

Most self-hosting happens alone. Someone puts a few apps on a box in the garage, gets them talking to each other, puts them online, and it works. Nobody else ever sees how they did it, so the next person starts from scratch.

We'd like that to change. A setup in a garage can already serve more than its owner. Edgible gives each app its own hostname, and you choose who gets in: anyone, people in your organization, or callers with an API key. That's how you end up running the site for your club or the tools for your team.

Cards are the other half. When you've got something working that you're happy with, you write it down as a card, and someone else can run the same thing on their own machine. Maybe they tweak it and share their version back. That's the part we're most excited about.

## What's in a card

Exposing one port to the internet isn't the hard bit. The hard bit is the whole setup: which apps go together and how they find each other, which hostname is open and which needs a sign-in, what runs on which machine, how you check it works, and how you take it all down again without losing anything. That's what a card records.

Take the website card. It's the site, an editor for its pages, analytics, and an uptime monitor that you can put on a second machine, each with the right level of access.

A card never contains anything personal. No device names, hostnames, organization ids, or passwords. You fill in the first three on your own machine, and the card makes its passwords there itself.

## Shaped for sharing

Almost everything about a card's form comes from one idea: it's meant to be passed on. Each choice is there so a setup that worked on one person's machine works on the next person's too.

- **Nothing personal in it**, so you can publish it without a second thought. Your devices and hostnames stay in `card.env` on your machine, and its passwords are made there.
- **Places, not machines.** A card says "the forge" and "the runner", not "my Mac mini", so whoever runs it maps each place to a machine they have.
- **The same shape every time**, so a stranger can follow it, and so can their AI assistant.
- **Checks instead of trust.** `check-env` looks at a machine the author never saw, and Verify proves it worked there, so you don't have to take the author's word for it.
- **Tested on a real machine**, so a card's badge tells you it still works today, not just when it was written.
- **Plain files in git**, so a card can be read before it's run, forked, compared, reviewed in a pull request, and shared back as a variant.

## What a card keeps and protects

Running something yourself only makes sense if you know what's yours and that it's safe. So a card says so, in the open, and every card's page shows it.

- **What it keeps.** Each volume the card makes is marked: yours alone (back it up), rebuilt by the app, or safe to lose. A backup takes what matters, and after a restore or a move a quick count of numbers and dates shows your data arrived, without anyone reading it.
- **What it protects.** Every password and key the app uses is listed, with where it comes from. The ones only the app needs are made on your machine the first time it starts. Nobody types them, and they're never written into a file you share or sent anywhere: not to your AI assistant, not to Edgible. The one you need, such as the admin's password, is made there too, and you see it with one command on that machine. Keys you bring, such as an AI model's, stay in `card.env` on your machine.
- **How well the app fits self-hosting.** A short list of facts about the app itself: does it keep its secrets in files, does it check its own health, does it start without root, does it run on both kinds of processor. Each card's tile shows how many it passes. They're facts, not opinions, and when an app falls short we'd rather ask its authors kindly than complain.

## A person behind every card

A card's app may be written by a person, with an AI's help, or entirely by an AI. Cards do not label that. They show who answers for the card: a person or an organisation (the steward), or that nobody does. Running or testing a card needs an Edgible account that a person created, and a person at Edgible reads a card before it is listed, so there is always a human responsible for what is here.

## Why "cards" and not a catalog

We thought about building a catalog of apps for a long time. The trouble is that a catalog is a promise: every app in it works, stays up to date, and is supported. Keeping that promise for every app out there would be a full-time job, and a fragile one.

So we made a smaller promise instead. A card belongs to whoever wrote it. It's their record of what worked for them, and they decide how it's built, down to whether they pin image versions. The apps themselves belong to their own projects, so a card gets each one running and reachable and then points you at that app's own docs. Our job at Edgible is the format and the tools around it.

## Same shape every time

Once you've used one card, you know how to use them all. Every README has the same sections (Why, What, How, Verify, Tear down) and the same steps, and the settings follow the same names. The [conventions table](https://github.com/edgible-org/card-kit#conventions) has the details if you're writing one.

We also wanted cards to be checkable rather than "trust me". Before you start, `check-env.py` looks at your machine for anything the card would trip over, like a port that's already taken or an app with the same name, and prints the fixes as lines you can paste. After you publish, the Verify section checks that each hostname answers the way it should. And Tear down takes everything apart in the right order, backing up your data before it deletes anything.

Because the steps are the same every time, they're easy to follow. That goes for you, and for an AI assistant if you're working with one: [Use cards with your AI](AI.md) shows how to set one up.

## Get involved

Have a look at the [cards](README.md) and try one. If you change one to suit yourself, share it back as a variant with a name that says what's different, like `n8n-sqlite`. And if you've built something in your own garage that you're proud of, we'd love to see it as a card. [CONTRIBUTING.md](CONTRIBUTING.md) explains how.
