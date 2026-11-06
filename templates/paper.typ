// Paper typography inspired by the supplied Typst manuscript and by
// pmichaillat/latex-paper. Keep the public bindings literal for mt2l discovery.
#import "../core.typ": mt2l
#import "statements.typ": statement-render

#let paper-layout(
  title: "Untitled paper",
  authors: (),
  affiliations: (),
  date: "",
  keywords: (),
  url: "",
  acknowledgements: "",
  paper-size: "a4",
  font-size: 11pt,
  body,
) = {
  assert(type(title) == str, message: "paper title must be a string")
  assert(type(authors) == array, message: "paper authors must be an array of strings")
  assert(type(affiliations) == array, message: "paper affiliations must be an array of strings")
  assert(type(keywords) == array, message: "paper keywords must be an array of strings")
  assert(paper-size in ("a4", "us-letter"), message: "paper-size must be a4 or us-letter")
  assert(font-size in (10pt, 11pt, 12pt), message: "font-size must be 10pt, 11pt, or 12pt")
  set document(title: title, author: authors)
  set page(
    paper: paper-size,
    margin: (x: 16.3%, top: 25.4mm, bottom: 30.5mm),
    numbering: "1",
    number-align: center,
  )
  set text(font: ("STIX Two Text", "Libertinus Serif", "New Computer Modern"), size: font-size, lang: "en")
  show math.equation: set text(font: ("STIX Two Math", "New Computer Modern Math"))
  set par(justify: true, first-line-indent: 1.4em, leading: 0.65em, spacing: 0.55em)
  set heading(numbering: "1.1")
  show heading: set text(hyphenate: false)
  show heading.where(level: 1): it => block(width: 100%, above: 1.8em, below: 1em, sticky: true)[
    #align(center, text(size: 1.2em, weight: "bold")[
      #if it.numbering != none { [#counter(heading).display(it.numbering). ] }#it.body
    ])
  ]
  show heading.where(level: 2): set text(size: 1em, weight: "bold")
  show heading.where(level: 3): set text(size: 1em, style: "italic", weight: "regular")
  set enum(indent: 1.4em, numbering: "1.")
  set list(indent: 1.4em)
  set terms(hanging-indent: 1.4em)
  show figure.where(kind: "mt2l-statement"): statement-render
  show figure.where(kind: "mt2l-example"): statement-render
  // Native labeled displays are numbered. Unlabeled displays use no counter.
  set math.equation(numbering: "(1)")
  show math.equation.where(block: true): it => {
    if it.has("label") or it.numbering == none { it } else {
      counter(math.equation).update(n => n - 1)
      math.equation(it.body, block: true, numbering: none)
    }
  }
  show math.equation.where(block: true): set block(breakable: true)
  show math.equation.where(block: false): it => box(it)
  show ref: set text(fill: rgb("2459a6"))
  show link: set text(fill: rgb("2459a6"))
  set cite(style: "chicago-author-date")
  set bibliography(style: "chicago-author-date")
  show figure.where(kind: table): set figure.caption(position: top)
  set figure.caption(separator: [. #h(0.5em)])
  // Metadata is resolved by native Typst before the exporter reads any prose.
  [#metadata((
    mt2l-paper: true,
    paper: (
      title: title, authors: authors, affiliations: affiliations, date: date,
      keywords: keywords, url: url, acknowledgements: acknowledgements,
      size: if paper-size == "a4" { "a4paper" } else { "letterpaper" },
      fontsize: repr(font-size),
    ),
  )) <mt2l-meta>]
  block(width: 100%, above: 1em, below: 2em)[
    #set par(first-line-indent: 0pt, justify: false)
    #align(center)[
      #text(size: 2em, weight: "bold", title)
      #v(1.1em)
      #authors.join([#h(1.2em)])
      #if affiliations.len() > 0 { v(0.5em); text(size: 0.9em, affiliations.join(linebreak())) }
      #if date != "" { v(0.7em); date }
      #if url != "" { v(0.5em); text(size: 0.8em, link(url)) }
    ]
    #if acknowledgements != "" { v(0.8em); text(size: 0.85em, acknowledgements) }
    #if keywords.len() > 0 { v(0.8em); text(size: 0.9em)[*Keywords:* #keywords.join(", ")] }
  ]
  body
}

#let paper = mt2l(
  fn: paper-layout,
  placement: "document",
  latex-template: ```latex
$BODY$
```,
)

