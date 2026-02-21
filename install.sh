#!/bin/sh
# Cortex installer — short-term memory for Claude Code
# Run: curl -fsSL <url>/install.sh | sh
#   or: sh install.sh

set -e

HOOKS_DIR="$HOME/.git-hooks"
HOOK_FILE="$HOOKS_DIR/post-commit"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "=== Cortex: Short-Term Memory for Claude Code ==="
echo ""

# 1. Create hooks directory
mkdir -p "$HOOKS_DIR"
echo "[1/4] Created $HOOKS_DIR"

# 2. Copy hook (or warn if one exists)
if [ -f "$HOOK_FILE" ]; then
    echo ""
    echo "WARNING: $HOOK_FILE already exists."
    printf "Overwrite? [y/N] "
    read -r REPLY
    if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
        echo "Skipped. You can manually merge the hook from: $SCRIPT_DIR/post-commit"
        echo ""
    else
        cp "$SCRIPT_DIR/post-commit" "$HOOK_FILE"
        echo "[2/4] Replaced $HOOK_FILE"
    fi
else
    cp "$SCRIPT_DIR/post-commit" "$HOOK_FILE"
    echo "[2/4] Installed $HOOK_FILE"
fi

# 3. Make executable
chmod +x "$HOOK_FILE"
echo "[3/4] Made hook executable"

# 4. Set global hooks path
CURRENT_HOOKS_PATH=$(git config --global core.hooksPath 2>/dev/null || echo "")
if [ "$CURRENT_HOOKS_PATH" = "$HOOKS_DIR" ]; then
    echo "[4/4] Global hooks path already set to $HOOKS_DIR"
elif [ -n "$CURRENT_HOOKS_PATH" ]; then
    echo ""
    echo "WARNING: Global hooks path is already set to: $CURRENT_HOOKS_PATH"
    printf "Change to $HOOKS_DIR? [y/N] "
    read -r REPLY
    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
        git config --global core.hooksPath "$HOOKS_DIR"
        echo "[4/4] Updated global hooks path to $HOOKS_DIR"
    else
        echo "[4/4] Skipped. Hook installed but won't run until hooks path is set."
    fi
else
    git config --global core.hooksPath "$HOOKS_DIR"
    echo "[4/4] Set global hooks path to $HOOKS_DIR"
fi

# 5. Check for claude CLI
echo ""
if command -v claude >/dev/null 2>&1; then
    echo "Claude CLI found: $(which claude)"
else
    echo "NOTE: Claude Code CLI (claude) not found in PATH."
    echo "The hook will silently skip until claude is installed."
    echo "Install: https://docs.anthropic.com/en/docs/claude-code"
fi

# 6. Remind about CLAUDE.md
echo ""
echo "=== Done! ==="
echo ""
echo "One more thing: add the short-term memory instructions to your"
echo "platform-level CLAUDE.md so Claude Code reads the snapshots."
echo ""
echo "The snippet is in: shortterm-memory-claudemd-snippet.md"
echo "Copy its contents into your ~/.claude/CLAUDE.md (or equivalent)."
echo ""
