#import "@local/mt2l:0.1.2": paper, abstract, definition, theorem, proof

#show: paper.with(
  title: "The title of your paper",
  authors: ("First Author", "Second Author"),
  affiliations: ("Your University",),
  date: "November 2026",
  keywords: ("mathematics", "research"),
)

#abstract[
  State the question, your approach, and the main result of your paper.
  This document compiles in Typst and exports to editable LaTeX with mt2l.
]

= Introduction <sec:introduction>

Present the research question and the related literature. Cite your sources
with #cite(<knuth1984>, form: "prose"). The main result is @thm:main.

= Main result

#definition(name: [Nonnegative real])[
  A real number $x$ is nonnegative when $x >= 0$.
]<def:nonnegative>

#theorem(name: [A basic inequality])[
  For any real $a$ and $b$, $a^2 + b^2 >= 2 a b$.
]<thm:main>

#proof(depend: <thm:main>)[
  The square of a real number is nonnegative. Expanding $(a - b)^2 >= 0$
  proves the claim.
]

$ (a - b)^2 = a^2 - 2 a b + b^2 . $<eq:identity>

Use @eq:identity for the algebraic identity, and
@def:nonnegative for the definition.

= Conclusion

Explain what the result adds and what remains to be investigated.

#bibliography("paper.bib")
