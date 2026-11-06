# Examples

Run from the repository root after `./install.sh --force`. Outputs go into
`build/examples/`, leaving the sources clean.

| Example | What it demonstrates | LaTeX template |
| --- | --- | --- |
| `01-basics` | Plain text, lists, and mathematics | Minimal default |
| `02-bindings` | One editable inline binding | Minimal default |
| `03-modular` | Separate binding module, nesting, local arguments, PDF assets | Minimal default |
| `04-paper` | Paper starter, native labels, equations, citations, bibliography | Paper |
| `05-dependencies` | Statements, automatic proof headings, dependency graph | Paper |
| `06-complete-paper` | Full paper API, figures, tables, citations, appendix | Paper |
| `07-external-packages` | PDF adapters for CeTZ and Pavemat | Minimal default |

For the first three examples:

```sh
typst compile --root . examples/02-bindings/main.typ /tmp/bindings.pdf
mt2l --root . examples/02-bindings/main.typ build/examples/bindings.tex
```

For a paper example:

```sh
typst compile --root . examples/04-paper/main.typ /tmp/paper.pdf
mt2l --root . examples/04-paper/main.typ build/examples/paper.tex \
  --template templates/paper/latex_template/paper.tex
cd build/examples
latexmk -pdf paper.tex
```

Examples 04–06 reuse the repository's paper bindings instead of copying them.
For an independent project with editable local templates:

```sh
mt2l init paper my-paper
# Offline, using the installed templates: mt2l init --local paper my-paper
```

Example 05 downloads autograph/fletcher on first compilation. Example 07
requires CeTZ and Pavemat; Typst downloads these packages as needed.
