"""End-to-end regressions: valid Typst documents, exported TeX, and real PDFs.

Run with: python -m unittest discover -s tests -v
Only the Python standard library, Typst, Pandoc and pdflatex are required.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PRELUDE = '''#import "mt2l.typ": mt2l, mt2l-export-meta
#let echo(body) = body
#let box = mt2l(fn: echo, latex-template: ```latex
\\textbf{$BODY$}
```)
'''


class ConversionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mt2l-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copy(ROOT / "mt2l.typ", self.root / "mt2l.typ")

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def run_command(self, command, *, cwd=None, success=True):
        result = subprocess.run([str(arg) for arg in command], cwd=cwd or self.root,
                                capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def convert(self, source, *, native=True, success=True, name="main.typ"):
        path = self.write(name, source)
        if native:
            self.run_command(["typst", "compile", "--root", self.root, path,
                              self.root / "native.pdf"])
        output = self.root / "output" / "document.tex"
        result = self.run_command(["bash", ROOT / "scripts/convert.sh", "--root", self.root,
                                   path, output], success=success)
        if not success:
            return result
        tex = output.read_text()
        self.assertNotRegex(tex, r"MT2L[0-9a-f]{12}X\d+END")
        return tex

    @staticmethod
    def body(tex):
        return tex.split(r"\begin{document}", 1)[1].split(r"\end{document}", 1)[0].strip()

    def compile_latex(self, output=None):
        output = output or self.root / "output" / "document.tex"
        self.run_command(["pdflatex", "-interaction=nonstopmode", "-halt-on-error", output.name],
                         cwd=output.parent)
        self.assertTrue(output.with_suffix(".pdf").is_file())

    def test_inline_surrounding_text_and_multiple_calls(self):
        tex = self.convert(PRELUDE + "Avant #box()[premier] entre #box()[second] après.\n")
        self.assertEqual(self.body(tex), r"Avant \textbf{premier} entre \textbf{second} après.")
        self.compile_latex()

    def test_nested_containers_and_table_cells(self):
        tex = self.convert(PRELUDE + '''- Avant #box()[élément] après.
  - #box()[imbriqué]

#table(columns: 2, [Cellule #box()[gauche]], [#box()[droite]])
''')
        for text in [r"Avant \textbf{élément} après.", r"\textbf{imbriqué}",
                     r"\textbf{gauche}", r"\textbf{droite}"]:
            self.assertIn(text, tex)

    def test_nested_contracts_and_shorthand(self):
        tex = self.convert(PRELUDE + "#box[Extérieur #box()[Intérieur]]\n")
        self.assertEqual(self.body(tex), r"\textbf{Extérieur \textbf{Intérieur}}")

    def test_math_retains_display_and_inline_modes(self):
        tex = self.convert('''#import "mt2l.typ": mt2l
#let scalar() = $x$
#let exported = mt2l(fn: scalar, latex-template: ```latex
x
```)
$ y = #exported() $

En ligne : $y = #exported()$.
''')
        self.assertIn(r"\[y = x\]", tex)
        self.assertIn(r"\(y = x\)", tex)
        self.compile_latex()

    def test_comments_delimiters_and_raw_examples(self):
        tex = self.convert(PRELUDE + '''// #box()[ignoré]
/* Outer /* #box()[ignoré] */ comment */
#box()[
  // ] , ) } ignored delimiters
  Texte.
]

````typst
#box()[exemple]
```nested fence```
````

`#box()[exemple court]`
''')
        self.assertIn(r"\textbf{Texte.}", tex)
        self.assertNotIn("ignoré", tex)
        self.assertIn("exemple", tex)
        self.compile_latex()

    def test_commented_arguments(self):
        tex = self.convert('''#import "mt2l.typ": mt2l
#let named(name: none) = name
#let exported = mt2l(fn: named, latex-template: ```latex
$ARGS.name$
```)
#exported(
  // Comment with commas: , , and brackets: ) ]
  name: [Contenu], /* nested /* , */ comment */
)
''')
        self.assertEqual(self.body(tex), "Contenu")

    def test_prose_quotes_parentheses_and_code_strings(self):
        tex = self.convert(PRELUDE + '''Une mesure de 5".

#box()[Texte (avec une parenthèse ouverte et un "guillemet.]

Une citation "avec #box()[un appel] dedans".

#text("Littéral #box()[exemple]")

#text([Conteneur #box()[imbriqué]])
''')
        self.assertIn(r"\textbf{Texte (avec une parenthèse ouverte", tex)
        self.assertIn(r"\textbf{un appel}", tex)
        self.assertNotIn(r"\textbf{exemple}", tex)
        self.assertIn(r"\textbf{imbriqué}", tex)
        self.compile_latex()

    def test_automatic_links_do_not_start_comments(self):
        tex = self.convert(PRELUDE + '''https://example.org #box()[après le lien]

#box()[Avant https://example.org et après.]
''')
        self.assertIn(r"\textbf{après le lien}", tex)
        self.assertIn(r"\url{https://example.org}", tex)
        self.assertIn("et après.", tex)

    def test_strings_are_escaped_and_raw_is_explicit(self):
        tex = self.convert('''#import "mt2l.typ": mt2l
#let named(name: none, id: none) = name
#let exported = mt2l(fn: named, latex-template: ```latex
\\textbf{$ARGS.name$}\\label{$RAW.ARGS.id$}
```)
#exported(name: "A & B_100% # {C}", id: "test_label")
''')
        self.assertIn(r"\textbf{A \& B\_100\% \# \{C\}}\label{test_label}", tex)
        self.compile_latex()

    def test_unicode_string_escape(self):
        tex = self.convert(PRELUDE.replace("$BODY$", "$ARGS.name$") + '''
#let named(name: none) = name
#let exported = mt2l(fn: named, latex-template: ```latex
$ARGS.name$
```)
#exported(name: "A\\u{e9}B")
''')
        self.assertIn("AéB", tex)

    def test_local_boolean_and_none_values(self):
        tex = self.convert(PRELUDE.replace("$BODY$", "$if(LOCAL.visible)$OUI$else$NON$endif$") + '''
#box(mt2l_variables: (visible: false,))[a]

#box(mt2l_variables: (visible: true,))[b]

#box(mt2l_variables: (visible: none,))[c]
''')
        self.assertEqual(self.body(tex).split(), [r"\textbf{NON}", r"\textbf{OUI}", r"\textbf{NON}"])

    def test_metadata_removal_keeps_intervening_content(self):
        tex = self.convert('''#import "mt2l.typ": mt2l-export-meta
#let config = ctx => (fontsize: ctx.text-size, colorlinks: true,)
Un paragraphe à garder.
#mt2l-export-meta(config)
Fin. #link("https://example.org")[Exemple]
''')
        self.assertIn("Un paragraphe à garder.", tex)
        self.assertIn("Fin.", tex)
        self.compile_latex()

    def test_local_imports_aliases_namespaces_and_reexports(self):
        self.write("adapters.typ", PRELUDE)
        self.write("bridge.typ", '#import "adapters.typ": box as exported\n')
        tex = self.convert('''#import "adapters.typ": box as renamed
#import "adapters.typ" as adapters
#import "bridge.typ": exported
#renamed()[Premier]

#adapters.box()[Deuxième]

#exported()[Troisième]
''')
        for word in ["Premier", "Deuxième", "Troisième"]:
            self.assertIn(r"\textbf{" + word + "}", tex)

    def test_wildcard_and_multiline_imports(self):
        self.write("adapters.typ", PRELUDE)
        tex = self.convert('''#import "adapters.typ": // multiline imports
  echo, // unused helper
  box
#box()[Multiligne]
''')
        self.assertIn(r"\textbf{Multiligne}", tex)
        tex = self.convert('#import "adapters.typ": *\n#box()[Étoile]\n')
        self.assertIn(r"\textbf{Étoile}", tex)

    def test_pdf_body_does_not_require_pandoc_to_understand_typst(self):
        self.convert('''#import "mt2l.typ": mt2l
#let exported = mt2l(fn: block, mode: "pdfrender", typst-template: ```typst
#set page(width: auto, height: auto, margin: 0pt)
$HERE$
```, latex-template: ```latex
\\includegraphics{$PATH$}
```)
#exported()[#context [#repr(text.size)]]
''')
        self.compile_latex()

    def test_explicit_syntax_context_and_deduplicated_latex_preamble(self):
        tex = self.convert('''#import "mt2l.typ": mt2l
#let titre = [Un *titre*]
#let echo(body) = body
#let exported = mt2l(fn: echo, typst-preamble: ```typst
#let titre = [Un *titre*]
```, latex-preamble: ```latex
\\newcommand{\\custom}[1]{\\textit{#1}}
```, latex-template: ```latex
\\custom{$BODY$}
```)
#exported()[#titre]

#exported()[Encore]
''')
        self.assertIn(r"\custom{Un \textbf{titre}}", tex)
        self.assertEqual(tex.count(r"\newcommand{\custom}"), 1)
        self.compile_latex()

    def test_pdf_context_resources_and_output_outside_root(self):
        self.write("adapters/mark.svg", '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect width="20" height="20" fill="blue"/></svg>')
        self.write("adapters/graphics.typ", '''#import "../mt2l.typ": mt2l
#let exported = mt2l(fn: rect, mode: "pdfrender", typst-preamble: ```typst
#let couleur = blue
```, typst-template: ```typst
#set page(width: auto, height: auto, margin: 0pt)
$HERE$
#image("$MODULE$/mark.svg")
```, latex-template: ```latex
\\includegraphics{$PATH$}
```)
''')
        source = self.write("main.typ", '''#import "adapters/graphics.typ": exported
#let couleur = blue
#exported(fill: couleur, width: 1cm, height: 1cm)
''')
        with tempfile.TemporaryDirectory(prefix="mt2l-output-") as outside:
            output = Path(outside) / "document.tex"
            self.run_command(["bash", ROOT / "scripts/convert.sh", "--root", self.root, source, output])
            self.assertEqual(len(list((Path(outside) / "document-assets").glob("*.pdf"))), 1)
            self.compile_latex(output)

    def test_block_contract_rejected_inside_text(self):
        result = self.convert(PRELUDE.replace("fn: echo,", 'fn: echo, placement: "block",')
                              + "Avant #box()[milieu] après.\n", success=False)
        self.assertIn("block contract cannot appear inside text", result.stderr)
        self.assertIn("main.typ:", result.stderr)

    def test_failed_conversion_keeps_previous_output(self):
        output = self.root / "output" / "document.tex"
        output.parent.mkdir()
        output.write_text("previous successful build")
        self.convert(PRELUDE.replace("fn: echo,", 'fn: echo, placement: "block",')
                     + "Avant #box()[milieu].\n", success=False)
        self.assertEqual(output.read_text(), "previous successful build")
        self.assertEqual(list(output.parent.glob(".mt2l-*")), [])

    def test_invalid_mode_reports_contract_location(self):
        result = self.convert(PRELUDE.replace("fn: echo,", 'fn: echo, mode: "oops",')
                              + "#box()[Texte]\n", success=False)
        self.assertIn("main.typ:3:1: contract box: unknown mode: oops", result.stderr)

    def test_original_cetz_pavemat_example(self):
        output = self.root / "example.tex"
        self.run_command(["bash", ROOT / "scripts/convert-test.sh", ROOT / "examples/packages.typ", output])
        self.assertIn(r"\begin{definition}", output.read_text())
        self.assertEqual(len(list((self.root / "example-assets").glob("*.pdf"))), 2)
        self.compile_latex(output)


if __name__ == "__main__":
    unittest.main()
