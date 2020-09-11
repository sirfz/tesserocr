import unittest
import re
import os.path
import tesserocr
try:
    from PIL import Image
    pil_installed = True
except ImportError:
    pil_installed = False


def version_to_int(version):
    subversion = None
    subtrahend = 0
    # Subtracts a certain amount from the version number to differentiate between
    # alpha, beta and release versions.
    if "alpha" in version:
        version_split = version.split("alpha")
        subversion = version_split[1]
        subtrahend = 2
    elif "beta" in version:
        version_split = version.split("beta")
        subversion = version_split[1]
        subtrahend = 1
    version = re.search(r'((?:\d+\.)+\d+)', version).group()
    # Split the groups on ".", take only the first one, and print each group with leading 0 if needed
    # To be safe, also handle cases where an extra group is added to the version string, or if one or two groups
    # are dropped.
    version_groups = (version.split('.') + [0, 0])[:3]
    version_str = "{:02}{:02}{:02}".format(*map(int, version_groups))
    version_str = str((int(version_str, 10) - subtrahend))
    # Adds a 2 digit subversion number for the subversionrelease.
    subversion_str = "00"
    if subversion is not None and subversion != "":
        subversion = re.search(r'(?:\d+)', subversion).group()
        subversion_groups = (subversion.split('-') + [0, 0])[:1]
        subversion_str = "{:02}".format(*map(int, subversion_groups))
    version_str += subversion_str
    return int(version_str, 16)


_TESSERACT_VERSION = version_to_int(tesserocr.PyTessBaseAPI.Version())


