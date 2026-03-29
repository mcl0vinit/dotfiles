# dotfiles

Portable dotfiles for local macOS and cloud Linux machines, with Nix/Home Manager as the source of truth.

## What lives here

- `flake.nix`: multi-machine Home Manager entrypoint
- `nix/modules`: shared modules split by concern
- `config/`: app configs that should follow you between machines
- `shell/`: bash startup files
- `bin/`: small user-facing helpers like `codex`, `hm-switch`, and `bootstrap`

## Bootstrapping a machine

1. Clone this repo somewhere convenient.
2. Run `./bin/bootstrap`.
3. `bootstrap` only links the repo to `~/.dotfiles` by default. It does not change your active Home Manager generation.
4. When you are ready to actually apply it, run `./bin/bootstrap --apply`.
5. The apply step backs up the currently managed files into `~/.local/state/dotfiles-bootstrap-backups/<timestamp>`, writes a rollback script there, and then applies the correct Home Manager profile for the current OS and CPU.

After that, `hms` reapplies the config and `hme` opens the main Nix entrypoint.

## Local Safety

- `./bin/bootstrap` is link-only and safe to run on an already-configured machine.
- `./bin/bootstrap --apply` is the step that changes your active Home Manager generation.
- Every apply writes a rollback script into the backup directory before switching anything.

## Remote Notes

- macOS uses `portable-darwin`
- x86_64 Linux uses `portable-linux`
- arm64 Linux uses `portable-linux-arm`
- macOS-only config such as Ghostty and the current SSH include pattern is gated so it is not forced onto Linux
- fresh remote machines still need one-time login/setup for Codex, GitHub CLI, and SSH keys

## Safe To Publish

- I scanned the tracked files for common secret patterns and did not find tokens, private keys, or auth files.
- This repo intentionally includes your non-secret personal defaults such as Git identity and machine preferences.
- The current `.gitignore` blocks the main auth-bearing files you are likely to accidentally add later.

## Included now

- Nix/Home Manager flake
- tmux setup and custom Codex-aware tmux helpers from the current machine
- bash startup files
- `codex` wrapper script
- `nvim`, `ghostty`, `zed`, `direnv`, `gh`, `htop`, `nix`, and `ssh` config
- portable Codex approval rules and a base config example

## Intentionally not committed

- SSH keys
- `gh` auth hosts
- Codex auth, history, MCP secrets, machine-specific trust paths, and live `config.toml`
- Stripe CLI secrets
- `.env` files and local override files
- machine-local caches and state

## Next places to grow

- add host-specific overrides if a cloud box needs different packages
- add secrets management before tracking anything sensitive
- pull more app configs into `config/` once they are worth syncing
