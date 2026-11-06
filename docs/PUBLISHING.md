# Publishing mt2l

## GitHub

The source repository is https://github.com/louis2038/mt2l.
The project and package use the MIT license.

Commit the project files allowed by `.gitignore` and push them to GitHub.
For each release, update the version in `typst.toml`, examples, and
documentation together. Create and push the matching `vX.Y.Z` tag.
The bootstrap selects the highest stable version from the repository's tags.

Users can install or update to the latest stable version with:

```sh
curl -fsSL https://raw.githubusercontent.com/louis2038/mt2l/main/get.sh | bash
```

`get.sh` downloads the tagged GitHub archive and runs `install.sh`.
`install.sh` installs the package and CLI from local files, without sudo.
It skips the same or a newer installed version unless `--force` is given.
Neither automatically installs Typst or Pandoc. The installed command
supports `mt2l --update` and `mt2l --uninstall`.

## Typst Universe

Prepare the submission from the repository root:

```sh
package_dir="build/universe/packages/preview/mt2l/0.1.2"
mkdir -p "$package_dir"
mkdir -p "$package_dir/templates" "$package_dir/starter"
cp typst.toml mt2l.typ core.typ LICENSE thumbnail.png "$package_dir/"
cp templates/paper.typ templates/statements.typ templates/LICENSE-latex-paper "$package_dir/templates/"
cp starter/paper.bib "$package_dir/starter/"
sed 's/@local\/mt2l:/@preview\/mt2l:/g' starter/main.typ > "$package_dir/starter/main.typ"
cp docs/universe.md "$package_dir/README.md"
```

Fork [typst/packages](https://github.com/typst/packages), copy the prepared
folder into `packages/preview/mt2l/0.1.2`, and open a pull request.
The submission includes the Typst API, the paper module, the starter, the
thumbnail, documentation, and licenses. The external CLI and the Pandoc LaTeX
templates stay in the mt2l GitHub repository.

The `[template]` manifest section enables `typst init` and the Universe
template button. Regenerate the thumbnail after changing the starter layout:

```sh
typst compile --format png --pages 1 --ppi 150 starter/main.typ thumbnail.png
```

Check the prepared submission by initializing its starter with the local
package path pointing at `build/universe/packages`, then compile that document.

Once accepted, the public import is:

```typst
#import "@preview/mt2l:0.1.2": mt2l, mt2l-export-meta
```

A GitHub tag does not publish the package on Universe, and importing the
Typst package does not install the external CLI.

See the official [submission guidelines](https://github.com/typst/packages/blob/main/docs/README.md),
[manifest reference](https://github.com/typst/packages/blob/main/docs/manifest.md),
and [licensing requirements](https://github.com/typst/packages/blob/main/docs/licensing.md).
