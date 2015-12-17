from PIL import Image
from cStringIO import StringIO
from tesseract cimport *


cdef class PSM:
    # Orientation and script detection only.
    OSD_ONLY = PSM_OSD_ONLY
    # Automatic page segmentation with orientation and script detection. (OSD)
    AUTO_OSD = PSM_AUTO_OSD
    # Automatic page segmentation, but no OSD, or OCR.
    AUTO_ONLY = PSM_AUTO_ONLY
    # Fully automatic page segmentation, but no OSD. (tesserocr default)
    AUTO = PSM_AUTO
    # Assume a single column of text of variable sizes.
    SINGLE_COLUMN = PSM_SINGLE_COLUMN
    # Assume a single uniform block of vertically aligned text.
    SINGLE_BLOCK_VERT_TEXT = PSM_SINGLE_BLOCK_VERT_TEXT
    # Assume a single uniform block of text. (Default.)
    SINGLE_BLOCK = PSM_SINGLE_BLOCK
    # Treat the image as a single text line.
    SINGLE_LINE = PSM_SINGLE_LINE
    # Treat the image as a single word.
    SINGLE_WORD = PSM_SINGLE_WORD
    # Treat the image as a single word in a circle.
    CIRCLE_WORD = PSM_CIRCLE_WORD
    # Treat the image as a single character.
    SINGLE_CHAR = PSM_SINGLE_CHAR
    # Find as much text as possible in no particular order.
    SPARSE_TEXT = PSM_SPARSE_TEXT
    # Sparse text with orientation and script det.
    SPARSE_TEXT_OSD = PSM_SPARSE_TEXT_OSD
    # Treat the image as a single text line, bypassing hacks that are Tesseract-specific.
    RAW_LINE = PSM_RAW_LINE
    # Number of enum entries.
    COUNT = PSM_COUNT


cdef char *_image_to_text(const unsigned char *buff, const size_t len_, const char *lang,
                          const PageSegMode pagesegmode) nogil:
    cdef TessBaseAPI baseapi
    cdef Pix *pix
    cdef char *text
    with nogil:
        pix = pixReadMemBmp(buff, len_)
        try:
            baseapi.Init(NULL, lang)
            baseapi.SetPageSegMode(pagesegmode)
            baseapi.SetImage(pix)
            text = baseapi.GetUTF8Text()
        finally:
            pixDestroy(&pix)
            baseapi.End()
        return text


def image_to_text(image, const char *lang=NULL, const PageSegMode pagesegmode=PSM_AUTO):
    """extract OCR text from image.

    parameters:
    - image: `PIL.Image` object
    - lang: ISO 639-3 string (eng by default)
    - pagesegmode: Page seg mode. Default to `PSM.AUTO`
    """
    buff = StringIO()
    image.save(buff, 'BMP')
    v = buff.getvalue()
    return _image_to_text(v, len(v), lang, pagesegmode).strip()


def tesseract_version():
    return TessBaseAPI.Version()
