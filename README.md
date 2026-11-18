# herdr compact tree patch

A patch for [herdr](https://github.com/herdrdev/herdr) that makes the worktree tree in the Spaces sidebar
configurable, so a narrow sidebar spends its columns on names instead of indentation. Without settings, herdr looks
the same as before.

## Build and install

Needs git, curl, and [rustup](https://rustup.rs).

```bash
./build.sh --install            # build and install (backs up your current herdr)
./preset.sh compact             # set a preset
herdr server stop && herdr      # restart herdr to use it (from outside herdr)
```

`herdr update` replaces the patched build with an official one.

## Presets

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

## Adding a preset

Copy a file in [`presets/`](presets), change its values, and set it with `./preset.sh NAME`. Each value is the text
drawn before a sidebar line:

| Key | Line |
|---|---|
| `top_first` | repo, first line |
| `top_rest` | repo, later lines, no worktrees shown |
| `group_rest` | repo, later lines, worktrees shown |
| `child_first` / `last_child_first` | worktree, first line |
| `child_rest` / `last_child_rest` | worktree, later lines |

## Supported versions

| herdr | Patch |
|---|---|
| v0.9.3 | [`patches/v0.9.3/compact-tree.patch`](patches/v0.9.3/compact-tree.patch) |

## What changes

- `src/config/sidebar.rs`: the settings under `[ui.sidebar.spaces.tree]`, defaulting to herdr's current tree.
- `src/client/shell/sidebar.rs`, `src/client/shell/endpoint_sidebar.rs`: draw the configured text instead of the
  hard-coded tree.
- `src/config.rs`: exports the settings.

## References

- [herdrdev/herdr#2321](https://github.com/herdrdev/herdr/discussions/2321): configurable worktree indentation
- [herdrdev/herdr#4634](https://github.com/herdrdev/herdr/discussions/4634): compact worktree layout
