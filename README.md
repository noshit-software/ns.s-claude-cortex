# Cortex: Short-Term Memory for Claude Code

Claude Code has amnesia. Every time its working memory fills up, it compresses everything into a vague summary and starts over. Then it re-reads all your files to figure out where it was, which fills up the memory again, which triggers another compression. Repeat forever.

Cortex fixes this. A git hook fires after every commit and writes a one-line journal entry — what changed, what was decided, what's next. Written by a separate Claude instance so it costs the main session nothing. Lives on disk, survives the amnesia.

When Claude Code starts fresh or recovers from compression, it reads the journal (~200 tokens) instead of re-reading thousands of tokens of source code.

## Install

```bash
git clone https://github.com/noshit-software/claude-cortex.git
cd claude-cortex
sh install.sh
```

The installer:
1. Copies `post-commit` to `~/.git-hooks/`
2. Makes it executable
3. Sets `git config --global core.hooksPath ~/.git-hooks`
4. Checks that the `claude` CLI is available

Then add the CLAUDE.md snippet (see below).

To remove: `sh uninstall.sh`

## After Installing: Add to CLAUDE.md

Copy the contents of [shortterm-memory-claudemd-snippet.md](shortterm-memory-claudemd-snippet.md) into your platform-level `~/.claude/CLAUDE.md`. This tells Claude Code to read the snapshots on startup.

## How It Works

After every commit, the `post-commit` hook:

1. Invokes `claude` CLI in a **separate, disposable context window**
2. Writes a one-line pipe-delimited snapshot to `.claude/shortterm.log`
3. Updates `.claude/codebook.json` if any terms have become frequent enough for abbreviation

The snapshot captures what files changed, what task was being worked on, what decisions were made, and what's next. The log keeps only the last 5 entries.

### The Codebook

Over time, terms that keep showing up get assigned short codes. `src/agents/researcher.ts` becomes `R`. Journal entries get shorter as the project matures.

```json
{
  "R": "src/agents/researcher.ts",
  "B": "src/agents/builder.ts",
  "CA": "content-analysis"
}
```

Capped at 2KB. Grows automatically, prune manually if needed.

### What Gets Stored

- File paths that changed
- Task summaries
- Decisions and rejected approaches
- Next steps

Never stored: file contents, code snippets, diffs, conversation history. The snapshot is a **pointer** — it tells Claude Code what to look at, not what the files contain.

## Files

After install:
```
~/.git-hooks/
└── post-commit
```

Created automatically per-project on first commit:
```
your-project/.claude/
├── shortterm.log    # Last 5 state snapshots
└── codebook.json    # Project-specific abbreviations
```

## Requirements

- Git
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` in PATH)

The hook silently does nothing if `claude` isn't installed — it won't block your commits.

## Troubleshooting

**Hook doesn't seem to run:** Check `which claude`. The hook exits silently if the CLI isn't found. Look for `.claude/shortterm.log` in your project after committing.

**Context still fills up fast:** Cortex reduces recovery cost after compaction — it doesn't prevent compaction. Also check: large CLAUDE.md files (aim for under 5KB), MCP tool definitions, long unbroken sessions.

**Codebook too large:** Manually trim `.claude/codebook.json` — remove entries for things you're no longer working on.

## How It All Fits Together

```
You type a message in Claude Code
    |
Claude Code reads CLAUDE.md (includes short-term memory instructions)
    |
Claude Code reads .claude/shortterm.log + codebook.json (~200 tokens)
    |
Claude Code has recent context without re-reading source files
    |
You work, context fills up, you commit frequently
    |
Post-commit hook fires -> claude CLI writes snapshot in separate context
    |
Main session continues uninterrupted
    |
Context compacts -> Claude Code reads fresh snapshots -> fast recovery
```
