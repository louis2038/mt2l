#import "@local/mt2l:0.1.2": mt2l

#let theorem-layout(name: none, body) = block[
  #strong[Theorem #name.] #body
]
#let theorem = mt2l(
  fn: theorem-layout,
  placement: "block",
  latex-preamble: ```latex
\usepackage{amsthm}
\newtheorem{customtheorem}{Theorem}
```,
  latex-template: ```latex
\begin{customtheorem}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(LOCAL.label)$\label{$RAW.LOCAL.label$}$endif$
$BODY$
\end{customtheorem}
```,
)
#let highlight = mt2l(
  fn: strong, placement: "inline",
  latex-template: ```latex
\textbf{$BODY$}
```,
)
#let disk = mt2l(
  fn: circle, mode: "pdfrender", placement: "inline",
  latex-preamble: ```latex
\usepackage{graphicx}
```,
  typst-template: ```typst
#set page(width: auto, height: auto, margin: 0pt)
$HERE$
```,
  latex-template: ```latex
\raisebox{-.2em}{\includegraphics[height=1em]{$PATH$}}
```,
)
