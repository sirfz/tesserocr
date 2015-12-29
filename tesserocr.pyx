#!python
#cython: c_string_type=unicode, c_string_encoding=utf-8
"""Python wrapper around the Tesseract-OCR 3.02+ C++ API

This module provides a wrapper class `PyTessBaseAPI` to call
Tesseract API methods. See :class:`~tesserocr.PyTessBaseAPI` for details.

In addition, helper functions are provided for ocr operations:

    >>> text = image_to_text(Image.open('./image.jpg').convert('L'), lang='eng')
    >>> text = file_to_text('./image.jpg', psm=PSM.AUTO)
    >>> print tesseract_version()
    tesseract 3.04.00
     leptonica-1.72
      libjpeg 8d (libjpeg-turbo 1.3.0) : libpng 1.2.51 : libtiff 4.0.3 : zlib 1.2.8
    >>> get_languages()
    ('/usr/share/tesseract-ocr/tessdata/',
     ['eng', 'osd', 'equ'])
"""

__version__ = '1.2.1rc2'

import os
from cStringIO import StringIO
from contextlib import closing
from os.path import abspath, join
try:
    from PIL import Image
except ImportError:
    # PIL.Image won't be supported
    pass

from tesseract cimport *
from libc.stdlib cimport free


# default paramters
setMsgSeverity(L_SEVERITY_NONE)  # suppress leptonica error messages
cdef TessBaseAPI _api = TessBaseAPI()
_api.SetVariable('debug_file', '/dev/null')  # suppress tesseract debug messages
_api.Init(NULL, NULL)
cdef unicode _abs_path = abspath(join(_api.GetDatapath(), os.pardir)) + os.sep
cdef unicode _lang_s = _api.GetInitLanguagesAsString()
cdef cchar_t *_DEFAULT_PATH = _abs_path
cdef cchar_t *_DEFAULT_LANG = _lang_s
_api.End()
TessBaseAPI.ClearPersistentCache()


cdef class PSM:
    """An enum that defines all available page segmentation modes.

    `OSD_ONLY`: Orientation and script detection only.
    `AUTO_OSD`: Automatic page segmentation with orientation and script detection. (OSD)
    `AUTO_ONLY`: Automatic page segmentation, but no OSD, or OCR.
    `AUTO`: Fully automatic page segmentation, but no OSD. (:mod:`tesserocr` default)
    `SINGLE_COLUMN`: Assume a single column of text of variable sizes.
    `SINGLE_BLOCK_VERT_TEXT`: Assume a single uniform block of vertically aligned text.
    `SINGLE_BLOCK`: Assume a single uniform block of text.
    `SINGLE_LINE`: Treat the image as a single text line.
    `SINGLE_WORD`: Treat the image as a single word.
    `CIRCLE_WORD`: Treat the image as a single word in a circle.
    `SINGLE_CHAR`: Treat the image as a single character.
    `SPARSE_TEXT`: Find as much text as possible in no particular order.
    `SPARSE_TEXT_OSD`: Sparse text with orientation and script det.
    `RAW_LINE`: Treat the image as a single text line, bypassing hacks that are Tesseract-specific.
    `COUNT`: Number of enum entries.
    """

    OSD_ONLY = PSM_OSD_ONLY
    """Orientation and script detection only."""

    AUTO_OSD = PSM_AUTO_OSD
    """Automatic page segmentation with orientation and script detection. (OSD)"""

    AUTO_ONLY = PSM_AUTO_ONLY
    """Automatic page segmentation, but no OSD, or OCR."""

    AUTO = PSM_AUTO
    """Fully automatic page segmentation, but no OSD. (tesserocr default)"""

    SINGLE_COLUMN = PSM_SINGLE_COLUMN
    """Assume a single column of text of variable sizes."""

    SINGLE_BLOCK_VERT_TEXT = PSM_SINGLE_BLOCK_VERT_TEXT
    """Assume a single uniform block of vertically aligned text."""

    SINGLE_BLOCK = PSM_SINGLE_BLOCK
    """Assume a single uniform block of text. (Default.)"""

    SINGLE_LINE = PSM_SINGLE_LINE
    """Treat the image as a single text line."""

    SINGLE_WORD = PSM_SINGLE_WORD
    """Treat the image as a single word."""

    CIRCLE_WORD = PSM_CIRCLE_WORD
    """Treat the image as a single word in a circle."""

    SINGLE_CHAR = PSM_SINGLE_CHAR
    """Treat the image as a single character."""

    SPARSE_TEXT = PSM_SPARSE_TEXT
    """Find as much text as possible in no particular order."""

    SPARSE_TEXT_OSD = PSM_SPARSE_TEXT_OSD
    """Sparse text with orientation and script det."""

    RAW_LINE = PSM_RAW_LINE
    """Treat the image as a single text line, bypassing hacks that are Tesseract-specific."""

    COUNT = PSM_COUNT
    """Number of enum entries."""


