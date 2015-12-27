# An attemp to address the PIL.Image buffer directly without copying it.
#
# This is achieved by extracting the buffer ptr from Image.im.unsafe_ptrs
# the xsize, ysize, pixelsize and linesize are extracted as well to be used
# in TessBaseAPI.SetImage(buffer, width, height, bytes_per_pixel, bytes_per_line)
#
# This works but for sometimes the output is different than the original code. I assume
# this is due to the different image format used in this method.
#
# The performance advantage was not significant based on benchmarks on my machine.
from libc.stdint cimport uintptr_t

cdef object _mode_to_bpp = {'1':1, 'L':8, 'P':8, 'RGB':24, 'RGBA':32, 'CMYK':32, 'YCbCr':24, 'I':32, 'F':32}


cdef void _image_buffer2(image, cuchar_t **buff, int *width, int *height,
                         int *bpp, int *bpl):
    cdef uintptr_t buff_ptr
    # get buffer from unsafe pointers without copying it
    image.load()
    ptrs = image.im.unsafe_ptrs
    for f in ptrs:
        name = f[0]
        if name == 'xsize':  # width
            width[0] = f[1]
        elif name == 'ysize':  # height
            height[0] = f[1]
        elif name == 'image':  # buffer address
            buff_ptr = f[1]
            buff[0] = (<cuchar_t **>buff_ptr)[0]
        elif name == 'pixelsize':  # bytes_per_pixel
            bpp[0] = f[1]
        elif name == 'linesize':  # bytes_per_line
            bpl[0] = f[1]


cdef char *_image_to_text2(const unsigned char *buff, int width, int height, int bpp, int bpl,
                          const char *lang,
                          const PageSegMode pagesegmode, const char *path) nogil except NULL:
    cdef:
        TessBaseAPI baseapi
        char *text

    if baseapi.Init(path, lang) == -1:
        return NULL

    baseapi.SetPageSegMode(pagesegmode)
    baseapi.SetImage(buff, width, height, bpp, bpl)
    text = baseapi.GetUTF8Text()
    baseapi.End()
    return text


def image_to_text2(image, const char *lang=_DEFAULT_LANG, const PageSegMode pagesegmode=PSM_AUTO,
                   const char *path=_DEFAULT_PATH):
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
        cuchar_t *buff = NULL
        int width = 0
        int height = 0
        int bpp = 0
        int bpl = 0
        char *text

    _image_buffer2(image, &buff, &width, &height, &bpp, &bpl)

    with nogil:
        text = _image_to_text2(buff, width, height, bpp, bpl,
                               lang, pagesegmode, path)
        if text == NULL:
            with gil:
                raise RuntimeError('Failed to recognize image text.')
    return _strip_and_free(text)
