#import "@local/mt2l:0.1.2": paper, abstract, theorem, proposition, lemma, corollary, conjecture, definition, assumption, example, remark, proof, solution, equation, xref, citep, citet, citeauthor, citeyear, references, paper-figure, paper-table, appendix, glue

#show: paper.with(
  title: "A paper written in Typst",
  authors: ("First Author", "Second Author"),
  affiliations: ("Department of Mathematics, Example University",),
  date: "November 2026",
  keywords: ("Typst", "LaTeX", "mathematics"),
)

#abstract[
  This paper demonstrates an environment for writing mathematics in Typst
  and exporting an editable LaTeX manuscript. The statements, references,
  equations, figures, tables, and citations keep their meaning in both formats.
]

= Introduction <sec-introduction>

Write ordinary Typst prose, *strong text*, _emphasis_, lists, and mathematics.
The typesetting tradition is described by #citet("knuth1984"). We can also
cite a page #citep("knuth1984", supplement: [p. 1]), mention
#citeauthor("knuth1984"), or show only the year #citeyear("knuth1984").

See #xref("thm-main"), #xref("eq-square"), and #xref("tab-values").
Forward references work without manually maintaining their numbers.

= Mathematical statements

#definition(name: [Nonnegative real], id: "def-positive")[
  A real number $x$ is nonnegative when $x >= 0$.
]

#assumption(id: "ass-real")[All variables in this section are real.]

#lemma(id: "lem-square", depend: ("def-positive", "ass-real"))[For every real $x$, we have $x^2 >= 0$.]

#proof(depend: "lem-square")[
  For $x >= 0$, multiply two nonnegative factors. For $x < 0$, apply the
  same argument to $-x$.
]

#theorem(name: [A basic inequality], id: "thm-main", depend: "lem-square")[
  For any real $a$ and $b$, we have $a^2 + b^2 >= 2 a b$.
]

#proof(depend: "thm-main")[
  By #xref("lem-square"), $(a - b)^2 >= 0$. Expanding gives the result.
]

#proposition(id: "prop-equality")[Equality holds exactly when $a = b$.]

#corollary[Setting $b = 1$ gives $a^2 + 1 >= 2 a$.]

#conjecture[Related bounds can be explored for other convex functions.]

#example(name: [Two equal numbers], id: "ex-equality")[Take $a = b = 2$.]

#remark[Numbered statements share one counter; examples have a separate counter.]

#solution[Substituting $a = b = 2$ gives $8 = 8$.]

== Equations

#glue(indent: false)[The algebraic identity used in the proof is]

#equation(id: "eq-square")[$ (a - b)^2 = a^2 - 2 a b + b^2 . $]

A formula without an identifier stays unnumbered:

#equation[$ x^2 >= 0. $]

= Figures and tables

#paper-figure(caption: [A native Typst illustration.], id: "fig-shape", note: [The drawing is exported as a PDF; its caption stays editable.])[
  #rect(width: 6cm, height: 2cm, radius: 4pt, fill: rgb("edf2fa"))[
    #align(center + horizon)[An illustration: $a^2 + b^2$]
  ]
]

#paper-table(caption: [Some squares.], id: "tab-values", note: [Table cells remain editable in LaTeX.])[
  #table(
    columns: 3,
    align: center,
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([$x$], [$x^2$], [Nonnegative?]),
    table.hline(stroke: 0.4pt),
    [$-1$], [$1$], [Yes],
    [$0$], [$0$], [Yes],
    [$1$], [$1$], [Yes],
    table.hline(stroke: 0.8pt),
  )
]

Both #xref("fig-shape") and #xref("tab-values") have native Typst
counterparts and corresponding LaTeX labels. See also #xref("sec-introduction").

#references(path: path("paper.bib"))

#appendix[
  = Supplementary result <sec-appendix>

  #lemma(id: "lem-appendix")[For every real $x$, $(-x)^2 = x^2$.]

  #proof[Expand the product $(-x)(-x)$.]

  #equation(id: "eq-appendix")[$ (-x)^2 = x^2 . $]

  The appendix uses its own numbering: #xref("lem-appendix") and
  #xref("eq-appendix").
]
