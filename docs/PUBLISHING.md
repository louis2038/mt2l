# Publishing mt2l

## GitHub release

Update `typst.toml`, package imports, examples, and documentation together.
Commit, then create and push the matching `vX.Y.Z` tag. The installer and
`mt2l --update` select the highest stable tag. `mt2l init` downloads its
model from the tag matching the installed CLI version. Each registered
`templates/NAME/` directory must contain `main.typ`, `template.typ`,
`binding.typ`, its bibliography/resources, and `latex_template/`.

For development before publishing a tag, use:

```sh
./install.sh --force
mt2l init --local paper my-paper
```

## Typst Universe

The manifest points directly to `templates/paper/main.typ`. There is no
separate starter directory. Prepare the submission from the repository root:

```sh
package_dir="build/universe/packages/preview/mt2l/0.1.2"
mkdir -p "$package_dir/templates"
cp typst.toml mt2l.typ core.typ LICENSE thumbnail.png "$package_dir/"
cp -R templates/. "$package_dir/templates/"
for binding in "$package_dir"/templates/*/binding.typ; do
  sed 's/@local\/mt2l:/@preview\/mt2l:/g' "$binding" > "$binding.tmp"
  mv "$binding.tmp" "$binding"
done
cp docs/universe.md "$package_dir/README.md"
```

Fork [typst/packages](https://github.com/typst/packages), add the prepared
folder at `packages/preview/mt2l/0.1.2`, and open a pull request. A GitHub tag
does not publish to Universe. Keep previous published versions intact.

The submission includes the generic API and complete template directories.
The external CLI stays in the mt2l GitHub repository. Native Typst compilation
needs no external utility; LaTeX export requires the CLI and Pandoc.

Check the prepared submission with `typst init` and compile its result using
`--package-path build/universe/packages`. Regenerate the thumbnail from the
paper model when its visible layout changes:

```sh
typst compile --root . --format png --pages 1 --ppi 150 templates/paper/main.typ thumbnail.png
```

See the official [submission guidelines](https://github.com/typst/packages/blob/main/docs/README.md),
[manifest reference](https://github.com/typst/packages/blob/main/docs/manifest.md),
and [licensing requirements](https://github.com/typst/packages/blob/main/docs/licensing.md).
