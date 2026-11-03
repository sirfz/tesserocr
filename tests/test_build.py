import importlib.util
import os
import re
import runpy
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

_ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(
    (_ROOT / "tesserocr/tesserocr.templ.pyx").is_file(), "requires the source templates"
)
class TestBuildTemplates(unittest.TestCase):
    def setUp(self):
        if any(importlib.util.find_spec(name) is None for name in ("Cython", "setuptools")):
            self.skipTest("requires Cython and setuptools")
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.package = self.root / "tesserocr"
        self.package.mkdir()
        for name in ("setup.py", "README.rst"):
            shutil.copyfile(_ROOT / name, self.root / name)
        for name in ("__init__.py", "tesserocr.templ.pyx", "tesseract.templ.pxd", "tesseract5.pxd"):
            shutil.copyfile(_ROOT / "tesserocr" / name, self.package / name)

        with mock.patch("setuptools.setup") as setup_mock:
            with mock.patch("subprocess.Popen") as popen, mock.patch("logging.getLogger"):
                popen.return_value.returncode = 0
                popen.return_value.communicate.return_value = (b"5.5.3", b"")
                self.build = runpy.run_path(str(self.root / "setup.py"))
        self.setup_args = setup_mock.call_args.kwargs

    def _render(self, version):
        self.build["render_templates"]({
            "TESSERACT_MAJOR_VERSION": int(version.split(".")[0]),
            "TESSERACT_VERSION": self.build["version_to_int"](version),
        })
        return tuple((self.package / name).read_text(encoding="utf-8")
                     for name in ("tesserocr.pyx", "tesseract.pxd"))

    def test_template_directives_are_cython_comments(self):
        for name in ("tesserocr.templ.pyx", "tesseract.templ.pxd"):
            text = (self.package / name).read_text(encoding="utf-8")
            self.assertIn("### {{if ", text)
            for line in text.splitlines():
                if "{{" in line:
                    self.assertTrue(line.startswith("### {{"), line)

    def test_metadata_reads_template_without_generated_sources(self):
        self.assertEqual(
            self.setup_args["version"], self.build["find_version"]("tesserocr/tesserocr.templ.pyx")
        )
        for name in ("tesserocr.pyx", "tesseract.pxd"):
            self.assertFalse((self.package / name).exists())

    def test_regenerates_for_version_and_template_changes(self):
        original = self._render("4.1.1")
        paths = [self.package / name for name in ("tesserocr.pyx", "tesseract.pxd")]
        for path in paths:
            os.utime(path, (1, 1))
        timestamps = [path.stat().st_mtime_ns for path in paths]
        self.assertEqual(self._render("4.1.1"), original)
        self.assertEqual([path.stat().st_mtime_ns for path in paths], timestamps)

        modern = self._render("5.0.0")
        self.assertNotEqual(modern, original)
        # Even versions selecting identical branches must invalidate native build output.
        self.assertNotEqual(self._render("5.5.3"), modern)
        self.assertEqual(self._render("4.1.1"), original)

        template = self.package / "tesserocr.templ.pyx"
        template.write_text(template.read_text(encoding="utf-8") + "\n# template changed\n", encoding="utf-8")
        self.assertTrue(self._render("4.1.1")[0].endswith("# template changed\n"))

    def test_crlf_templates_do_not_trigger_rewrites(self):
        for name in ("tesserocr.templ.pyx", "tesseract.templ.pxd"):
            template = self.package / name
            text = template.read_text(encoding="utf-8")
            template.write_bytes(text.replace("\n", "\r\n").encode("utf-8"))
        original = self._render("5.5.3")
        paths = [self.package / name for name in ("tesserocr.pyx", "tesseract.pxd")]
        for path in paths:
            os.utime(path, (1, 1))
        timestamps = [path.stat().st_mtime_ns for path in paths]
        self.assertEqual(self._render("5.5.3"), original)
        self.assertEqual([path.stat().st_mtime_ns for path in paths], timestamps)

    def test_build_ext_renders_before_cythonize(self):
        from setuptools import Distribution

        extensions = self.setup_args["ext_modules"]
        command = self.build["my_build_ext"](Distribution({"ext_modules": extensions}))

        def cythonize(sources):
            for name in ("tesserocr.pyx", "tesseract.pxd"):
                text = (self.package / name).read_text(encoding="utf-8")
                self.assertNotIn("{{", text)
            return sources

        with mock.patch("Cython.Build.Dependencies.cythonize", side_effect=cythonize) as translate:
            command.ensure_finalized()
        translate.assert_called_once_with(extensions)

    def test_version_branches_translate(self):
        from Cython.Compiler.Main import compile as cython_compile

        versions = ("3.04.00", "3.04.01", "3.05.02", "4.0.0alpha", "4.0.0beta", "4.0.0", "4.1.1", "5.0.0", "5.3.4", "5.5.3")
        for version in versions:
            with self.subTest(version=version):
                pyx, pxd = self._render(version)
                major = int(version.split(".")[0])
                number = self.build["version_to_int"](version)
                for text in (pyx, pxd):
                    self.assertNotIn("{{", text)
                    self.assertNotRegex(text, re.compile(r"^\s*(IF|ELIF|ELSE|DEF)\b", re.M))
                for marker, expected in (
                    ("from .tesseract5 cimport *", major >= 5),
                    ("GenericVector[STRING]", major < 5),
                    ("cpdef bool RecognizeForChopTest(", major < 5),
                    ("def RowAttributes(", number >= 0x3040100),
                    ("def BlanksBeforeWord(", number >= 0x4000000),
                    ("def GetBestLSTMSymbolChoices(", number >= 0x4000000),
                    ("def GetTSVText(", number >= 0x3999800),
                    ("def DetectOrientationScript(", number >= 0x3999800),
                    ("LSTM_ONLY = OEM_LSTM_ONLY", number >= 0x3999800),
                    ("CUBE_ONLY = OEM_CUBE_ONLY", number < 0x3999800),
                ):
                    self.assertEqual(marker in pyx, expected, marker)
                for marker, expected in (
                    ("void RowAttributes(", number >= 0x3040100),
                    ("int BlanksBeforeWord(", number >= 0x4000000),
                    ("TessOsdRenderer(", number >= 0x3040100),
                    ("TessAltoRenderer(", number >= 0x3999800),
                ):
                    self.assertEqual(marker in pxd, expected, marker)

                result = cython_compile(
                    str(self.package / "tesserocr.pyx"),
                    full_module_name="tesserocr.tesserocr",
                    cplus=True,
                    include_path=[str(self.root)],
                    output_file=str(self.root / "tesserocr.cpp"),
                )
                self.assertEqual(result.num_errors, 0)
