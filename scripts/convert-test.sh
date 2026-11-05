#!/usr/bin/env bash
# Compatibility entry point, retaining the original example and arguments.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
input=${1:-"$root/examples/packages.typ"}
output=${2:-"$root/output_test.tex"}
template=${3:-"$root/templates/default.tex"}

exec bash "$root/scripts/convert.sh" --root "$root" --template "$template" "$input" "$output"
