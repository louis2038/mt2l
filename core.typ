// Public Typst prelude for the generic mt2l converter.
// Normal Typst compilation only sees transparent forwarding wrappers.
// `placement` is auto, inline, block, or document (#show: name.with(...)).
// A block call must stand alone in its own paragraph.
// `typst-preamble` supplies definitions to isolated conversions.
// `latex-preamble` is emitted once in the outer document header.
// `render-context: "document"` captures a standalone PDF call with its queries.
// `reference-argument` converts literal target IDs into LaTeX references.
// `label-argument` maps a trailing native label to a named export argument.
#let mt2l(
  mode: "syntax",
  placement: "auto",
  latex-template: none,
  typst-template: none,
  typst-preamble: none,
  latex-preamble: none,
  body-format: "latex",
  asset-argument: none,
  reference-argument: none,
  label-argument: none,
  render-context: "isolated",
  fn: none,
) = {
  // mt2l_variables is conversion-only metadata. It becomes $LOCAL.*$ in
  // templates and is deliberately not sent to fn, so arbitrary library
  // functions retain their original signature.
  let wrapped(mt2l_variables: none, ..args) = {
    if mode != "pdfrender" or render-context != "document" {
      return fn(..args)
    }
    // Document-aware renders retain counters, queries, and dependency data.
    // A selected render gets its own cropped page for the external CLI.
    counter("mt2l-document-render").step()
    context {
      let index = counter("mt2l-document-render").get().first()
      let selected = sys.inputs.at("mt2l-render", default: "") == str(index)
      if selected {
        page(width: auto, height: auto, margin: 0pt, header: none, footer: none, numbering: none, background: none, foreground: none)[
          #show link: it => it.body
          #metadata(index) <mt2l-render>
          #fn(..args)
        ]
      } else {
        fn(..args)
      }
    }
  }
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