cdef unicode _strip_and_free(char *text):
    """Return stripped unicode string and free the c pointer"""
    try:
        return text.strip()
    finally:
        free(text)


cdef str _image_buffer(image):
    """Return raw bytes of a PIL Image"""
    with closing(StringIO()) as f:
        image.save(f, 'BMP')
        return f.getvalue()


cdef class PyTessBaseAPI:
    """Cython wrapper class around the C++ TessBaseAPI class.

    Usage as a context manager:

    >>> with PyTessBaseAPI(path='./', lang='eng') as tesseract:
    ...     tesseract.SetImage(image)
    ...     text = tesseract.GetUTF8Text()

    Example with manual handling:

    >>> tesseract = PyTessBaseAPI(path='./', lang='eng')
    >>> try:
    ...     tesseract.SetImage(image)
    ...     text = tesseract.GetUTF8Text()
    ... finally:
    ...     tesseract.End()
    """

    cdef:
        TessBaseAPI _baseapi
        Pix *_pix

    @staticmethod
    def Version():
        return TessBaseAPI.Version()

    @staticmethod
    def ClearPersistentCache():
        return TessBaseAPI.ClearPersistentCache()

    def __cinit__(PyTessBaseAPI self, cchar_t *path=_DEFAULT_PATH,
                  cchar_t *lang=_DEFAULT_LANG, PageSegMode psm=PSM_AUTO):
        with nogil:
            self._pix = NULL
            self._init_api(path, lang, psm)

    def __dealloc__(PyTessBaseAPI self):
        self._end_api()

    cdef int _init_api(PyTessBaseAPI self, cchar_t *path, cchar_t *lang,
                        PageSegMode psm) nogil:
        cdef int res
        res = self._baseapi.Init(path, lang)
        if res != -1:
            self._baseapi.SetPageSegMode(psm)
        return res

    cdef void _end_api(PyTessBaseAPI self) nogil:
        self._destroy_pix()
        self._baseapi.End()

    cdef void _destroy_pix(PyTessBaseAPI self) nogil:
        if self._pix != NULL:
            pixDestroy(&self._pix)
            self._pix = NULL

    def GetDatapath(PyTessBaseAPI self):
        """Return tessdata parent directory"""
        return self._baseapi.GetDatapath()

    def SetVariable(PyTessBaseAPI self, const char *name, const char *val):
        """Set the value of an internal "parameter."

        Supply the name of the parameter and the value as a string, just as
        you would in a config file.

        Eg SetVariable("tessedit_char_blacklist", "xyz"); to ignore x, y and z.
        Or SetVariable("classify_bln_numeric_mode", "1"); to set numeric-only mode.

        SetVariable may be used before Init, but settings will revert to
        defaults on End().

        Args:
            name (str): parameter name
            value (str): paramter value
        Returns:
            bool: `False` if the name lookup failed.
        """
        return self._baseapi.SetVariable(name, val)

    def GetVariableAsString(PyTessBaseAPI self, const char *name):
        """Return the value of named variable as a string, if it exists."""
        cdef STRING val
        if self._baseapi.GetVariableAsString(name, &val):
            return val.string()
        return None

    def Init(PyTessBaseAPI self, cchar_t *path=_DEFAULT_PATH, cchar_t *lang=_DEFAULT_LANG,
             PageSegMode psm=PSM_AUTO):
        """Initialize the API with the given data path, lang and psm.

        It is entirely safe (and eventually will be efficient too) to call
        `Init` multiple times on the same instance to change language, or just
        to reset the classifier.

        Args:
            path (str): The name of the parent directory of tessdata.
                Must end in /.
            lang (str): An ISO 639-3 language string. Defaults to 'eng'.
                The language may be a string of the form [~]<lang>[+[~]<lang>]* indicating
                that multiple languages are to be loaded. Eg hin+eng will load Hindi and
                English. Languages may specify internally that they want to be loaded
                with one or more other languages, so the ~ sign is available to override
                that. Eg if hin were set to load eng by default, then hin+~eng would force
                loading only hin. The number of loaded languages is limited only by
                memory, with the caveat that loading additional languages will impact
                both speed and accuracy, as there is more work to do to decide on the
                applicable language, and there is more chance of hallucinating incorrect
                words.
            psm (int): Page segmentation mode. Defaults to `PSM.AUTO`.
                See :class:`tesserocr.PSM` for avaialble psm values.
        Raises:
            RuntimeError: If API initialization fails.
        """
        with nogil:
            if self._init_api(path, lang, psm) == -1:
                with gil:
                    raise RuntimeError('Failed to initialize api')

    def GetInitLanguagesAsString(PyTessBaseAPI self):
        """Return the languages string used in the last valid initialization.

        If the last initialization specified "deu+hin" then that will be
        returned. If hin loaded eng automatically as well, then that will
        not be included in this list. To find the languages actually
        loaded use `GetLoadedLanguages`.
        """
        return self._baseapi.GetInitLanguagesAsString()

    def GetLoadedLanguages(PyTessBaseAPI self):
        """Return the loaded languages as a list of STRINGs.

        Includes all languages loaded by the last Init, including those loaded
        as dependencies of other loaded languages.
        """
        cdef GenericVector[STRING] langs
        self._baseapi.GetLoadedLanguagesAsVector(&langs)
        return [langs[i].string() for i in xrange(langs.size())]

    def GetAvailableLanguages(PyTessBaseAPI self):
        """Return list of available languages in the init data path"""
        cdef:
            GenericVector[STRING] v
            int i
        langs = []
        self._baseapi.GetAvailableLanguagesAsVector(&v)
        langs = [v[i].string() for i in xrange(v.size())]
        return langs

    def ReadConfigFile(PyTessBaseAPI self, const char *filename):
        """Read a "config" file containing a set of param, value pairs.

        Searches the standard places: tessdata/configs, tessdata/tessconfigs.

        Args:
            filename: config file name. Also accepts relative or absolute path name.
        """
        self._baseapi.ReadConfigFile(filename)

    def SetPageSegMode(PyTessBaseAPI self, PageSegMode psm):
        """Set page segmentation mode.

        Args:
            psm (int): page segmentation mode.
                See :class:`~tesserocr.PSM` for all available psm options.
        """
        with nogil:
            self._baseapi.SetPageSegMode(psm)

    def GetPageSegMode(PyTessBaseAPI self):
        """Return the current page segmentation mode."""
        return self._baseapi.GetPageSegMode()

    def SetImage(PyTessBaseAPI self, image):
        """Provide an image for Tesseract to recognize.

        This method can be called multiple times after `Init`.

        Args:
            image (:class:PIL.Image): Image object.
        Raises:
            RuntimeError: If for any reason the api failed
                to load the given image.
        """
        cdef:
            cuchar_t *buff
            size_t size
            str raw

        raw = _image_buffer(image)
        buff = raw
        size = len(raw)

        with nogil:
            self._destroy_pix()
            self._pix = pixReadMemBmp(buff, size)
            if self._pix == NULL:
                with gil:
                    raise RuntimeError('Error reading image')
            self._baseapi.SetImage(self._pix)

    def SetImageFile(PyTessBaseAPI self, cchar_t *filename):
        """Set image from file for Tesserac to recognize.

        Args:
            filename (str): Image file relative or absolute path.
        Raises:
            RuntimeError: If for any reason the api failed
                to load the given image.
        """
        with nogil:
            self._destroy_pix()
            self._pix = pixRead(filename)
            if self._pix == NULL:
                with gil:
                    raise RuntimeError('Error reading image')
            self._baseapi.SetImage(self._pix)

    def SetSourceResolution(PyTessBaseAPI self, int ppi):
        """Set the resolution of the source image in pixels per inch so font size
        information can be calculated in results.

        Call this after `SetImage`.
        """
        self._baseapi.SetSourceResolution(ppi)

    def SetRectangle(PyTessBaseAPI self, int left, int top, int width, int height):
        """Restrict recognition to a sub-rectangle of the image. Call after `SetImage`.

        Each SetRectangle clears the recogntion results so multiple rectangles
        can be recognized with the same image.
        """
        self._baseapi.SetRectangle(left, top, width, height)

    def GetThresholdedImage(PyTessBaseAPI self):
        """Return a copy of the internal thresholded image from Tesseract.

        May be called any time after SetImage.
        """
        cdef:
            Pix *pix = self._baseapi.GetThresholdedImage()
            unsigned char *buff
            size_t size

        if pix == NULL:
            return None

        pixWriteMemBmp(&buff, &size, pix)
        pixDestroy(&pix)

        with closing(StringIO(<bytes>buff[:size])) as f:
            image = Image.open(f)
            image.load()

        return image

    def GetThresholdedImageScaleFactor(PyTessBaseAPI self):
        """Return the scale factor of the thresholded image that would be returned by
        GetThresholdedImage().

        Returns:
            int: 0 if no thresholder has been set.
        """
        return self._baseapi.GetThresholdedImageScaleFactor()

    def GetUTF8Text(PyTessBaseAPI self):
        """Return the recognized text coded as UTF-8 from the image."""
        cdef char *text
        with nogil:
            text = self._baseapi.GetUTF8Text()
            self._destroy_pix()
            if text == NULL:
                with gil:
                    raise RuntimeError('Failed to recognize. No image set?')
        return _strip_and_free(text)

    def AllWordConfidences(PyTessBaseAPI self):
        """Return all word confidences (between 0 and 100) as a list.

        The number of confidences should correspond to the number of space-
        delimited words in `GetUTF8Text`.
        """
        cdef:
            int *confidences = self._baseapi.AllWordConfidences()
            int confidence
            size_t i = 0

        confs = []
        while confidences[i] != -1:
            confidence = confidences[i]
            confs.append(confidence)
            i += 1
        free(confidences)
        return confs

    def AdaptToWordStr(PyTessBaseAPI self, PageSegMode psm, const char *word):
        """Apply the given word to the adaptive classifier if possible.

        Assumes that `SetImage` / `SetRectangle` have been used to set the image
        to the given word.

        Args:
            psm (int): Should be `PSM.SINGLE_WORD` or
                `PSM.CIRCLE_WORD`, as that will be used to control layout analysis.
                The currently set PageSegMode is preserved.
            word (str): The word must be SPACE-DELIMITED UTF-8 - l i k e t h i s , so it can
                tell the boundaries of the graphemes.
        Returns:
            bool: `False` if adaption was not possible for some reason.
        """
        return self._baseapi.AdaptToWordStr(psm, word)

    def Clear(PyTessBaseAPI self):
        """Free up recognition results and any stored image data, without actually
        freeing any recognition data that would be time-consuming to reload.
        """
        with nogil:
            self._destroy_pix()
            self._baseapi.Clear()

    def End(PyTessBaseAPI self):
        """Close down tesseract and free up all memory."""
        with nogil:
            self._end_api()

    def __enter__(PyTessBaseAPI self):
        return self

    def __exit__(PyTessBaseAPI self, exc_tp, exc_val, exc_tb):
        with nogil:
            self._end_api()
        return False


