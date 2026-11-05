# mt2l

Define modular Typst-to-LaTeX conversion contracts directly in your document.
The same functions keep working in normal Typst compilation. Export custom
elements as editable LaTeX or render complex graphics as PDF assets.

## Use in Typst

````typst
#import "@preview/mt2l:0.1.0": mt2l, mt2l-export-meta

#let highlight = mt2l(
  fn: strong,
  placement: "inline",
  latex-template: ```latex
\textbf{$BODY$}
```,
)

Before #highlight[important text] after.
````

The package provides the `mt2l` contract factory and `mt2l-export-meta`.
`mt2l_variables` holds per-call conversion metadata. Contracts support
`syntax` and `pdfrender` modes and `auto`, `inline`, or `block` placement.

## Export to LaTeX

LaTeX export requires the external **mt2l command**, Typst >= 0.15 and Pandoc
>= 3.7. Importing the package does not run or install these programs.
The package itself works in normal Typst compilation, including the web app;
run LaTeX export on a computer with the CLI installed.

On Linux or macOS, install the CLI without sudo:

```sh
curl -fsSL https://raw.githubusercontent.com/louis2038/mt2l/v0.1.0/get.sh | bash
```

Then export your document:

```sh
mt2l main.typ build/article.tex
```

The installer reports missing dependencies and links to their official
installation instructions. It does not install system dependencies or edit
shell configuration. If necessary, it explains how to add `~/.local/bin`
to your `PATH`.

See the [repository documentation](https://github.com/louis2038/mt2l#readme)
for PDF rendering, templates, explicit context, limitations, and examples.

## License

MIT. Copyright (c) 2026 louis2038. See [LICENSE](LICENSE).
