#import "@local/mt2l:0.1.2": mt2l

// One function, two representations: native Typst and editable LaTeX.
#let highlight = mt2l(
  fn: strong,
  placement: "inline",
  latex-template: ```latex
\textbf{$BODY$}
```,
)

= Your first binding

This is #highlight[ordinary Typst content]. The same binding can be
#highlight[called again], including inside a list:

- Keep #highlight[important words] editable in the exported LaTeX.
