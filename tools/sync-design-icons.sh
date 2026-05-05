#!/bin/bash
# Sync icon-*.png from a fresh claude.ai/design export into assets/.
#
# Filter icons (Überall, Erziehung, Alltagstraining, Hundebegegnungen,
# Beschäftigung & Events, Problemverhalten — each in default + white
# variants) are visual primitives that the design tool owns. Whenever
# the design refreshes them, we want the new versions in the repo.
#
# Photos (JPGs) are NOT touched by this script — those are handled by
# resize-assets.ps1 in their own naming convention.
#
# Usage:
#   bash tools/sync-design-icons.sh <design-extract-dir>
# e.g.
#   bash tools/sync-design-icons.sh /c/DATA/Claude/design-extract-v15

set -e
SRC_DIR="${1:?usage: $0 <design-extract-dir>}"
DST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets"

if [ ! -d "$SRC_DIR/assets" ]; then
    echo "ERR: $SRC_DIR/assets not found"
    exit 1
fi

changed=0
synced=0
for src in "$SRC_DIR/assets"/icon-*.png; do
    [ -f "$src" ] || continue
    name=$(basename "$src")
    dst="$DST_DIR/$name"
    if [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        echo "  added:   $name"
        changed=$((changed+1))
    elif ! cmp -s "$src" "$dst"; then
        cp "$src" "$dst"
        echo "  updated: $name"
        changed=$((changed+1))
    fi
    synced=$((synced+1))
done

echo "icon sync: $changed changed, $synced total checked"
