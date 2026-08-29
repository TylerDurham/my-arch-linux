# MY-ARCH-LINUX

My arch linux setup.

Work in progress.

## Usage

`install.sh` runs the modules in `install.d/`. Each module sets up one piece of
the system, so they can be run one at a time or as a full pass.

```sh
./install.sh                      # run every module
./install.sh -m fonts packages    # run only the named modules (.sh optional)
./install.sh -s                   # pick modules interactively with fzf
./install.sh -l                   # list the available modules
./install.sh -u -m docker         # uninstall a module
./install.sh -h                   # show help
```

Set `DEBUG=1` in the environment for verbose logging.

## Modules

| Module | Does |
| --- | --- |
| `audio` | install the audio pieces Arch does not pull in by default |
| `aur-packages` | install (or remove) the AUR packages listed in `aur-packages.txt` |
| `claude-desktop` | build and install Anthropic's Claude desktop app |
| `docker` | install (or remove) Docker, rootful or rootless |
| `fingerprint` | set up a fingerprint reader and wire it into unlock prompts |
| `fonts` | install (or remove) the fonts bundled in `install.d/fonts` |
| `gtk-icon-theme` | install (or remove) the Tela-circle icon theme |
| `gtk-theme` | install (or remove) the Graphite GTK theme |
| `kvm` | install (or remove) the KVM/QEMU virtualisation stack |
| `packages` | install (or remove) the repo packages listed in `packages.txt` |
| `thunderbolt` | install boltd, the Thunderbolt device manager |
| `yay` | install (or remove) the yay AUR helper |

`module.sh` is the template to copy when adding a new one.

### Options

The runner passes no per-module arguments, so modules take their options from
the environment.

| Variable | Module | Does |
| --- | --- | --- |
| `NO_CONFIRM=1` | `packages`, `aur-packages`, `audio`, `thunderbolt`, `kvm` | skip pacman's prompt and yay's PKGBUILD review |
| `QEMU_FLAVOR` | `kvm` | `qemu-full` to emulate every architecture, not just this one |
| `FORCE=1` | `gtk-theme`, `gtk-icon-theme` | rebuild a theme that is already installed |
| `PACKAGE_LIST` | `packages` | read a different package list |
| `AUR_PACKAGE_LIST` | `aur-packages` | read a different AUR package list |
| `FINGERS` | `fingerprint` | fingers to enroll, space separated |
| `ENROLL_ONLY=1` | `fingerprint` | (re-)enroll fingers, leave PAM alone |
| `WIRE_LOGIN=1` | `fingerprint` | also wire up the SDDM greeter |
| `ROOTLESS=1` | `docker` | run the daemon as your own user |
| `PRUNE=0` | `docker` | skip the weekly `docker system prune` timer |

## Writing a module

A module is sourced, not executed, so it carries no shebang and no argument
parsing. It defines three hooks:

```sh
on_init()       # validate the environment and gather state
on_install()    # do the work
on_uninstall()  # undo it
```

`install.sh` sources each module in a subshell and provides the logging helpers
(`info`, `warn`, `error`, `die`, `debug`, `indent`). It runs `on_init` first,
then `on_install` or `on_uninstall`; a module missing the hook for the action
being run is an error.

## Layout

```
install.sh              module runner
install.d/              one module per piece of the system
install.d/module.sh     template for a new module
install.d/packages.txt  repo packages
install.d/aur-packages.txt
install.d/flatpaks.txt
install.d/fonts/        fonts installed by the fonts module
dotfiles/
arch-packages.tsv       package inventories
nixos-packages.tsv
```
