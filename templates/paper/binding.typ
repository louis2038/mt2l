// LaTeX equivalents of the functions in template.typ.
#import "@local/mt2l:0.1.2": mt2l
#import "template.typ": *
#import "template.typ" as native

#let template = mt2l(
  fn: native.template,
  placement: "document",
  latex-template: ```latex
$BODY$
```,
)
#let abstract = mt2l(
  fn: native.abstract, placement: "block",
  latex-template: ```latex
\begin{abstract}
$BODY$
\end{abstract}
```,
)


#let equation = mt2l(
  fn: native.equation, placement: "block", body-format: "math",
  latex-template: ```latex
$if(ARGS.id)$\begin{equation}\label{$RAW.ARGS.id$}$else$\begin{equation*}$endif$
$BODY$
$if(ARGS.id)$\end{equation}$else$\end{equation*}$endif$
```,
)
#let xref = mt2l(
  fn: native.xref, placement: "inline",
  latex-template: ```latex
\cref{$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let citep = mt2l(
  fn: native.citep, placement: "inline",
  latex-template: ```latex
\citep$if(ARGS.supplement)$[{$ARGS.supplement$}]$endif${$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let citet = mt2l(
  fn: native.citet, placement: "inline",
  latex-template: ```latex
\citet$if(ARGS.supplement)$[{$ARGS.supplement$}]$endif${$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let citeauthor = mt2l(
  fn: native.citeauthor, placement: "inline",
  latex-template: ```latex
\citeauthor{$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let citeyear = mt2l(
  fn: native.citeyear, placement: "inline",
  latex-template: ```latex
\citeyear{$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let references = mt2l(
  fn: native.references,
  placement: "block", asset-argument: "path",
  latex-template: ```latex
\bibliographystyle{plainnat}
\bibliography{$PATH$}
```,
)

#let paper-figure = mt2l(
  fn: native.paper-figure, mode: "pdfrender", placement: "block",
  typst-template: ```typst
#set page(width: auto, height: auto, margin: 0pt)
#set text(font: ("STIX Two Text", "Libertinus Serif", "New Computer Modern"), size: 11pt)
$BODY$
```,
  latex-template: ```latex
\begin{figure}[htbp]
\centering
\includegraphics[max width=\linewidth]{$PATH$}
$if(ARGS.caption)$\caption{$ARGS.caption$}$else$\refstepcounter{figure}$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$if(ARGS.note)$\par\smallskip{\footnotesize $ARGS.note$\par}$endif$
\end{figure}
```,
)
#let paper-table = mt2l(
  fn: native.paper-table, placement: "block",
  latex-template: ```latex
\begin{center}
$if(ARGS.caption)$\captionof{table}{$ARGS.caption$}$else$\refstepcounter{table}$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
$if(ARGS.note)$\par\smallskip{\footnotesize $ARGS.note$\par}$endif$
\end{center}
```,
)

#let appendix = mt2l(
  fn: native.appendix, placement: "block",
  latex-template: ```latex
\appendix
\setcounter{theorem}{0}\setcounter{example}{0}
\setcounter{figure}{0}\setcounter{table}{0}\setcounter{equation}{0}
\renewcommand{\thetheorem}{A\arabic{theorem}}
\renewcommand{\theexample}{A\arabic{example}}
\renewcommand{\thefigure}{A\arabic{figure}}
\renewcommand{\thetable}{A\arabic{table}}
\renewcommand{\theequation}{A\arabic{equation}}
$BODY$
```,
)
#let glue = mt2l(
  fn: native.glue, placement: "block",
  latex-template: ```latex
$if(RAW.ARGS.indent)$$if(ARGS.indent)$$else$\noindent $endif$$endif$$BODY$\nopagebreak[4]
```,
)
#let theorem = mt2l(
  fn: native.theorem, placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{theorem}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{theorem}
```,
)
#let proposition = mt2l(
  fn: native.proposition, placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{proposition}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{proposition}
```,
)
#let lemma = mt2l(
  fn: native.lemma, placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{lemma}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{lemma}
```,
)
#let corollary = mt2l(
  fn: native.corollary, placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{corollary}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{corollary}
```,
)
#let conjecture = mt2l(
  fn: native.conjecture, placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{conjecture}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{conjecture}
```,
)
#let definition = mt2l(
  fn: native.definition, placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{definition}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{definition}
```,
)
#let assumption = mt2l(
  fn: native.assumption, placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{assumption}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{assumption}
```,
)
#let example = mt2l(
  fn: native.example, placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{example}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
\begin{mt2lruled}
$BODY$
\end{mt2lruled}
\end{example}
```,
)
#let remark = mt2l(
  fn: native.remark, placement: "block",
  latex-template: ```latex
\begin{remark}$if(ARGS.name)$[{$ARGS.name$}]$endif$
\begin{mt2lruled}
$BODY$
\end{mt2lruled}
\end{remark}
```,
)
#let proof = mt2l(
  fn: native.proof, placement: "block", reference-argument: "depend",
  latex-template: ```latex
\begin{proof}$if(ARGS.name)$[{$ARGS.name$}]$else$$if(ARGS.depend)$[{Proof of $ARGS.depend$}]$endif$$endif$
\begin{mt2lruled}
$BODY$
\hfill\qedhere
\end{mt2lruled}
\end{proof}
```,
)
#let solution = mt2l(
  fn: native.solution, placement: "block",
  latex-template: ```latex
\begin{solution}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$BODY$
\end{solution}
```,
)

#let notation = mt2l(
  fn: native.notation, placement: "block",
  latex-template: ```latex
\begin{notation}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$BODY$
\end{notation}
```,
)

#let link-graph = mt2l(
  fn: native.link-graph, mode: "pdfrender", render-context: "document", placement: "block",
  latex-template: ```latex
\begin{center}
\includegraphics[max width=\linewidth]{$PATH$}
\end{center}
```,
)
