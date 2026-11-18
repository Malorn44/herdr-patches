# herdr patches

Small patches for [herdr](https://github.com/herdrdev/herdr), built from an official release:

- **Compact tree:** makes the worktree tree in the Spaces sidebar configurable, so a narrow sidebar spends its
  columns on names instead of indentation. Without settings, herdr looks the same as before.
- **WSL file links:** under WSL, rewrites `file:///home/...` links from programs in panes to
  `file://wsl.localhost/<distro>/home/...` (and `file:///mnt/c/...` to `file:///C:/...`), which Windows Terminal
  can open.

## Build and install

Needs git, curl, and [rustup](https://rustup.rs).

```bash
./build.sh --install                        # build with every patch and install (backs up your herdr)
./build.sh --install --patch compact-tree   # or pick patches (repeatable; --list shows them)
./preset.sh compact                         # set a tree preset
herdr server stop && herdr                  # restart herdr to use it (from outside herdr)
```

`herdr update` replaces the patched build with an official one.

## Tree presets

```text
default                 compact                 thin                    rail
 ● my-repo              ● my-repo               ● my-repo               ● my-repo
   main                 │ main                  │ main                  │ main
   ├─ ○ feature-log…    ├─ ○ feature-login-…    ├ ○ feature-login-p…    │○ feature-login-pa…
   │    ○ in review     │  ○ in review          │ ○ in review           │  ○ in review
   └─ ○ fix-crash-o…    └─ ○ fix-crash-on-s…    └ ○ fix-crash-on-st…    │○ fix-crash-on-sta…
        ● ci running       ● ci running           ● ci running          │  ● ci running
```

Set one with `./preset.sh NAME`. Requires the patched build (see above).

To add one, copy a file in [`presets/`](presets), change its values, and set it with `./preset.sh NAME`. Each value
is the text drawn before a sidebar line:

| Key | Line |
|---|---|
| `top_first` | repo, first line |
| `top_rest` | repo, later lines, no worktrees shown |
| `group_rest` | repo, later lines, worktrees shown |
| `child_first` / `last_child_first` | worktree, first line |
| `child_rest` / `last_child_rest` | worktree, later lines |

## WSL file links

Nothing to set: it applies when `WSL_DISTRO_NAME` is set. Web links, `C:/...` paths and links already in the
`wsl.localhost` form pass through unchanged.

## Supported versions

| herdr | Patches |
|---|---|
| v0.9.3 | [`compact-tree`](patches/v0.9.3/compact-tree.patch), [`wsl-file-links`](patches/v0.9.3/wsl-file-links.patch) |

## What changes

- **compact-tree:** `src/config/sidebar.rs` adds the settings under `[ui.sidebar.spaces.tree]`, defaulting to
  herdr's current tree; `src/client/shell/sidebar.rs` and `endpoint_sidebar.rs` draw them instead of the hard-coded
  tree; `src/config.rs` exports them.
- **wsl-file-links:** `src/protocol/render_ansi.rs` rewrites the link as herdr writes it to your terminal.

## References

- [herdrdev/herdr#2321](https://github.com/herdrdev/herdr/discussions/2321): configurable worktree indentation
- [herdrdev/herdr#4634](https://github.com/herdrdev/herdr/discussions/4634): compact worktree layout
- [microsoft/terminal `TerminalPage.cpp`](https://github.com/microsoft/terminal/blob/main/src/cascadia/TerminalApp/TerminalPage.cpp):
  which `file://` links Windows Terminal opens
