#import "../mt2l.typ": mt2l

#let theorem(name: none, body) = block[
  #strong[Théorème #name]
  #body
]

#let theorem-mt2l = mt2l(
  fn: theorem,
  placement: "block",
  latex-preamble: ```latex
\newtheorem{mt2ltheorem}{Théorème}
```,
  latex-template: ```latex
\begin{mt2ltheorem}$if(ARGS.name)$[$ARGS.name$]$endif$
$if(LOCAL.label)$\label{$RAW.LOCAL.label$}$endif$
$BODY$
\end{mt2ltheorem}
```,
)

#let highlight = mt2l(
  fn: strong,
  placement: "inline",
  latex-template: ```latex
\textbf{$BODY$}
```,
)

// The same call remains an ordinary Typst circle in the native document.
#let disk-mt2l = mt2l(
  fn: circle,
  mode: "pdfrender",
  placement: "inline",
  typst-template: ```typst
#set page(width: auto, height: auto, margin: 0pt)
$HERE$
```,
  latex-template: ```latex
\raisebox{-.2em}{\includegraphics[height=1em]{$PATH$}}
```,
)
