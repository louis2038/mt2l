// Advanced adapters for third-party Typst drawing packages.
#import "@local/mt2l:0.1.2": mt2l, mt2l-export-meta
#import "@preview/pavemat:0.2.0": pavemat
#import "@preview/cetz:0.5.2" as cetz

// These values are evaluated by Typst at the metadata location, then become
// ordinary variables in both local mt2l templates and the outer LaTeX template.
#set text(size: 10pt)
#let mt2l-meta = ctx => (
  fontsize: ctx.text-size,
  colorlinks: true,
  documentclass: "article",
)
#mt2l-export-meta(mt2l-meta)

// This stands in for a potentially complex function imported from a package.
#let definition(name: none, id: none, body) = block[
  #strong[Definition — #name]
  #body
]

#let definition_mt2l = mt2l(
  mode: "syntax",
  latex-template: ```latex
\begin{definition}[$ARGS.name$]
\label{$RAW.ARGS.id$}
$BODY$
\end{definition}
```,
  latex-preamble: ```latex
\usepackage{amsthm,graphicx}
\newtheorem{definition}{Definition}
```,
  fn: definition,
)

// The result is inserted inside a mathematical formula in LaTeX.
#let pavmat_mt2l = mt2l(
  mode: "pdfrender",
  typst-template: ```typst
#import "@preview/pavemat:0.2.0": pavemat
#set page(width: auto, height: auto, margin: 2pt)
$HERE$
```,
  latex-template: ```latex
\vcenter{\hbox{\includegraphics[height=5.2em,keepaspectratio]{$PATH$}}}
```,
  fn: pavemat,
)

// Cetz receives its drawing function as its first positional argument.
#let cetz_figure_mt2l = mt2l(
  mode: "pdfrender",
  typst-template: ```typst
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto, margin: 4pt)
$HERE$
```,
  latex-template: ```latex
\begin{figure}[ht]
\centering
\includegraphics[width=.42\linewidth]{$PATH$}
$if(LOCAL.caption)$
\caption{$LOCAL.caption$}
$endif$
$if(LOCAL.label)$
\label{$RAW.LOCAL.label$}
$endif$
\end{figure}
```,
  fn: cetz.canvas,
)

#definition_mt2l(
  name: [Discrete empirical model of level $t$],
  id: "def:discrete-model",
)[
  A *discrete empirical model of level* $t$ is a compatible family
  $N = (N_C)_(C in cal(M))$ such that
  $N_C in 𝒟_NN^t (ℰ(C))$ for every context $C$.
]

The following matrix is a local PDF even though it occurs inside an equation:

$
  d_g = #pavmat_mt2l(
    pave: (
      (path: "SSSS", from: (0, 2)),
      (path: "DDDD", from: (2, 0)),
    ),
    fills: (
      "2-0": purple.transparentize(80%),
      "0-0": red.transparentize(80%),
      "2-2": blue.transparentize(80%),
      "0-2": green.transparentize(80%),
    ),
  )[$mat(
    1, 0, 1, 0;
    0, 0, 0, 0;
    0, 0, 0, 0;
    1, 0, 1, 0
  )$]
$

And this is a regular Typst Cetz canvas, exported as a LaTeX figure:

#cetz_figure_mt2l(
  mt2l_variables: (
    caption: [Local Cetz triangle with $t$],
    label: "fig:local-cetz-triangle",
  ),
  {
  import cetz.draw: *
  line((0, 0), (4, 0), stroke: blue + 1.2pt)
  line((0, 0), (2, 2.5), stroke: red + 1.2pt)
  line((4, 0), (2, 2.5), stroke: green + 1.2pt)
  for point in ((0, 0), (4, 0), (2, 2.5)) {
    circle(point, radius: .12, fill: white, stroke: black)
  }
  content((2, -.35), [local Cetz triangle])
})
