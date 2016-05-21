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
    """Read image meta data from unsafe pointers."""
    cdef uintptr_t buff_ptr
    # get buffer from unsafe pointers without copying it
    image.load()
    ptrs = dict(image.im.unsafe_ptrs)
    width[0] = ptrs['xsize']
    height[0] = ptrs['ysize']
    buff_ptr = ptrs['image']
    buff[0] = (<cuchar_t **>buff_ptr)[0]
    bpp[0] = ptrs['pixelsize']
    bpl[0] = ptrs['linesize']
    # for f in ptrs:
    #     name = f[0]
    #     if name == 'xsize':  # width
    #         width[0] = f[1]
    #     elif name == 'ysize':  # height
    #         height[0] = f[1]
    #     elif name == 'image':  # buffer address
    #         buff_ptr = f[1]
    #         buff[0] = (<cuchar_t **>buff_ptr)[0]
    #     elif name == 'pixelsize':  # bytes_per_pixel
    #         bpp[0] = f[1]
    #     elif name == 'linesize':  # bytes_per_line
    #         bpl[0] = f[1]


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
    # print width, height
    # print bpp
    # print bpl

    with nogil:
        text = _image_to_text2(buff, width, height, bpp, bpl,
                               lang, pagesegmode, path)
        if text == NULL:
            with gil:
                raise RuntimeError('Failed to recognize image text.')
    return _free_str(text)


cdef Pix *raw_to_pix(cuchar_t *buff, int bpp, int width, int height, int bpl) nogil:
    """Convert PIL image to Pix.

    Applies the same logic done by tesseract's api.SetImage."""
    cdef:
        int x
        int y
        int wpl
        uint *data
        Pix *pix
    bpp = bpp * 8
    pix = pixCreate(width, height, 32 if bpp == 24 else bpp)
    wpl = pixGetWpl(pix)
    data = pixGetData(pix)
    if bpp == 8:
        # Greyscale just copies the bytes in the right order.
        for y in xrange(height):
            for x in xrange(width):
                SET_DATA_BYTE(data, x, buff[x])
            data += wpl
            buff += bpl
    elif bpp == 24:
        # Put the colors in the correct places in the line buffer.
        for y in xrange(height):
            for x in xrange(width):
                SET_DATA_BYTE(data, COLOR_RED, buff[3 * x])
                SET_DATA_BYTE(data, COLOR_GREEN, buff[3 * x + 1])
                SET_DATA_BYTE(data, COLOR_BLUE, buff[3 * x + 2])
                data += 1
            buff += bpl
    elif bpp == 32:
        # Maintain byte order consistency across different endianness.
        for y in xrange(height):
            for x in xrange(width):
                data[x] = (buff[x * 4] << 24) | (buff[x * 4 + 1] << 16) | (buff[x * 4 + 2] << 8) | buff[x * 4 + 3]
            data += wpl
            buff += bpl
    else:
        with gil:
            raise RuntimeError("Cannot convert RAW image to Pix with bpp = {}".format(bpp))
    return pix

def image_to_text3(image, const char *lang=_DEFAULT_LANG, const PageSegMode psm=PSM_AUTO,
                   const char *path=_DEFAULT_PATH):
    cdef:
        Pix *pix
        cuchar_t *buff = NULL
        int width = 0
        int height = 0
        int bpp = 0
        int bpl = 0
        char *text

    _image_buffer2(image, &buff, &width, &height, &bpp, &bpl)

    with nogil:
        pix = raw_to_pix(buff, bpp, width, height, bpl)
        text = _image_to_text(pix, lang, psm, path)
        if text == NULL:
            with gil:
                raise RuntimeError('Failed recognize picture')

    return _free_str(text)
