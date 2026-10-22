import os
import subprocess
import sys
import textwrap
import unittest


def _run_tox(project_root):
    prefix = os.environ.get("TESSDATA_PREFIX")
    if prefix:
        os.environ["TESSDATA_PREFIX"] = os.path.join(project_root, prefix)
    unittest.main(module=None, argv=["unittest", "discover", "-v"])


class _SubprocessTestCase(unittest.TestCase):
    _image_file = os.path.join(os.path.dirname(__file__), "eurotext.png")

    def _run(self, script):
        env = dict(os.environ, OMP_THREAD_LIMIT="1")
        if not getattr(sys, "_is_gil_enabled", lambda: True)():
            env["PYTHON_GIL"] = "0"
        result = subprocess.run(
            [sys.executable, "-X", "faulthandler", "-c", textwrap.dedent(script), self._image_file],
            check=False, env=env,
            capture_output=True,
            text=True,
            timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
