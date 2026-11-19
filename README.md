![GitHub Release](https://img.shields.io/github/v/release/gaofengnan/tmux-debian)
![GitHub Release Date](https://img.shields.io/github/release-date/gaofengnan/tmux-debian)

<img src="tmux-logo.png" alt="tmux" width="152" align="right">

# tmux for Debian and Ubuntu

> Fork of [dariogriffo/tmux-debian](https://github.com/dariogriffo/tmux-debian) (MIT); the original packaging is by Dario Griffo. Served at [deb.gaofn.xyz](https://deb.gaofn.xyz) for Debian 12 (bookworm) and 13 (trixie).

This repository contains build scripts that produce **unofficial** Debian and
Ubuntu packages (`.deb`) of the latest [tmux](https://github.com/tmux/tmux)
release, hosted at [deb.gaofn.xyz](https://deb.gaofn.xyz).

tmux publishes source code only, so every tagged release is compiled here
from upstream's release tarball (`tmux-<version>.tar.gz`). The package is
called `tmux`, like the distribution's, and replaces it in place.

Supported suites: Debian **bookworm, trixie, forky, sid** and Ubuntu **jammy,
noble, questing, resolute**. Architectures: **amd64 and arm64** (a Raspberry
Pi 4/5 on a 64-bit OS takes arm64). Other architectures are not built.

## How it is built

- **One binary per architecture for every suite.** It is compiled in
  `ubuntu:jammy`, which has the oldest glibc (2.35) and the oldest libevent,
  jemalloc and libsystemd of the eight suites; the binary needs glibc 2.34.
  arm64 is cross-compiled, then run on a native arm64 runner before release.
- **Configured like Debian's own tmux**: `--enable-systemd --enable-jemalloc
  --enable-sixel`, with full hardening.
- **ncurses' terminfo library is linked in statically** (ncurses 6.6, its
  signature checked against Thomas E. Dickey's key as shipped by Debian,
  `debian/upstream/ncurses-signing-key.asc`). Since ncurses 6.4.20230625,
  tmux needs `tiparm_s()` to expand the capabilities it adds itself
  (clipboard via OSC 52, cursor colour and style, styled underlines...).
  bookworm and jammy don't have it and the other suites do, so a build
  against the system library would lose those features somewhere. The
  static library reads the system's own terminfo database
  (`/etc/terminfo`, `/usr/share/terminfo`, `/lib/terminfo`, `~/.terminfo`),
  exactly as Debian's ncurses does.
- **The same integration as Debian's package**: `/usr/bin/tmux` is
  registered in `/etc/shells`, and a systemd-tmpfiles rule keeps
  `/tmp/tmux-*` (the server sockets) from being cleaned up under long-lived
  sessions. Man page, `example_tmux.conf` and upstream's CHANGES are
  included.

## Upgrading from the distribution's tmux

The package upgrades the distribution's `tmux` in place: no new name, no
Conflicts, and everything that depends on tmux (byobu, tmuxinator,
tmux-plugin-manager, python3-libtmux...) keeps working.

Sessions that are already running keep the **old** tmux server until they
exit. The client and server protocol has not changed since tmux 3.2a, so
the new `tmux` attaches to them normally, but options and commands added
since your old version (floating panes, for example) only work once the
server restarts: exit your sessions, or run `tmux kill-server`.

On sid the archive may carry the same version. `3.8-1~griffo` sorts below
Debian's `3.8-1`, so apt keeps whichever is newer.

To go back: `sudo apt install --allow-downgrades tmux=<version>` with the
version `apt policy tmux` lists for your distribution.

## Install / Update

### The Debian way (apt)

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://deb.gaofn.xyz/deb.gaofn.xyz.gpg -o /etc/apt/keyrings/deb.gaofn.xyz.gpg
sudo curl -fsSL https://deb.gaofn.xyz/deb.gaofn.xyz.sources -o /etc/apt/sources.list.d/deb.gaofn.xyz.sources
# Debian 12 (bookworm): fetch deb.gaofn.xyz-bookworm.sources instead
sudo apt update
sudo apt install tmux
```

### Manual installation

1. Download the `.deb` for your architecture from the
   [Releases](https://github.com/gaofengnan/tmux-debian/releases) page.
2. Install it:

```sh
sudo apt install ./tmux_*.deb
```

## Building locally

Requires Docker, `dpkg-dev` and `gpgv`:

```sh
./build_debian.sh 3.8 1 all   # -> ./out/*.deb   (builds the source package first, in out/src)
./build_src.sh    3.8 1       # -> *.dsc / *.orig.tar.gz / *.debian.tar.xz
```

The `.orig.tar.gz` is upstream's `tmux-<version>.tar.gz` with ncurses'
release unpacked into `ncurses/`. It is reproducible: rebuilding it for a
given release gives the same bytes.

## How releases work

A scheduled workflow (`check-upstream.yml`) compares the latest tmux release
with the latest release published here and, once upstream's tarball is
attached, dispatches `release.yml`. That validates the upstream licence
(ISC), builds both architectures and the source package, runs the arm64
package on a native arm64 runner and publishes a GitHub Release tagged
`<version>+<build>`.

## Disclaimer

- This is an unofficial community packaging project, not affiliated with
  the tmux project. For tmux itself, see
  [tmux/tmux](https://github.com/tmux/tmux).
- This repo is not for tmux bug reports, only for the Debian packaging.
- Inspired by the packaging approach of
  [neovim-debian](https://github.com/dariogriffo/neovim-debian).