cdef char *_image_to_text(Pix *pix, const char *lang, const PageSegMode pagesegmode,
                          const char *path) nogil:
    cdef:
        TessBaseAPI baseapi
        char *text

    if baseapi.Init(path, lang) == -1:
        return NULL

    baseapi.SetPageSegMode(pagesegmode)
    baseapi.SetImage(pix)
    text = baseapi.GetUTF8Text()
    pixDestroy(&pix)
    baseapi.End()

    return text


def image_to_text(image, cchar_t *lang=_DEFAULT_LANG, PageSegMode psm=PSM_AUTO,
                   cchar_t *path=_DEFAULT_PATH):
    """Recognize OCR text from an image object.

    Args:
        image (:class:`PIL.Image`): image to be processed.
    Kwargs:
        lang (str): An ISO 639-3 language string. Defaults to 'eng'.
        psm (int): Page segmentation mode. Defaults to `PSM.AUTO`.
            See :class:`~tesserocr.PSM` for all available psm options.
        path (str): The name of the parent directory of tessdata.
            Must end in /.
    Returns:
        unicode: The text extracted from the image.
    Raises:
        RuntimeError: When image fails to be loaded or recognition fails.
    """
    cdef:
        Pix *pix
        cuchar_t *buff
        size_t size
        char *text
        str raw

    raw = _image_buffer(image)
    buff = raw
    size = len(raw)

    with nogil:
        pix = pixReadMemBmp(buff, size)
        if pix == NULL:
            with gil:
                raise RuntimeError('Failed to read picture')
        text = _image_to_text(pix, lang, psm, path)
        if text == NULL:
            with gil:
                raise RuntimeError('Failed recognize picture')

    return _strip_and_free(text)


