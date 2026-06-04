# claude-mergerc

A zsh plugin that merges multiple JSON or YAML fragments into your `~/.claude/settings.json`, with an interactive diff/apply flow.

Claude Code reads a single `settings.json`, but splitting that config across smaller, purpose-scoped fragments is often easier to maintain. `claude-mergerc` deep-merges the fragments into one file, shows you a diff, and lets you apply, back up, or edit manually before overwriting.

Fragments may be written in YAML, and the diff/manual-merge flow can run in YAML (`-y`) — but the output written to `settings.json` is **always JSON**, since that's the only format Claude Code reads.

## Requirements

- `zsh`
- [`jq`](https://jqlang.org/)
- [`yq`](https://github.com/mikefarah/yq) (mikefarah, v4+) — required only for YAML fragments and YAML mode (`-y`)
- Optional: [`delta`](https://github.com/dandavison/delta) or `colordiff` for nicer diffs (falls back to `diff --color`)

## Installation

### [zinit](https://github.com/zdharma-continuum/zinit)

```zsh
zinit light bezhermoso/claude-mergerc
```

### [oh-my-zsh](https://ohmyz.sh/)

```zsh
git clone https://github.com/bezhermoso/claude-mergerc \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/claude-mergerc
```

Then add `claude-mergerc` to your `plugins=(...)` in `~/.zshrc`.

### Manual

```zsh
git clone https://github.com/bezhermoso/claude-mergerc ~/.zsh/claude-mergerc
echo 'source ~/.zsh/claude-mergerc/claude-mergerc.plugin.zsh' >> ~/.zshrc
```

## Usage

Drop JSON or YAML fragments into your fragments directory (default: `~/.config/claude/fragments/`), then run:

```zsh
claude-mergerc
```

The command will:

1. Deep-merge every `*.json`, `*.yaml`, and `*.yml` file under the fragments directory (sorted by filename). YAML fragments are converted to JSON (via `yq`) before merging.
2. Compare the result against your existing `~/.claude/settings.json`.
3. Show a diff, then prompt:
   - **[a]** Apply merged config (overwrite current)
   - **[b]** Backup current, then apply
   - **[e]** Manual merge in `$EDITOR` (vimdiff-style): a `to-apply` buffer seeded from your current settings opens next to the read-only-by-convention `from-fragments` merge result. Pull in the hunks you want, save, quit — `to-apply` is what gets written.
   - **[q]** Quit, no changes

If `~/.claude/settings.json` doesn't exist yet, it prints the merged output and asks whether to create it.

### Flags

```
claude-mergerc [-d DIR]... [-i GLOB]... [-x GLOB]... [-y] [-h]
```

| Flag       | Purpose                                                                 |
| ---------- | ----------------------------------------------------------------------- |
| `-d DIR`   | Add a fragments directory (repeatable). Extends `CLAUDE_MERGERC_FRAGMENTS_DIR`. |
| `-i GLOB`  | Add an include pattern — filename glob (repeatable). Extends `CLAUDE_MERGERC_INCLUDE`. |
| `-x GLOB`  | Add an exclude pattern — filename glob (repeatable). Extends `CLAUDE_MERGERC_EXCLUDE`. |
| `-y`       | YAML mode: stage the merged config as YAML, diff in YAML, and manual-merge in YAML buffers. Output is still JSON. |
| `-h`       | Show help.                                                              |

Examples:

```zsh
# Merge only the base + permission fragments
claude-mergerc -i '00-*.json' -i '10-*.json'

# Merge shared fragments plus a work-only overlay directory
claude-mergerc -d ~/.config/claude/fragments-work

# Skip any experimental fragments
claude-mergerc -x '*-experimental.json'
```

## Configuration

Override defaults via environment variables. List-valued variables use `:` as the separator (like `$PATH`):

| Variable                        | Default                                                 |
| ------------------------------- | ------------------------------------------------------- |
| `CLAUDE_MERGERC_FRAGMENTS_DIR`  | `${XDG_CONFIG_HOME:-$HOME/.config}/claude/fragments`    |
| `CLAUDE_MERGERC_INCLUDE`        | `*.json:*.yaml:*.yml`                                   |
| `CLAUDE_MERGERC_EXCLUDE`        | *(none)*                                                |
| `CLAUDE_MERGERC_OUTPUT`         | `$HOME/.claude/settings.json`                           |
| `CLAUDE_MERGERC_YAML`           | *(unset)* — set to `1` to enable YAML mode (same as `-y`) |

Example:

```zsh
# Two fragment dirs: personal first, then work overlay
export CLAUDE_MERGERC_FRAGMENTS_DIR="$HOME/.dotfiles/claude/fragments:$HOME/.config/claude/fragments-work"

# Always skip local overrides and experimental fragments
export CLAUDE_MERGERC_EXCLUDE="99-local.json:*-experimental.json"
```

CLI flags extend these lists for a single invocation rather than replacing them.

## Merge behavior

- **Objects** are deep-merged key by key.
- **Arrays** are concatenated and deduplicated (`unique`).
- **Scalars** (strings, numbers, booleans): later fragments win.

Within each directory, fragments are sorted by filename — so prefixes like `00-base.json`, `10-permissions.json`, `99-overrides.json` control precedence. Across directories, earlier dirs are base layers and later dirs are overlays: a fragment in a later dir wins over same-keyed values from earlier dirs.

## YAML support

Requires [`yq`](https://github.com/mikefarah/yq) (mikefarah, v4+). JSON-only setups don't need it.

### YAML fragments

Fragments can be `*.yaml` / `*.yml` — handy for comments and less quoting:

```yaml
# 20-hooks.yaml — comments survive in the fragment (not in the output)
hooks:
  PostToolUse:
    - matcher: Edit|Write
      hooks:
        - type: command
          command: my-format-hook
```

YAML fragments are converted to JSON before merging, so they mix freely with JSON fragments in the same directory and follow the same ordering rules.

### YAML mode (`-y`)

`claude-mergerc -y` runs the whole interactive flow in YAML:

- The merged config is staged as YAML.
- The diff is shown YAML-vs-YAML (your current `settings.json` is converted on the fly).
- The `[e]` manual-merge option opens YAML buffers in `$EDITOR`; the edited result is converted back and validated before applying.

Regardless of mode, **the file written to `settings.json` is always JSON** — YAML is only used for fragments and the human-facing diff/edit steps, because Claude Code only reads JSON.

## Examples

### Splitting settings by concern

```
~/.config/claude/fragments/
├── 00-base.json              # model, theme, env vars
├── 10-permissions.json       # allow/deny rules
├── 20-hooks.json             # pre/post-tool hooks
├── 30-mcp.json               # MCP server config
└── 99-local.json             # machine-specific overrides (gitignored)
```

`00-base.json`:
```json
{
  "model": "claude-opus-4-7",
  "env": { "EDITOR": "nvim" }
}
```

`10-permissions.json`:
```json
{
  "permissions": {
    "allow": ["Bash(git status:*)", "Bash(git diff:*)"]
  }
}
```

Running `claude-mergerc` produces a single `settings.json` combining all fragments.

### Per-machine overrides

Commit the shared fragments to your dotfiles repo. Keep a `99-local.json` (gitignored) for host-specific tweaks — API keys, local paths, experimental permissions. The deep merge handles the rest.

### Personal vs. work fragments

If your machine is used for both personal and work coding, keep fragments separated and compose them per host. Two approaches:

**Approach 1 — one dir, filter by context.** Tag fragments by context and use `-x` (or `CLAUDE_MERGERC_EXCLUDE`) to skip the ones that don't apply:

```
~/.config/claude/fragments/
├── 00-base.json              # shared
├── 10-permissions.json       # shared
├── 50-personal.json          # personal-only
└── 70-work.json              # work-only
```

```zsh
# On a personal machine:
claude-mergerc -x '70-work.json'

# On a work machine:
claude-mergerc -x '50-personal.json'
```

**Approach 2 — overlay directories.** Keep a shared base dir and a context-specific overlay dir, and use the multi-dir env var or `-d`:

```
~/.dotfiles/claude/fragments/         # shared, in public dotfiles repo
~/.config/claude/fragments-work/      # work-only, in private/encrypted location
```

```zsh
export CLAUDE_MERGERC_FRAGMENTS_DIR="$HOME/.dotfiles/claude/fragments:$HOME/.config/claude/fragments-work"
```

Because earlier dirs are base layers and later dirs are overlays, the work fragments cleanly override shared values without touching the shared files. This works well when work tooling lives in a private dotfiles repo or an encrypted overlay, since the two worlds stay in separate directories.

### Sharing fragments across machines

Because fragments are plain JSON/YAML files in a directory, they sync cleanly through any dotfiles manager (GNU stow, chezmoi, bare git repo, etc.). Run `claude-mergerc` after pulling changes to stitch the new fragments into `settings.json`.

## License

MIT
