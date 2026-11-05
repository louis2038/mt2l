#!/usr/bin/env bash
# Installation bookkeeping; no network calls or external package dependencies.

mt2l_install_locations() {
  local data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}
  if [[ -z "${XDG_DATA_HOME:-}" && "$(uname -s)" == Darwin ]]; then
    data_dir="$HOME/Library/Application Support"
  fi
  package_root=${TYPST_PACKAGE_PATH:-"$data_dir/typst/packages"}
  bin_dir=${MT2L_BIN_DIR:-"$HOME/.local/bin"}
  package_parent="$package_root/local/mt2l"
  command_path="$bin_dir/mt2l"
}

mt2l_managed_launcher() {
  [[ -f "$1" && ! -L "$1" ]] &&
    { grep -Fqx '# Installed by mt2l/install.sh.' "$1" ||
      grep -Fqx '# Installed by t2l/install.sh.' "$1"; }
}

mt2l_installed_version() {
  local info
  mt2l_managed_launcher "$command_path" || return 0
  info=$(bash "$command_path" --version 2>/dev/null) || return 0
  if [[ "$info" =~ ^mt2l\ ([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

mt2l_uninstall() {
  local directory version removed=0
  # Do not follow package-directory symlinks into unrelated installations.
  if [[ -L "$package_parent" || -L "$package_root/local" ]]; then
    printf 'Refusing to uninstall through a symlink: %s\n' "$package_parent" >&2
    return 1
  fi
  for directory in "$package_parent"/*; do
    [[ -d "$directory" && ! -L "$directory" ]] || continue
    version=${directory##*/}
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    if [[ -f "$directory/.mt2l-managed" ]] &&
        grep -Fqx "mt2l $version" "$directory/.mt2l-managed"; then
      rm -rf -- "$directory"
      printf 'Removed package: %s\n' "$directory"
      removed=1
    else
      printf 'Kept unmanaged package: %s\n' "$directory"
    fi
  done
  if mt2l_managed_launcher "$command_path"; then
    rm -- "$command_path"
    printf 'Removed command: %s\n' "$command_path"
    removed=1
  elif [[ -e "$command_path" || -L "$command_path" ]]; then
    printf 'Kept unmanaged command: %s\n' "$command_path"
  fi
  rmdir -- "$package_parent" 2>/dev/null || true
  if ((removed == 0)); then printf 'No managed mt2l installation found.\n'; fi
}