class TestTessBaseApi(unittest.TestCase):

    _test_dir = os.path.abspath(os.path.dirname(__file__))
    _image_file = os.path.join(_test_dir, 'eurotext.tif')

    def setUp(self):
        if pil_installed:
            with open(self._image_file, 'rb') as f:
                self._image = Image.open(f)
                self._image.load()
        self._api = tesserocr.PyTessBaseAPI(init=True)

    def tearDown(self):
        if pil_installed:
            self._image.close()
        self._api.End()

    def test_context_manager(self):
        """Test context manager behavior"""
        with self._api as api:
            self.assertIs(api, self._api)
            api.SetImageFile(self._image_file)
            self.assertEqual(api.GetUTF8Text(), self._api.GetUTF8Text())
        # assert api has Ended
        self.assertRaises(RuntimeError, self._api.GetUTF8Text)

    def test_init_full(self):
        """Test InitFull."""
        # check default settings
        self.assertEqual(self._api.GetVariableAsString('file_type'), '.tif')
        self.assertEqual(self._api.GetVariableAsString('edges_childarea'), '0.5')
        # use box.train config variables
        configs = ['box.train']
        # change edges_childarea
        vars_ = {'edges_childarea': '0.7'}
        self._api.End()
        self._api.InitFull(configs=configs, variables=vars_)
        # assert file_type from box.train and custom edges_childarea
        self.assertEqual(self._api.GetVariableAsString('file_type'), '.bl')
        self.assertEqual(self._api.GetVariableAsString('edges_childarea'), '0.7')
        # reset back to default
        self._api.End()
        self._api.Init()

    def test_init(self):
        """Test Init calls with different lang and oem."""
        self._api.Init(lang='eng+osd')
        self.assertEqual(self._api.GetInitLanguagesAsString(), 'eng+osd')
        self._api.Init(lang='eng')
        self.assertEqual(self._api.GetInitLanguagesAsString(), 'eng')
        self._api.Init(oem=tesserocr.OEM.TESSERACT_ONLY)
        self.assertEqual(self._api.oem(), tesserocr.OEM.TESSERACT_ONLY)

    @unittest.skipIf(not pil_installed, "Pillow not installed")
    def test_image(self):
        """Test SetImage and GetUTF8Text."""
        self._api.SetImage(self._image)
        text = self._api.GetUTF8Text()
        self.assertIn('quick', text)
        text2 = tesserocr.image_to_text(self._image)
        self.assertEqual(text, text2)

    def test_image_file(self):
        """Test SetImageFile and GetUTF8Text."""
        self._api.SetImageFile(self._image_file)
        text = self._api.GetUTF8Text()
        self.assertIn('quick', text)
        text2 = tesserocr.file_to_text(self._image_file)
        self.assertEqual(text, text2)

    @unittest.skipIf(not pil_installed, "Pillow not installed")
    def test_thresholded_image(self):
        """Test GetThresholdedImage and GetThresholdedImageScaleFactor."""
        orig_size = self._image.size
        self._api.SetImage(self._image)
        image = self._api.GetThresholdedImage()
        self.assertIsNot(image, None)
        self.assertIsInstance(image, Image.Image)
        self.assertEqual(image.size, orig_size)
        self.assertEqual(self._api.GetThresholdedImageScaleFactor(), 1)

    def test_page_seg_mode(self):
        """Test SetPageSegMode and GetPageSegMode."""
        self._api.SetPageSegMode(tesserocr.PSM.SINGLE_WORD)
        self.assertEqual(self._api.GetPageSegMode(), tesserocr.PSM.SINGLE_WORD)
        self._api.SetPageSegMode(tesserocr.PSM.AUTO)
        self.assertEqual(self._api.GetPageSegMode(), tesserocr.PSM.AUTO)

    def test_data_path(self):
        """Test GetDatapath and Init with an invalid data path."""
        path = self._api.GetDatapath()
        self._api.End()
        self.assertRaises(RuntimeError, self._api.Init, path=(self._test_dir + os.path.sep))  # no tessdata
        if _TESSERACT_VERSION >= 0x3999800:
            new_path = path
        else:
            new_path = os.path.abspath(os.path.join(path, os.path.pardir)) + os.path.sep
        self._api.End()
        self._api.Init(new_path)
        self.assertEqual(self._api.GetDatapath(), path)

    def test_langs(self):
        """Test get langs methods."""
        self._api.Init(lang='eng')
        lang = self._api.GetInitLanguagesAsString()
        self.assertEqual(lang, 'eng')
        langs = self._api.GetLoadedLanguages()
        self.assertEqual(langs, ['eng'])
        self.assertIn('eng', self._api.GetAvailableLanguages())

    def test_variables(self):
        """Test SetVariable and GetVariableAsString."""
        self._api.SetVariable('debug_file', '/dev/null')
        self.assertEqual(self._api.GetVariableAsString('debug_file'), '/dev/null')

    @unittest.skipIf(not pil_installed, "Pillow not installed")
    def test_rectangle(self):
        """Test SetRectangle."""
        self._api.SetImage(self._image)
        self._api.SetRectangle(0, 0, 100, 43)
        thresh = self._api.GetThresholdedImage()
        self.assertEqual(thresh.size, (100, 43))

    def test_word_confidences(self):
        """Test AllWordConfidences and MapWordConfidences."""
        self._api.SetImageFile(self._image_file)
        words = self._api.AllWords()
        self.assertEqual(words, [])
        self._api.Recognize()
        words = self._api.AllWords()
        confidences = self._api.AllWordConfidences()
        self.assertEqual(len(words), len(confidences))
        mapped_confidences = self._api.MapWordConfidences()
        self.assertEqual([v[0] for v in mapped_confidences], words)
        self.assertEqual([v[1] for v in mapped_confidences], confidences)

    @unittest.skipIf(_TESSERACT_VERSION < 0x4000000, "tesseract < 4")
    def test_LSTM_choices(self):
        """Test GetBestLSTMSymbolChoices."""
        self._api.SetVariable("lstm_choice_mode", "2")
        self._api.SetImageFile(self._image_file)
        self._api.Recognize()
        LSTM_choices = self._api.GetBestLSTMSymbolChoices()
        words = self._api.AllWords()
        self.assertEqual(len(words), len(LSTM_choices))

        for choice, word in zip(LSTM_choices, words):
            chosen_word = ""
            for timestep in choice:
                for alternative in timestep:
                    self.assertGreaterEqual(alternative[1], 0.0)
                    self.assertLessEqual(alternative[1], 2.0)
                chosen_symbol = timestep[0][0]
                if chosen_symbol != " ":
                    chosen_word += chosen_symbol
            self.assertEqual(chosen_word, word)

    @unittest.skipIf(_TESSERACT_VERSION < 0x4000000, "tesseract < 4")
    def test_result_iterator(self):
        """Test result iterator."""
        self._api.SetImageFile(self._image_file)
        self._api.Recognize()
        it = self._api.GetIterator()
        level = tesserocr.RIL.WORD
        for i, w in enumerate(tesserocr.iterate_level(it, level)):
            text = w.GetUTF8Text(level)
            blanks = w.BlanksBeforeWord()
            if i == 0:
                self.assertEqual(text, "The")
                self.assertEqual(blanks, 0)
            elif i == 1:
                self.assertEqual(text, "(quick)")
                self.assertEqual(blanks, 1)
            else:
                break

    def test_detect_os(self):
        """Test DetectOS and DetectOrientationScript (tesseract v4+)."""
        self._api.SetPageSegMode(tesserocr.PSM.OSD_ONLY)
        self._api.SetImageFile(self._image_file)
        orientation = self._api.DetectOS()
        all(self.assertIn(k, orientation) for k in ['sconfidence', 'oconfidence', 'script', 'orientation'])
        self.assertEqual(orientation['orientation'], 0)
        languages = tesserocr.get_languages()[1] # this is sorted alphabetically!
        self.assertLess(orientation['script'], len(languages))
        script_name = languages[orientation['script']] # therefore does not work
        #self.assertEqual(script_name, 'Latin') # cannot test: not reliable
        if _TESSERACT_VERSION >= 0x3999800:
            orientation = self._api.DetectOrientationScript()
            all(self.assertIn(k, orientation) for k in ['orient_deg', 'orient_conf', 'script_name', 'script_conf'])
            self.assertEqual(orientation['orient_deg'], 0)
            self.assertEqual(orientation['script_name'], 'Latin')

    def test_clear(self):
        """Test Clear."""
        self._api.SetImageFile(self._image_file)
        self._api.GetUTF8Text()
        self._api.Clear()
        self.assertRaises(RuntimeError, self._api.GetUTF8Text)

    def test_end(self):
        """Test End."""
        self._api.End()
        self._api.SetImageFile(self._image_file)
        self.assertRaises(RuntimeError, self._api.GetUTF8Text)

    @unittest.skipIf(not pil_installed, "Pillow not installed")
    def test_empty_getcomponents(self):
        self._api.Init()
        image = Image.new("RGB", (100, 100), (1, 1, 1))
        self._api.SetImage(image)
        result = self._api.GetComponentImages(tesserocr.RIL.TEXTLINE, True)
        # Test if empty
        self.assertFalse(result)

    @unittest.skipIf(not pil_installed, "Pillow not installed")
    def test_empty_small_getcomponents(self):
        self._api.Init()
        image = Image.new("RGB", (1, 1), (1, 1, 1))
        self._api.SetImage(image)
        result = self._api.GetComponentImages(tesserocr.RIL.TEXTLINE, True)
        # Test if empty
        self.assertFalse(result)

    def test_layout_getcomponents(self):
        self._api.Init()
        self._api.SetImageFile(self._image_file)
        result = self._api.GetComponentImages(tesserocr.RIL.BLOCK, True)
        # Test if not empty
        self.assertTrue(result)
        _, xywh, _, _ = result[0] # bbox of largest
        self.assertIn('w', xywh)
        self.assertIn('h', xywh)
        area = xywh['w'] * xywh['h']
        # Test if the largest block is quite large
        self.assertGreater(area, 400000)

    def test_layout_boundingbox(self):
        self._api.Init()
        self._api.SetImageFile(self._image_file)
        layout = self._api.AnalyseLayout()
        # Test if not empty
        self.assertTrue(layout)
        self.assertFalse(layout.Empty(tesserocr.RIL.BLOCK))
        result = layout.BoundingBox(tesserocr.RIL.BLOCK) # bbox of largest
        self.assertIsNot(result, None)
        x0, y0, x1, y1 = result
        area = (x1 - x0) * (y1 - y0)
        # Test if the largest block is quite large
        self.assertGreater(area, 400000)

    def test_layout_blockpolygon(self):
        self._api.Init()
        self._api.SetImageFile(self._image_file)
        layout = self._api.AnalyseLayout()
        # Test if not empty
        self.assertTrue(layout)
        self.assertFalse(layout.Empty(tesserocr.RIL.BLOCK))
        result = layout.BlockPolygon() # polygon of largest
        # Test if not empty
        self.assertIsNot(result, None)
        # Test there are at least 4 contour points
        self.assertGreaterEqual(len(result), 4)
        xs, ys = zip(*result)
        x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
        area = (x1 - x0) * (y1 - y0)
        # Test if the largest block is quite large
        self.assertGreater(area, 400000)

    def test_recognize(self):
        """Test Recognize with and without timeout."""
        self._api.SetImageFile(self._image_file)
        # timeout after 1 milliseconds (likely)
        res = self._api.Recognize(1)
        self.assertFalse(res)
        self._api.SetImageFile(self._image_file)
        # timeout after 10 seconds (unlikely)
        res = self._api.Recognize(10000)
        self.assertTrue(res)
        self._api.SetImageFile(self._image_file)
        # no timeout
        res = self._api.Recognize()
        self.assertTrue(res)

    @unittest.skipIf(_TESSERACT_VERSION < 0x3040100, "tesseract < 4")
    def test_row_attributes(self):
        self._api.SetImageFile(self._image_file)
        self._api.Recognize()
        it = self._api.GetIterator()
        attrs = it.RowAttributes()
        self.assertIsInstance(attrs['row_height'], float)
        self.assertIsInstance(attrs['ascenders'], float)
        self.assertIsInstance(attrs['descenders'], float)


if __name__ == '__main__':
    unittest.main()
