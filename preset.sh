#!/usr/bin/env bash
# Put a preset's [ui.sidebar.spaces.tree] table into herdr's config.toml and
# reload herdr.
#
#   ./preset.sh NAME   use presets/NAME.toml (replaces any existing tree table)
#   ./preset.sh        list the presets
#
# herdr's config is $XDG_CONFIG_HOME/herdr/config.toml, or
# ~/.config/herdr/config.toml without XDG_CONFIG_HOME. The previous config is
# kept as config.toml.bak.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
config="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml"

if [ $# -eq 0 ]; then
  for f in "$here"/presets/*.toml; do
    printf '%-10s %s\n' "$(basename "$f" .toml)" "$(head -1 "$f" | sed 's/^# [^:]*: //')"
  done
  exit 0
fi
preset="$here/presets/$1.toml"
if [ ! -f "$preset" ]; then
  echo "no preset '$1'; run ./preset.sh to list them" >&2
  exit 1
fi

mkdir -p "$(dirname "$config")"
touch "$config"
cp "$config" "$config.bak"

# Drop an existing [ui.sidebar.spaces.tree] table (up to the next table
# header) and our marker comment, then append the preset's table.
marker="# herdr-compact-tree preset:"
awk -v marker="$marker" '
  index($0, marker) == 1 { next }
  /^[[:space:]]*\[ui\.sidebar\.spaces\.tree\][[:space:]]*(#.*)?$/ { skip = 1; next }
  skip && /^[[:space:]]*\[/ { skip = 0 }
  !skip { print }
' "$config.bak" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$config"
{ echo; echo "$marker $1 (set by preset.sh)"; grep -v '^#' "$preset"; } >> "$config"
echo "set preset $1 in $config (previous: $config.bak)"

if command -v herdr >/dev/null; then
  herdr config check || true
  herdr server reload-config >/dev/null 2>&1 && echo "reloaded herdr" || echo "herdr isn't running; it will use the preset on next start"
fi
