# claude-mergerc

A zsh plugin that merges multiple JSON fragments into your `~/.claude/settings.json`, with an interactive diff/apply flow.

Claude Code reads a single `settings.json`, but splitting that config across smaller, purpose-scoped fragments is often easier to maintain. `claude-mergerc` deep-merges the fragments into one file, shows you a diff, and lets you apply, back up, or edit manually before overwriting.

## Requirements

- `zsh`
- [`jq`](https://jqlang.org/)
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

Drop JSON fragments into your fragments directory (default: `~/.config/claude/fragments/`), then run:

```zsh
claude-mergerc
```

The command will:

1. Deep-merge every `*.json` file under the fragments directory (sorted by filename).
2. Compare the result against your existing `~/.claude/settings.json`.
3. Show a diff, then prompt:
   - **[a]** Apply merged config (overwrite current)
   - **[b]** Backup current, then apply
   - **[e]** Open both in `$EDITOR` (vimdiff-style manual merge)
   - **[q]** Quit, no changes

If `~/.claude/settings.json` doesn't exist yet, it prints the merged output and asks whether to create it.

## Configuration

Override paths via environment variables:

| Variable                        | Default                                                 |
| ------------------------------- | ------------------------------------------------------- |
| `CLAUDE_MERGERC_FRAGMENTS_DIR`  | `${XDG_CONFIG_HOME:-$HOME/.config}/claude/fragments`    |
| `CLAUDE_MERGERC_OUTPUT`         | `$HOME/.claude/settings.json`                           |

Example:

```zsh
export CLAUDE_MERGERC_FRAGMENTS_DIR="$HOME/.dotfiles/claude/fragments"
```

## Merge behavior

- **Objects** are deep-merged key by key.
- **Arrays** are concatenated and deduplicated (`unique`).
- **Scalars** (strings, numbers, booleans): later fragments win.

Fragments are processed in filename-sorted order, so you can control precedence with prefixes like `00-base.json`, `10-permissions.json`, `99-overrides.json`.

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

### Sharing fragments across machines

Because fragments are plain JSON files in a directory, they sync cleanly through any dotfiles manager (GNU stow, chezmoi, bare git repo, etc.). Run `claude-mergerc` after pulling changes to stitch the new fragments into `settings.json`.

## License

MIT
