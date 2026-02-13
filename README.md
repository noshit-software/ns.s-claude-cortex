# Global Git Hooks & Short-Term Memory for Claude Code

## Plain Language Summary
The problem: Claude Code has amnesia. Every time its working memory fills up, it compresses everything into a vague summary and starts over. Then it has to re-read all your files to figure out where it was, which fills up the memory again, which triggers another compression. It's like someone who keeps forgetting where they put their keys, so they search the whole house every time, which makes them tired, which makes them forget again.

What we built: A tiny journal that Claude Code writes in after every commit. One line, heavily compressed, that says "I was working on this file, I made these decisions, I tried this and it didn't work, and here's what's next." It's written by a separate Claude instance so it doesn't cost the main session anything. And it lives on disk, so it survives the amnesia.
When Claude Code starts a new session or recovers from compression, it reads the journal first — maybe 200 tokens instead of re-reading thousands of tokens of source code. It knows where it left off without having to rediscover everything.

The clever bit is the codebook. Over time, terms that keep showing up get assigned short codes. src/agents/researcher.ts becomes R1. The journal entries get shorter as the project matures, which means they cost even less context to read back.

The practical bit is that none of this relies on Claude Code remembering to do it. A git hook fires automatically after every commit and tells Claude to write the entry. Same way your documentation hook forces docs to be updated — mechanical enforcement, not wishful thinking.

## What This Is

Two global git hooks that apply to every repository on your machine:

1. **Pre-commit: Documentation enforcement** — blocks commits that change code without updating CLAUDE.md or README.md
2. **Post-commit: Short-term memory** — after each commit, invokes the `claude` CLI to write a compressed state snapshot that future Claude Code sessions can use for fast context recovery

The short-term memory system solves the **compaction death spiral** — where Claude Code compacts its context, loses track of what it was doing, re-reads all the files to catch up, fills the context again, and compacts again in a tightening loop.

## How Short-Term Memory Works

### The Problem

Claude Code has no persistent state between sessions or across compactions. When context runs out:

1. Conversation gets compressed into a lossy prose summary
2. Claude Code loses specifics — what files were being edited, what was decided, what was tried and rejected
3. To recover, it re-reads source files, burning through context tokens
4. This fills the context faster, causing another compaction sooner
5. Each cycle gets shorter and less productive

### The Solution

After every commit, a post-commit hook invokes the `claude` CLI in a **separate, disposable context window** to write a one-line state snapshot to `.claude/shortterm.log`. This snapshot captures:

- What files were changed
- What task was being worked on
- What decisions were made
- What's next

The format is pipe-delimited and compressed using a project-specific codebook (`.claude/codebook.json`) that maps frequently-used terms to short abbreviations. A single snapshot is under 200 characters. The log keeps only the last 5 entries.

On session start, Claude Code reads the log and codebook (~200-500 tokens total) and immediately has context from recent work — without re-reading source files.

### The Codebook

The codebook starts empty (`{}`) and grows automatically. When the `claude` CLI writes a snapshot, it checks the existing log for repeated terms. If any term appears 3+ times, it gets added to the codebook as a short abbreviation.

Example after a few sessions on Nebula:

```json
{
  "R": "src/agents/researcher.ts",
  "B": "src/agents/builder.ts",
  "CA": "content-analysis",
  "DDG": "duckduckgo-search"
}
```

The codebook is capped at 2KB to prevent it from becoming its own context problem.

### What Gets Stored (and What Doesn't)

