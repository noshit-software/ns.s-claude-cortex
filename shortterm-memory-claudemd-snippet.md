## Short-Term Memory

State snapshots are written automatically after each commit via global post-commit hook.

**On session start:** Read `.claude/shortterm.log` and `.claude/codebook.json` before doing anything else. These contain compressed context from recent sessions — use them to orient yourself instead of re-reading files unnecessarily.

**Format:** Each log line is pipe-delimited: `timestamp|project|files-changed|task-summary|decisions|next-steps`

**Codebook:** `.claude/codebook.json` maps frequently-used terms to short abbreviations. Use existing abbreviations when writing snapshots. If a term appears 3+ times in the log, add a new codebook entry. Keep codebook under 2KB.

**Rules:**
- Log is capped at 5 entries — oldest are trimmed automatically
- Snapshots are written by the post-commit hook, not manually
- Never store file contents or code in snapshots — only references and summaries
- If shortterm.log doesn't exist yet, proceed normally — it'll populate after the first commit
