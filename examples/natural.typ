#import "@local/mt2l:0.1.2": paper, abstract, theorem, lemma, proposition, proof, link-graph, appendix
#show: paper.with(title: "Natural Typst notation", authors: ("Your Name",))

#abstract[Write ordinary Typst labels, equations, and citations.]

= Introduction <sec:intro>

Previous work @knuth1984 and @knuth1984[p. 2].
#cite(<knuth1984>, form: "prose", supplement: [p. 3]) discusses typesetting.
See @thm:main, @prop:binary, @eq:3 and @sec:intro.

#lemma[For all real $x$, $x^2 >= 0$.]<lem:base>

#theorem(depend: <lem:base>)[Use @lem:base to bound the square.]<thm:main>

#proof(depend: <thm:main>)[Apply @lem:base.]

$ x ∈ {0,1} $<eq:3>

$ y = x^2 $

$ z = y $ <eq:second>

#proposition(depend: <thm:main>)[The value in @eq:3 is binary.]<prop:binary>

#proof(depend: <prop:binary>)[Use the two values.]

#link-graph()

#bibliography("paper.bib")

#appendix[
  = Extra result <sec:appendix>

  #lemma(depend: <thm:main>)[An auxiliary fact.]<lem:extra>

  $ q = 1 $<eq:extra>

  See @lem:extra and @eq:extra.
]
