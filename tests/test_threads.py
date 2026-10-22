import importlib.util
import os
import subprocess
import sys
import sysconfig
import unittest

from tests import _SubprocessTestCase


class TestThreads(_SubprocessTestCase):
    @unittest.skipUnless(sysconfig.get_config_var("Py_GIL_DISABLED"), "free-threaded CPython required")
    def test_import_keeps_gil_disabled(self):
        env = dict(os.environ)
        env.pop("PYTHON_GIL", None)
        result = subprocess.run(
            [sys.executable, "-W", "error", "-c", """
import sys
assert not sys._is_gil_enabled(), 'GIL enabled before import'
import tesserocr
assert not sys._is_gil_enabled(), 'tesserocr enabled the GIL'
"""],
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(getattr(sys, "_is_gil_enabled", lambda: True)(), "GIL-enabled interpreter required")
    def test_worker_recognition_does_not_wait_for_gil(self):
        self._run("""
            import sys
            import threading
            import time
            from concurrent.futures import ThreadPoolExecutor
            from queue import Queue
            import tesserocr

            deadlines = Queue()
            started = threading.Event()
            def recognize():
                with tesserocr.PyTessBaseAPI() as api:
                    api.SetImageFile(sys.argv[1])
                    before = time.monotonic()
                    assert api.Recognize()
                    # Allow slower CI hosts four times the measured OCR duration.
                    timeout = max(1000, int((time.monotonic() - before) * 4000))
                    api.SetImageFile(sys.argv[1])
                    deadlines.put(timeout)
                    assert started.wait(timeout=30)
                    return api.Recognize(timeout)

            with ThreadPoolExecutor(max_workers=1) as pool:
                result = pool.submit(recognize)
                timeout = deadlines.get(timeout=30)
                started.set()
                time.sleep(0.01)
                hold_seconds = timeout / 1000 * 2
                previous = sys.getswitchinterval()
                try:
                    sys.setswitchinterval(hold_seconds * 2)
                    until = time.monotonic() + hold_seconds
                    while time.monotonic() < until:
                        pass
                finally:
                    sys.setswitchinterval(previous)
                assert result.result(timeout=30), 'worker waited for the GIL and timed out'
        """)

    def test_parallel_api_lifecycle(self):
        self._run("""
            import sys
            import threading
            from concurrent.futures import ThreadPoolExecutor
            import tesserocr

            expected = tesserocr.file_to_text(sys.argv[1])
            started = threading.Barrier(4)
            def recognize():
                for _ in range(3):
                    started.wait(timeout=30)
                    with tesserocr.PyTessBaseAPI() as api:
                        api.SetImageFile(sys.argv[1])
                        assert api.Recognize()
                        iterator = api.GetIterator()
                        assert api.GetUTF8Text() == expected
                        assert iterator.GetUTF8Text(tesserocr.RIL.WORD) == 'The'
                        del iterator
                        api.Clear()
                        api.SetImageFile(sys.argv[1])
                        assert api.GetUTF8Text() == expected
                        api.End()
                        api.Init()
                        api.SetImageFile(sys.argv[1])
                        assert api.GetUTF8Text() == expected

            with ThreadPoolExecutor(max_workers=4) as pool:
                results = [pool.submit(recognize) for _ in range(4)]
                for result in results:
                    result.result(timeout=45)
        """)

    @unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow not installed")
    def test_parallel_helpers(self):
        self._run("""
            import sys
            import threading
            from concurrent.futures import ThreadPoolExecutor
            from PIL import Image
            import tesserocr

            expected = tesserocr.file_to_text(sys.argv[1])
            started = threading.Barrier(4)
            def recognize():
                with Image.open(sys.argv[1]) as image:
                    image.load()
                    for _ in range(2):
                        started.wait(timeout=30)
                        assert tesserocr.file_to_text(sys.argv[1]) == expected
                        assert tesserocr.image_to_text(image) == expected

            with ThreadPoolExecutor(max_workers=4) as pool:
                results = [pool.submit(recognize) for _ in range(4)]
                for result in results:
                    result.result(timeout=45)
        """)
