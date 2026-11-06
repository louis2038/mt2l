#!/usr/bin/env bash
# Resolve a stable GitHub tag, download it, and run its per-user installer.
# The function wrapper keeps an incomplete piped download from running.
mt2l_bootstrap() {
  set -euo pipefail
  local version="" temporary url page=1 count json tag matched force=0 uninstall=0
  while (($#)); do
    case "$1" in
      --version)
        if (($# < 2)); then printf 'Missing version.\n' >&2; return 2; fi
        version=$2; shift 2 ;;
      --update) shift ;;
      --force) force=1; shift ;;
      --uninstall) uninstall=1; shift ;;
      -h|--help)
        cat <<'HELP'
Usage: bash get.sh [--version X.Y.Z] [--force]
       bash get.sh --uninstall

Install or update to the latest stable tagged version, without sudo.
--version     Select a specific version instead of checking GitHub tags.
--force       Reinstall or deliberately downgrade the selected version.
--uninstall   Remove managed packages and launcher. For offline removal,
              use mt2l --uninstall or ./install.sh --uninstall instead.
HELP
        return 0 ;;
      *) printf 'Unknown argument: %s\n' "$1" >&2; return 2 ;;
    esac
  done
  if ((uninstall)) && { ((force)) || [[ -n "$version" ]]; }; then
    printf '%s\n' '--uninstall cannot be combined with --force or --version.' >&2
    return 2
  fi
  if [[ -n "$version" && ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Expected a release version such as 0.1.2.\n' >&2
    return 2
  fi
  for program in curl tar mktemp sed sort tail grep; do
    if ! command -v "$program" >/dev/null 2>&1; then
      printf 'Required program not found: %s\n' "$program" >&2
      return 127
    fi
  done
  temporary=$(mktemp -d "${TMPDIR:-/tmp}/mt2l-download-XXXXXXXX")
  trap "rm -rf -- $(printf '%q' "$temporary")" EXIT
  if [[ -z "$version" ]]; then
    printf 'Checking GitHub for the latest stable mt2l version...\n'
    : > "$temporary/versions"
    while true; do
      curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
        --retry 2 --connect-timeout 15 --max-time 180 \
        --header 'Accept: application/vnd.github+json' \
        --output "$temporary/tags.json" \
        "https://api.github.com/repos/louis2038/mt2l/tags?per_page=100&page=$page"
      # Match tag names regardless of JSON indentation; no jq dependency.
      json=$(< "$temporary/tags.json")
      count=0
      while [[ "$json" =~ \"name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; do
        tag=${BASH_REMATCH[1]}
        matched=${BASH_REMATCH[0]}
        json=${json#*"$matched"}
        count=$((count + 1))
        if [[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
          printf '%s\n' "${BASH_REMATCH[1]}" >> "$temporary/versions"
        fi
      done
      if ((count < 100)); then break; fi
      page=$((page + 1))
    done
    version=$(LC_ALL=C sort -t . -k1,1n -k2,2n -k3,3n "$temporary/versions" | tail -n 1)
    if [[ -z "$version" ]]; then
      printf 'No stable mt2l tag found on GitHub. No installation changes made.\n' >&2
      return 1
    fi
    printf 'Latest stable version: %s\n' "$version"
  fi
  local installed_command installed_info installed_version newest
  installed_command="${MT2L_BIN_DIR:-$HOME/.local/bin}/mt2l"
  if ((force == 0 && uninstall == 0)) &&
      [[ -f "$installed_command" && ! -L "$installed_command" ]] &&
      { grep -Fqx '# Installed by mt2l/install.sh.' "$installed_command" ||
        grep -Fqx '# Installed by t2l/install.sh.' "$installed_command"; }; then
    installed_info=$(bash "$installed_command" --version 2>/dev/null) || installed_info=""
    if [[ "$installed_info" =~ ^mt2l\ ([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
      installed_version=${BASH_REMATCH[1]}
      newest=$(printf '%s\n%s\n' "$version" "$installed_version" | LC_ALL=C sort -t . -k1,1n -k2,2n -k3,3n | tail -n 1)
      if [[ "$newest" == "$installed_version" ]]; then
        printf 'mt2l %s is already installed (requested: %s). No changes needed.\n' "$installed_version" "$version"
        return 0
      fi
    fi
  fi
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
  local archive_version
  archive_version=$(sed -nE 's/^version[[:space:]]*=[[:space:]]*"([0-9]+\.[0-9]+\.[0-9]+)"[[:space:]]*$/\1/p' "$temporary/source/typst.toml")
  if [[ "$archive_version" != "$version" ]]; then
    printf 'Release tag %s does not match its package manifest (%s).\n' "$version" "$archive_version" >&2
    return 1
  fi
  # Do not let a child installer consume the rest of a piped script.
  if ((uninstall)); then
    bash "$temporary/source/install.sh" --uninstall < /dev/null
  elif ((force)) && [[ -f "$temporary/source/scripts/manage.sh" ]]; then
    bash "$temporary/source/install.sh" --force < /dev/null
  else
    bash "$temporary/source/install.sh" < /dev/null
  fi
}
mt2l_bootstrap "$@"
