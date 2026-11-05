# mt2l — Typst → LaTeX, avec des contrats dans Typst

Écris ton document en Typst et décris l'export des fonctions personnalisées
avec `mt2l(...)`. La compilation Typst normale appelle la fonction d'origine.
À l'export, le moteur Lua/Pandoc applique son contrat :

- `syntax` produit du LaTeX éditable à partir d'un template ;
- `pdfrender` compile un fragment avec Typst et inclut son PDF dans le LaTeX.

## Démarrage

Installe le CLI et le package local sans sudo, depuis une version précise :

```sh
curl -fsSL https://raw.githubusercontent.com/louis2038/mt2l/v0.1.0/get.sh | bash
```

Le lanceur télécharge l'archive du tag `v0.1.0` depuis GitHub, puis exécute
l'installateur. Il faut Bash, curl et tar. Cette URL nécessite que le tag
soit publié dans le [dépôt GitHub](https://github.com/louis2038/mt2l).

Depuis le repo, une seule commande installe le package et le CLI pour ton
utilisateur, **sans sudo** :

```sh
./install.sh
```

L'installateur vérifie les dépendances avant de copier les fichiers. S'il
manque Pandoc, il affiche les liens officiels et la commande pour extraire
l'archive Linux dans `~/.local`, sans sudo. Il indique aussi la commande du
gestionnaire de paquets disponible. L'installateur local ne télécharge rien, ne lance jamais
`sudo` et ne modifie pas tes fichiers de configuration du shell.

Prérequis : **Typst >= 0.15** et **Pandoc >= 3.7** dans le `PATH`.
Ces versions correspondent à la base prise en charge par le moteur.
Pour installer Pandoc : [instructions officielles](https://pandoc.org/installing.html)
et [archives officielles](https://github.com/jgm/pandoc/releases/latest).
Pour compiler le LaTeX
produit : une installation LaTeX avec `pdflatex`. Vérifié avec Typst 0.15.0,
Pandoc 3.7.0.2 et TeX Live 2026.

Dans n'importe quel document, importe ensuite :

```typst
#import "@local/mt2l:0.1.0": mt2l, mt2l-export-meta
```

Après acceptation du package sur Typst Universe, l'import public sera :

```typst
#import "@preview/mt2l:0.1.0": mt2l, mt2l-export-meta
```

Le CLI accepte les deux espaces de noms. La publication sur Universe est
indépendante de l'installation du CLI. Voir les
[instructions de publication](docs/PUBLISHING.md) et la
[documentation destinée à Universe](docs/universe.md).

Déclare tes adaptateurs avec `mt2l(...)` comme dans les exemples ci-dessous,
puis exporte depuis le terminal :

```sh
mt2l main.typ
mt2l main.typ build/article.tex
mt2l --version
```

Un exemple complet utilisant le package est fourni dans `examples/package.typ`.
Après installation, depuis le repo :

```sh
mt2l examples/package.typ build/package.tex
typst compile examples/package.typ build/package-typst.pdf
```

Sur Linux, les fichiers sont installés dans :

- `~/.local/share/typst/packages/local/mt2l/0.1.0/` : manifeste, code Typst,
  moteur Lua, templates et exemples ;
- `~/.local/bin/mt2l` : lanceur du moteur installé.

Le package, l'API Typst et la commande s'appellent tous `mt2l`.
Lors de la migration, l'installateur retire l'ancien package et l'ancien
lanceur `t2l` uniquement s'ils avaient été créés par cet installateur.
Les anciens documents doivent utiliser le nouvel import et les noms
`mt2l`, `mt2l-export-meta` et `mt2l_variables`.

Le CLI ne dépend plus de l'emplacement du repo. L'import Typst fournit les
fonctions ; la commande extérieure `mt2l` lance Typst et Pandoc pour l'export.
Le compilateur Typst n'exécute pas les scripts contenus dans le package.

L'installation peut être relancée pour mettre à jour la même version.
Un fichier ou package existant non créé par cet installateur est préservé.
Le moteur refuse un import de `@local/mt2l` dont la version diffère de la sienne.

Si `~/.local/bin` n'est pas dans le `PATH`, le script indique la ligne à
exécuter dans le terminal. Il détecte aussi si un autre programme nommé `mt2l`
passe avant celui installé : tu peux alors utiliser `~/.local/bin/mt2l`
directement ou mettre ce dossier en premier avec
`export PATH="$HOME/.local/bin:$PATH"`.
Pour conserver ce réglage, ajoute-le à la configuration
de ton shell. `XDG_DATA_HOME` et `TYPST_PACKAGE_PATH` sont respectés ;
`MT2L_BIN_DIR` permet de choisir le dossier du lanceur. Sur macOS, le dossier
de données par défaut est `~/Library/Application Support`. L'installateur
nécessite Bash et les outils usuels de Linux/macOS.

Pour travailler directement depuis les sources sans installer le CLI :

```sh
./scripts/convert.sh --root . examples/main.typ build/example.tex
cd build
pdflatex -interaction=nonstopmode -halt-on-error example.tex
```

Pour obtenir le PDF Typst du même document :

```sh
typst compile --root . examples/main.typ build/example-typst.pdf
```

L'exemple `examples/packages.typ` utilise CeTZ et Pavemat. Les packages Typst doivent
être présents dans le cache local ou téléchargeables lors du premier usage.
L'ancienne commande reste disponible :

```sh
./scripts/convert-test.sh examples/packages.typ build/test.tex
```

`convert.sh` accepte `--root DIR`, `--template FILE`, puis `INPUT [OUTPUT]`.
La racine vaut par défaut le dossier du document ; fournis `--root` pour
autoriser des imports dans ses dossiers parents. La sortie par défaut porte
le même nom que l'entrée avec l'extension `.tex`. Les dossiers de sortie sont
créés automatiquement. Compile le LaTeX depuis son dossier de sortie afin de
retrouver les PDF dans le sous-dossier `*-assets`.

## Un adaptateur réutilisable

Dans un module `adapters.typ` à côté de `mt2l.typ` :

````typst
#import "mt2l.typ": mt2l

#let highlight = mt2l(
  fn: strong,
  placement: "inline",
  latex-template: ```latex
\textbf{$BODY$}
```,
)
````

Puis, dans le document :

```typst
#import "adapters.typ": highlight
Avant #highlight[un passage] après.
```

Les imports locaux sélectifs, `*`, les alias et les espaces de noms sont pris
en charge, ainsi que la réexportation des adaptateurs importés. Par exemple :

```typst
#import "adapters.typ": highlight as emphasis
#import "adapters.typ" as adapters
#emphasis[Premier] et #adapters.highlight[deuxième].
```

Les contrats sont découverts à partir des imports, sans ajouter de marqueurs
dans le document Typst normal. Voir `examples/adapters.typ` pour un théorème
avec son préambule LaTeX et un dessin exporté en PDF.

## Options d'un contrat

| Option | Effet |
| --- | --- |
| `fn` | Fonction Typst d'origine, obligatoire. |
| `mode` | `"syntax"` par défaut, ou `"pdfrender"`. |
| `placement` | `"auto"` par défaut, `"inline"` ou `"block"`. |
| `latex-template` | Bloc brut contenant un template Pandoc, obligatoire. |
| `typst-template` | Document Typst à compiler, obligatoire en `pdfrender`. |
| `typst-preamble` | Source Typst littérale ajoutée aux conversions isolées. |
| `latex-preamble` | Définitions LaTeX ajoutées une seule fois au document. |

`auto` produit un bloc lorsque l'appel occupe seul un paragraphe, sinon du
contenu en ligne. Déclare les environnements LaTeX tels que `figure` ou un
théorème en `block` : un appel au milieu d'une phrase ou d'une équation est
alors refusé avec une erreur. `inline` convient aux commandes comme
`\textbf` et aux graphiques intégrés au texte ou aux mathématiques.

## Variables des templates

Les templates utilisent la syntaxe Pandoc : `$BODY$`, `$if(LOCAL.caption)$`,
`$for(ARGS.pos)$`, etc. Les templates doivent être des blocs bruts clôturés
par au moins trois accents graves.

| Variable | Dans `latex-template` |
| --- | --- |
| `BODY` | Corps `[...]` converti récursivement en LaTeX. |
| `ARGS.nom` | Argument nommé ; les chaînes sont échappées pour LaTeX. |
| `ARGS.pos` | Liste des arguments positionnels. |
| `LOCAL.nom` | Métadonnée locale de `mt2l_variables`, avec les mêmes règles. |
| `RAW.ARGS.nom`, `RAW.LOCAL.nom` | Valeur source non échappée ; les guillemets des chaînes sont retirés. |
| `RAW.BODY` | Source originale du corps. |
| `PATH` | Chemin relatif du PDF généré, en `pdfrender`. |
| `TARGET` | Nom de la fonction `fn`. |

`false` et `none` sont faux dans les conditions ; `true` est vrai. Les contenus
`[...]` sont convertis en LaTeX. Utilise la variante `RAW` volontairement pour
les identifiants, par exemple `\label{$RAW.LOCAL.label$}`, ou pour injecter du
LaTeX déjà écrit. Elle n'applique aucun échappement.

Dans `typst-template`, `ARGS`, `LOCAL` et `BODY` contiennent leur **source
Typst**, et `$HERE$` est l'appel complet de `fn`, sans `mt2l_variables`.
`$MODULE$` contient le chemin du dossier de l'adaptateur depuis la racine
Typst : utilise par exemple `#image("$MODULE$/schema.svg")` pour une ressource
placée à côté du module. À la racine, `MODULE` est vide. Les autres chemins
relatifs du fragment se résolvent depuis la racine du projet.

Un dollar littéral dans un template Pandoc s'écrit `$$`. Cette règle ne
s'applique pas à `typst-preamble`, qui reste du source littéral.

Les namespaces globaux `ARGS`, `LOCAL`, `RAW`, `BODY`, `PATH`, `TARGET`, `HERE`
et `MODULE` sont réservés aux contrats.

## Contexte et préambules

Chaque corps `syntax` est interprété isolément par le lecteur Typst de Pandoc.
Chaque PDF est compilé dans un document Typst séparé. Les variables, imports
et réglages du document principal ne sont donc pas automatiquement hérités.
Fournis les définitions nécessaires explicitement :

````typst
typst-preamble: ```typst
#let couleur = blue
```,
````

Ce préambule est ajouté au début du fragment PDF, et avant chaque contenu
interprété par Pandoc. Il doit contenir des définitions plutôt que du contenu
à afficher. Les imports locaux de ce préambule peuvent utiliser des chemins
absolus **Typst**, relatifs à la racine, comme `#import "/lib/tools.typ": *`.

En `pdfrender`, un corps utilisé uniquement pour générer le PDF n'est pas
interprété par Pandoc : des constructions Typst complexes peuvent rester
entièrement dans le fragment graphique.

`latex-preamble` peut déclarer les packages, macros et environnements requis
par l'adaptateur. Les fragments identiques sont dédupliqués, dans l'ordre de
leur première utilisation. Un template de document personnalisé doit contenir :

```latex
$for(header-includes)$
$header-includes$
$endfor$
```

`mt2l-export-meta` conserve son usage : une fonction reçoit `text-size`,
`page-width` et `page-height` résolus à son emplacement et renvoie un
dictionnaire sérialisable en JSON. Un seul export global est autorisé.
Ses valeurs deviennent les variables du template extérieur et des contrats.

## Vérification et limites

```sh
python -m unittest discover -s tests -v
python scripts/test_install.py
python scripts/test_release.py
python scripts/package.py
```

Les tests couvrent les paragraphes, appels multiples et imbriqués, listes,
cellules de tableaux, mathématiques, commentaires et blocs bruts, imports,
échappement, booléens, contexte explicite et compilation de vrais PDF.

Les contrats doivent être déclarés sous la forme `#let nom = mt2l(...)`, avec
des options littérales, et appelés explicitement par `#nom(...)` ou
`#nom[...]`. Les fabriques de contrats dynamiques, les appels indirects ou
sans `#` à l'intérieur du code Typst ne sont pas interceptés. Les imports
doivent utiliser des chemins littéraux ; la découverte automatique des
contrats dans les packages `@preview` n'est pas implémentée.
Le package `@local/mt2l` fournit l'API ; les adaptateurs peuvent être déclarés
dans le document ou dans des modules locaux. La découverte des adaptateurs
déclarés dans d'autres packages installés n'est pas encore implémentée.

Le mode `syntax` reste limité aux constructions comprises par le lecteur
Typst de Pandoc. Un préambule explicite aide à fournir des définitions ; le
mode `pdfrender` permet de conserver les éléments graphiques plus complexes.

Les PDF sont recompilés à chaque export pour prendre en compte les changements
des ressources importées. Leurs noms dépendent du fragment généré. Le moteur
ne remplace un PDF et le fichier `.tex` final qu'après leur génération réussie.
Les anciennes ressources ne sont pas supprimées automatiquement.

## Licence

MIT, Copyright (c) 2026 louis2038. Voir [LICENSE](LICENSE).
