// Identified statements carry document metadata so queries include forward
// dependencies and work regardless of where the graph is displayed.
#import "../core.typ": mt2l

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

#let theorem = mt2l(
  fn: statement("Theorem"), placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{theorem}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{theorem}
```,
)
#let proposition = mt2l(
  fn: statement("Proposition"), placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{proposition}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{proposition}
```,
)
#let lemma = mt2l(
  fn: statement("Lemma"), placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{lemma}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{lemma}
```,
)
#let corollary = mt2l(
  fn: statement("Corollary"), placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{corollary}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{corollary}
```,
)
#let conjecture = mt2l(
  fn: statement("Conjecture"), placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{conjecture}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{conjecture}
```,
)
#let definition = mt2l(
  fn: statement("Definition", italic: false), placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{definition}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{definition}
```,
)
#let assumption = mt2l(
  fn: statement("Assumption"), placement: "block",
  label-argument: "id",
  latex-template: ```latex
\begin{assumption}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$if(ARGS.id)$\label{$RAW.ARGS.id$}$endif$
$BODY$
\end{assumption}
```,
)
#let example = mt2l(
  fn: statement("Example", italic: false, example: true, ruled: true), placement: "block",
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
  fn: statement("Remark", italic: false, numbered: false, ruled: true), placement: "block",
  latex-template: ```latex
\begin{remark}$if(ARGS.name)$[{$ARGS.name$}]$endif$
\begin{mt2lruled}
$BODY$
\end{mt2lruled}
\end{remark}
```,
)
#let proof = mt2l(
  fn: statement("Proof", italic: false, numbered: false, ruled: true, qed: true), placement: "block", reference-argument: "depend",
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
  fn: statement("Solution", italic: false, numbered: false), placement: "block",
  latex-template: ```latex
\begin{solution}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$BODY$
\end{solution}
```,
)

#let notation = mt2l(
  fn: statement("Notation", italic: false, numbered: false), placement: "block",
  latex-template: ```latex
\begin{notation}$if(ARGS.name)$[{$ARGS.name$}]$endif$
$BODY$
\end{notation}
```,
)

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

#let link-graph = mt2l(
  fn: link-graph-layout, mode: "pdfrender", render-context: "document", placement: "block",
  latex-template: ```latex
\begin{center}
\includegraphics[max width=\linewidth]{$PATH$}
\end{center}
```,
)
