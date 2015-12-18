from PIL import Image
from cStringIO import StringIO
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


cdef char *_image_to_text(const unsigned char *buff, const size_t len_, const char *lang,
                          const PageSegMode pagesegmode) nogil except NULL:
    cdef TessBaseAPI baseapi
    cdef Pix *pix
    cdef char *text
    with nogil:
        if baseapi.Init(NULL, lang) == -1:
            return NULL
        pix = pixReadMemBmp(buff, len_)
        baseapi.SetPageSegMode(pagesegmode)
        baseapi.SetImage(pix)
        text = baseapi.GetUTF8Text()
        pixDestroy(&pix)
        baseapi.End()
        return text


def image_to_text(image, const char *lang=NULL, const PageSegMode pagesegmode=PSM_AUTO):
    """Extract OCR text from an image.

    Args:
        image (:class:`PIL.Image`): image to be processed.
    Kwargs:
        lang (str): An ISO 639-3 language string. Defaults to 'eng'
        pagesegmode (int): Page segmentation mode. Defaults to `PSM.AUTO`
            See :class:`~tesserocr.PSM` for all available psm options.
    Returns:
        str: The text extract from the image.
    """
    buff = StringIO()
    image.save(buff, 'BMP')
    v = buff.getvalue()
    return _image_to_text(v, len(v), lang, pagesegmode).strip()


def tesseract_version():
    """Return tesseract-ocr version number"""
    return TessBaseAPI.Version()
