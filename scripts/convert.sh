#!/usr/bin/env bash
# General entry point for exporting and managing mt2l.
set -euo pipefail

converter_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$converter_root/scripts/dependencies.sh"
project_root=${MT2L_PROJECT_ROOT:-}
# Registry: one "name=directory" entry per template. Paths may contain spaces.
# Add "paper2=$converter_root/templates/paper2" to register another template.
MT2L_TEMPLATES=(
  "default=$converter_root/templates/default"
  "paper=$converter_root/templates/paper"
)
mt2l_template_directory() {
  local entry
  for entry in "${MT2L_TEMPLATES[@]}"; do
    if [[ "${entry%%=*}" == "$1" ]]; then printf '%s\n' "${entry#*=}"; return 0; fi
  done
  return 1
}
template="$(mt2l_template_directory default)/latex_template/default.tex"
usage() {
  cat <<'HELP'
mt2l - Export Typst documents to editable LaTeX

CREATE A PROJECT
  mt2l init NAME [DIR]          Download a model from the installed version's GitHub tag.
  mt2l init --local NAME [DIR]  Copy a model from this installation, without downloading.

  NAME is one of the models listed below. DIR defaults to NAME.
  The entire model is copied: main.typ, paper.bib, template.typ,
  binding.typ, and latex_template/. All files are editable.
  An existing destination is never overwritten.

AVAILABLE MODELS
HELP
  local entry name description latex_file
  for entry in "${MT2L_TEMPLATES[@]}"; do
    name=${entry%%=*}
    case "$name" in
      default) description="Minimal document: text, mathematics, and bibliography." ;;
      paper) description="Research paper: statements, proofs, references, figures, and tables." ;;
      *) description="Custom project model." ;;
    esac
    printf '  %-12s %s\n' "$name" "$description"
    for latex_file in "${entry#*=}"/latex_template/*.tex; do
      [[ -f "$latex_file" ]] || continue
      printf '               LaTeX file: latex_template/%s\n' "$(basename "$latex_file")"
    done
  done
  printf '\n  Local model directory: %s/templates/\n' "$converter_root"
  cat <<'HELP'

EXPORT
  mt2l INPUT [OUTPUT] [--template FILE] [--root DIR]

  INPUT             Source .typ file.
  OUTPUT            Destination .tex file; defaults to the input name with .tex.
  --template FILE   Path to your editable LaTeX template, e.g. latex_template/paper.tex.
                    This is a file path, not a model name such as "paper".
                    If omitted, use a minimal article with no theorem environments.
  --root DIR        Typst project root; defaults to the input directory.

  Export requires Typst >= 0.15 and Pandoc >= 3.7.

EXAMPLES
  mt2l init paper my-paper
  cd my-paper
  mt2l main.typ --template latex_template/paper.tex

  # Offline alternative (creates a separate project):
  mt2l init --local default my-notes

MANAGE THE INSTALLATION
  mt2l --version                         Show the installed version.
  mt2l --update                          Install the latest stable GitHub release.
  mt2l --update --version X.Y.Z           Select a specific release.
  mt2l --update --force                   Reinstall or allow a downgrade.
  mt2l --uninstall                       Remove this managed installation.
  mt2l --help                            Show this help and available models.
HELP
}

if [[ "${1:-}" == init ]]; then
  shift
  local_init=0
  init_args=()
  for argument in "$@"; do
    case "$argument" in
      -h|--help) usage; exit 0 ;;
      --local) local_init=1 ;;
      -*) printf 'Unknown init option: %s\n' "$argument" >&2; exit 2 ;;
      *) init_args+=("$argument") ;;
    esac
  done
  if ((${#init_args[@]} < 1 || ${#init_args[@]} > 2)); then
    printf 'Usage: mt2l init [--local] NAME [DIR]\n' >&2; exit 2
  fi
  preset=${init_args[0]}
  if ! preset_dir=$(mt2l_template_directory "$preset"); then
    printf 'Unknown template: %s\n' "$preset" >&2
    usage >&2; exit 2
  fi
  destination=${init_args[1]:-$preset}
  if [[ -e "$destination" || -L "$destination" ]]; then
    printf 'Destination already exists: %s\n' "$destination" >&2; exit 1
  fi
  version=$(mt2l_read_version "$converter_root/typst.toml")
  staging=$(mktemp -d)
  trap 'rm -rf -- "$staging"' EXIT
  mkdir "$staging/project"
  if ((local_init)); then
    cp -R -- "$preset_dir/." "$staging/project/"
  else
    for program in curl tar; do
      if ! command -v "$program" >/dev/null 2>&1; then
        printf 'Required program not found: %s\n' "$program" >&2; exit 127
      fi
    done
    url="https://codeload.github.com/louis2038/mt2l/tar.gz/refs/tags/v$version"
    printf 'Downloading template %s from mt2l v%s...\n' "$preset" "$version"
    if ! curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
      --connect-timeout 15 --max-time 120 --output "$staging/release.tar.gz" "$url"; then
      printf 'Download failed. For the bundled template, use: mt2l init --local %q %q\n' "$preset" "$destination" >&2
      exit 1
    fi
    tar -tzf "$staging/release.tar.gz" > "$staging/contents"
    IFS= read -r archive_root < "$staging/contents"
    archive_root=${archive_root%%/*}
    relative_dir=${preset_dir#"$converter_root/"}
    tar -xzf "$staging/release.tar.gz" -C "$staging/project" --strip-components=3 \
      -- "$archive_root/$relative_dir/"
  fi
  for name in main.typ template.typ binding.typ; do
    if [[ ! -f "$staging/project/$name" ]]; then
      printf 'Template %s is missing %s.\n' "$preset" "$name" >&2; exit 1
    fi
  done
  latex_files=("$staging/project"/latex_template/*.tex)
  if [[ ! -f "${latex_files[0]}" ]]; then
    printf 'Template %s has no LaTeX template.\n' "$preset" >&2; exit 1
  fi
  mkdir -p -- "$(dirname "$destination")"
  # mkdir also protects against a destination created during the download.
  mkdir -- "$destination"
  cp -R -- "$staging/project/." "$destination/"
  printf 'Created %s from template %s.\n' "$destination" "$preset"
  printf 'cd %q\n' "$destination"
  printf 'typst compile main.typ\nmt2l main.typ --template latex_template/%s\n' "$(basename "${latex_files[0]}")"
  exit 0
fi
positional=()
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
    --) shift; positional+=("$@"); break ;;
    -*) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) positional+=("$1"); shift ;;
  esac
done
set -- "${positional[@]}"
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
