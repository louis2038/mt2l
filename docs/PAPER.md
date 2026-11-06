# Writing a paper with mt2l

Create a project with the installed CLI:

```sh
mt2l --init my-paper
cd my-paper
typst compile main.typ
mt2l main.typ
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
```

This creates `main.typ`, `paper.bib`, and the template's attribution. An
existing directory is never overwritten. You can also initialize the same
starter with `typst init @local/mt2l:0.1.2 my-paper`.
After publication on Universe, use `@preview` instead of `@local`.

The Typst package formats your document. **The external mt2l CLI is required
for LaTeX export**, along with Typst >= 0.15 and Pandoc >= 3.7. A LaTeX
installation and BibTeX are needed to build the exported PDF.

## Document setup

```typst
#import "@local/mt2l:0.1.2": paper, abstract, theorem, proof

#show: paper.with(
  title: "A research paper",
  authors: ("First Author", "Second Author"),
  affiliations: ("Example University",),
  date: "November 2026",
  keywords: ("mathematics", "research"),
)

#abstract[Explain the question, method, and main result.]

= Introduction <sec-intro>

The main result is @thm:main.

#theorem(name: [A basic bound])[For real $x$, $x^2 >= 0$.]<thm:main>

#proof(depend: <thm:main>)[Multiply $x$ by itself.]
```

`paper.with(...)` selects the bundled LaTeX template automatically. No
`--template` option or copied style file is needed. Use `--template paper`
to select it explicitly, or `--template journal.tex` to supply another one.
A replacement template must provide the environments used by your paper.

| Paper option | Default / accepted values |
| --- | --- |
| `title` | `"Untitled paper"`; a plain string |
| `authors` | `()`; an array of name strings |
| `affiliations` | `()`; an array of affiliation strings |
| `date` | `""`; a plain string |
| `keywords` | `()`; an array of strings |
| `url` | `""`; a paper URL |
| `acknowledgements` | `""`; a plain string |
| `paper-size` | `"a4"` or `"us-letter"` |
| `font-size` | `11pt`; choose `10pt`, `11pt`, or `12pt` |

Metadata is shared by the native PDF and the exported LaTeX. Text such as
`"Research & development"` is escaped for LaTeX automatically. Keep rich text
and mathematics in `abstract[...]` and the document body. `paper` already
exports global metadata: do not add a second `mt2l-export-meta` call.

