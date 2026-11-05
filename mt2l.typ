// Public Typst prelude for the generic mt2l converter.
// Normal Typst compilation only sees transparent forwarding wrappers.
// `placement` is auto, inline, or block; a block call must stand alone.
// `typst-preamble` supplies definitions to isolated conversions.
// `latex-preamble` is emitted once in the outer document header.
#let mt2l(
  mode: "syntax",
  placement: "auto",
  latex-template: none,
  typst-template: none,
  typst-preamble: none,
  latex-preamble: none,
  fn: none,
) = {
  // mt2l_variables is conversion-only metadata. It becomes $LOCAL.*$ in
  // templates and is deliberately not sent to fn, so arbitrary library
  // functions retain their original signature.
  let wrapped(mt2l_variables: none, ..args) = fn(..args)
  wrapped
}

// `make` receives values resolved at the location of this call. Its result
// must be a dictionary containing JSON-compatible values.
//
// Example:
// #let mt2l-meta = ctx => (
//   fontsize: ctx.text-size,
//   page-width: ctx.page-width,
//   colorlinks: true,
// )
// #mt2l-export-meta(mt2l-meta)
#let mt2l-export-meta(make) = context [
  #metadata(make((
    text-size: text.size,
    page-width: page.width,
    page-height: page.height,
  ))) <mt2l-meta>
]
