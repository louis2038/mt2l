#import "binding.typ": theorem, highlight, disk

= Reusable bindings

A binding module can mix editable LaTeX and PDF-rendered Typst drawings.
Here is #highlight[highlighted text] and a disk #disk(radius: 5pt, fill: blue).

#theorem(name: [An identity], mt2l_variables: (label: "thm:identity",))[
  For every integer $n$, $n + 0 = n$.
  The body supports #highlight[nested bindings].
]
