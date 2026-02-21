#!/bin/sh
# Cortex uninstaller — removes the post-commit hook
# Run: sh uninstall.sh

set -e

HOOKS_DIR="$HOME/.git-hooks"
HOOK_FILE="$HOOKS_DIR/post-commit"

echo ""
echo "=== Uninstalling Cortex ==="
echo ""

if [ -f "$HOOK_FILE" ]; then
    rm "$HOOK_FILE"
    echo "Removed $HOOK_FILE"
else
    echo "No hook found at $HOOK_FILE — nothing to remove."
fi

# Check if hooks dir is now empty
if [ -d "$HOOKS_DIR" ] && [ -z "$(ls -A "$HOOKS_DIR")" ]; then
    rmdir "$HOOKS_DIR"
    git config --global --unset core.hooksPath 2>/dev/null || true
    echo "Removed empty $HOOKS_DIR and unset global hooks path."
else
    echo "Other hooks still in $HOOKS_DIR — left hooks path as-is."
fi

echo ""
echo "Note: .claude/shortterm.log and .claude/codebook.json in your"
echo "projects are harmless and can be left alone or deleted manually."
echo ""
echo "Done."
echo ""
