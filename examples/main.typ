#import "../mt2l.typ": mt2l-export-meta
#import "adapters.typ": theorem-mt2l, highlight, disk-mt2l

#mt2l-export-meta(ctx => (
  title: "Un document, deux sorties",
  colorlinks: true,
))

= Conversion modulaire

Ce paragraphe conserve #highlight[son texte en gras], puis
#highlight[un deuxième appel], avec un dessin Typst
#disk-mt2l(radius: 5pt, fill: blue).

#theorem-mt2l(
  name: [Un exemple avec $n$],
  mt2l_variables: (label: "thm:exemple_modulaire",),
)[
  Pour tout entier $n$, on a $n + 0 = n$.
  Le corps accepte aussi #highlight[un adaptateur imbriqué].
]

- Une liste peut contenir #highlight[un appel en ligne].
- Les fonctions sont déclarées dans un module séparé.
