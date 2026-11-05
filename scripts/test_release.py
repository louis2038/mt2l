"""Exercise the piped installer and a clean Universe package without network."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from package import build

ROOT = Path(__file__).resolve().parents[1]


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mt2l release '")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source, self.package = build(self.root / "release")
        self.env = dict(os.environ, TYPST_PACKAGE_PATH=str(self.root / "installed-packages"),
                        MT2L_BIN_DIR=str(self.root / "bin"), XDG_DATA_HOME=str(self.root / "data"))

    def run_command(self, args, **kwargs):
        result = subprocess.run([str(arg) for arg in args], cwd=self.root,
                                env=self.env, text=True, capture_output=True, **kwargs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_small_universe_package_and_preview_export(self):
        self.assertEqual({p.name for p in self.package.iterdir()},
                         {"typst.toml", "mt2l.typ", "README.md", "LICENSE"})
        self.run_command(["bash", self.source / "install.sh"])
        document = self.root / "main.typ"
        document.write_text('''#import "@preview/mt2l:0.1.0": mt2l
#let highlight = mt2l(fn: strong, latex-template: ```latex
\\textbf{$BODY$}
```)
Before #highlight[important] after.
''')
        self.env["TYPST_PACKAGE_PATH"] = str(self.root / "release/packages")
        self.run_command(["typst", "compile", document, self.root / "native.pdf"])
        self.run_command([self.root / "bin/mt2l", document, self.root / "main.tex"])
        self.assertIn(r"Before \textbf{important} after.", (self.root / "main.tex").read_text())

    def fake_curl(self, fail=False):
        tools = self.root / "tools"
        tools.mkdir()
        curl = tools / "curl"
        curl.write_text('''#!/bin/bash
set -eu
output=""
while (($#)); do
  if [[ "$1" == --output ]]; then output=$2; shift 2
  else url=$1; shift; fi
done
printf '%s' "$url" > "$MT2L_TEST_URL"
''' + ("exit 22\n" if fail else 'cp "$MT2L_TEST_ARCHIVE" "$output"\n'))
        curl.chmod(0o755)
        self.env.update(PATH=str(tools) + os.pathsep + self.env["PATH"],
                        MT2L_TEST_ARCHIVE=str(self.root / "release/mt2l-0.1.0.tar.gz"),
                        MT2L_TEST_URL=str(self.root / "url.txt"))

    def test_piped_bootstrap_installs_from_tagged_archive(self):
        self.fake_curl()
        self.run_command(["bash"], input=(ROOT / "get.sh").read_text())
        self.assertEqual((self.root / "url.txt").read_text(),
                         "https://codeload.github.com/louis2038/mt2l/tar.gz/refs/tags/v0.1.0")
        self.assertEqual(self.run_command([self.root / "bin/mt2l", "--version"]).stdout.strip(),
                         "mt2l 0.1.0")

    def test_failed_download_does_not_install(self):
        self.fake_curl(fail=True)
        result = subprocess.run(["bash"], input=(ROOT / "get.sh").read_text(),
                                cwd=self.root, env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "bin/mt2l").exists())

    def test_clean_distribution_can_run_its_tests(self):
        self.assertFalse((self.source / "input.typ").exists())
        self.assertFalse((self.source / "lipics-v2021.cls").exists())
        self.run_command([sys.executable, self.source / "scripts/test_install.py"])
        self.run_command([sys.executable, "-m", "unittest", "discover", "-s", self.source / "tests", "-v"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
