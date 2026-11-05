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
package_dir="build/universe/packages/preview/mt2l/0.1.1"
mkdir -p "$package_dir"
cp typst.toml mt2l.typ LICENSE "$package_dir/"
cp docs/universe.md "$package_dir/README.md"
```

Fork [typst/packages](https://github.com/typst/packages), copy the prepared
folder into `packages/preview/mt2l/0.1.1`, and open a pull request.
Only the Typst API, manifest, README, and license belong in this submission.
The external CLI stays in the mt2l GitHub repository.

Once accepted, the public import is:

```typst
#import "@preview/mt2l:0.1.1": mt2l, mt2l-export-meta
```

A GitHub tag does not publish the package on Universe, and importing the
Typst package does not install the external CLI.

See the official [submission guidelines](https://github.com/typst/packages/blob/main/docs/README.md),
[manifest reference](https://github.com/typst/packages/blob/main/docs/manifest.md),
and [licensing requirements](https://github.com/typst/packages/blob/main/docs/licensing.md).
