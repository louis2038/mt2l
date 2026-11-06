#!/usr/bin/env bash
# General entry point for exporting and managing mt2l.
set -euo pipefail

converter_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$converter_root/scripts/dependencies.sh"
project_root=${MT2L_PROJECT_ROOT:-}
template="$converter_root/templates/default.tex"
usage() {
  cat <<'HELP'
Usage: mt2l [--root DIR] [--template FILE] INPUT [OUTPUT]
       mt2l --init [DIR]
       mt2l --update [--version X.Y.Z] [--force]
       mt2l --uninstall

Export a Typst document to LaTeX. OUTPUT defaults to INPUT with a .tex suffix.
--root defaults to the input directory; set it for imports from parent folders.
The output directory is created automatically. Requires Typst and Pandoc.
--init creates a ready-to-edit paper directory (default: paper).
--template paper selects the bundled LaTeX paper template explicitly.
Documents using #show: paper.with(...) select it automatically.
HELP
}
while (($#)); do
  case "$1" in
    --root|--template)
      if (($# < 2)); then printf 'Missing value for %s\n' "$1" >&2; exit 2; fi
      if [[ "$1" == --root ]]; then project_root=$2; else template=$2; fi
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --version) printf 'mt2l %s\n' "$(mt2l_read_version "$converter_root/typst.toml")"; exit 0 ;;
    --init)
      shift
      if (($# > 1)); then printf 'Usage: mt2l --init [DIR]\n' >&2; exit 2; fi
      destination=${1:-paper}
      if [[ -e "$destination" || -L "$destination" ]]; then
        printf 'Paper directory already exists: %s\n' "$destination" >&2; exit 1
      fi
      mkdir -p -- "$(dirname "$destination")"
      mkdir -- "$destination"
      # Only this newly created directory is removed if copying fails.
      trap 'rm -rf -- "$destination"' EXIT
      install -m 644 "$converter_root/starter/main.typ" "$destination/main.typ"
      install -m 644 "$converter_root/starter/paper.bib" "$destination/paper.bib"
      install -m 644 "$converter_root/templates/LICENSE-latex-paper" "$destination/LICENSE-latex-paper"
      trap - EXIT
      printf 'Created %s/main.typ and paper.bib\n\n' "$destination"
      printf 'Typst PDF: typst compile %q/main.typ\nLaTeX:     mt2l %q/main.typ\n' "$destination" "$destination"
      exit 0 ;;
    --update) shift; exec bash "$converter_root/get.sh" "$@" ;;
    --uninstall)
      if (($# != 1)); then printf 'Use mt2l --uninstall without other arguments.\n' >&2; exit 2; fi
      exec bash "$converter_root/install.sh" --uninstall ;;
    --) shift; break ;;
    -*) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) break ;;
  esac
done
if (($# < 1 || $# > 2)); then usage >&2; exit 2; fi
mt2l_check_dependencies || exit 127
input=$1
output=${2:-"${input%.typ}.tex"}
if [[ "$template" == paper ]]; then template="$converter_root/templates/paper.tex"; fi
if [[ ! -f "$input" ]]; then printf 'Input file not found: %s\n' "$input" >&2; exit 1; fi
if [[ ! -f "$template" ]]; then printf 'Template not found: %s\n' "$template" >&2; exit 1; fi
input_dir=$(cd "$(dirname "$input")" && pwd)
input="$input_dir/$(basename "$input")"
project_root=$(cd "${project_root:-$input_dir}" && pwd)
template="$(cd "$(dirname "$template")" && pwd)/$(basename "$template")"
mkdir -p "$(dirname "$output")"
output_dir=$(cd "$(dirname "$output")" && pwd)
output="$output_dir/$(basename "$output")"
if [[ "$input" == "$output" ]]; then printf 'Input and output must differ.\n' >&2; exit 2; fi
asset_dir="$output_dir/$(basename "${output%.tex}")-assets"
export MT2L_PROJECT_ROOT="$project_root"
export MT2L_ASSET_DIR="$asset_dir"
export MT2L_LATEX_ASSET_DIR="$(basename "$asset_dir")"

# Publish the .tex only after a successful conversion.
temporary_output=$(mktemp "$output_dir/.mt2l-XXXXXXXX.tex")
asset_manifest=""
# Cleanup is restricted to these two temporary files. The *-assets folder,
# including copied .bib files, belongs to the exported document.
trap 'rm -f -- "$temporary_output"; if [[ -n "$asset_manifest" ]]; then rm -f -- "$asset_manifest"; fi' EXIT
asset_manifest=$(mktemp "$output_dir/.mt2l-assets-XXXXXXXX")
export MT2L_ASSET_MANIFEST="$asset_manifest"
pandoc --from=markdown --to=latex --natbib \
  --lua-filter="$converter_root/scripts/mt2l.lua" \
  --standalone --template="$template" "$input" --output="$temporary_output"
assets=()
while IFS= read -r -d '' asset; do assets+=("$asset"); done < "$asset_manifest"
rm -f -- "$asset_manifest"
asset_manifest=""
for asset in "${assets[@]}"; do
  if [[ ! -f "$asset" ]]; then
    printf 'Export resource missing after cleanup: %s\nThe previous LaTeX output was preserved.\n' "$asset" >&2
    exit 1
  fi
done
mv -f "$temporary_output" "$output"
printf 'Generated %s\n' "$output"
