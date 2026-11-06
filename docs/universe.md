# mt2l — Modular Typst to LaTeX

Write research papers in Typst and export editable LaTeX. Start with the
built-in paper environment, or define conversion bindings for your own
functions. The same document still compiles normally with Typst.

> [!WARNING]
> **LaTeX export requires the `mt2l` command-line utility.** Importing the
> Typst package does not install or run the exporter. The CLI requires
> **Typst >= 0.15** and **Pandoc >= 3.7**.

Create a project with editable Typst and LaTeX templates:

```sh
mt2l init paper my-paper    # Or: mt2l init default my-document
cd my-paper
```

For an offline copy of the installed model, use
`mt2l init --local paper my-paper` instead.

Edit the generated `main.typ`:

````typst
#import "binding.typ": template, abstract, theorem, proof

#show: template.with(title: "My paper", authors: ("Your Name",))

#abstract[The question, method, and main result.]

= Introduction

Our main result is @thm:main.

#theorem(name: [A simple bound])[For real $x$, $x^2 >= 0$.]<thm:main>

#proof(depend: <thm:main>)[The product of two equal real numbers is nonnegative.]

$ x ∈ {0,1} $<eq:3>

See @eq:3.
````

Export from your terminal:

```sh
mt2l main.typ --template latex_template/paper.tex
mt2l main.typ build/article.tex --template latex_template/paper.tex
mt2l main.typ                          # Minimal article, without the paper style
```

Edit `template.typ` to change native Typst functions and show rules.
Edit `binding.typ` to change their LaTeX conversion bindings. Edit
`latex_template/paper.tex` to change the LaTeX layout. The LaTeX template
is selected only by `--template FILE`; it is never inferred from Typst styling.
Without that option, mt2l uses a minimal article template with no theorem
environments. Use `typst compile main.typ` for the native Typst PDF.

## Installation

### Typst Universe + CLI

Import the package in your document:

```typst
#import "@preview/mt2l:0.1.2": mt2l, mt2l-export-meta
```

Install the CLI on Linux or macOS, without sudo:

```sh
curl -fsSL https://raw.githubusercontent.com/louis2038/mt2l/main/get.sh | bash
```

The installer selects the latest stable `vX.Y.Z` tag from GitHub and upgrades
older installations. It skips reinstalling the same version and does not
downgrade a newer installation unless `--force` is requested.

### Fully local installation

