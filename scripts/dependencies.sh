#!/usr/bin/env bash
# Shared by the installer and the installed command. Never installs software.

mt2l_pandoc_help() {
  cat >&2 <<'HELP'
Pandoc >= 3.7 is required to export LaTeX.
Official installation instructions: https://pandoc.org/installing.html
Downloads: https://github.com/jgm/pandoc/releases/latest

Linux, without sudo: download the .tar.gz for your architecture, then run
  mkdir -p "$HOME/.local"
  tar -xzf /path/to/pandoc-archive.tar.gz --strip-components=1 -C "$HOME/.local"
  export PATH="$HOME/.local/bin:$PATH"
Replace /path/to/pandoc-archive.tar.gz with the downloaded archive's path.
HELP
  if command -v dnf >/dev/null 2>&1; then
    printf '\nAlternatively, on Fedora: sudo dnf install pandoc\n' >&2
  elif command -v apt-get >/dev/null 2>&1; then
    printf '\nAlternatively, on Debian/Ubuntu: sudo apt install pandoc\n' >&2
  elif command -v pacman >/dev/null 2>&1; then
    printf '\nAlternatively, on Arch Linux: sudo pacman -S pandoc\n' >&2
  elif command -v brew >/dev/null 2>&1; then
    printf '\nAlternatively, with Homebrew: brew install pandoc\n' >&2
  fi
}

mt2l_check_dependencies() {
  local missing=0 info major minor
  if ! command -v typst >/dev/null 2>&1; then
    printf 'Typst >= 0.15 is required. Install it from:\nhttps://github.com/typst/typst/releases/latest\n' >&2
    missing=1
  else
    info=$(typst --version) || return 1
    if [[ "$info" =~ ^typst\ ([0-9]+)\.([0-9]+)\. ]]; then
      major=${BASH_REMATCH[1]}; minor=${BASH_REMATCH[2]}
      if ((major == 0 && minor < 15)); then
        printf 'Typst is too old: %s\nTypst >= 0.15 is required.\nhttps://github.com/typst/typst/releases/latest\n' "$info" >&2
        missing=1
      fi
    else
      printf 'Cannot determine the Typst version: %s\n' "$info" >&2
      missing=1
    fi
  fi
  if ! command -v pandoc >/dev/null 2>&1; then
    mt2l_pandoc_help
    missing=1
  else
    info=$(pandoc --version) || return 1
    if [[ "$info" =~ ^pandoc\ ([0-9]+)\.([0-9]+) ]]; then
      major=${BASH_REMATCH[1]}; minor=${BASH_REMATCH[2]}
      if ((major < 3 || (major == 3 && minor < 7))); then
        printf 'Pandoc is too old: %s\n' "${info%%$'\n'*}" >&2
        mt2l_pandoc_help
        missing=1
      fi
    else
      printf 'Cannot determine the Pandoc version.\n' >&2
      missing=1
    fi
  fi
  ((missing == 0))
}

mt2l_read_version() {
  local line
  while IFS= read -r line; do
    if [[ "$line" =~ ^version[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done < "$1"
  printf 'Cannot find package version in %s\n' "$1" >&2
  return 1
}