def file_to_text(cchar_t *filename, cchar_t *lang=_DEFAULT_LANG, PageSegMode psm=PSM_AUTO,
                 cchar_t *path=_DEFAULT_PATH):
    """Extract OCR text from an image file.

    Args:
        filename (str): Image file relative or absolute path.
    Kwargs:
        lang (str): An ISO 639-3 language string. Defaults to 'eng'
        psm (int): Page segmentation mode. Defaults to `PSM.AUTO`
            See :class:`~tesserocr.PSM` for all available psm options.
        path (str): The name of the parent directory of tessdata.
            Must end in /.
    Returns:
        unicode: The text extracted from the image.
    Raises:
        RuntimeError: When image fails to be loaded or recognition fails.
    """
    cdef:
        Pix *pix
        char *text

    with nogil:
        pix = pixRead(filename)
        if pix == NULL:
            with gil:
                raise RuntimeError('Failed to read picture')
        text = _image_to_text(pix, lang, psm, path)
        if text == NULL:
            with gil:
                raise RuntimeError('Failed recognize picture')

    return _strip_and_free(text)


def tesseract_version():
    """Return tesseract-ocr and leptonica version info"""
    version_str = u"tesseract {}\n {}\n  {}"
    tess_v = TessBaseAPI.Version()
    lept_v = _strip_and_free(getLeptonicaVersion())
    libs_v = _strip_and_free(getImagelibVersions())
    return version_str.format(tess_v, lept_v, libs_v)


def get_languages(cchar_t *path=_DEFAULT_PATH):
    """Return available languages in the given path.

    Args:
        path (str): The name of the parent directory of tessdata.
            Must end in /. Default tesseract-ocr datapath is used
            if no path is provided.
    Retruns
        tuple: Tuple with two elements:
            - path (str): tessdata parent directory path
            - languages (list): list of available languages as ISO 639-3 strings.
    """
    cdef:
        TessBaseAPI baseapi
        GenericVector[STRING] v
        int i
    baseapi.Init(path, NULL)
    path = baseapi.GetDatapath()
    baseapi.GetAvailableLanguagesAsVector(&v)
    langs = [v[i].string() for i in xrange(v.size())]
    baseapi.End()
    return path, langs
