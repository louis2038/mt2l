#import "@local/mt2l:0.1.0": mt2l, mt2l-export-meta

#mt2l-export-meta(ctx => (title: "Un package, deux sorties", colorlinks: true))

#let highlight = mt2l(
  fn: strong,
  placement: "inline",
  latex-template: ```latex
\textbf{$BODY$}
```,
)

#let disk = mt2l(
  fn: circle,
  mode: "pdfrender",
  placement: "inline",
  typst-template: ```typst
#set page(width: auto, height: auto, margin: 0pt)
$HERE$
```,
  latex-template: ```latex
\includegraphics[height=1em]{$PATH$}
```,
)

= Un package Typst avec export LaTeX

Du texte #highlight[en gras], un second #highlight[appel],
et un dessin #disk(radius: 5pt, fill: blue).

- Les adaptateurs restent des fonctions Typst normales.
- L'export se fait avec la commande `mt2l`.