From a checkout of the [mt2l repository](https://github.com/louis2038/mt2l):

```sh
./install.sh
```

Then use the local package:

```typst
#import "@local/mt2l:0.1.2": mt2l, mt2l-export-meta
```

This installs both the package and the CLI from your local files, without
network access or sudo. Typst and Pandoc must already be installed.

Both installation methods check dependencies and show installation commands
and [official Pandoc instructions](https://pandoc.org/installing.html) when
needed. Neither installs system dependencies nor changes your shell settings.
If `mt2l` is not found after installation, add its directory to your `PATH`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### Updating and uninstalling

```sh
mt2l --update                       # Check GitHub and install the latest stable version
mt2l --update --version 0.1.2       # Select a specific version
mt2l --update --force               # Reinstall even if already current
mt2l --uninstall                    # Remove mt2l from this installation
```

From a local checkout:

```sh
./install.sh                        # Install a newer local version; otherwise do nothing
./install.sh --force                # Reinstall or deliberately downgrade to the local version
./install.sh --uninstall            # Uninstall without network access
```

The local installer never checks GitHub; use `mt2l --update` or run the curl
command again to check for remote updates. Uninstalling removes the launcher
and all local package versions marked as installed by mt2l. It works without
Typst or Pandoc and preserves documents, unrelated commands, unmanaged
packages, and the Typst Universe cache. Updates preserve older package
versions so existing imports continue to resolve. Patch versions within the
same major/minor series are compatible with the exporter.

A LaTeX installation is needed only to compile the exported `.tex` file.
Compile from its output directory so relative graphics paths resolve:

```sh
cd build
pdflatex article.tex
```

## Features

### Ready-to-use paper environment

`mt2l init paper my-paper` downloads the complete paper directory and creates `main.typ`, `paper.bib`, `template.typ`, `binding.typ`, and
`latex_template/paper.tex` in `my-paper/`. `mt2l init default my-document`
creates a minimal document and `latex_template/default.tex` instead. The
destination defaults to the model name when omitted. Existing
destinations are never overwritten. The paper preset also includes its MIT
attribution in `latex_template/LICENSE-latex-paper`.

Each model supplies its own reusable helpers. Its `template.typ`
contains native functions and set/show rules. `binding.typ` imports those
functions and wraps them with their LaTeX equivalents. Its `template` function is applied
with `#show: template.with(...)`. `paper-layout` only provides the title block
and export metadata; it installs no statement or equation show rules.
To use your own LaTeX layout, pass its path to `--template FILE`. All
required LaTeX packages and environment definitions belong in that file.

The package includes title and abstract formatting; theorem, proposition,
lemma, corollary, conjecture, definition, assumption, example, remark, proof,
and solution environments; numbered equations; cross-references; figures;
editable tables; citations; bibliographies; and appendices. Statements accept
`depend` to declare prerequisites, `link-graph()` displays their dependency
graph, and `proof(depend: "thm-main")` automatically names the result being
proved. Proof and remark headings stay above the rule beside their content.
The dependency graph exports as a cropped PDF asset. All paper helpers
already have conversion bindings. No manual wrappers or copied style files
are required.

The LaTeX layout is inspired by
[Pascal Michaillat's latex-paper](https://github.com/pmichaillat/latex-paper),
adapted for portable fonts and shared statement counters. The Typst layout
uses STIX Two and serif fallbacks. Pagination and bibliography formatting
can differ between engines.

Read the [paper guide](https://github.com/louis2038/mt2l/blob/main/docs/PAPER.md)
for every option and binding. The complete example is
[`examples/06-complete-paper/main.typ`](https://github.com/louis2038/mt2l/blob/main/examples/06-complete-paper/main.typ).
Write ordinary Typst equations and labels: `$ x ∈ {0,1} $<eq:3>`,
`#theorem[... ]<thm:main>`, and `@thm:main`. Labeled displays are numbered;
unlabeled displays stay unnumbered. Citations use `@key`, `@key[p. 2]`, or
`#cite(<key>, form: "prose")`, with a normal `#bibliography("paper.bib")`.
The explicit `equation`, `xref`, and citation helpers remain available.

Pandoc already parses the mathematics and citations; mt2l uses its natbib
writer. The paper bindings preserve the labels, reference types, and citation
options that the Typst reader in Pandoc 3.7 does not retain.

### Editable LaTeX: `syntax`

Wrap a Typst function with a conversion contract. In normal Typst compilation,
`fn` receives the original arguments and content. During export,
`latex-template` controls its LaTeX representation.

For example, define a custom theorem and its LaTeX environment:

````typst
#import "@preview/mt2l:0.1.2": mt2l

#let theorem(name: none, body) = block[
  #strong[Theorem: #name]
  #body
]

#let theorem-export = mt2l(
  fn: theorem,
  mode: "syntax",
  placement: "block",
  latex-preamble: ```latex
\newtheorem{customtheorem}{Theorem}
```,
  latex-template: ```latex
\begin{customtheorem}$if(ARGS.name)$[$ARGS.name$]$endif$
$if(LOCAL.label)$\label{$RAW.LOCAL.label$}$endif$
$BODY$
\end{customtheorem}
```,
)

#theorem-export(
  name: [Identity],
  mt2l_variables: (label: "thm:additive_identity",),
)[
  For every integer $n$, we have $n + 0 = n$.
]
````

Bodies are converted recursively: nested contracts, text formatting, lists,
table cells, and inline or display mathematics keep their surrounding content.

### Typst graphics: `pdfrender`

Render a function call with Typst and insert the resulting PDF into LaTeX.
This is useful for CeTZ drawings, styled matrices, and other graphics that
should retain their Typst appearance.

````typst
#import "@preview/mt2l:0.1.2": mt2l

#let disk = mt2l(
  fn: circle,
  mode: "pdfrender",
  placement: "inline",
  typst-template: ```typst
#set page(width: auto, height: auto, margin: 0pt)
$HERE$
```,
  latex-template: ```latex
\includegraphics[height=1em]{$PATH$}
```,
)

A blue disk: #disk(radius: 5pt, fill: blue).
````

`HERE` expands to the original function call, including its arguments and
body. The PDF is saved next to the exported document in a `*-assets` folder;
`PATH` points to that PDF relative to the `.tex` file. Choose dimensions and
baseline alignment in the LaTeX template. Graphics can also appear in equations.

PDF-only content is compiled by Typst without requiring Pandoc to understand
its body. PDF assets are rebuilt on each export to pick up resource changes.

### Inline and block placement

| `placement` | Behavior |
| --- | --- |
| `"auto"` (default) | A standalone paragraph becomes a LaTeX block; other calls stay inline. |
| `"inline"` | Insert LaTeX within text or mathematics. |
| `"block"` | Require a standalone call; reject placement inside text or mathematics. |

Use `block` for environments such as theorems and figures, and `inline` for
text commands and graphics embedded in a sentence or formula.

### Reusable adapter modules

Put contracts in a local `.typ` module and import them into your documents.
Selective imports, wildcard imports, aliases, namespaces, and re-exported
contracts are supported.

```typst
#import "adapters.typ": highlight
#import "adapters.typ": highlight as emphasis
#import "adapters.typ" as adapters

#highlight[First], #emphasis[second], #adapters.highlight[third].
```

See [the adapter module](https://github.com/louis2038/mt2l/blob/main/examples/03-modular/binding.typ)
and [its document](https://github.com/louis2038/mt2l/blob/main/examples/03-modular/main.typ).

### Arguments and local metadata

Templates can read named arguments through `ARGS.name` and positional
arguments through `ARGS.pos`. Add export-only values with `mt2l_variables`:

```typst
#theorem-export(
  name: [Identity],
  mt2l_variables: (label: "thm:identity",),
)[For every integer $n$, we have $n + 0 = n$.]
```

These values appear under `LOCAL` and are not forwarded to the original
Typst function. In LaTeX templates, `true` is true, while `false` and `none`
are false in conditions. Strings are escaped for LaTeX, and content blocks
are converted to LaTeX.

Use `RAW.ARGS.name` or `RAW.LOCAL.name` explicitly for unescaped identifiers
or existing LaTeX, for example `\label{$RAW.LOCAL.label$}`.

### Context and preambles

Each converted text fragment and each rendered PDF has its own context.
Definitions, imports, and styles from the main document are not automatically
inherited. Supply shared definitions through `typst-preamble`:

````typst
typst-preamble: ```typst
#let accent = blue
#import "/lib/tools.typ": *
```,
````

This literal source is prepended to generated PDF documents and to fragments
read by Pandoc. Keep it to definitions and imports rather than visible content.
Absolute Typst paths such as `/lib/tools.typ` start at the project root.

In `typst-template`, use `$MODULE$` to locate resources beside the adapter's
source file, for example `#image("$MODULE$/diagram.svg")`. Other relative
resource paths resolve from the project root.

`latex-preamble` adds packages, macros, or environments to the outer LaTeX
preamble. Identical fragments are included once, in first-use order.

### Global document metadata

Export contextual values to both the outer document template and individual
contracts with `mt2l-export-meta`:

```typst
#import "@preview/mt2l:0.1.2": mt2l-export-meta

#set text(size: 10pt)
#mt2l-export-meta(ctx => (
  title: "My article",
  fontsize: ctx.text-size,
  documentclass: "article",
  colorlinks: true,
))
```

The callback receives `text-size`, `page-width`, and `page-height` at the
export location. Return a dictionary of JSON-compatible values. At most one
global metadata export is allowed. Names used by the template API below are
reserved.

### Custom document templates

Replace the complete outer LaTeX template:

```sh
mt2l --template journal.tex main.typ build/article.tex
```

Use Pandoc template syntax, including `$body$`, metadata variables such as
`$title$`, conditions, and loops. Include this in your preamble to receive
adapter definitions from `latex-preamble`:

```latex
$for(header-includes)$
$header-includes$
$endfor$
```

### Reliable exports

The output's `*-assets` directory contains permanent resources, including
copied `.bib` files and rendered PDFs. Keep it beside the `.tex` when moving
or sharing the export. Cleanup removes only temporary files; the CLI checks
that all exported resources still exist before replacing the `.tex`.

Comments and raw code examples are left untouched. Conversion errors identify
the affected contract and source location where available. A failed conversion
does not replace the previous `.tex` file, and each PDF is replaced only after
successful rendering. Old assets are kept rather than deleted automatically.

## Reference

### Contract options

| Option | Description |
| --- | --- |
| `fn` | Original Typst function. Required. |
| `mode` | `"syntax"` (default) or `"pdfrender"`. |
| `placement` | `"auto"` (default), `"inline"`, `"block"`, or `"document"` for `#show: name.with(...)`. |
| `latex-template` | Fenced raw block containing a Pandoc template. Required. |
| `typst-template` | Fenced raw block for the PDF document. Required for isolated `pdfrender`. |
| `typst-preamble` | Literal Typst definitions prepended to isolated conversions. |
| `latex-preamble` | LaTeX definitions added once to the outer document. |
| `body-format` | `"latex"` (default), or `"math"` to extract one equation without math delimiters. |
| `asset-argument` | Name of a file argument copied into output assets; a literal string or `path("file")`. In `syntax` mode, its exported location is `PATH`. |
| `reference-argument` | Name of an argument converted to `\cref{...}`; accepts literal IDs, labels, or tuples of them. |
| `label-argument` | Consume a trailing `<label>` as this named export argument. The native function must return a labelable element; paper statements do. |
| `render-context` | `"isolated"` (default), or `"document"` to render a `pdfrender` call with the complete document's counters and queries. A document render does not need `typst-template`. |

### Template variables

| Variable | In `latex-template` |
| --- | --- |
| `BODY` | The attached `[...]` body converted to LaTeX. |
| `ARGS.name` | A converted named argument. |
| `ARGS.pos` | Converted positional arguments, as a list. |
| `LOCAL.name` | A converted value from `mt2l_variables`. |
| `RAW.ARGS.name`, `RAW.LOCAL.name` | Unescaped source values; string quotes are removed. |
| `RAW.BODY` | The original body source. |
| `PATH` | Relative path of a rendered PDF or a copied `asset-argument` file. |
| `TARGET` | The original `fn` expression. |
| `MODULE` | Adapter directory relative to the project root, prefixed with `/`; empty at the root. |

In `typst-template`, `ARGS`, `LOCAL`, and `BODY` contain their original Typst
source. `HERE` contains the full call to `fn`, excluding `mt2l_variables`.
Global metadata values are also available in both templates.

Templates use [Pandoc syntax](https://pandoc.org/MANUAL.html#templates):
`$BODY$`, `$if(LOCAL.caption)$`, `$for(ARGS.pos)$`, and so on. Write a literal
dollar as `$$` inside a template. This escaping does not apply to the literal
`typst-preamble`.

### Template directories

Each preset contains its own starter `main.typ`, bibliography, and two
implementation files (`template.typ` and `binding.typ`):

```text
templates/
  default/
    main.typ
    paper.bib
    template.typ
    binding.typ
    latex_template/default.tex
  paper/
    main.typ
    paper.bib
    template.typ
    binding.typ
    latex_template/paper.tex
    latex_template/LICENSE-latex-paper
```

`template.typ` defines native Typst functions and styling. `binding.typ`
imports it and defines each function's LaTeX equivalent with `mt2l`.
The document imports `binding.typ` and applies `#show: template.with(...)`.

To add a preset, copy a directory (for example, `paper` to `paper2`), edit
its two Typst files and LaTeX template, then register its directory in the
`MT2L_TEMPLATES` array at the top of `scripts/convert.sh`:

```bash
"paper2=$converter_root/templates/paper2"
```

Include `main.typ` and all resources directly in that directory. The starter
imports `binding.typ` and applies `#show: template.with(...)`. The package
entrypoint exposes only `mt2l` and `mt2l-export-meta`; all template-specific
functions belong to the local files.

After publishing a release and reinstalling, use `mt2l init paper2 my-project`.
Init downloads the archive for the installed CLI version (`vX.Y.Z`), extracts
only the registered template directory, and copies its entire contents into
the destination. It never overwrites an existing destination. To use templates
from a local checkout or installation without downloading:

```sh
mt2l init --local paper2 my-project
```

The native and LaTeX templates remain editable in the new project. Export
selects the LaTeX file explicitly; no template is inferred from the Typst style.

### CLI

Run `mt2l --help` (or `mt2l init --help`) to list available models, their
LaTeX files, and the directory used by `init --local`.

```text
mt2l INPUT [OUTPUT] [--template FILE] [--root DIR]
mt2l init [--local] NAME [DIR]
mt2l --help
mt2l --version
mt2l --update [--version X.Y.Z] [--force]
mt2l --uninstall
```

`OUTPUT` defaults to the input filename with a `.tex` extension. Output
folders are created automatically. `--root` defaults to the input directory;
set it when your document imports files from parent folders.

`init` downloads the complete model directory from the matching GitHub tag.
`init --local` copies the bundled directory without network access. `--template` accepts a
file path, such as `latex_template/paper.tex`; preset names are not accepted
as shortcuts. Options may appear before or after the input filename.
Omitting `--template` always uses the minimal article template.

For a source checkout, `./scripts/convert.sh` accepts the same arguments.

### Installation paths

On Linux, the package and exporter are installed under
`~/.local/share/typst/packages/local/mt2l/0.1.2/`, with the launcher in
`~/.local/bin/mt2l`. On macOS, package data defaults to
`~/Library/Application Support/typst/packages/local/mt2l/0.1.2/`.

| Environment variable | Purpose |
| --- | --- |
| `XDG_DATA_HOME` | Override the default data directory. |
| `TYPST_PACKAGE_PATH` | Override the Typst packages directory. |
| `MT2L_BIN_DIR` | Choose the launcher directory. |
| `MT2L_PROJECT_ROOT` | Set the export project root; `--root` takes precedence. |

## Limitations

- The `syntax` mode supports the constructs understood by Pandoc's Typst
  reader. Use `pdfrender` for graphics that need native Typst rendering.
- Contracts must use `#let name = mt2l(...)` with literal options, and calls
  must use `#name(...)` or `#name[...]`. Dynamic contract factories and indirect
  calls inside Typst code are not intercepted.
- Import paths must be literal. Contract discovery supports local files and
  the model bindings in your project. Adapters declared in other installed packages
  are not discovered automatically.
- The package can be imported in the Typst web app, but LaTeX export runs
  through the external CLI on your computer.

## Examples

Work through the [example guide](https://github.com/louis2038/mt2l/blob/main/examples/README.md)
from plain text to custom bindings, modular PDF rendering, papers, dependency
graphs, full paper features, and third-party drawing packages. Each numbered
directory has its own `main.typ`; generated files belong in `build/`.

MIT licensed. Paper layout attribution is included with its LaTeX template.
