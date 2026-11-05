# Publishing mt2l 0.1.0

The source repository is https://github.com/louis2038/mt2l.
The project and package use the MIT license.

## Validate and prepare

```sh
python scripts/test_install.py
python scripts/test_release.py
python -m unittest discover -s tests -v
python scripts/package.py
```

Python 3.11+ is needed for these development commands, not for installation or
export. The generated `build/release/source/mt2l-0.1.0` directory contains the
explicit source distribution. Private report drafts, old Git history, PDF
outputs, and third-party document classes from a working folder are excluded.

## Publish the source and version tag on GitHub

Push the reviewed source to `louis2038/mt2l`, then create and push `v0.1.0`.
The public installer downloads this exact Git tag, so the command below is
usable only after the tag is available publicly:

```sh
curl -fsSL https://raw.githubusercontent.com/louis2038/mt2l/v0.1.0/get.sh | bash
```

This fetches `get.sh`, which downloads the tagged GitHub source archive and
runs `install.sh`. It installs the CLI and a local development package without
sudo. Dependencies are checked and are never automatically installed.

## Submit to Typst Universe

Fork https://github.com/typst/packages, create a branch, and copy
`build/release/packages/preview/mt2l/0.1.0` to
`packages/preview/mt2l/0.1.0` in that fork. Open a pull request to `typst/packages`.
The submission contains only the Typst API, its manifest, README and license;
the external exporter stays in its GitHub repository.

The import becomes publicly available after the submission is accepted:

```typst
#import "@preview/mt2l:0.1.0": mt2l, mt2l-export-meta
```

Before acceptance, test it offline by setting `TYPST_PACKAGE_PATH` to the
generated `build/release/packages` directory. The release test does this
without downloading anything from Universe. The locally installed
`@local/mt2l:0.1.0` remains available independently.

Official guidance:

- https://github.com/typst/packages/blob/main/docs/README.md
- https://github.com/typst/packages/blob/main/docs/manifest.md
- https://github.com/typst/packages/blob/main/docs/licensing.md

## Next release

Update the manifest, installer bootstrap default, example imports, docs, and
version-specific tests together. Publish a new Git tag and submit a new
version directory to Typst Universe. A GitHub tag alone does not publish the
Typst package, and an import alone does not install the external command.
