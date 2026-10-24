# Use cards with your AI

With an AI agent, such as Claude Code, you don't need to know which app you want or how a card works. Describe what you need in your own words. Your agent finds a card that fits, sets it up on your machine, checks that it works, and looks after it afterwards. When no card fits, it builds one with you, and you can share it back so the next person's agent finds it.

![With an AI agent: you describe a need and the agent suggests options from the cards. If a card fits, it deploys it on your machine. If not, it builds a new card with you, and you share it back so the next person finds it](about/ai-loop.svg)

## What you need

- **An AI agent that runs commands on your machine.** We test with Claude Code. The skill is in the open Agent Skills format, so other agents that read it should be able to use it too, but we haven't measured how well yet.
- **Edgible on that machine:** the `edgible` CLI, logged in, with the machine added as a serving device. [Start here](https://guides.edgible.com/guides/start-here/index.html) if you haven't yet.
- **Docker**, for most cards. A native card, such as [ollama-osx](ollama-osx), runs without it.

## Install the skill

The skill is what teaches your agent about cards. For Claude Code:

```bash
git clone https://github.com/edgible-org/card-kit.git ~/.card-kit
mkdir -p ~/.claude/skills
ln -s ~/.card-kit/skills/edgible-cards ~/.claude/skills/edgible-cards
```

`git -C ~/.card-kit pull` keeps it up to date. For another agent, put the `edgible-cards` folder where that agent reads skills. To check it's there, ask: "What can you do with Edgible cards?"

## Ask in your own words

No special phrasing. Talk to it the way you'd talk to a friend who knows self-hosting:

- "Pocket is shutting down. I want to keep my saved articles and still read them on my phone." It offers two or three bookmark apps, recommends one, and says how the phone app signs in.
- "We pay $14 a month for website analytics. Could we run our own?" It points to the umami card, and is honest about whether the saving is worth the upkeep.
- "Get Uptime Kuma running so I hear when my site goes down." It uses the tested card and puts its choices to you before starting anything.
- "I want my Ollama models on my Mac's GPU, usable from anywhere." It sets up ollama-osx, behind an API key.
- "What's running, and is it all healthy?" A short table: each card, its hostnames, and whether each is up.
- "Gitea won't load on my phone today. What's wrong?" It works from the app outwards, and tells you what it found.
- "Back up Vaultwarden before I upgrade it." It backs up, upgrades, and checks it still works.

More, with what a good answer does, in [What to ask](https://github.com/edgible-org/card-kit/blob/main/skills/edgible-cards/EXAMPLES.md).

## When no card fits

Your agent doesn't stop at "there's no card for that":

1. It shortlists apps for your need from awesome-selfhosted, maintained and with a container image, and you pick one.
2. It writes a new card for it, in the same shape as every other card.
3. It tests the card end to end on your machine, with the same test the nightly regression runs, and shows you the result.
4. With your yes, it opens a pull request to [edgible-org/cards](https://github.com/edgible-org/cards), with the test result in it. Once it's reviewed and merged, the regression keeps testing it, and the next person's agent finds it.

If it can't make a card pass, it offers to open an issue instead, with what it tried. A fix to an existing card goes the same way.

## What it always asks you first

- Publishing an admin or personal page open to anyone.
- Installing software on the machine itself (a native card), or giving a container control of Docker.
- Stopping, changing or deleting anything it didn't set up, deleting data, upgrades, and moves. It backs up first.
- Anything that leaves your machine, such as a pull request or an issue.

It never shows your passwords in the chat. They stay in the card's `card.env` on your machine, and it tells you which line holds the one you need.

## Connect with MCP

The skill teaches an agent how to work with cards. The edgible-mcp server gives any [MCP](https://modelcontextprotocol.io) client a few tools that answer from the live catalog and your Edgible account. Today they only read, so they can't change anything:

- **find** searches the cards for a need in your own words, with how well it suits Edgible and how to publish it.
- **describe** shows one card: its apps, auth modes, minimum machine, and test status.
- **whats_running** lists your devices and apps, and checks that each hostname answers the way its auth mode says.

There are two ways to connect it:

- **On your own computer**, over stdio, using that computer's `edgible` sign-in. See [card-kit's edgible-mcp](https://github.com/edgible-org/card-kit/tree/main/edgible-mcp#run-it).
- **From anywhere**, with the [edgible-mcp](edgible-mcp) card. It runs the server on your machine behind an Edgible API key, one per person. Claude Code and other clients that can send a header work with it. Claude's desktop and web connectors expect their own sign-in, so they can't use it yet.

The skill and the server work well together: the skill knows what to ask and how to set things up, and the tools give it fresh answers without a terminal.

### What's coming

- **A public finder.** find and describe with no sign-in, which you'll be able to add as a connector in Claude's and ChatGPT's apps.
- **Tools that act.** A second release adds tools to deploy a card and to remove one, following the card's own steps and asking you first, as the skill does. They ship once they've passed on our test machines.
- **More to check.** Backup and health status for each app in whats_running, as those features land.
- **Measured on more agents.** We'll test the skill and these tools on other agents and models, not only Claude, and show the results here.

## Without a terminal

In Claude's desktop or web app, the skill runs in a sandbox that can't reach your machine. It still helps you choose, and then gives you each command to run yourself, one step at a time, and reads what you paste back.
