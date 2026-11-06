// Minimal native Typst template. Add your set and show rules here.
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

#let template = paper-layout
