# Publishing mt2l

## GitHub

The source repository is https://github.com/louis2038/mt2l.
The project and package use the MIT license.

Commit the project files allowed by `.gitignore` and push them to GitHub.
For each release, update the version in `typst.toml`, `get.sh`, examples,
and documentation together. Create and push the matching `vX.Y.Z` tag.

Users can install version 0.1.0 with:

```sh
curl -fsSL https://raw.githubusercontent.com/louis2038/mt2l/v0.1.0/get.sh | bash
```

`get.sh` downloads the tagged GitHub archive and runs `install.sh`.
`install.sh` installs the package and CLI from local files, without sudo.
Neither automatically installs Typst or Pandoc.

## Typst Universe

Prepare the submission from the repository root:

```sh
package_dir="build/universe/packages/preview/mt2l/0.1.0"
mkdir -p "$package_dir"
cp typst.toml mt2l.typ LICENSE "$package_dir/"
cp docs/universe.md "$package_dir/README.md"
```

Fork [typst/packages](https://github.com/typst/packages), copy the prepared
folder into `packages/preview/mt2l/0.1.0`, and open a pull request.
Only the Typst API, manifest, README, and license belong in this submission.
The external CLI stays in the mt2l GitHub repository.

Once accepted, the public import is:

```typst
#import "@preview/mt2l:0.1.0": mt2l, mt2l-export-meta
```

A GitHub tag does not publish the package on Universe, and importing the
Typst package does not install the external CLI.

See the official [submission guidelines](https://github.com/typst/packages/blob/main/docs/README.md),
[manifest reference](https://github.com/typst/packages/blob/main/docs/manifest.md),
and [licensing requirements](https://github.com/typst/packages/blob/main/docs/licensing.md).