**Stored:**
- File paths that were changed
- Task summaries (what was being worked on)
- Decisions made (approaches chosen)
- Rejected approaches (what was tried and didn't work)
- Next steps

**Never stored:**
- File contents or code snippets
- Full conversation history
- Diffs or patches

The snapshot is a **pointer** — it tells Claude Code what to look at, not what the files contain.

## Files

```
~/.git-hooks/
├── pre-commit      # Documentation enforcement (blocks commit if no docs updated)
└── post-commit     # Short-term memory (writes state snapshot after each commit)
```

Each project gets these files automatically (created by the post-commit hook on first commit):

```
your-project/
└── .claude/
    ├── shortterm.log    # Last 5 state snapshots (one line each)
    └── codebook.json    # Project-specific abbreviations
```

## Setup

### Prerequisites

- Git
- Claude Code CLI (`claude` command available in PATH)

### Installation

```bash
# Create the global hooks directory
mkdir -p ~/.git-hooks

# Copy the hook files (from wherever you downloaded them)
cp pre-commit ~/.git-hooks/
cp post-commit ~/.git-hooks/

# Make them executable
chmod +x ~/.git-hooks/pre-commit
chmod +x ~/.git-hooks/post-commit

# Tell git to use global hooks for all repos
git config --global core.hooksPath ~/.git-hooks
```

### Verify Installation

```bash
# Confirm global hooks path is set
git config --global core.hooksPath
# Should output: /home/skyth/.git-hooks (or equivalent)

# Confirm hooks are executable
ls -la ~/.git-hooks/
# Should show -rwxr-xr-x for both files
```

### Add to CLAUDE.md

Append this to your platform-level CLAUDE.md so Claude Code knows to read the snapshots:

```markdown
## Short-Term Memory

State snapshots are written automatically after each commit via global post-commit hook.

**On session start:** Read `.claude/shortterm.log` and `.claude/codebook.json` before
doing anything else. These contain compressed context from recent sessions — use them
to orient yourself instead of re-reading files unnecessarily.

**Format:** Each log line is pipe-delimited:
`timestamp|project|files-changed|task-summary|decisions|next-steps`

**Codebook:** `.claude/codebook.json` maps frequently-used terms to short abbreviations.
Use existing abbreviations when writing snapshots. If a term appears 3+ times in the
log, add a new codebook entry. Keep codebook under 2KB.

**Rules:**
- Log is capped at 5 entries — oldest are trimmed automatically
- Snapshots are written by the post-commit hook, not manually
- Never store file contents or code in snapshots — only references and summaries
- If shortterm.log doesn't exist yet, proceed normally — it'll populate after first commit
```

## Removing Local Hooks

Since global hooks replace per-project hooks, remove any local hooks that duplicate the same behavior:

```bash
# In each project that has local hooks
rm .git/hooks/pre-commit
rm .git/hooks/post-commit
```

Note: if a repo sets its own `core.hooksPath` in local git config, that overrides the global setting. Check with:

```bash
git config --local core.hooksPath
# If this returns a value, that repo is using local hooks, not global
```

To remove the local override:

```bash
git config --local --unset core.hooksPath
```

## Troubleshooting

### Pre-commit hook blocks my commit but I don't have docs to update

The hook only triggers when `.ts` or `.js` files are staged (excluding tests and package-lock). If you're committing a code change that genuinely doesn't need documentation, you can bypass once:

```bash
git commit --no-verify -m "your message"
```

Use sparingly — the hook exists for a reason.

### Post-commit hook doesn't seem to be running

1. Check that `claude` CLI is in your PATH: `which claude`
2. The hook silently exits if `claude` isn't found — this is intentional so it doesn't block commits on machines without Claude Code
3. Check if `.claude/shortterm.log` exists in your project after committing

### Context window still filling up fast

The short-term memory system reduces recovery cost after compaction, but doesn't prevent compaction itself. Other things that eat context:

- Large CLAUDE.md files (audit and trim — aim for under 5KB)
- MCP server tool definitions
- Reading large source files repeatedly
- Long unbroken sessions (break work into smaller tasks, commit often)

### Codebook growing too large

The 2KB cap is enforced by the `claude` CLI prompt, not mechanically. If it drifts, manually trim `.claude/codebook.json` — remove entries that are no longer relevant to active work.

## How It All Fits Together

```
You type a message in Claude Code
    ↓
Claude Code reads CLAUDE.md (includes short-term memory instructions)
    ↓
Claude Code reads .claude/shortterm.log + codebook.json (~200-500 tokens)
    ↓
Claude Code has recent context without re-reading source files
    ↓
You work, Claude Code works, context fills up naturally
    ↓
You commit (frequently and incrementally)
    ↓
Post-commit hook fires → claude CLI writes snapshot in separate context
    ↓
Main session continues uninterrupted
    ↓
Eventually context compacts
    ↓
On recovery, Claude Code reads the fresh snapshots instead of
re-reading every file from scratch → faster recovery, less context burn
```
