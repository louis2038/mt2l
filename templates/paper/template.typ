// Native Typst functions and style. Edit this file to customize the PDF.
// Generic title and export metadata; styling belongs to template files.
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

#let abstract-layout(body) = block(width: 100%, above: 0.5em, below: 2em, inset: (x: 1.4em))[
  #set par(first-line-indent: 0pt)
  #align(center, strong[Abstract])
  #v(0.5em)
  #body
]

#let equation-layout(id: none, body) = context [
  #math.equation(block: true, numbering: if id == none { none } else if state("mt2l-paper-appendix", false).get() { n => "(A" + str(n) + ")" } else { "(1)" }, body)
  #if id != none { label(id) }
]

#let paper-figure-layout(caption: none, id: none, note: none, body) = [
  #figure(kind: image, caption: caption, body)
  #if id != none { label(id) }
  #if note != none { block(text(size: 0.85em, note)) }
]

#let paper-table-layout(caption: none, id: none, note: none, body) = [
  #figure(kind: table, caption: caption, body)
  #if id != none { label(id) }
  #if note != none { block(text(size: 0.85em, note)) }
]

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

#let dependency-ids(depend) = {
  if depend == none { return () }
  let values = if type(depend) == array { depend } else { (depend,) }
  let ids = ()
  for value in values {
    assert(type(value) in (str, label), message: "depend expects an ID, a label, or an array of them")
    let id = str(value)
    assert(id != "", message: "dependency IDs cannot be empty")
    if not ids.contains(id) { ids.push(id) }
  }
  ids
}

// Return a native figure so a trailing <label> attaches to the statement.
// The paper's show rules supply its appearance and dependency metadata.

#let statement(kind, italic: true, example: false, numbered: true, ruled: false, qed: false) = {
  (name: none, id: none, depend: none, breakable: true, body) => {
    let config = (kind: kind, italic: italic, numbered: numbered, ruled: ruled,
      qed: qed, name: name, depend: dependency-ids(depend), breakable: breakable, body: body)
    let track = if example { "mt2l-example" } else { "mt2l-statement" }
    let item = if numbered {
      figure(kind: track, supplement: kind, outlined: false, metadata(config))
    } else {
      figure(kind: track, supplement: kind, numbering: none, outlined: false, metadata(config))
    }
    if id == none { item } else { [#item#label(str(id))] }
  }
}


#let statement-render(it) = context {
  let config = it.body.value
  let id = if it.has("label") { str(it.label) } else { none }
  assert(config.numbered or id == none, message: "unnumbered statements cannot have a label; label the result instead")
  if not config.qed and config.depend.len() > 0 {
    assert(id != none, message: "a statement with depend needs an id or a trailing label")
    assert(not config.depend.contains(id), message: "a statement cannot depend on itself: " + id)
  }
  let title = if config.qed {
    emph(if config.name != none { config.name } else if config.depend.len() > 0 {
      [Proof of #config.depend.map(id => ref(label(id))).join([ and ])]
    } else { [Proof] })
  } else if not config.numbered {
    strong(emph([#config.kind#if config.name != none { [ (#config.name)] }]))
  } else {
    smallcaps(strong([#config.kind #counter(figure.where(kind: it.kind)).display(it.numbering, at: it.location())#if config.name != none { [ (#config.name)] }]))
  }
  let content = [
    #if config.italic { emph(config.body) } else { config.body }
    #if config.qed { h(1fr); box[$square$] }
  ]
  if id != none {
    [#metadata((id: id, kind: config.kind, depend: config.depend)) <mt2l-statement-node>]
  }
  set align(start)
  block(width: 100%, breakable: config.breakable, above: 0.8em, below: 0.8em)[
    #set par(first-line-indent: 0pt)
    #if config.ruled {
      block(width: 100%, sticky: true, above: 0pt, below: 0.3em)[#title.]
      block(width: 100%, breakable: config.breakable, above: 0pt, below: 0pt,
        inset: (left: 0.65em, top: 0.12em), stroke: (left: 0.6pt + gray), content)
    } else {
      [#title.#h(0.3em)#content]
    }
  ]
}


#let dependency-graph-data() = {
  let nodes = query(<mt2l-statement-node>).map(it => it.value)
  let ids = nodes.map(it => it.id)
  assert(ids.dedup().len() == ids.len(), message: "statement IDs must be unique")
  for node in nodes {
    for prerequisite in node.depend {
      assert(ids.contains(prerequisite), message: "unknown dependency " + prerequisite + " for " + node.id)
    }
  }
  // Topological validation rejects cycles before handing the graph to dot.
  let pending = nodes
  let resolved = ()
  while pending.len() > 0 {
    let ready = pending.filter(node => node.depend.all(id => resolved.contains(id)))
    assert(ready.len() > 0, message: "cyclic statement dependencies: " + pending.map(it => it.id).join(", "))
    let ready-ids = ready.map(it => it.id)
    resolved += ready-ids
    pending = pending.filter(node => not ready-ids.contains(node.id))
  }
  nodes
}


#let link-graph-layout(scale-factor: 85%) = context {
  // Import only when a graph is requested; normal papers need no graph package.
  import "@preview/autograph:0.1.0" as autograph
  import "@preview/fletcher:0.5.8": shapes
  let nodes = dependency-graph-data()
  if nodes.len() == 0 { return [No identified statements.] }
  let node-elements = nodes.map(node => autograph.node(
    label(node.id), ref(label(node.id)), shape: shapes.rect,
    stroke: 0.8pt + rgb("6a1b9a"), fill: rgb("f3e5f5"), inset: 0.45em,
  ))
  let edges = ()
  for node in nodes {
    for prerequisite in node.depend {
      edges.push(autograph.edge(label(prerequisite), label(node.id),
        stroke: 0.8pt + black, mark: (end: ">", fill: black, scale: 0.7)))
    }
  }
  align(center, scale(scale-factor, reflow: true, autograph.diagram(
    engine: "dot", bezier: true, node-stroke: black, node-fill: white,
    ..node-elements, ..edges,
  )))
}



#let paper-style(paper-size: "a4", font-size: 11pt, ..args) = {
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
  paper-layout(paper-size: paper-size, font-size: font-size, ..args)
}



#let template = paper-style
#let abstract = abstract-layout
#let equation = equation-layout
#let xref = id => ref(label(id))
#let citep = (key, supplement: none) => cite(label(key), supplement: supplement, form: "normal")
#let citet = (key, supplement: none) => cite(label(key), supplement: supplement, form: "prose")
#let citeauthor = key => cite(label(key), form: "author")
#let citeyear = key => cite(label(key), form: "year")
#let references = (path: none) => bibliography(path, title: [References], style: "chicago-author-date")
#let paper-figure = paper-figure-layout
#let paper-table = paper-table-layout
#let appendix = appendix-layout
#let glue = (indent: true, body) => block(sticky: true)[#if indent { h(1.4em) }#body]
#let theorem = statement("Theorem")
#let proposition = statement("Proposition")
#let lemma = statement("Lemma")
#let corollary = statement("Corollary")
#let conjecture = statement("Conjecture")
#let definition = statement("Definition", italic: false)
#let assumption = statement("Assumption")
#let example = statement("Example", italic: false, example: true, ruled: true)
#let remark = statement("Remark", italic: false, numbered: false, ruled: true)
#let proof = statement("Proof", italic: false, numbered: false, ruled: true, qed: true)
#let solution = statement("Solution", italic: false, numbered: false)
#let notation = statement("Notation", italic: false, numbered: false)
#let link-graph = link-graph-layout
