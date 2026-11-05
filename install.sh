#!/usr/bin/env bash
# Per-user installation; dependencies are checked, never downloaded or installed.
set -euo pipefail
source_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$source_root/scripts/dependencies.sh"
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  cat <<'HELP'
Usage: ./install.sh

Install the mt2l Typst package and mt2l command for the current user, without sudo.
Requires Typst >= 0.15 and Pandoc >= 3.7. No downloads or shell-profile changes.

Optional environment variables:
  XDG_DATA_HOME       Data directory (default: ~/.local/share on Linux).
  TYPST_PACKAGE_PATH Typst packages directory (overrides the data directory).
  MT2L_BIN_DIR         Command directory (default: ~/.local/bin).
HELP
  exit 0
fi
if (($#)); then printf 'Unknown argument: %s. Use --help.\n' "$1" >&2; exit 2; fi
mt2l_check_dependencies || exit 1
version=$(mt2l_read_version "$source_root/typst.toml")
data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}
if [[ -z "${XDG_DATA_HOME:-}" && "$(uname -s)" == Darwin ]]; then
  data_dir="$HOME/Library/Application Support"
fi
package_root=${TYPST_PACKAGE_PATH:-"$data_dir/typst/packages"}
bin_dir=${MT2L_BIN_DIR:-"$HOME/.local/bin"}
mkdir -p "$package_root/local/mt2l" "$bin_dir"
package_parent=$(cd "$package_root/local/mt2l" && pwd)
bin_dir=$(cd "$bin_dir" && pwd)
destination="$package_parent/$version"
command_path="$bin_dir/mt2l"
if [[ -L "$destination" || ( -e "$destination" && ! -f "$destination/.mt2l-managed" ) ]]; then
  printf 'Refusing to replace an unmanaged package: %s\n' "$destination" >&2
  exit 1
fi
if [[ -L "$command_path" || ( -e "$command_path" && ! -f "$command_path" ) ]]; then
  printf 'Refusing to replace an existing command: %s\n' "$command_path" >&2
  exit 1
fi
if [[ -f "$command_path" ]] &&
    ! grep -Fqx '# Installed by mt2l/install.sh.' "$command_path" &&
    ! grep -Fqx '# Installed by t2l/install.sh.' "$command_path"; then
  printf 'Refusing to replace an unmanaged command: %s\n' "$command_path" >&2
  exit 1
fi

staging=$(mktemp -d "$package_parent/.mt2l-install-XXXXXXXX")
launcher=$(mktemp "$bin_dir/.mt2l-install-XXXXXXXX")
backup=""
published=0
complete=0
cleanup() {
  local status=$?
  if ((complete == 0 && published == 1)); then rm -rf -- "$destination"; fi
  if [[ -n "$backup" && -d "$backup/previous" ]]; then
    if ((complete == 0)); then mv -- "$backup/previous" "$destination"; fi
  fi
  rm -rf -- "$staging"
  rm -f -- "$launcher"
  if [[ -n "$backup" ]]; then rm -rf -- "$backup"; fi
  return "$status"
}
trap cleanup EXIT
mkdir -p "$staging/scripts/mt2l" "$staging/templates" "$staging/examples"
install -m 644 "$source_root/typst.toml" "$source_root/mt2l.typ" "$source_root/README.md" "$source_root/LICENSE" "$staging/"
install -m 644 "$source_root/scripts/mt2l.lua" "$source_root/scripts/dependencies.sh" "$staging/scripts/"
install -m 644 "$source_root/scripts/mt2l/lexer.lua" "$staging/scripts/mt2l/"
install -m 755 "$source_root/scripts/convert.sh" "$staging/scripts/"
install -m 644 "$source_root/templates/default.tex" "$staging/templates/"
install -m 644 "$source_root/examples/"*.typ "$staging/examples/"
printf 'mt2l %s\n' "$version" > "$staging/.mt2l-managed"
{
  printf '#!/usr/bin/env bash\n# Installed by mt2l/install.sh.\n'
  # Shell-quote install paths, including spaces and quotes. No repo dependency.
  printf 'export TYPST_PACKAGE_PATH=${TYPST_PACKAGE_PATH:-%q}\n' "$(dirname "$(dirname "$package_parent")")"
  printf 'exec bash %q "$@"\n' "$destination/scripts/convert.sh"
} > "$launcher"
chmod 755 "$launcher"
if [[ -d "$destination" ]]; then
  backup=$(mktemp -d "$package_parent/.mt2l-backup-XXXXXXXX")
  mv -- "$destination" "$backup/previous"
fi
mv -- "$staging" "$destination"
published=1
mv -f -- "$launcher" "$command_path"
complete=1
# Migrate only the old launcher created by this installer. Unrelated programs
# named t2l, including ones elsewhere in PATH, are never touched.
legacy_command="$bin_dir/t2l"
if [[ -f "$legacy_command" && ! -L "$legacy_command" ]] &&
    grep -Fqx '# Installed by t2l/install.sh.' "$legacy_command"; then
  rm -- "$legacy_command"
fi
# Remove only the previous version installed by us, after publishing mt2l.
# Other versions and packages in the same namespace remain user-owned.
legacy_parent="$package_root/local/t2l"
legacy_package="$legacy_parent/$version"
if [[ ! -L "$legacy_parent" && ! -L "$legacy_package" &&
      -f "$legacy_package/.t2l-managed" ]] &&
    grep -Fqx "t2l $version" "$legacy_package/.t2l-managed"; then
  rm -rf -- "$legacy_package"
  rmdir -- "$legacy_parent" 2>/dev/null || true
fi
printf 'Installed mt2l %s\nPackage: %s\nCommand: %s\n' "$version" "$destination" "$command_path"
printf '\nIn Typst:\n  #import "@local/mt2l:%s": mt2l, mt2l-export-meta\n\nExport:\n  mt2l main.typ\n' "$version"
resolved_command=$(command -v mt2l || true)
if [[ -n "$resolved_command" && "$resolved_command" != "$command_path" ]]; then
  printf '\nAnother mt2l takes precedence in PATH: %s\nUse the installed command directly:\n  %q main.typ\n' "$resolved_command" "$command_path"
  printf 'Or put this installation first (current terminal):\n  export PATH=%q:"$PATH"\n' "$bin_dir"
else
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) printf '\nAdd this directory to PATH (current terminal):\n  export PATH=%q:"$PATH"\n' "$bin_dir" ;;
  esac
fi
