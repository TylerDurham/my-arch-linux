# MY-ARCH-LINUX

My arch linux setup.

Work in progress.

## Features

- [Keybinds](docs/keybinds.md) — the full Hyprland keybind list
- [Monitor profiles](docs/nwg-profiles.md) — per-machine display layouts via `nwg-displays`

## Usage

The repo is split into packages — `arch`, `hyprland`, `shell`, `neovim` — each
a self-contained stow package with its own `install` script and `install.d/`
modules. Run a package's installer directly:

```sh
cd hyprland
./install -i          # install every core module
./install -i -x       # also install optional modules from install.d/extra
./install -i -s       # pick modules interactively with fzf
./install -u          # uninstall (modules run in reverse order)
```

Add `-v`/`--verbose` for debug logging. Running `./install` at the repo root
picks one or more packages with fzf.

## Packages

| Package | Does |
| --- | --- |
| `arch` | Arch packages, yay, GTK theme/icons, Plymouth, and optional extras (audio, docker, kvm, fingerprint, flatpaks, fonts, thunderbolt, mise, nodejs) |
| `hyprland` | Hyprland, Waybar, Rofi, and the rest of the desktop dotfiles |
| `shell` | bash/zsh, git, tmux, ghostty, and the `my` bin/lib scripts every package's installer relies on |
| `neovim` | Neovim config |

Each package's `install.d/` holds its core modules (`NN-name.sh`, run in
numeric order); `install.d/extra/` holds optional ones, included with `-x`.

### Options

Some `arch` extras take options from the environment:

| Variable | Module | Does |
| --- | --- | --- |
| `NO_CONFIRM=1` | `01-packages`, `10-plymouth`, `extra/aur-packages`, `extra/audio`, `extra/thunderbolt`, `extra/kvm`, `extra/flatpaks` | skip pacman's prompt and yay's PKGBUILD review |
| `QEMU_FLAVOR` | `extra/kvm` | `qemu-full` to emulate every architecture, not just this one |
| `FORCE=1` | `03-gtk-theme`, `05-gtk-icon-theme` | rebuild a theme that is already installed |
| `PACKAGE_LIST` | `01-packages` | read a different package list |
| `AUR_PACKAGE_LIST` | `extra/aur-packages` | read a different AUR package list |
| `FLATPAK_LIST` | `extra/flatpaks` | read a different flatpak list |
| `SCOPE=user` | `extra/flatpaks` | install into `~/.local/share/flatpak` instead of system-wide |
| `FINGERS` | `extra/fingerprint` | fingers to enroll, space separated |
| `ENROLL_ONLY=1` | `extra/fingerprint` | (re-)enroll fingers, leave PAM alone |
| `WIRE_LOGIN=1` | `extra/fingerprint` | also wire up the SDDM greeter |
| `ROOTLESS=1` | `extra/docker` | run the daemon as your own user |
| `PRUNE=0` | `extra/docker` | skip the weekly `docker system prune` timer |

## Writing a module

A module is sourced, not executed, so it carries no shebang and no argument
parsing. It defines up to four hooks:

```sh
on_init()       # validate the environment and gather state (optional)
on_install()    # do the work
on_uninstall()  # undo it
on_completed()  # run after install/uninstall succeeds (optional)
```

Each package's `install` script sources the repo-root `envs.sh` and the
shared `installer.sh` (in `shell/dotfiles/.local/share/my/lib/bash/`), which
provide the logging helpers (`info`, `warn`, `error`, `die`, `debug`,
`indent`) and source each module in a subshell. It runs `on_init` first, then
`on_install` or `on_uninstall`, then `on_completed`; a module missing the hook
for the action being run is an error.

## Layout

```
install                      pick one or more packages to run (fzf)
envs.sh                      shared globals every package's install sources
arch/                        Arch OS setup
arch/install                 package installer entrypoint
arch/install.d/              core modules (packages, yay, themes, plymouth, ...)
arch/install.d/extra/        optional modules (docker, kvm, fingerprint, ...)
hyprland/                    Hyprland desktop
shell/                       shell, git, and the shared my bin/lib scripts
neovim/                      Neovim config
<package>/dotfiles/          stowed into $HOME
<package>/install.d/module.sh.txt   template for a new module
arch-packages.tsv            package inventories
nixos-packages.tsv
```
</content>
