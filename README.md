# SkillHub

A native macOS app for managing AI coding agent skills across multiple agents.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![License MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

## What is this

AI coding agents like Claude Code, Codex, and OpenCode support "skills" — Markdown files dropped into a config directory that give the agent extra context, instructions, or domain knowledge. Managing these across multiple agents and multiple skill sources quickly becomes painful: which skills are enabled for which agent? How do you enable a whole source at once?

SkillHub gives you a single window to see and control all of it.

## Features

- **Skill Matrix** — one row per skill, one column per agent; toggle any cell with a switch
- **Batch toggle** — click a source or group pill to enable/disable all its skills for an agent at once
- **Multi-source** — install from a Git URL or a local folder; multiple sources coexist
- **Auto-detect agents** — detects installed agents by checking their config paths; uninstalled agents appear dimmed
- **Live sync** — writes directly to each agent's config file on toggle; no separate "save" step
- **Search** — filter skills by name across all sources (⌘F)
- **Git update** — pull the latest skills from a Git-based source with one click

## Supported agents

| Agent | Config path |
|---|---|
| Claude Code | `~/.claude/` |
| Gemini CLI | `~/.gemini/` |
| Codex | `~/.codex/` |
| OpenCode | `~/.opencode/` |
| Copilot CLI | `~/.github-copilot/` |
| OpenClaw | `~/.openclaw/` |
| Hermes | `~/.hermes/` |

## Requirements

- macOS 14 Sonoma or later
- Xcode 15+ or Swift 5.9+ (to build from source)

## Build & run

```bash
git clone https://github.com/zzjzz9266a/skillhub.git
cd skillhub
swift run
```

Or open in Xcode:

```bash
open Package.swift
```

## Install a skill source

1. Click **+** in the toolbar
2. Paste a Git URL (e.g. `https://github.com/someone/skills`) or a local path
3. SkillHub clones/copies the source and shows all discovered skills in the matrix
4. Toggle individual skills or use the source-level pill to enable everything at once

## How skills work

A skill is a Markdown file (`.md`) inside a source directory. SkillHub reads the YAML front matter for metadata (name, description) and writes to each agent's config to register or deregister the skill.

```
my-skills/
├── code-review.md       # a skill
├── web-design.md        # another skill
└── tools/
    └── sql-helper.md    # grouped under "tools"
```

## Tech stack

- **SwiftUI + AppKit** — native macOS UI, `NSVisualEffectView` for sidebar vibrancy
- **GRDB** — SQLite via [GRDB.swift](https://github.com/groue/GRDB.swift) for local state
- **Yams** — YAML parsing via [Yams](https://github.com/jpsim/Yams) for skill front matter
- **Swift Package Manager** — no Xcode project file required

## License

MIT
