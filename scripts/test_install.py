"""Run: python scripts/test_install.py. Installs only into temporary directories."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mt2l install '")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, XDG_DATA_HOME=str(self.root / "data"),
                        MT2L_BIN_DIR=str(self.root / "bin"),
                        TYPST_PACKAGE_PATH=str(self.root / "packages"))
        self.package = self.root / "packages/local/mt2l/0.1.0"
        self.command = self.root / "bin/mt2l"

    def run_command(self, *args, success=True, env=None, cwd=None):
        result = subprocess.run([str(arg) for arg in args], env=env or self.env,
                                cwd=cwd or self.root, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def install(self, source=ROOT, **kwargs):
        return self.run_command("/bin/bash", source / "install.sh", **kwargs)

    def test_installed_package_and_cli_work_without_repo(self):
        source = self.root / "source"
        source.mkdir()
        for name in ["install.sh", "typst.toml", "mt2l.typ", "README.md", "LICENSE"]:
            shutil.copy(ROOT / name, source / name)
        for name in ["scripts", "templates", "examples"]:
            shutil.copytree(ROOT / name, source / name)
        self.install(source)
        self.install(source)  # A second installation must be safe.
        shutil.rmtree(source)
        self.assertEqual(self.run_command(self.command, "--version").stdout.strip(), "mt2l 0.1.0")
        document = self.root / "main.typ"
        shutil.copy(self.package / "examples/package.typ", document)
        self.run_command("typst", "compile", document, self.root / "native.pdf")
        self.run_command(self.command, document, self.root / "output/main.tex")
        tex = (self.root / "output/main.tex").read_text()
        self.assertIn(r"\textbf{en gras}", tex)
        self.assertEqual(len(list((self.root / "output/main-assets").glob("*.pdf"))), 1)
        self.run_command("pdflatex", "-interaction=nonstopmode", "-halt-on-error", "main.tex",
                         cwd=self.root / "output")
        self.assertTrue((self.root / "output/main.pdf").is_file())

    def restricted_environment(self, pandoc=None):
        tools = self.root / "tools"
        tools.mkdir()
        for name in ["bash", "dirname", "cat", "typst"]:
            (tools / name).symlink_to(shutil.which(name))
        if pandoc:
            fake = tools / "pandoc"
            fake.write_text('#!/bin/bash\nprintf "pandoc ' + pandoc + '\\n"\n')
            fake.chmod(0o755)
        return dict(self.env, PATH=str(tools))

    def test_missing_pandoc_shows_actionable_help_and_writes_nothing(self):
        result = self.install(success=False, env=self.restricted_environment())
        self.assertIn("https://pandoc.org/installing.html", result.stderr)
        self.assertIn("https://github.com/jgm/pandoc/releases/latest", result.stderr)
        self.assertIn("without sudo", result.stderr)
        self.assertIn("tar -xzf", result.stderr)
        self.assertFalse(self.package.exists())
        self.assertFalse(self.command.exists())

    def test_old_pandoc_is_rejected_before_installation(self):
        result = self.install(success=False, env=self.restricted_environment("3.6.4"))
        self.assertIn("Pandoc is too old", result.stderr)
        self.assertFalse(self.package.exists())

    def test_installed_command_reports_missing_pandoc(self):
        self.install()
        result = self.run_command(self.command, self.root / "main.typ", success=False,
                                  env=self.restricted_environment())
        self.assertIn("https://pandoc.org/installing.html", result.stderr)
        self.assertIn("without sudo", result.stderr)

    def test_unmanaged_package_is_preserved(self):
        self.package.mkdir(parents=True)
        marker = self.package / "personal.typ"
        marker.write_text("Do not overwrite")
        result = self.install(success=False)
        self.assertIn("unmanaged package", result.stderr)
        self.assertEqual(marker.read_text(), "Do not overwrite")

    def test_other_command_in_path_is_reported_and_preserved(self):
        tools = self.root / "other-tools"
        tools.mkdir()
        other = tools / "mt2l"
        other.write_text('#!/bin/bash\necho "other program"\n')
        other.chmod(0o755)
        env = dict(self.env, PATH=str(tools) + os.pathsep + self.env["PATH"])
        result = self.install(env=env)
        self.assertIn("Another mt2l takes precedence", result.stdout)
        self.assertIn(str(other), result.stdout)
        self.assertIn("export PATH=", result.stdout)
        self.assertEqual(other.read_text(), '#!/bin/bash\necho "other program"\n')

    def test_unmanaged_command_is_preserved(self):
        self.command.parent.mkdir()
        self.command.write_text("personal command")
        result = self.install(success=False)
        self.assertIn("unmanaged command", result.stderr)
        self.assertEqual(self.command.read_text(), "personal command")

    def test_migration_removes_only_the_managed_legacy_launcher(self):
        self.install()
        legacy = self.command.with_name("t2l")
        legacy.write_text('#!/bin/bash\n# Installed by t2l/install.sh.\n')
        self.install()
        self.assertFalse(legacy.exists())
        self.assertTrue(self.command.is_file())
        legacy.write_text("unrelated t2l program")
        self.install()
        self.assertEqual(legacy.read_text(), "unrelated t2l program")

    def test_migration_replaces_old_package_and_launcher_signature(self):
        legacy = self.root / "packages/local/t2l/0.1.0"
        legacy.mkdir(parents=True)
        (legacy / ".t2l-managed").write_text("t2l 0.1.0\n")
        (legacy / "t2l.typ").write_text("old package")
        self.command.parent.mkdir()
        self.command.write_text('#!/bin/bash\n# Installed by t2l/install.sh.\n')
        self.install()
        self.assertFalse(legacy.exists())
        self.assertTrue((self.package / "mt2l.typ").is_file())
        self.assertIn("mt2l/install.sh", self.command.read_text())
        self.assertEqual(self.run_command(self.command, "--version").stdout.strip(), "mt2l 0.1.0")

    def test_unmanaged_old_package_is_not_removed(self):
        legacy = self.root / "packages/local/t2l/0.1.0"
        legacy.mkdir(parents=True)
        (legacy / "personal.typ").write_text("personal package")
        self.install()
        self.assertEqual((legacy / "personal.typ").read_text(), "personal package")

    def test_mismatched_package_and_engine_report_versions(self):
        self.install()
        other = self.package.with_name("0.2.0")
        shutil.copytree(self.package, other)
        manifest = other / "typst.toml"
        manifest.write_text(manifest.read_text().replace('version = "0.1.0"', 'version = "0.2.0"'))
        document = self.root / "main.typ"
        document.write_text('#import "@local/mt2l:0.2.0": mt2l\nTexte.\n')
        result = self.run_command(self.command, document, success=False)
        self.assertIn("package 0.2.0 does not match engine 0.1.0", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