#let abstract-layout(body) = block(width: 100%, above: 0.5em, below: 2em, inset: (x: 1.4em))[
  #set par(first-line-indent: 0pt)
  #align(center, strong[Abstract])
  #v(0.5em)
  #body
]
#let abstract = mt2l(
  fn: abstract-layout, placement: "block",
  latex-template: ```latex
\begin{abstract}
$BODY$
\end{abstract}
```,
)

#import "statements.typ": theorem, proposition, lemma, corollary, conjecture, definition, assumption, example, remark, proof, solution, notation, link-graph

#let equation-layout(id: none, body) = context [
  #math.equation(block: true, numbering: if id == none { none } else if state("mt2l-paper-appendix", false).get() { n => "(A" + str(n) + ")" } else { "(1)" }, body)
  #if id != none { label(id) }
]
#let equation = mt2l(
  fn: equation-layout, placement: "block", body-format: "math",
  latex-template: ```latex
$if(ARGS.id)$\begin{equation}\label{$RAW.ARGS.id$}$else$\begin{equation*}$endif$
$BODY$
$if(ARGS.id)$\end{equation}$else$\end{equation*}$endif$
```,
)
#let xref = mt2l(
  fn: id => ref(label(id)), placement: "inline",
  latex-template: ```latex
\cref{$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let citep = mt2l(
  fn: (key, supplement: none) => cite(label(key), supplement: supplement, form: "normal"), placement: "inline",
  latex-template: ```latex
\citep$if(ARGS.supplement)$[{$ARGS.supplement$}]$endif${$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let citet = mt2l(
  fn: (key, supplement: none) => cite(label(key), supplement: supplement, form: "prose"), placement: "inline",
  latex-template: ```latex
\citet$if(ARGS.supplement)$[{$ARGS.supplement$}]$endif${$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let citeauthor = mt2l(
  fn: key => cite(label(key), form: "author"), placement: "inline",
  latex-template: ```latex
\citeauthor{$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let citeyear = mt2l(
  fn: key => cite(label(key), form: "year"), placement: "inline",
  latex-template: ```latex
\citeyear{$for(RAW.ARGS.pos)$$RAW.ARGS.pos$$endfor$}
```,
)
#let references = mt2l(
  fn: (path: none) => bibliography(path, title: [References], style: "chicago-author-date"),
  placement: "block", asset-argument: "path",
  latex-template: ```latex
\bibliographystyle{plainnat}
\bibliography{$PATH$}
```,
)

#let paper-figure-layout(caption: none, id: none, note: none, body) = [
  #figure(kind: image, caption: caption, body)
  #if id != none { label(id) }
  #if note != none { block(text(size: 0.85em, note)) }
]
#let paper-figure = mt2l(
  fn: paper-figure-layout, mode: "pdfrender", placement: "block",
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
#let paper-table-layout(caption: none, id: none, note: none, body) = [
  #figure(kind: table, caption: caption, body)
  #if id != none { label(id) }
  #if note != none { block(text(size: 0.85em, note)) }
]
#let paper-table = mt2l(
  fn: paper-table-layout, placement: "block",
  latex-template: ```latex
\begin{center}
$if(ARGS.caption)$\captionof{table}{$ARGS.caption$}$else$\refstepcounter{table}$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
$if(ARGS.note)$\par\smallskip{\footnotesize $ARGS.note$\par}$endif$
\end{center}
```,
)

#let appendix-layout(body) = {
  state("mt2l-paper-appendix", false).update(true)
  counter(heading).update(0)
  counter(math.equation).update(0)
  counter(figure.where(kind: "mt2l-statement")).update(0)
  counter(figure.where(kind: "mt2l-example")).update(0)
  counter(figure.where(kind: image)).update(0)
  counter(figure.where(kind: table)).update(0)
  set heading(numbering: "A.1")
  set math.equation(numbering: n => "(A" + str(n) + ")")
  set figure(numbering: n => "A" + str(n))
  body
}
#let appendix = mt2l(
  fn: appendix-layout, placement: "block",
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
  fn: (indent: true, body) => block(sticky: true)[#if indent { h(1.4em) }#body], placement: "block",
  latex-template: ```latex
$if(RAW.ARGS.indent)$$if(ARGS.indent)$$else$\noindent $endif$$endif$$BODY$\nopagebreak[4]
```,
)
