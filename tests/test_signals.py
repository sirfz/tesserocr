import importlib.util
import unittest

from tests import _SubprocessTestCase


class TestSignals(_SubprocessTestCase):
    @unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow not installed")
    def test_cooperative_signal_cancellation(self):
        self._run("""
            import signal
            import sys
            import tempfile
            import threading
            from pathlib import Path
            from PIL import Image
            import tesserocr

            with Image.open(sys.argv[1]) as source:
                image = Image.new('RGB', (source.width, source.height * 6), 'white')
                for row in range(6):
                    image.paste(source, (0, row * source.height))
                with tempfile.TemporaryDirectory() as directory:
                    filename = str(Path(directory) / 'page.png')
                    image.save(filename)
                    with tesserocr.PyTessBaseAPI() as api:
                        calls = (
                            lambda: api.Recognize(),
                            lambda: api.Recognize(10000),
                            lambda: api.GetUTF8Text(),
                            lambda: tesserocr.file_to_text(filename),
                            lambda: tesserocr.image_to_text(image),
                        )
                        for call in calls:
                            api.SetImage(image)
                            expected = KeyboardInterrupt('cancel OCR')
                            received = []
                            def interrupt(signum, frame):
                                received.append(signum)
                                if len(received) == 2:
                                    raise expected
                            signal.signal(signal.SIGINT, interrupt)
                            stopped = threading.Event()
                            def send_signals():
                                while not stopped.wait(0.05):
                                    signal.raise_signal(signal.SIGINT)
                            sender = threading.Thread(target=send_signals)
                            sender.start()
                            try:
                                call()
                            except KeyboardInterrupt as error:
                                assert error is expected
                            else:
                                raise AssertionError('recognition was not cancelled')
                            finally:
                                stopped.set()
                                sender.join()
                            assert len(received) >= 2
                            api.SetImage(source)
                            assert 'quick' in api.GetUTF8Text()
            assert 'cysignals.signals' not in sys.modules
        """)

    def test_sigint_during_worker_ocr(self):
        self._run("""
            import signal
            import sys
            import threading
            import time
            from concurrent.futures import ThreadPoolExecutor
            import tesserocr

            started = threading.Barrier(3)
            def recognize():
                with tesserocr.PyTessBaseAPI() as api:
                    api.SetImageFile(sys.argv[1])
                    started.wait(timeout=30)
                    return api.GetUTF8Text()

            with ThreadPoolExecutor(max_workers=2) as pool:
                results = [pool.submit(recognize) for _ in range(2)]
                started.wait(timeout=30)
                time.sleep(0.01)
                try:
                    signal.raise_signal(signal.SIGINT)
                except KeyboardInterrupt:
                    pass
                else:
                    raise AssertionError('SIGINT was not handled on the main thread')
                for result in results:
                    assert 'quick' in result.result(timeout=30)
            assert 'cysignals.signals' not in sys.modules
        """)
