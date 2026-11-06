// LaTeX equivalent of the native document template.
#import "@local/mt2l:0.1.2": mt2l
#import "template.typ" as native

#let template = mt2l(
  fn: native.template,
  placement: "document",
  latex-template: ```latex
$BODY$
```,
)
