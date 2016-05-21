import unittest
import os.path
import tesserocr
try:
    from PIL import Image
    pil_installed = True
except ImportError:
    pil_installed = False


class TestTessBaseApi(unittest.TestCase):

    def setUp(self):
        self._test_dir = os.path.abspath(os.path.dirname(__file__))
        self._image_file = os.path.join(self._test_dir, 'eurotext.tif')
        if pil_installed:
            self._image = Image.open(self._image_file)
        self._api = tesserocr.PyTessBaseAPI(init=True)

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
        # reset
        self._api.End()
        self._api.Init()

    @unittest.skipIf(not pil_installed, "Pillow not installed")
    def test_image(self):
        """Test SetImage and GetUTF8Text."""
        self._api.Init()
        self._api.SetImage(self._image)
        text = self._api.GetUTF8Text()
        self.assertIn('quick', text)
        text2 = tesserocr.image_to_text(self._image)
        self.assertEqual(text, text2)

    def test_image_file(self):
        """Test SetImageFile and GetUTF8Text."""
        self._api.Init()
        self._api.SetImageFile(self._image_file)
        text = self._api.GetUTF8Text()
        self.assertIn('quick', text)
        text2 = tesserocr.file_to_text(self._image_file)
        self.assertEqual(text, text2)

    @unittest.skipIf(not pil_installed, "Pillow not installed")
    def test_thresholded_image(self):
        """Test GetThresholdedImage and GetThresholdedImageScaleFactor."""
        self._api.Init()
        orig_size = self._image.size
        self._api.SetImage(self._image)
        image = self._api.GetThresholdedImage()
        self.assertIsNot(image, None)
        self.assertEqual(image.size, orig_size)
        self.assertEqual(self._api.GetThresholdedImageScaleFactor(), 1)

    def test_page_seg_mode(self):
        """Test SetPageSegMode and GetPageSegMode."""
        self._api.Init()
        self._api.SetPageSegMode(tesserocr.PSM.SINGLE_WORD)
        self.assertEqual(self._api.GetPageSegMode(), tesserocr.PSM.SINGLE_WORD)
        self._api.SetPageSegMode(tesserocr.PSM.AUTO)
        self.assertEqual(self._api.GetPageSegMode(), tesserocr.PSM.AUTO)

    def test_data_path(self):
        """Test GetDatapath and Init with an invalid data path."""
        self._api.End()
        self._api.Init()
        path = self._api.GetDatapath()
        self._api.End()
        self.assertRaises(RuntimeError, self._api.Init, path=(self._test_dir + os.path.sep))  # no tessdata
        new_path = os.path.abspath(os.path.join(path, os.path.pardir)) + os.path.sep
        self._api.End()
        self._api.Init(new_path)
        self.assertEqual(self._api.GetDatapath(), path)

    def test_langs(self):
        """Test get langs methods."""
        self._api.End()
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
        self._api.Init()
        self._api.SetImage(self._image)
        self._api.SetRectangle(0, 0, 100, 43)
        thresh = self._api.GetThresholdedImage()
        self.assertEqual(thresh.size, (100, 43))

    def test_word_confidences(self):
        """Test AllWordConfidences and MapWordConfidences."""
        self._api.Init()
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

    def test_detect_os(self):
        self._api.Init()
        self._api.SetPageSegMode(tesserocr.PSM.OSD_ONLY)
        self._api.SetImageFile(self._image_file)
        orientation = self._api.DetectOS()
        all(self.assertIn(k, orientation) for k in ['sconfidence', 'oconfidence', 'script', 'orientation'])
        self.assertEqual(orientation['orientation'], 0)

    def test_clear(self):
        """Test Clear."""
        self._api.Init()
        self._api.SetImageFile(self._image_file)
        self._api.GetUTF8Text()
        self._api.Clear()
        self.assertRaises(RuntimeError, self._api.GetUTF8Text)

    def test_end(self):
        """Test End."""
        self._api.End()
        self._api.SetImageFile(self._image_file)
        self.assertRaises(RuntimeError, self._api.GetUTF8Text)
