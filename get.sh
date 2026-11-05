#!/usr/bin/env bash
# Download a tagged mt2l release, then run its per-user installer. Keeping all
# operations inside a function prevents an incomplete function download running.
mt2l_bootstrap() {
  set -euo pipefail
  local version="0.1.0" temporary url
  while (($#)); do
    case "$1" in
      --version)
        if (($# < 2)); then printf 'Missing version.\n' >&2; return 2; fi
        version=$2; shift 2 ;;
      -h|--help)
        printf 'Usage: bash get.sh [--version X.Y.Z]\nInstalls mt2l for the current user, without sudo.\n'
        return 0 ;;
      *) printf 'Unknown argument: %s\n' "$1" >&2; return 2 ;;
    esac
  done
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Expected a release version such as 0.1.0.\n' >&2
    return 2
  fi
  for program in curl tar mktemp; do
    if ! command -v "$program" >/dev/null 2>&1; then
      printf 'Required program not found: %s\n' "$program" >&2
      return 127
    fi
  done
  temporary=$(mktemp -d "${TMPDIR:-/tmp}/mt2l-download-XXXXXXXX")
  # Expand the temporary path now, shell-quoted, so EXIT also works on failure.
  trap "rm -rf -- $(printf '%q' "$temporary")" EXIT
  url="https://codeload.github.com/louis2038/mt2l/tar.gz/refs/tags/v$version"
  printf 'Downloading mt2l %s from GitHub...\n' "$version"
  curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    --retry 2 --connect-timeout 15 --max-time 180 --output "$temporary/source.tar.gz" "$url"
  mkdir "$temporary/source"
  tar -xzf "$temporary/source.tar.gz" --strip-components=1 -C "$temporary/source"
  if [[ ! -f "$temporary/source/install.sh" || ! -f "$temporary/source/typst.toml" ]]; then
    printf 'The release archive does not contain an mt2l installer.\n' >&2
    return 1
  fi
  # Read no more bytes from the pipe while the installer runs.
  bash "$temporary/source/install.sh" < /dev/null
}
mt2l_bootstrap "$@"
