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
       mt2l --update [--version X.Y.Z] [--force]
       mt2l --uninstall

Export a Typst document to LaTeX. OUTPUT defaults to INPUT with a .tex suffix.
--root defaults to the input directory; set it for imports from parent folders.
The output directory is created automatically. Requires Typst and Pandoc.
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
trap 'rm -f "$temporary_output"' EXIT
pandoc --from=markdown --to=latex \
  --lua-filter="$converter_root/scripts/mt2l.lua" \
  --standalone --template="$template" "$input" --output="$temporary_output"
mv -f "$temporary_output" "$output"
printf 'Generated %s\n' "$output"
