#!/usr/bin/env bash
# Build herdr from an official release tag with the patches in patches/<version>/ applied.
#
#   ./build.sh [--install] [--patch NAME]... [VERSION]
#   ./build.sh --list
#
#   VERSION     a herdr release tag with a folder under patches/ (default: the
#               newest one there)
#   --install   copy the build over your current herdr (backed up first);
#               restart the herdr server afterwards to use it
#   --patch     apply only this patch (repeatable; default: every patch for
#               the version). NAME is the file name without .patch
#   --list      show the patches for each version
#
# Environment:
#   INSTALL_DIR   where --install puts herdr (default: the directory of the
#                 herdr on your PATH, else ~/.local/bin)
#   WORK_DIR      clone/build directory (default: ~/.cache/herdr-patches)
#
# Needs git, curl, and rustup/cargo (herdr pins its Rust version). Zig, which
# herdr's terminal library needs, is downloaded once and checksum-verified.

set -euo pipefail

ZIG_VERSION=0.16.0
here=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}/herdr-patches
work=${WORK_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/herdr-patches}

install=0
version=""
chosen=()
while [ $# -gt 0 ]; do
  arg=$1; shift
  case "$arg" in
    --install) install=1 ;;
    --patch) chosen+=("${1:?--patch needs a name}"); shift ;;
    --list)
      for d in "$here"/patches/*/; do
        echo "$(basename "$d"): $(ls "$d" | sed -n 's/\.patch$//p' | tr '\n' ' ')"
      done
      exit 0 ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    v*) version=$arg ;;
    *) echo "unknown argument: $arg (see --help)" >&2; exit 2 ;;
  esac
done
if [ -z "$version" ]; then
  version=$(ls "$here/patches" | sort -V | tail -1)
fi
patch_dir="$here/patches/$version"
if [ ! -d "$patch_dir" ]; then
  echo "no patch for herdr $version; supported: $(ls "$here/patches" | tr '\n' ' ')" >&2
  exit 1
fi
available=$(ls "$patch_dir" | sed -n 's/\.patch$//p')
if [ ${#chosen[@]} -eq 0 ]; then
  mapfile -t chosen <<< "$available"
fi
for name in "${chosen[@]}"; do
  if ! grep -qx -- "$name" <<< "$available"; then
    echo "no patch '$name' for herdr $version; available: $(tr '\n' ' ' <<< "$available")" >&2
    exit 1
  fi
done

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

# Zig, per platform (checksums from https://ziglang.org/download/index.json).
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)               zig_target=x86_64-linux;  zig_sha=70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00 ;;
  Linux-aarch64|Linux-arm64)  zig_target=aarch64-linux; zig_sha=ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17 ;;
  Darwin-x86_64)              zig_target=x86_64-macos;  zig_sha=0387557ed1877bc6a2e1802c8391953baddba76081876301c522f52977b52ba7 ;;
  Darwin-arm64)               zig_target=aarch64-macos; zig_sha=b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489 ;;
  *) echo "unsupported platform: $(uname -s) $(uname -m)" >&2; exit 1 ;;
esac
zig="$data/zig-$zig_target-$ZIG_VERSION/zig"
if [ ! -x "$zig" ]; then
  echo "downloading zig $ZIG_VERSION"
  mkdir -p "$data" "$work"
  tarball="$work/zig.tar.xz"
  curl -sSLf --retry 5 --retry-all-errors --retry-delay 1 -o "$tarball" "https://ziglang.org/download/$ZIG_VERSION/zig-$zig_target-$ZIG_VERSION.tar.xz"
  echo "$zig_sha  $tarball" | sha256 -c - >/dev/null
  tar -xJf "$tarball" -C "$data"
  rm "$tarball"
fi

# Fresh official source at the tag, then the patches.
src="$work/herdr-$version"
rm -rf "$src"
mkdir -p "$work"
git clone --quiet --depth 1 --branch "$version" https://github.com/herdrdev/herdr.git "$src" 2>/dev/null
for name in "${chosen[@]}"; do
  p="$patch_dir/$name.patch"
  if ! git -C "$src" apply --check "$p" 2>/dev/null; then
    echo "$(basename "$p") doesn't apply to herdr $version" >&2
    exit 1
  fi
  git -C "$src" apply "$p"
  echo "applied $(basename "$p")"
done

# Zig's package downloader can fail TLS (flaky networks, some proxies) where
# curl with retries gets through. When the build stops on a dependency
# download, fetch it with curl into Zig's package cache and try again.
log="$work/build.log"
echo "building herdr $version (a few minutes the first time)"
for attempt in $(seq 1 15); do
  # Show cargo's progress while keeping a copy of its output for the check below.
  if (cd "$src" && ZIG="$zig" CARGO_TERM_PROGRESS_WHEN=always \
      CARGO_TERM_PROGRESS_WIDTH="$(tput cols 2>/dev/null || echo 80)" cargo build --release) 2>&1 | tee "$log"; then
    break
  fi
  url=$(grep -A1 "unable to connect to server" "$log" | grep -oE 'https://[^"]+' | head -1 || true)
  if [ -z "$url" ] || [ "$attempt" = 15 ]; then
    exit 1
  fi
  echo "fetching zig dependency $(basename "$url") with curl"
  curl -sSLf --retry 5 --retry-all-errors --retry-delay 1 -o "$work/$(basename "$url")" "$url"
  (cd "$src/vendor/libghostty-vt" && "$zig" fetch "$work/$(basename "$url")" >/dev/null)
  rm "$work/$(basename "$url")"
done

out="$work/herdr-$version$(printf '+%s' "${chosen[@]}")"
cp "$src/target/release/herdr" "$out"
echo "built $out"

if [ "$install" = 1 ]; then
  current=$(command -v herdr || true)
  dest=${INSTALL_DIR:-${current:+$(dirname "$current")}}
  dest=${dest:-$HOME/.local/bin}
  mkdir -p "$dest"
  if [ -e "$dest/herdr" ]; then
    backup="$dest/herdr.backup-$(date +%Y%m%d-%H%M%S)"
    cp -p "$dest/herdr" "$backup"
    echo "backed up the previous herdr to $backup"
  fi
  cp "$out" "$dest/herdr.new"
  mv -f "$dest/herdr.new" "$dest/herdr"
  echo "installed $dest/herdr; restart the herdr server to use it (herdr server stop, then herdr)"
fi