The Typst version uses STIX Two with serif fallbacks, wide margins, a 1.4 em
indent, small-cap statement titles, and a rule beside proofs, remarks, and
examples. The rule covers the content; the heading stays above it.
The LaTeX version takes its minimalist layout from
[Pascal Michaillat's latex-paper](https://github.com/pmichaillat/latex-paper),
adapted to use Latin Modern, standard mathematical notation, shared statement
counters, and portable `plainnat` bibliographies. Layout and pagination can
differ between the two engines. The MIT attribution is included in
`templates/LICENSE-latex-paper`.

## Mathematical environments

Import only the helpers you need, or use a namespace:

```typst
#import "@local/mt2l:0.1.2" as mt
#show: mt.paper.with(title: "My paper")

#mt.definition[Define the object here.]<def-real>

#mt.theorem(name: [Main result])[State the result here.]<thm-main>

#mt.proof(depend: <thm-main>)[Give the argument here.]
```

| Typst helper | LaTeX environment | Numbering |
| --- | --- | --- |
| `theorem` | `theorem` | Shared statement counter |
| `proposition` | `proposition` | Shared statement counter |
| `lemma` | `lemma` | Shared statement counter |
| `corollary` | `corollary` | Shared statement counter |
| `conjecture` | `conjecture` | Shared statement counter |
| `assumption` | `assumption` | Shared statement counter |
| `definition` | `definition` | Shared statement counter; upright body |
| `remark` | `remark` | Unnumbered; upright, ruled body |
| `example` | `example` | Separate example counter; upright body |
| `proof` | `proof` | Unnumbered; ends with a QED symbol |
| `solution` | `solution` | Unnumbered |
| `notation` | `notation` | Unnumbered |

Each takes an attached body `[...]` and optional `name: [Title]`.
Numbered environments accept a trailing `<thm:main>` label and `depend` for
prerequisites. The earlier `id: "thm-main"` argument is also supported.
Proofs, solutions, remarks, and notations are unnumbered; reference a numbered
statement instead. `breakable: false` keeps an
environment together in Typst; LaTeX uses its normal environment page breaks.
Separate block calls with a blank line and keep them outside running prose.

### Dependencies, proof headings, and the graph

```typst
#import "@local/mt2l:0.1.2": definition, lemma, theorem, proof, link-graph

#definition[All variables are real.]<def-real>

#lemma(depend: <def-real>)[For real $x$, $x^2 >= 0$.]<lem-square>

#theorem(depend: (<def-real>, <lem-square>))[
  For real $a$ and $b$, $a^2 + b^2 >= 2 a b$.
]<thm-bound>

#proof(depend: "thm-bound")[Expand $(a - b)^2 >= 0$.]

#link-graph(scale-factor: 85%)
```

`depend` accepts an ID string (`"lem-square"`), a label (`<lem-square>`),
or a tuple of them. Repeated prerequisites are combined. A numbered statement
with dependencies must also have an `id` or a trailing label. Every identified numbered statement
becomes a graph node, including examples; an arrow goes from each prerequisite
to the statement that uses it. Unidentified statements are not graph nodes.

For a proof, `depend` names the **result being proved**. The heading becomes
“Proof of Theorem 3”, with a real reference, in both Typst and LaTeX. Multiple
targets produce a combined heading. `name: [Custom heading]` overrides this
automatic title. A proof does not add a node or an edge; declare the logical
prerequisites on its result. The QED symbol stays in the proof body.

`link-graph()` reads the whole document, including statements that follow it.
It rejects duplicate IDs, unknown prerequisites, self-dependencies, and cycles.
The `autograph:0.1.0` and `fletcher:0.5.8` packages are loaded only when a graph
is requested; Typst downloads them on first use if necessary. `scale-factor`
controls its size. An empty graph displays “No identified statements.”

The LaTeX binding uses `pdfrender` with `render-context: "document"`: mt2l
captures a cropped PDF from the original document, retaining the actual
statement numbers and dependency data. The surrounding LaTeX stays editable.
Keep graph calls standalone and write them directly in document order; calls
generated by loops or custom functions are outside the converter's syntax API.
The dedicated `examples/dependencies.typ` demonstrates this workflow.

### Equations and cross-references

```typst
$ (a - b)^2 = a^2 - 2 a b + b^2 . $<eq:square>

See @eq:square.

$ x^2 >= 0 $
```

The paper's show rule numbers labeled displayed equations, while leaving
unlabeled ones unnumbered. Keep the spaces inside `$ ... $` for a display;
ordinary `$x$` remains inline. The export uses Pandoc's mathematical conversion
and puts the label inside a numbered LaTeX `equation` environment.

Use `@id` for references to statements, equations, figures, tables, and labeled
headings (`= Introduction <sec:intro>`). The export resolves the target's type
and uses `\cref`, including for forward references and IDs containing `:`.
Use simple identifiers made of letters, digits, hyphens, underscores, and colons.
`@id[Custom supplement]` and `#ref(<id>)` are supported too.

The explicit forms `equation(id: "eq-square")[$ ... $]` and
`xref("eq-square")` still work. The default workflow needs neither helper.

### Keeping an introduction with its equation

```typst
#import "@local/mt2l:0.1.2": glue

#glue(indent: false)[The identity is]

$ (a + b)^2 = a^2 + 2 a b + b^2 $
```

`glue` keeps text with what follows. Its default is `indent: true`; pass
`false` after a heading or when no initial indent is wanted.

## Figures

```typst
#import "@local/mt2l:0.1.2": paper-figure

#paper-figure(caption: [An illustration.], id: "fig-shape", note: [A figure note.])[
  #rect(width: 5cm, height: 2cm)[A native Typst drawing]
]
```

The drawing becomes a cropped PDF asset. Its caption, label, note, and float
remain editable LaTeX. The native PDF uses Typst's normal figure layout;
LaTeX can move the float. `caption`, `id`, and `note` are optional.

The built-in figure renderer knows Typst's standard functions and resolves
resource paths from the project root. For example, with `main.typ` at the
root you can use `#image("images/chart.svg")` in the body. For third-party
drawing packages or custom definitions, define your own `pdfrender` adapter
with an explicit `typst-preamble` (see the main README). Nested contract
calls inside a rendered drawing are not expanded by Pandoc.

## Tables

```typst
#import "@local/mt2l:0.1.2": paper-table

#paper-table(caption: [Results.], id: "tab-results", note: [An optional note.])[
  #table(
    columns: 2,
    table.header([Method], [Score]),
    [Baseline], [0.8],
    [Proposed], [0.9],
  )
]
```

The cells become an editable LaTeX `longtable`; captions appear above the
table. `caption`, `id`, and `note` are optional. Typst-specific cell strokes,
spacing, and other visual details follow Pandoc's table conversion. A custom
`tablef` or external table library is unnecessary for this template.

## Citations and bibliography

Use a shared BibTeX `.bib` file and ordinary Typst citations for both formats:

```typst
Previous work @knuth1984[p. 1].
#cite(<knuth1984>, form: "prose") describes the method.
The author is #cite(<knuth1984>, form: "author");
the year is #cite(<knuth1984>, form: "year").

#bibliography("paper.bib")
```

Pandoc already recognizes ordinary citations. The CLI uses `--natbib`, and the
paper adapter fills the gaps observed in Pandoc 3.7.0.2: citation supplements,
`form` options, cross-reference types, colon IDs, and the bibliography command.
Math and citation formatting remain Pandoc's responsibility. See the
[Pandoc citation documentation](https://pandoc.org/MANUAL.html#citations).

`cite` supports `normal`, `prose`, `author`, `year`, and `none` forms. An
optional `supplement: [p. 2]` is preserved. Use literal citation labels.
`bibliography` accepts one literal `.bib` path (string or `path("file.bib")`),
optional `title`, and `full: true`. The file is copied to output assets so the
exported document contains no absolute path to your machine. YAML sources,
multiple bibliographies, and per-citation CSL styles need custom adapters.

The earlier `citep`, `citet`, `citeauthor`, `citeyear`, and
`references(path: path("paper.bib"))` helpers are still available.

Typst uses Chicago author-date; LaTeX uses natbib with `plainnat`. Citation
punctuation and bibliography formatting can differ. To compile LaTeX, run
`pdflatex`, `bibtex`, then `pdflatex` twice, from the output directory.

## Appendix

```typst
#import "@local/mt2l:0.1.2": appendix, lemma

#appendix[
  = Additional results <sec-appendix>

  #lemma[An auxiliary result.]<lem-extra>

  $ x^2 >= 0 $<eq-extra>

  See @lem-extra and @eq-extra.
]
```

Use one appendix block at the end of the paper. It resets statement, example,
figure, table, and equation counters and uses `A1`, `A2`, etc. for them.
Sections become `A`, `B`, etc. Keep the bibliography before this block.

The examples in `examples/natural.typ`, `examples/paper.typ`, and
`examples/dependencies.typ` demonstrate the public paper bindings. Generic conversion contracts can still be imported
from the same package and used alongside these helpers.
