from PIL import Image
from cStringIO import StringIO
from contextlib import closing
from tesseract cimport *


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


cdef unicode _u(char *text):
    """Return UTF-8 unicode stripped string"""
    return text.decode('UTF-8').strip()


cdef str _image_buffer(image):
    """Return raw bytes of a PIL Image"""
    with closing(StringIO()) as f:
        image.save(f, 'BMP')
        return f.getvalue()


cdef class PyTessBaseAPI:
    """Cython wrapper class for C++ TessBaseAPI.

    Instances of this class are context managers which conviently handles initializing
    and terminating the Tesseract API for you.
    """

    cdef:
        TessBaseAPI _baseapi
        Pix *_pix

    def __cinit__(PyTessBaseAPI self):
        self._pix = NULL

    def __dealloc__(PyTessBaseAPI self):
        self.End()

    cdef void _destroy_pix(PyTessBaseAPI self) nogil:
        if self._pix != NULL:
            pixDestroy(&self._pix)
            self._pix = NULL

    cdef int _init_api(PyTessBaseAPI self, const char *path, const char* lang) nogil:
        cdef int res = self._baseapi.Init(path, lang)
        self._baseapi.SetPageSegMode(PSM_AUTO)  # default tesserocr psm
        return res

    def Init(PyTessBaseAPI self, const char *path=NULL, const char* lang=NULL):
        """Initialize tesseract API.

        Args:
            path (str): The name of the parent directory of tessdata.
                Must end in /.
            lang: An ISO 639-3 language string. Defaults to 'eng'.
        Retruns:
            int: 0 on success, -1 on failure.
        """
        cdef int res
        with nogil:
            res = self._init_api(path, lang)
        return res

    def GetDatapath(PyTessBaseAPI self):
        """Return tessdata parent directory"""
        return self._baseapi.GetDatapath()

    def GetAvailableLanguages(PyTessBaseAPI self):
        """Return list of available languages"""
        cdef:
            GenericVector[STRING] v
            int i
        langs = []
        self._baseapi.GetAvailableLanguagesAsVector(&v)
        langs = [v[i].string() for i in xrange(v.size())]
        return langs

    def SetPageSegMode(PyTessBaseAPI self, PageSegMode psm):
        """Set page segmentation mode.

        Args:
            psm (int): page segmentation mode.
                See :class:`~tesserocr.PSM` for all available psm options.
        """
        with nogil:
            self._baseapi.SetPageSegMode(psm)

    def SetImage(PyTessBaseAPI self, image):
        """Set image object to recognize.

        Args:
            image (:class:PIL.Image): Image object.
        Raises:
            RuntimeError: If for any reason the api failed
                to load the given image.
        """
        cdef:
            const unsigned char *buff
            size_t size
            str raw

        raw = _image_buffer(image)
        buff = raw
        size = len(raw)

        with nogil:
            self._destroy_pix()
            self._pix = pixReadMemBmp(buff, size)
            if not self._pix:
                self._pix = NULL
                with gil:
                    raise RuntimeError('Error reading image')
            self._baseapi.SetImage(self._pix)

    def SetImageFile(PyTessBaseAPI self, const char *image_file):
        """Set image from file to recognize.

        Args:
            image (str): Image file path.
        Raises:
            RuntimeError: If for any reason the api failed
                to load the given image.
        """
        with nogil:
            self._destroy_pix()
            self._pix = pixRead(image_file)
            if not self._pix:
                self._pix = NULL
                with gil:
                    raise RuntimeError('Error reading image')
            self._baseapi.SetImage(self._pix)

    def GetUTF8Text(PyTessBaseAPI self):
        """Return the recognized text from the image."""
        cdef char *text
        with nogil:
            text = self._baseapi.GetUTF8Text()
            self._destroy_pix()
            if text == NULL:
                with gil:
                    raise RuntimeError('Failed to recognize. No image set?')
        return _u(text)

    def Clear(PyTessBaseAPI self):
        """Free up recognition results and any stored image data, without actually
        freeing any recognition data that would be time-consuming to reload.
        """
        with nogil:
            self._destroy_pix()
            self._baseapi.Clear()

    cpdef void End(PyTessBaseAPI self):
        """Close down tesseract and free up all memory."""
        with nogil:
            self._destroy_pix()
            self._baseapi.End()

    def __enter__(PyTessBaseAPI self, const char *path=NULL, const char *lang=NULL):
        with nogil:
            if self._init_api(path, lang) == -1:
                with gil:
                    raise RuntimeError('Failed to initialize Tesseract API')
        return self

    def __exit__(PyTessBaseAPI self, exc_tp, exc_val, exc_tb):
        self.End()


cdef char *_image_to_text(Pix *pix, const char *lang,
                          const PageSegMode pagesegmode, const char *path) nogil except NULL:
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


def image_to_text(image, const char *lang=NULL, const PageSegMode pagesegmode=PSM_AUTO,
                  const char *path=NULL):
    """Recognize OCR text from an image object.

    Args:
        image (:class:`PIL.Image`): image to be processed.
    Kwargs:
        lang (str): An ISO 639-3 language string. Defaults to 'eng'.
        pagesegmode (int): Page segmentation mode. Defaults to `PSM.AUTO`.
            See :class:`~tesserocr.PSM` for all available psm options.
        path (str): The name of the parent directory of tessdata.
            Must end in /.
    Returns:
        str: The text extracted from the image.
    Raises:
        RuntimeError: When image fails to be loaded or recognition fails.
    """
    cdef:
        Pix *pix
        const unsigned char *buff
        size_t size
        char *text
        str raw

    raw = _image_buffer(image)
    buff = raw
    size = len(raw)

    with nogil:
        pix = pixReadMemBmp(buff, size)
        if not pix:
            with gil:
                raise RuntimeError('Failed to read image.')
        text = _image_to_text(pix, lang, pagesegmode, path)
        if text == NULL:
            with gil:
                raise RuntimeError('Failed to recognize image text.')
    return _u(text)


def file_to_text(const char *image_file, const char *lang=NULL, const PageSegMode pagesegmode=PSM_AUTO,
                  const char *path=NULL):
    """Extract OCR text from an image file.

    Args:
        image_file (str): image file path.
    Kwargs:
        lang (str): An ISO 639-3 language string. Defaults to 'eng'
        pagesegmode (int): Page segmentation mode. Defaults to `PSM.AUTO`
            See :class:`~tesserocr.PSM` for all available psm options.
        path (str): The name of the parent directory of tessdata.
            Must end in /.
    Returns:
        str: The text extracted from the image.
    Raises:
        RuntimeError: When image fails to be loaded or recognition fails.
    """
    cdef:
        Pix *pix
        char *text

    with nogil:
        pix = pixRead(image_file)
        if not pix:
            with gil:
                raise RuntimeError('Failed to read image.')
        text = _image_to_text(pix, lang, pagesegmode, path)
        if text == NULL:
            with gil:
                raise RuntimeError('Failed to recognize image text.')
    return _u(text)


def tesseract_version():
    """Return tesseract-ocr and leptonica version info"""
    version_str = "tesseract {}\n {}\n  {}"
    return version_str.format(TessBaseAPI.Version(), getLeptonicaVersion(), getImagelibVersions())


def get_languages(const char *path=NULL):
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
