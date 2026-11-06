#import "../../templates/paper/binding.typ": template, abstract, definition, lemma, theorem, corollary, proof, remark, notation, link-graph

#show: template.with(title: "Statements and their dependencies", authors: ("Your Name",))

#abstract[
  Declare mathematical dependencies once. The graph and proof headings use
  the document's actual references and numbering in both output formats.
]

= Definitions and results

#definition(id: "def-real", name: [Real variables])[
  The variables $a$ and $b$ are real numbers.
]

#lemma(id: "lem-square", depend: "def-real")[For every real $x$, $x^2 >= 0$.]

#proof(depend: "lem-square")[The square of a real number is nonnegative.]

#theorem(id: "thm-bound", depend: ("def-real", "lem-square"))[
  For real $a$ and $b$, $a^2 + b^2 >= 2 a b$.
]

#proof(depend: "thm-bound")[Expanding $(a - b)^2 >= 0$ gives the inequality.]

#corollary(id: "cor-unit", depend: <thm-bound>)[For real $a$, $a^2 + 1 >= 2 a$.]

#proof(depend: ("thm-bound", "cor-unit"))[
  The theorem follows from the nonnegative square; substitute $b = 1$
  to obtain the corollary.
]

#remark(name: [Equality case])[
  Equality holds exactly when $a = b$. The rule is beside this content,
  leaving the remark's heading above it.
]

#notation[We write $RR$ for the real numbers.]

= Dependency graph

The arrows point from each prerequisite to the result that uses it.

#link-graph()
