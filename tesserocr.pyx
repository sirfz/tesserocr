#!python
#cython: c_string_type=unicode, c_string_encoding=utf-8
"""Python wrapper around the Tesseract-OCR C++ API

This module provides a wrapper class :class:`PyTessBaseAPI` to call
Tesseract API methods. See :class:`PyTessBaseAPI` for details.

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

__version__ = '2.3.0'

import os
from io import BytesIO
from os.path import abspath, join
try:
    from PIL import Image
except ImportError:
    # PIL.Image won't be supported
    pass

from tesseract cimport *
from libc.stdlib cimport malloc, free
from cpython.version cimport PY_MAJOR_VERSION


cdef bytes _b(s):
    if PY_MAJOR_VERSION > 3:
        if isinstance(s, str):
            return s.encode('UTF-8')
    elif isinstance(s, unicode):
        return s.encode('UTF-8')
    return s


# default parameters
setMsgSeverity(L_SEVERITY_NONE)  # suppress leptonica error messages
cdef TessBaseAPI _api = TessBaseAPI()
_api.SetVariable('debug_file', '/dev/null')  # suppress tesseract debug messages
_api.Init(NULL, NULL)
IF TESSERACT_VERSION >= 0x040000:
    cdef _DEFAULT_PATH = _api.GetDatapath()  # "tessdata/" is not appended by tesseract since commit dba13db
ELSE:
    cdef _DEFAULT_PATH = abspath(join(_api.GetDatapath(), os.pardir)) + os.sep
_init_lang = _api.GetInitLanguagesAsString()
if _init_lang == '':
    _init_lang = 'eng'
cdef _DEFAULT_LANG = _init_lang
_api.End()
TessBaseAPI.ClearPersistentCache()


cdef class _Enum:

    def __init__(self):
        raise TypeError('{} is an enum and cannot be instantiated'.format(type(self).__name__))


cdef class OEM(_Enum):
    """An enum that defines avaialble OCR engine modes.

    Attributes:
        TESSERACT_ONLY: Run Tesseract only - fastest
        LSTM_ONLY: Run just the LSTM line recognizer. (>=v4.00)
        TESSERACT_LSTM_COMBINED: Run the LSTM recognizer, but allow fallback
            to Tesseract when things get difficult. (>=v4.00)
        CUBE_ONLY: Specify this mode when calling Init*(), to indicate that
            any of the above modes should be automatically inferred from the
            variables in the language-specific config, command-line configs, or
            if not specified in any of the above should be set to the default
            `OEM.TESSERACT_ONLY`.
        TESSERACT_CUBE_COMBINED: Run Cube only - better accuracy, but slower.
        DEFAULT: Run both and combine results - best accuracy.
    """

    TESSERACT_ONLY = OEM_TESSERACT_ONLY
    IF TESSERACT_VERSION >= 0x040000:
        LSTM_ONLY = OEM_LSTM_ONLY
        TESSERACT_LSTM_COMBINED = OEM_TESSERACT_LSTM_COMBINED
    ELSE:
        CUBE_ONLY = OEM_CUBE_ONLY
        TESSERACT_CUBE_COMBINED = OEM_TESSERACT_CUBE_COMBINED
    DEFAULT = OEM_DEFAULT


cdef class PSM(_Enum):
    """An enum that defines all available page segmentation modes.

    Attributes:
        OSD_ONLY: Orientation and script detection only.
        AUTO_OSD: Automatic page segmentation with orientation and script detection. (OSD)
        AUTO_ONLY: Automatic page segmentation, but no OSD, or OCR.
        AUTO: Fully automatic page segmentation, but no OSD. (:mod:`tesserocr` default)
        SINGLE_COLUMN: Assume a single column of text of variable sizes.
        SINGLE_BLOCK_VERT_TEXT: Assume a single uniform block of vertically aligned text.
        SINGLE_BLOCK: Assume a single uniform block of text.
        SINGLE_LINE: Treat the image as a single text line.
        SINGLE_WORD: Treat the image as a single word.
        CIRCLE_WORD: Treat the image as a single word in a circle.
        SINGLE_CHAR: Treat the image as a single character.
        SPARSE_TEXT: Find as much text as possible in no particular order.
        SPARSE_TEXT_OSD: Sparse text with orientation and script det.
        RAW_LINE: Treat the image as a single text line, bypassing hacks that are Tesseract-specific.
        COUNT: Number of enum entries.
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


cdef class RIL(_Enum):
    """An enum that defines available Page Iterator levels.

    Attributes:
        BLOCK: of text/image/separator line.
        PARA: within a block.
        TEXTLINE: within a paragraph.
        WORD: within a textline.
        SYMBOL: character within a word.
    """

    BLOCK = RIL_BLOCK
    """of text/image/separator line."""

    PARA = RIL_PARA
    """within a block."""

    TEXTLINE = RIL_TEXTLINE
    """within a paragraph."""

    WORD = RIL_WORD
    """within a textline."""

    SYMBOL = RIL_SYMBOL
    """character within a word."""


cdef class PT(_Enum):
    """An enum the defines avaialbe Poly Block types.

    Attributes:
        UNKNOWN: Type is not yet known. Keep as the first element.
        FLOWING_TEXT: Text that lives inside a column.
        HEADING_TEXT: Text that spans more than one column.
        PULLOUT_TEXT: Text that is in a cross-column pull-out region.
        EQUATION: Partition belonging to an equation region.
        INLINE_EQUATION: Partition has inline equation.
        TABLE: Partition belonging to a table region.
        VERTICAL_TEXT: Text-line runs vertically.
        CAPTION_TEXT: Text that belongs to an image.
        FLOWING_IMAGE: Image that lives inside a column.
        HEADING_IMAGE: Image that spans more than one column.
        PULLOUT_IMAGE: Image that is in a cross-column pull-out region.
        HORZ_LINE: Horizontal Line.
        VERT_LINE: Vertical Line.
        NOISE: Lies outside of any column.
        COUNT: Count
    """

    UNKNOWN = PT_UNKNOWN
    """Type is not yet known. Keep as the first element."""

    FLOWING_TEXT = PT_FLOWING_TEXT
    """Text that lives inside a column."""

    HEADING_TEXT = PT_HEADING_TEXT
    """Text that spans more than one column."""

    PULLOUT_TEXT = PT_PULLOUT_TEXT
    """Text that is in a cross-column pull-out region."""

    EQUATION = PT_EQUATION
    """Partition belonging to an equation region."""

    INLINE_EQUATION = PT_INLINE_EQUATION
    """Partition has inline equation."""

    TABLE = PT_TABLE
    """Partition belonging to a table region."""

    VERTICAL_TEXT = PT_VERTICAL_TEXT
    """Text-line runs vertically."""

    CAPTION_TEXT = PT_CAPTION_TEXT
    """Text that belongs to an image."""

    FLOWING_IMAGE = PT_FLOWING_IMAGE
    """Image that lives inside a column."""

    HEADING_IMAGE = PT_HEADING_IMAGE
    """Image that spans more than one column."""

    PULLOUT_IMAGE = PT_PULLOUT_IMAGE
    """Image that is in a cross-column pull-out region."""

    HORZ_LINE = PT_HORZ_LINE
    """Horizontal Line."""

    VERT_LINE = PT_VERT_LINE
    """Vertical Line."""

    NOISE = PT_NOISE
    """Lies outside of any column."""

    COUNT = PT_COUNT


cdef class Orientation(_Enum):
    """Enum for orientation options."""

    PAGE_UP = ORIENTATION_PAGE_UP
    PAGE_RIGHT = ORIENTATION_PAGE_RIGHT
    PAGE_DOWN = ORIENTATION_PAGE_DOWN
    PAGE_LEFT = ORIENTATION_PAGE_LEFT


cdef class WritingDirection(_Enum):
    """Enum for writing direction options."""

    LEFT_TO_RIGHT = WRITING_DIRECTION_LEFT_TO_RIGHT
    RIGHT_TO_LEFT = WRITING_DIRECTION_RIGHT_TO_LEFT
    TOP_TO_BOTTOM = WRITING_DIRECTION_TOP_TO_BOTTOM


cdef class TextlineOrder(_Enum):
    """Enum for text line order options."""

    LEFT_TO_RIGHT = TEXTLINE_ORDER_LEFT_TO_RIGHT
    RIGHT_TO_LEFT = TEXTLINE_ORDER_RIGHT_TO_LEFT
    TOP_TO_BOTTOM = TEXTLINE_ORDER_TOP_TO_BOTTOM


cdef class Justification(_Enum):
    """Enum for justification options."""

    UNKNOWN = JUSTIFICATION_UNKNOWN
    LEFT = JUSTIFICATION_LEFT
    CENTER = JUSTIFICATION_CENTER
    RIGHT = JUSTIFICATION_RIGHT


cdef class DIR(_Enum):
    """Enum for strong text direction values.

    Attributes:
        NEUTRAL: Text contains only neutral characters.
        LEFT_TO_RIGHT: Text contains no Right-to-Left characters.
        RIGHT_TO_LEFT: Text contains no Left-to-Right characters.
        MIX: Text contains a mixture of left-to-right and right-to-left characters.
    """

    NEUTRAL = DIR_NEUTRAL
    """Text contains only neutral characters."""
    LEFT_TO_RIGHT = DIR_LEFT_TO_RIGHT
    """Text contains no Right-to-Left characters."""
    RIGHT_TO_LEFT = DIR_RIGHT_TO_LEFT
    """Text contains no Left-to-Right characters."""
    MIX = DIR_MIX
    """Text contains a mixture of left-to-right
    and right-to-left characters."""


cdef unicode _free_str(char *text):
    """Return unicode string and free the c pointer"""
    try:
        return text
    finally:
        free(text)


cdef bytes _image_buffer(image):
    """Return raw bytes of a PIL Image"""
    with BytesIO() as f:
        image.save(f, image.format or 'JPEG')
        return f.getvalue()


cdef _pix_to_image(Pix *pix):
    """Convert Pix object to PIL.Image."""
    cdef:
        unsigned char *buff
        size_t size
        int result
        int fmt = pix.informat
    if fmt > 0:
        result = pixWriteMem(&buff, &size, pix, fmt)
    else:
        # write as JPEG if format is unknown
        result = pixWriteMemJpeg(&buff, &size, pix, 0, 0)

    try:
        if result == 1:
            raise RuntimeError("Failed to convert pix image to PIL.Image")
        with BytesIO(<bytes>buff[:size]) as f:
            image = Image.open(f)
            image.load()
    finally:
        free(buff)

    return image


cdef boxa_to_list(Boxa *boxa):
    """Convert Boxa (boxes array) to list of boxes dicts."""
    boxes = []
    for box in boxa.box[:boxa.n]:
       boxes.append(box[0])
    return boxes


cdef pixa_to_list(Pixa *pixa):
    """Convert Pixa (Array of pixes and boxes) to list of pix, box tuples."""
    return zip((_pix_to_image(pix) for pix in pixa.pix[:pixa.n]), boxa_to_list(pixa.boxa))


cdef class PyPageIterator:
    """Wrapper around Tesseract's ``PageIterator`` class.
    Returned by :meth:`PyTessBaseAPI.AnalyseLayout`.

    Instances of this class and its subclasses cannot be instantiated from Python.

    Accessing data
    ==============

    Coordinate system:

    Integer coordinates are at the cracks between the pixels.
    The top-left corner of the top-left pixel in the image is at (0,0).
    The bottom-right corner of the bottom-right pixel in the image is at
    (width, height).

    Every bounding box goes from the top-left of the top-left contained
    pixel to the bottom-right of the bottom-right contained pixel, so
    the bounding box of the single top-left pixel in the image is:
    (0,0)->(1,1).

    If an image rectangle has been set in the API, then returned coordinates
    relate to the original (full) image, rather than the rectangle.

    .. note::

        You can iterate through the elements of a level using the :func:`iterate_level`
        helper function:

        >>> for e in iterate_level(api.AnalyseLayout(), RIL.WORD):
        ...     orientation = e.Orientation()

    .. warning::

        This class points to data held within the :class:`PyTessBaseAPI`
        instance, and therefore can only be used while the :class:`PyTessBaseAPI`
        instance still exists and has not been subjected to a call of :meth:`Init`,
        :meth:`SetImage`, :meth:`Recognize`, :meth:`Clear`, :meth:`End`,
        or anything else that changes the internal `PAGE_RES`.
    """

    cdef PageIterator *_piter

    @staticmethod
    cdef PyPageIterator createPageIterator(PageIterator *piter):
        cdef PyPageIterator pyiter = PyPageIterator.__new__(PyPageIterator)
        pyiter._piter = piter
        return pyiter

    def __cinit__(self):
        self._piter = NULL

    def __dealloc__(self):
        if self._piter != NULL:
            del self._piter

    def __init__(self):
        raise TypeError('{} cannot be instantiated from Python'.format(type(self).__name__))

    def Begin(self):
        """Move the iterator to point to the start of the page to begin an iteration."""
        self._piter.Begin()

    def RestartParagraph(self):
        """Move the iterator to the beginning of the paragraph.

        This class implements this functionality by moving it to the zero indexed
        blob of the first (leftmost) word on the first row of the paragraph.
        """
        self._piter.RestartParagraph()

    def IsWithinFirstTextlineOfParagraph(self):
        """Return whether this iterator points anywhere in the first textline of a
        paragraph."""
        return self._piter.IsWithinFirstTextlineOfParagraph()

    def RestartRow(self):
        """Move the iterator to the beginning of the text line.

        This class implements this functionality by moving it to the zero indexed
        blob of the first (leftmost) word of the row.
        """
        return self._piter.RestartRow()

    def Next(self, PageIteratorLevel level):
        """Move to the start of the next object at the given level in the
        page hierarchy, and returns false if the end of the page was reached.

        .. note::

            :attr:`RIL.SYMBOL` will skip non-text blocks, but all other
            :class:`RIL` level values will visit each non-text block once.

        Think of non text blocks as containing a single para, with a single line,
        with a single imaginary word.

        Calls to Next with different levels may be freely intermixed.
        This function iterates words in right-to-left scripts correctly, if
        the appropriate language has been loaded into Tesseract.

        Args:
            level (int): Iterator level. See :class:`RIL`.
        """
        return self._piter.Next(level)

    def IsAtBeginningOf(self, PageIteratorLevel level):
        """Return whether the iterator is at the start of an object at the given
        level.

        For instance, suppose an iterator it is pointed to the first symbol of the
        first word of the third line of the second paragraph of the first block in
        a page, then::

            it.IsAtBeginningOf(RIL.BLOCK) is False
            it.IsAtBeginningOf(RIL.PARA) is False
            it.IsAtBeginningOf(RIL.TEXTLINE) is True
            it.IsAtBeginningOf(RIL.WORD) is True
            it.IsAtBeginningOf(RIL.SYMBOL) is True

        Args:
            level (int): Iterator level. See :class:`RIL`.

        Returns:
            bool: ``True`` if the iterator is at the start of an object at the
                given level.
        """
        return self._piter.IsAtBeginningOf(level)

    def IsAtFinalElement(self, PageIteratorLevel level, PageIteratorLevel element):
        """Return whether the iterator is positioned at the last element in a
        given level. (e.g. the last word in a line, the last line in a block)

        Here's some two-paragraph example
        text:

            It starts off innocuously
            enough but quickly turns bizarre.
            The author inserts a cornucopia
            of words to guard against confused
            references.

        Now take an iterator ``it`` pointed to the start of "bizarre."

            it.IsAtFinalElement(RIL.PARA, RIL.SYMBOL) = False
            it.IsAtFinalElement(RIL.PARA, RIL.WORD) = True
            it.IsAtFinalElement(RIL.BLOCK, RIL.WORD) = False

        Args:
            level (int): Iterator Level. See :class:`RIL`.
            element (int): Element level. See :class:`RIL`.

        Returns:
            bool: ``True`` if the iterator is positioned at the last element
                in the given level.
        """
        return self._piter.IsAtFinalElement(level, element)

    def SetBoundingBoxComponents(self, bool include_upper_dots, bool include_lower_dots):
        """Controls what to include in a bounding box. Bounding boxes of all levels
        between :attr:`RIL.WORD` and :attr:`RIL.BLOCK` can include or exclude potential diacritics.

        Between layout analysis and recognition, it isn't known where all
        diacritics belong, so this control is used to include or exclude some
        diacritics that are above or below the main body of the word. In most cases
        where the placement is obvious, and after recognition, it doesn't make as
        much difference, as the diacritics will already be included in the word.

        Args:
            include_upper_dots (bool): Include upper dots.
            include_lower_dots (bool): Include lower dots.
        """
        self._piter.SetBoundingBoxComponents(include_upper_dots, include_lower_dots)

    def BoundingBox(self, PageIteratorLevel level, const int padding=0):
        """Return the bounding rectangle of the current object at the given level.

        See comment on coordinate system above.

        Args:
            level (int): Page Iteration Level. See :class:`RIL` for avaialbe levels.

        Kwargs:
            padding (int): The padding argument to :meth:`GetImage` can be used to expand
                the image to include more foreground pixels.

        Returns:
            tuple or None if there is no such object at the current position.
                The returned bounding box (left, top, right and bottom values
                respectively) is guaranteed to match the size and position of
                the image returned by :meth:`GetBinaryImage`, but may clip
                foreground pixels from a grey image.
        """
        cdef int left, top, right, bottom
        if not self._piter.BoundingBox(level, padding, &left, &top, &right, &bottom):
            return None
        return left, top, right, bottom

    def BoundingBoxInternal(self, PageIteratorLevel level):
        """Return the bounding rectangle of the object in a coordinate system of the
        working image rectangle having its origin at (rect_left_, rect_top_) with
        respect to the original image and is scaled by a factor scale_.

        Args:
            level (int): Page Iteration Level. See :class:`RIL` for avaialbe levels.

        Returns:
            tuple or None if there is no such object at the current position.
                The returned bounding box is represented as a tuple with
                left, top, right and bottom values respectively.
        """
        cdef int left, top, right, bottom
        if not self._piter.BoundingBoxInternal(level, &left, &top, &right, &bottom):
            return None
        return left, top, right, bottom

    def Empty(self, PageIteratorLevel level):
        """Return whether there is no object of a given level.

        Args:
            level (int): Iterator level. See :class:`RIL`.

        Returns:
            bool: ``True`` if there is no object at the given level.
        """
        return self._piter.Empty(level)

    def BlockType(self):
        """Return the type of the current block. See :class:`PolyBlockType` for
        possible types.
        """
        return self._piter.BlockType()

    def BlockPolygon(self):
        """Return the polygon outline of the current block.

        Returns:
            list or None: list of points (x,y tuples) which list the vertices
                of the polygon, and the last edge is the line segment between the last
                point and the first point.

                ``None`` will be returned if the iterator is
                at the end of the document or layout analysis was not used.
        """
        cdef Pta *pta = self._piter.BlockPolygon()
        if pta == NULL:
            return None
        try:
            return zip((x for x in pta.x[:pta.n]), (y for y in pta.y[:pta.n]))
        finally:
            free(pta)

    def GetBinaryImage(self, PageIteratorLevel level):
        """Return a binary image of the current object at the given level.

        The position and size match the return from :meth:`BoundingBoxInternal`, and so
        this could be upscaled with respect to the original input image.

        Args:
            level (int): Iterator level. See :class:`RIL`.

        Returns:
            :class:`PIL.Image`: Image object or None if no image is returned.
        """
        cdef Pix *pix = self._piter.GetBinaryImage(level)
        if pix == NULL:
            return None
        try:
            return _pix_to_image(pix)
        finally:
            pixDestroy(&pix)

    def GetImage(self, PageIteratorLevel level, int padding, original_image):
        """Return an image of the current object at the given level in greyscale
        if available in the input.

        To guarantee a binary image use :meth:`BinaryImage`.

        Args:
            level (int): Iterator level. See :class:`RIL`.
            padding (int): Padding by which to expand the returned image.

                .. note::

                    in order to give the best possible image, the bounds are
                    expanded slightly over the binary connected component, by
                    the supplied padding, so the top-left position of the returned
                    image is returned along with the image (left, top respectively).
                    These will most likely not match the coordinates returned by
                    :meth:`BoundingBox`.

            original_image (:class:`PIL.Image`): Original image.
                If you do not supply an original image (None), you will get a binary one.

        Returns:
            tuple: The image (:class:`PIL.Image`) of the current object at the given level in greyscale
                followed by its top and left positions.
        """
        cdef:
            Pix *pix
            Pix *opix = NULL
            size_t size
            cuchar_t *buff
            int left
            int top
        if original_image:
            raw = _image_buffer(original_image)
            size = len(raw)
            buff = raw
            opix = pixReadMem(buff, size)
        pix = self._piter.GetImage(level, padding, opix, &left, &top)
        try:
            return _pix_to_image(pix), left, top
        finally:
            pixDestroy(&pix)
            if opix != NULL:
                pixDestroy(&opix)

    def Baseline(self, PageIteratorLevel level):
        """Return the baseline of the current object at the given level.

        The baseline is the line that passes through (x1, y1) and (x2, y2).

        .. warning::

            with vertical text, baselines may be vertical!

        Args:
            level (int): Iterator level. See :class:`RIL`.

        Returns:
            tuple: Baseline points' coordinates (x1, y1), (x2, y2).
                ``None`` if there is no baseline at the current position.
        """
        cdef int x1, y1, x2, y2
        if not self._piter.Baseline(level, &x1, &y1, &x2, &y2):
            return False
        return (x1, y1), (x2, y2)

    def Orientation(self):
        """Return the orientation for the block the iterator points to.

        Returns:
            tuple: The following values are returned respectively::

                orientation: See :class:`Orientation`
                writing_direction: See :class:`WritingDirection`
                textline_order: See :class:`TextlineOrder`
                deskew_angle: After rotating the block so the text orientation is
                    upright, how many radians does one have to rotate the
                    block anti-clockwise for it to be level?
                        -Pi/4 <= deskew_angle <= Pi/4
        """
        cdef:
            TessOrientation orientation
            TessWritingDirection writing_direction
            TessTextlineOrder textline_order
            float deskew_angle
        self._piter.Orientation(&orientation, &writing_direction, &textline_order, &deskew_angle)
        return orientation, writing_direction, textline_order, deskew_angle

    def ParagraphInfo(self):
        """Return information about the current paragraph, if available.

        Returns:
            tuple: The following values are returned respectively::

                justification:
                    LEFT if ragged right, or fully justified and script is left-to-right.
                    RIGHT if ragged left, or fully justified and script is right-to-left.
                    UNKNOWN if it looks like source code or we have very few lines.
                    See :class:`Justification`.
                is_list_item:
                    ``True`` if we believe this is a member of an ordered or unordered list.
                is_crown:
                    ``True`` if the first line of the paragraph is aligned with the other
                    lines of the paragraph even though subsequent paragraphs have first
                    line indents.  This typically indicates that this is the continuation
                    of a previous paragraph or that it is the very first paragraph in
                    the chapter.
                first_line_indent:
                    For LEFT aligned paragraphs, the first text line of paragraphs of
                    this kind are indented this many pixels from the left edge of the
                    rest of the paragraph.
                    for RIGHT aligned paragraphs, the first text line of paragraphs of
                    this kind are indented this many pixels from the right edge of the
                    rest of the paragraph.
                    NOTE 1: This value may be negative.
                    NOTE 2: if ``is_crown == True``, the first line of this paragraph is
                        actually flush, and first_line_indent is set to the "common"
                        first_line_indent for subsequent paragraphs in this block
                        of text.
        """
        cdef:
            TessParagraphJustification justification
            bool is_list_item
            bool is_crown
            int first_line_indent
        self._piter.ParagraphInfo(&justification, &is_list_item, &is_crown, &first_line_indent)
        return justification, is_list_item, is_crown, first_line_indent


cdef class PyLTRResultIterator(PyPageIterator):

    cdef LTRResultIterator *_ltrriter

    def __cinit__(self):
        self._ltrriter = NULL

    def __dealloc__(self):
        if self._ltrriter != NULL:
            del self._ltrriter
        self._piter = NULL

    def GetChoiceIterator(self):
        """Return `PyChoiceIterator` instance to iterate over symbol choices.

        Returns `None` on failure.
        """
        cdef:
            const LTRResultIterator *ltrriter = self._ltrriter
            ChoiceIterator *citer = new ChoiceIterator(ltrriter[0])
        if citer == NULL:
            return None
        return PyChoiceIterator.create(citer)

    def GetUTF8Text(self, PageIteratorLevel level):
        """Returns the UTF-8 encoded text string for the current
        object at the given level.

        Args:
            level (int): Iterator level. See :class:`RIL`.

        Returns:
            unicode: UTF-8 encoded text for the given level's current object.

        Raises:
            :exc:`RuntimeError`: If no text returned.
        """
        cdef char *text = self._ltrriter.GetUTF8Text(level)
        if text == NULL:
            raise RuntimeError('No text returned')
        return _free_str(text)

    def SetLineSeparator(self, separator):
        """Set the string inserted at the end of each text line. "\n" by default."""
        cdef bytes py_sep = _b(separator)
        self._ltrriter.SetLineSeparator(py_sep)

    def SetParagraphSeparator(self, separator):
        """Set the string inserted at the end of each paragraph. "\n" by default."""
        cdef bytes py_sep = _b(separator)
        self._ltrriter.SetParagraphSeparator(py_sep)

    def Confidence(self, PageIteratorLevel level):
        """Return the mean confidence of the current object at the given level.

        The number should be interpreted as a percent probability. (0.0-100.0)
        """
        return self._ltrriter.Confidence(level)

    def WordFontAttributes(self):
        """Return the font attributes of the current word.

        .. note::
            If iterating at a higher level object than words, eg textlines,
            then this will return the attributes of the first word in that textline.

        Returns:
            dict: `None` if nothing found or a dictionary with the font attributes::

                font_name: String representing a font name. Lifespan is the same as
                    the iterator itself, ie rendered invalid by various members of
                    :class:`PyTessBaseAPI`, including `Init`, `SetImage`, `End` or
                    deleting the :class:`PyTessBaseAPI`.
                bold (bool): ``True`` if bold.
                italic (bool): ``True`` if italic.
                underlined (bool): ``True`` if underlined.
                monospace (bool): ``True`` if monospace.
                serif (bool): ``True`` if serif.
                smallcaps (bool): ``True`` if smallcaps.
                pointsize (int): printers points (1/72 inch.)
                font_id (int): font id.
        """
        cdef:
            bool is_bold,
            bool is_italic
            bool is_underlined
            bool is_monospace
            bool is_serif
            bool is_smallcaps
            int pointsize
            int font_id
            cchar_t *font_name
        font_name = self._ltrriter.WordFontAttributes(&is_bold, &is_italic, &is_underlined,
                                                 &is_monospace, &is_serif, &is_smallcaps,
                                                 &pointsize, &font_id)
        if font_name == NULL:
            return None
        return {
            'font_name': font_name,
            'bold': is_bold,
            'italic': is_italic,
            'underlined': is_underlined,
            'monospace': is_monospace,
            'serif': is_serif,
            'smallcaps': is_smallcaps,
            'pointsize': pointsize,
            'font_id': font_id
        }

    def WordRecognitionLanguage(self):
        """Return the name of the language used to recognize this word.

        Returns ``None`` on error.
        """
        cdef cchar_t *lang = self._ltrriter.WordRecognitionLanguage()
        if lang == NULL:
            return None
        return lang

    def WordDirection(self):
        """Return the overall directionality of this word.

        See :class:`DIR` for available values.
        """
        return self._ltrriter.WordDirection()

    def WordIsFromDictionary(self):
        """Return True if the current word was found in a dictionary."""
        return self._ltrriter.WordIsFromDictionary()

    def WordIsNumeric(self):
        """Return True if the current word is numeric."""
        return self._ltrriter.WordIsNumeric()

    def HasBlamerInfo(self):
        """Return True if the word contains blamer information."""
        return self._ltrriter.HasBlamerInfo()

    def GetBlamerDebug(self):
        """Return a string with blamer information for this word."""
        return self._ltrriter.GetBlamerDebug()

    def GetBlamerMisadaptionDebug(self):
        """Return a string with misadaption information for this word."""
        return self._ltrriter.GetBlamerMisadaptionDebug()

    def HasTruthString(self):
        """Returns True if a truth string was recorded for the current word."""
        return self._ltrriter.HasTruthString()

    def EquivalentToTruth(self, text):
        """Return True if the given string is equivalent to the truth string for
        the current word."""
        cdef bytes py_text = _b(text)
        return self._ltrriter.EquivalentToTruth(py_text)

    def WordTruthUTF8Text(self):
        """Return a UTF-8 encoded truth string for the current word."""
        cdef char *text = self._ltrriter.WordTruthUTF8Text()
        return _free_str(text)

    def WordNormedUTF8Text(self):
        """Returns a UTF-8 encoded normalized OCR string for the
        current word."""
        cdef char *text = self._ltrriter.WordNormedUTF8Text()
        return _free_str(text)

    def WordLattice(self):
        """Return a serialized choice lattice."""
        cdef:
            cchar_t *word_lattice
            int lattice_size
        word_lattice = self._ltrriter.WordLattice(&lattice_size)
        if not lattice_size:
            return None
        return word_lattice[:lattice_size]

    def SymbolIsSuperscript(self):
        """Return True if the current symbol is a superscript.

        If iterating at a higher level object than symbols, eg words, then
        this will return the attributes of the first symbol in that word.
        """
        return self._ltrriter.SymbolIsSuperscript()

    def SymbolIsSubscript(self):
        """Return True if the current symbol is a subscript.

        If iterating at a higher level object than symbols, eg words, then
        this will return the attributes of the first symbol in that word.
        """
        return self._ltrriter.SymbolIsSubscript()

    def SymbolIsDropcap(self):
        """Return True if the current symbol is a dropcap.

        If iterating at a higher level object than symbols, eg words, then
        this will return the attributes of the first symbol in that word.
        """
        return self._ltrriter.SymbolIsDropcap()


cdef class PyResultIterator(PyLTRResultIterator):
    """Wrapper around Tesseract's ``ResultIterator`` class.

    .. note::

        You can iterate through the elements of a level using the :func:`iterate_level`
        helper function:

        >>> for e in iterate_level(api.GetIterator(), RIL.WORD):
        ...     word = e.GetUTF8Text()

    See :class:`PyPageIterator` for more details.
    """

    cdef ResultIterator *_riter

    @staticmethod
    cdef PyResultIterator createResultIterator(ResultIterator *riter):
        cdef PyResultIterator pyiter = PyResultIterator.__new__(PyResultIterator)
        pyiter._piter = <PageIterator *>riter
        pyiter._ltrriter = <LTRResultIterator *>riter
        pyiter._riter = riter
        return pyiter

    def __cinit__(self):
        self._riter = NULL

    def __dealloc__(self):
        if self._riter != NULL:
            del self._riter
            # set super class pointers to NULL
            # to avoid multiple deletes
        self._ltrriter = NULL

    def IsAtBeginningOf(self, PageIteratorLevel level):
        """Return whether we're at the logical beginning of the
        given level. (as opposed to :class:`PyResultIterator`'s left-to-right
        top-to-bottom order).

        Otherwise, this acts the same as :meth:`PyPageIterator.IsAtBeginningOf`.
        """
        return self._riter.IsAtBeginningOf(level)

    def ParagraphIsLtr(self):
        """Return whether the current paragraph's dominant reading direction
        is left-to-right (as opposed to right-to-left).
        """
        return self._riter.ParagraphIsLtr()


cdef class PyChoiceIterator:

    cdef ChoiceIterator *_citer

    @staticmethod
    cdef PyChoiceIterator create(ChoiceIterator *citer):
        cdef PyChoiceIterator pyciter = PyChoiceIterator.__new__(PyChoiceIterator)
        pyciter._citer = citer
        return pyciter

    def __cinit__(self):
        self._citer = NULL

    def __dealloc__(self):
        if self._citer != NULL:
            del self._citer

    def __init__(self, ltr_iterator):
        raise TypeError('ChoiceIterator cannot be instantiated from Python')

    def __iter__(self):
        return iterate_choices(self)

    def Next(self):
        """Move to the next choice for the symbol and returns False if there
        are none left."""
        return self._citer.Next()

    def GetUTF8Text(self):
        """Return the UTF-8 encoded text string for the current
        choice."""
        cdef cchar_t *text = self._citer.GetUTF8Text()
        if text == NULL:
            return None
        return text

    def Confidence(self):
        """Return the confidence of the current choice.

        The number should be interpreted as a percent probability. (0.0f-100.0f)
        """
        return self._citer.Confidence()


def iterate_choices(citerator):
    """Helper generator function to iterate :class:`PyChoiceIterator`."""
    yield citerator
    while citerator.Next():
        yield citerator


def iterate_level(iterator, PageIteratorLevel level):
    """Helper generator function to iterate a :class:`PyPageIterator`
    level.

    Args:
        iterator: Instance of :class:`PyPageIterator`
        level: Page iterator level :class:`RIL`
    """
    yield iterator
    while iterator.Next(level):
        yield iterator


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
        psm (int): Page segmentation mode. Defaults to :attr:`PSM.AUTO`.
            See :class:`PSM` for avaialble psm values.
        init (bool): If ``False``, :meth:`Init` will not be called and has to be called
            after initialization.
        oem (int): OCR engine mode. Defaults to :attr:`OEM.DEFAULT`.

    Raises:
        :exc:`RuntimeError`: If `init` is ``True`` and API initialization fails.
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

    def __cinit__(self, path=_DEFAULT_PATH,
                  lang=_DEFAULT_LANG, PageSegMode psm=PSM_AUTO,
                  bool init=True,
                  OcrEngineMode oem=OEM_DEFAULT):
        cdef:
            bytes py_path = _b(path)
            bytes py_lang = _b(lang)
            cchar_t *cpath = py_path
            cchar_t *clang = py_lang
        with nogil:
            self._pix = NULL
            if init:
                self._init_api(cpath, clang, oem, NULL, 0, NULL, NULL, False, psm)

    def __dealloc__(self):
        self._end_api()

    cdef int _init_api(self, cchar_t *path, cchar_t *lang,
                        OcrEngineMode oem, char **configs, int configs_size,
                        const GenericVector[STRING] *vars_vec, const GenericVector[STRING] *vars_vals,
                        bool set_only_non_debug_params, PageSegMode psm) nogil except -1:
        cdef int ret = self._baseapi.Init(path, lang, oem, configs, configs_size, vars_vec, vars_vals,
                                          set_only_non_debug_params)
        if ret == -1:
            with gil:
                raise RuntimeError('Failed to init API, possibly an invalid tessdata path: {}'.format(path))
        self._baseapi.SetPageSegMode(psm)
        return ret

    cdef void _end_api(self) nogil:
        self._destroy_pix()
        self._baseapi.End()

    cdef void _destroy_pix(self) nogil:
        if self._pix != NULL:
            pixDestroy(&self._pix)
            self._pix = NULL

    def GetDatapath(self):
        """Return tessdata parent directory"""
        return self._baseapi.GetDatapath()

    def SetOutputName(self, name):
        """Set the name of the bonus output files. Needed only for debugging."""
        cdef bytes py_name = _b(name)
        self._baseapi.SetOutputName(py_name)

    def SetVariable(self, name, val):
        """Set the value of an internal parameter.

        Supply the name of the parameter and the value as a string, just as
        you would in a config file.

        Eg SetVariable("tessedit_char_blacklist", "xyz"); to ignore x, y and z.
        Or SetVariable("classify_bln_numeric_mode", "1"); to set numeric-only mode.

        SetVariable may be used before Init, but settings will revert to
        defaults on End().

        Args:
            name (str): Variable name
            value (str): Variable value

        Returns:
            bool: ``False`` if the name lookup failed.
        """
        cdef:
            bytes py_name = _b(name)
            bytes py_val = _b(val)
        return self._baseapi.SetVariable(py_name, py_val)

    def SetDebugVariable(self, name, val):
        """Set the value of an internal parameter. (debug)

        Supply the name of the parameter and the value as a string, just as
        you would in a config file.

        Eg SetVariable("tessedit_char_blacklist", "xyz"); to ignore x, y and z.
        Or SetVariable("classify_bln_numeric_mode", "1"); to set numeric-only mode.

        SetVariable may be used before Init, but settings will revert to
        defaults on End().

        Args:
            name (str): Variable name
            value (str): Variable value

        Returns:
            bool: ``False`` if the name lookup failed.
        """
        cdef:
            bytes py_name = _b(name)
            bytes py_val = _b(val)
        return self._baseapi.SetDebugVariable(py_name, py_val)

    def GetIntVariable(self, name):
        """Return the value of the given int parameter if it exists among Tesseract parameters.

        Returns ``None`` if the paramter was not found.
        """
        cdef:
            bytes py_name = _b(name)
            int val
        if self._baseapi.GetIntVariable(py_name, &val):
            return val
        return None

    def GetBoolVariable(self, name):
        """Return the value of the given bool parameter if it exists among Tesseract parameters.

        Returns ``None`` if the paramter was not found.
        """
        cdef:
            bytes py_name = _b(name)
            bool val
        if self._baseapi.GetBoolVariable(py_name, &val):
            return val
        return None

    def GetDoubleVariable(self, name):
        """Return the value of the given double parameter if it exists among Tesseract parameters.

        Returns ``None`` if the paramter was not found.
        """
        cdef:
            bytes py_name = _b(name)
            double val
        if self._baseapi.GetDoubleVariable(py_name, &val):
            return val
        return None

    def GetStringVariable(self, name):
        """Return the value of the given string parameter if it exists among Tesseract parameters.

        Returns ``None`` if the paramter was not found.
        """
        cdef:
            bytes py_name = _b(name)
            cchar_t *val = self._baseapi.GetStringVariable(py_name)
        if val != NULL:
            return val
        return None

    def GetVariableAsString(self, name):
        """Return the value of named variable as a string (regardless of type),
        if it exists.

        Returns ``None`` if paramter was not found.
        """
        cdef:
            bytes py_name = _b(name)
            STRING val
        if self._baseapi.GetVariableAsString(py_name, &val):
            return val.string()
        return None

    def InitFull(self, path=_DEFAULT_PATH, lang=_DEFAULT_LANG,
                 OcrEngineMode oem=OEM_DEFAULT, list configs=[],
                 dict variables={}, bool set_only_non_debug_params=False):
        """Initialize the API with the given parameters (advanced).

        It is entirely safe (and eventually will be efficient too) to call
        :meth:`Init` multiple times on the same instance to change language, or just
        to reset the classifier.

        Page Segmentation Mode is set to :attr:`PSM.AUTO` after initialization by default.

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
            oem (int): OCR engine mode. Defaults to :attr:`OEM.DEFAULT`.
                See :class:`OEM` for all avaialbe options.
            configs (list): List of config files to load variables from.
            variables (dict): Extra variables to be set.
            set_only_non_debug_params (bool): If ``True``, only params that do not contain
                "debug" in the name will be set.

        Raises:
            :exc:`RuntimeError`: If API initialization fails.
        """
        cdef:
            bytes py_path = _b(path)
            bytes py_lang = _b(lang)
            cchar_t *cpath = py_path
            cchar_t *clang = py_lang
            int configs_size = len(configs)
            char **configs_ = <char **>malloc(configs_size * sizeof(char *))
            GenericVector[STRING] vars_vec
            GenericVector[STRING] vars_vals
            cchar_t *val
            STRING sval

        for i, c in enumerate(configs):
            c = _b(c)
            configs_[i] = c

        for k, v in variables.items():
            k = _b(k)
            val = k
            sval = val
            vars_vec.push_back(sval)
            v = _b(v)
            val = v
            sval = val
            vars_vals.push_back(sval)

        with nogil:
            try:
                self._init_api(cpath, clang, oem, configs_, configs_size, &vars_vec, &vars_vals,
                               set_only_non_debug_params, PSM_AUTO)
            finally:
                free(configs_)

    def Init(self, path=_DEFAULT_PATH, lang=_DEFAULT_LANG,
             OcrEngineMode oem=OEM_DEFAULT):
        """Initialize the API with the given data path, language and OCR engine mode.

        See :meth:`InitFull` for more intialization info and options.

        Args:
            path (str): The name of the parent directory of tessdata.
                Must end in /. Uses default installation path if not specified.
            lang (str): An ISO 639-3 language string. Defaults to 'eng'.
                See :meth:`InitFull` for full description of this parameter.
            oem (int): OCR engine mode. Defaults to :attr:`OEM.DEFAULT`.
                See :class:`OEM` for all avaialbe options.

        Raises:
            :exc:`RuntimeError`: If API initialization fails.
        """
        cdef:
            bytes py_path = _b(path)
            bytes py_lang = _b(lang)
            cchar_t *cpath = py_path
            cchar_t *clang = py_lang
        with nogil:
            self._init_api(cpath, clang, oem, NULL, 0, NULL, NULL, False, PSM_AUTO)

    def GetInitLanguagesAsString(self):
        """Return the languages string used in the last valid initialization.

        If the last initialization specified "deu+hin" then that will be
        returned. If hin loaded eng automatically as well, then that will
        not be included in this list. To find the languages actually
        loaded use :meth:`GetLoadedLanguages`.
        """
        return self._baseapi.GetInitLanguagesAsString()

    def GetLoadedLanguages(self):
        """Return the loaded languages as a list of STRINGs.

        Includes all languages loaded by the last Init, including those loaded
        as dependencies of other loaded languages.
        """
        cdef GenericVector[STRING] langs
        self._baseapi.GetLoadedLanguagesAsVector(&langs)
        return [langs[i].string() for i in xrange(langs.size())]

    def GetAvailableLanguages(self):
        """Return list of available languages in the init data path"""
        cdef:
            GenericVector[STRING] v
            int i
        langs = []
        self._baseapi.GetAvailableLanguagesAsVector(&v)
        langs = [v[i].string() for i in xrange(v.size())]
        return langs

    def InitForAnalysePage(self):
        """Init only for page layout analysis.

        Use only for calls to :meth:`SetImage` and :meth:`AnalysePage`.
        Calls that attempt recognition will generate an error.
        """
        self._baseapi.InitForAnalysePage()

    def ReadConfigFile(self, filename):
        """Read a "config" file containing a set of param, value pairs.

        Searches the standard places: tessdata/configs, tessdata/tessconfigs.

        Args:
            filename: config file name. Also accepts relative or absolute path name.
        """
        cdef bytes py_fname = _b(filename)
        self._baseapi.ReadConfigFile(py_fname)

    def SetPageSegMode(self, PageSegMode psm):
        """Set page segmentation mode.

        Args:
            psm (int): page segmentation mode.
                See :class:`PSM` for all available psm options.
        """
        with nogil:
            self._baseapi.SetPageSegMode(psm)

    def GetPageSegMode(self):
        """Return the current page segmentation mode."""
        return self._baseapi.GetPageSegMode()

    def TesseractRect(self, imagedata,
                      int bytes_per_pixel, int bytes_per_line,
                      int left, int top, int width, int height):
        """Recognize a rectangle from an image and return the result as a string.

        May be called many times for a single Init.
        Currently has no error checking.

        .. note::

            `TesseractRect` is the simplified convenience interface. For advanced
            uses, use :meth:`SetImage`, (optionally) :meth:`SetRectangle`,
            :meth:`Recognize`, and one or more of the `Get*Text` methods below.

        Args:
            imagedata (str): Raw image bytes.
            bytes_per_pixel (int): bytes per pixel.
                Greyscale of 8 and color of 24 or 32 bits per pixel may be given.
                Palette color images will not work properly and must be converted to
                24 bit.
                Binary images of 1 bit per pixel may also be given but they must be
                byte packed with the MSB of the first byte being the first pixel, and a
                1 represents WHITE. For binary images set bytes_per_pixel=0.
            bytes_per_line (int): bytes per line.
            left (int): left rectangle ordonate.
            top (int): top rectangle ordonate.
            width (int): image width.
            height (int): image height.

        Returns:
            unicode: The recognized text as UTF8.
        """
        cdef:
            bytes py_imagedata = _b(imagedata)
            cuchar_t *cimagedata = py_imagedata
            char *text
        with nogil:
            text = self._baseapi.TesseractRect(cimagedata, bytes_per_pixel, bytes_per_line,
                                               left, top, width, height)
            if text == NULL:
                with gil:
                    raise RuntimeError('Failed to recognize image')
        return _free_str(text)

    def ClearAdaptiveClassifier(self):
        """Call between pages or documents etc to free up memory and forget
        adaptive data.
        """
        self._baseapi.ClearAdaptiveClassifier()

    def SetImageBytes(self, imagedata, int width, int height,
                      int bytes_per_pixel, int bytes_per_line):
        """Provide an image for Tesseract to recognize.

        Format is as :meth:`TesseractRect` above. Does not copy the image buffer, or take
        ownership. The source image may be destroyed after Recognize is called,
        either explicitly or implicitly via one of the `Get*Text` methods.

        This method clears all recognition results, and sets the rectangle to the
        full image, so it may be followed immediately by a :meth:`GetUTF8Text`, and it
        will automatically perform recognition.

        Args:
            imagedata (str): Raw image bytes.
            width (int): image width.
            height (int): image height.
            bytes_per_pixel (int): bytes per pixel.
                Greyscale of 8 and color of 24 or 32 bits per pixel may be given.
                Palette color images will not work properly and must be converted to
                24 bit.
                Binary images of 1 bit per pixel may also be given but they must be
                byte packed with the MSB of the first byte being the first pixel, and a
                1 represents WHITE. For binary images set bytes_per_pixel=0.
            bytes_per_line (int): bytes per line.
        """
        cdef:
            bytes py_imagedata = _b(imagedata)
            cuchar_t *cimagedata = py_imagedata
        with nogil:
            self._destroy_pix()
            self._baseapi.SetImage(cimagedata, width, height, bytes_per_pixel, bytes_per_line)

    def SetImage(self, image):
        """Provide an image for Tesseract to recognize.

        This method can be called multiple times after :meth:`Init`.

        Args:
            image (:class:PIL.Image): Image object.

        Raises:
            :exc:`RuntimeError`: If for any reason the api failed
                to load the given image.
        """
        cdef:
            cuchar_t *buff
            size_t size
            bytes raw

        raw = _image_buffer(image)
        buff = raw
        size = len(raw)

        with nogil:
            self._destroy_pix()
            self._pix = pixReadMem(buff, size)
            if self._pix == NULL:
                with gil:
                    raise RuntimeError('Error reading image')
            self._baseapi.SetImage(self._pix)

    def SetImageFile(self, filename):
        """Set image from file for Tesserac to recognize.

        Args:
            filename (str): Image file relative or absolute path.

        Raises:
            :exc:`RuntimeError`: If for any reason the api failed
                to load the given image.
        """
        cdef:
            bytes py_fname = _b(filename)
            cchar_t *fname = py_fname
        with nogil:
            self._destroy_pix()
            self._pix = pixRead(fname)
            if self._pix == NULL:
                with gil:
                    raise RuntimeError('Error reading image')
            self._baseapi.SetImage(self._pix)

    def SetSourceResolution(self, int ppi):
        """Set the resolution of the source image in pixels per inch so font size
        information can be calculated in results.

        Call this after :meth:`SetImage`.
        """
        self._baseapi.SetSourceResolution(ppi)

    def SetRectangle(self, int left, int top, int width, int height):
        """Restrict recognition to a sub-rectangle of the image. Call after :meth:`SetImage`.

        Each SetRectangle clears the recogntion results so multiple rectangles
        can be recognized with the same image.

        Args:
            left (int): poisition from left
            top (int): position from top
            width (int): width
            height (int): height
        """
        self._baseapi.SetRectangle(left, top, width, height)

    def GetThresholdedImage(self):
        """Return a copy of the internal thresholded image from Tesseract.

        May be called any time after SetImage.
        """
        cdef Pix *pix = self._baseapi.GetThresholdedImage()

        if pix == NULL:
            return None

        try:
            return _pix_to_image(pix)
        finally:
            pixDestroy(&pix)

    def GetRegions(self):
        """Get the result of page layout analysis as a list of
        image, box bounds {x, y, width, height} tuples in reading order.

        Can be called before or after :meth:`Recognize`.

        Returns:
            list: List of tuples containing the following values respectively::

                image (:class:`PIL.Image`): Image object.
                bounding box (dict): dict with x, y, w, h keys.
        """
        cdef:
            Pixa *pixa
            Boxa *boxa
        boxa = self._baseapi.GetRegions(&pixa)
        if boxa == NULL:
            return []
        try:
            return pixa_to_list(pixa)
        finally:
            boxaDestroy(&boxa)
            pixaDestroy(&pixa)

    def GetTextlines(self, const bool raw_image=False, const int raw_padding=0,
                     const bool blockids=True, const bool paraids=False):
        """Get the textlines as a list of image, box bounds
        {x, y, width, height} tuples in reading order.

        Can be called before or after :meth:`Recognize`.

        Args:
            raw_image (bool): If ``True``, then extract from the original image
                instead of the thresholded image and pad by `raw_padding` pixels.
            raw_padding (int): Padding pixels.

        Kwargs:
            blockids (bool): If ``True`` (default), the block-id of each line is also
                included in the returned tuples (`None` otherwise).
            paraids (bool): If ``True``, the paragraph-id of each line within its block is
                also included in the returned tuples (`None` otherwise). Default is ``False``.

        Returns:
            list: List of tuples containing the following values respectively::

                image (:class:`PIL.Image`): Image object.
                bounding box (dict): dict with x, y, w, h keys.
                block id (int): textline block id (if blockids is ``True``). ``None`` otherwise.
                paragraph id (int): textline paragraph id within its block (if paraids is True).
                    ``None`` otherwise.
        """
        cdef:
            Pixa *pixa
            Boxa *boxa
            int *_blockids
            int *_paraids
        if not blockids:
            _blockids = NULL
        if not paraids:
            _paraids = NULL
        boxa = self._baseapi.GetTextlines(raw_image, raw_padding, &pixa, &_blockids, &_paraids)
        if boxa == NULL:
            return []
        try:
            pixa_list = pixa_to_list(pixa)
            if blockids:
                blockids_ = [bid for bid in _blockids[:pixa.n]]
                free(_blockids)
            else:
                blockids_ = [None] * pixa.n

            if paraids:
                paraids_ = [pid for pid in _paraids[:pixa.n]]
                free(_paraids)
            else:
                paraids_ = [None] * pixa.n

            return [p + (blockids_[n], paraids_[n]) for n, p in enumerate(pixa_list)]
        finally:
            boxaDestroy(&boxa)
            pixaDestroy(&pixa)

    def GetStrips(self, bool blockids=True):
        """Get the textlines and strips of image regions as a list
        of image, box bounds {x, y, width, height} tuples in reading order.

        Enables downstream handling of non-rectangular regions.

        Can be called before or after :meth:`Recognize`.

        Kwargs:
            blockids (bool): If ``True`` (default), the block-id of each line is also
                included in the returned tuples.
        Returns:
            list: List of tuples containing the following values respectively::
                image (:class:`PIL.Image`): Image object.
                bounding box (dict): dict with x, y, w, h keys.
                block id (int): textline block id (if blockids is ``True``). ``None`` otherwise.
        """
        cdef:
            Pixa *pixa
            Boxa *boxa
            int *_blockids
        if not blockids:
            _blockids = NULL
        boxa = self._baseapi.GetStrips(&pixa, &_blockids)
        if boxa == NULL:
            return []
        try:
            pixa_list = pixa_to_list(pixa)
            if blockids:
                blockids_ = [bid for bid in _blockids[:pixa.n]]
                free(_blockids)
            else:
                blockids_ = [None] * pixa.n

            return [p + (blockids_[n], ) for n, p in enumerate(pixa_list)]
        finally:
            boxaDestroy(&boxa)
            pixaDestroy(&pixa)

    def GetWords(self):
        """Get the words as a list of image, box bounds
        {x, y, width, height} tuples in reading order.

        Can be called before or after :meth:`Recognize`.

        Returns:
            list: List of tuples containing the following values respectively::
                image (:class:`PIL.Image`): Image object.
                bounding box (dict): dict with x, y, w, h keys.
        """
        cdef:
            Boxa *boxa
            Pixa *pixa
        boxa = self._baseapi.GetWords(&pixa)
        if boxa == NULL:
            return []
        try:
            return pixa_to_list(pixa)
        finally:
            boxaDestroy(&boxa)
            pixaDestroy(&pixa)

    def GetConnectedComponents(self):
        """Gets the individual connected (text) components (created
        after pages segmentation step, but before recognition)
        as a list of image, box bounds {x, y, width, height} tuples
        in reading order.

        Can be called before or after :meth:`Recognize`.

        Returns:
            list: List of tuples containing the following values respectively:

                image (:class:`PIL.Image`): Image object.
                bounding box (dict): dict with x, y, w, h keys.
        """
        cdef:
            Boxa *boxa
            Pixa *pixa
        boxa = self._baseapi.GetConnectedComponents(&pixa)
        if boxa == NULL:
            return []
        try:
            return pixa_to_list(pixa)
        finally:
            boxaDestroy(&boxa)
            pixaDestroy(&pixa)

    def GetComponentImages(self, const PageIteratorLevel level,
                           const bool text_only, const bool raw_image=False,
                           const int raw_padding=0,
                           const bool blockids=True, const bool paraids=False):
        """Get the given level kind of components (block, textline, word etc.) as a
        list of image, box bounds {x, y, width, height} tuples in reading order.

        Can be called before or after :meth:`Recognize`.

        Args:
            level (int): Iterator level. See :class:`RIL`.
            text_only (bool): If ``True``, then only text components are returned.

        Kwargs:
            raw_image (bool): If ``True``, then portions of the original image are extracted
                instead of the thresholded image and padded with `raw_padding`. Defaults to
                ``False``.
            raw_padding (int): Image padding pixels. Defaults to 0.
            blockids (bool): If ``True``, the block-id of each component is also included
                in the returned tuples (`None` otherwise). Defaults to ``True``.
            paraids (bool): If ``True``, the paragraph-id of each component with its block
                is also included in the returned tuples.

        Returns:
            list: List of tuples containing the following values respectively::

                image (:class:`PIL.Image`): Image object.
                bounding box (dict): dict with x, y, w, h keys.
                block id (int): textline block id (if blockids is ``True``). ``None`` otherwise.
                paragraph id (int): textline paragraph id within its block (if paraids is True).
                    ``None`` otherwise.
        """
        cdef:
            Boxa *boxa
            Pixa *pixa
            int *_blockids
            int *_paraids
        if not blockids:
            _blockids = NULL
        if not paraids:
            _paraids = NULL
        boxa = self._baseapi.GetComponentImages(level, text_only, raw_image, raw_padding,
                                                &pixa, &_blockids, &_paraids)
        if boxa == NULL:
            # no components found
            return []
        try:
            pixa_list = pixa_to_list(pixa)
            if blockids:
                blockids_ = [bid for bid in _blockids[:pixa.n]]
                free(_blockids)
            else:
                blockids_ = [None] * pixa.n

            if paraids:
                paraids_ = [pid for pid in _paraids[:pixa.n]]
                free(_paraids)
            else:
                paraids_ = [None] * pixa.n

            return [p + (blockids_[n], paraids_[n]) for n, p in enumerate(pixa_list)]
        finally:
            boxaDestroy(&boxa)
            pixaDestroy(&pixa)

    def GetThresholdedImageScaleFactor(self):
        """Return the scale factor of the thresholded image that would be returned by
        GetThresholdedImage().

        Returns:
            int: 0 if no thresholder has been set.
        """
        return self._baseapi.GetThresholdedImageScaleFactor()

    def AnalyseLayout(self, bool merge_similar_words=False):
        """Runs page layout analysis in the mode set by :meth:`SetPageSegMode`.

        May optionally be called prior to :meth:`Recognize` to get access to just
        the page layout results. Returns a :class:`PyPageIterator` iterator to the results.

        Kwargs:
            merge_similar_words (bool): If ``True``, words are combined where suitable
            for use with a line recognizer. Use if you want to use AnalyseLayout to find the
            textlines, and then want to process textline fragments with an external
            line recognizer.
        Returns:
            :class:`PyPageIterator`: Page iterator or `None` on error or an empty page.
        """
        cdef PageIterator *piter
        piter = self._baseapi.AnalyseLayout(merge_similar_words)
        if piter == NULL:
            return None
        return PyPageIterator.createPageIterator(piter)

    cpdef bool Recognize(self, int timeout=0):
        """Recognize the image from :meth:`SetImage`, generating Tesseract
        internal structures. Returns ``True`` on success.

        Optional. The `Get*Text` methods below will call :meth:`Recognize` if needed.

        After :meth:`Recognize`, the output is kept internally until the next :meth:`SetImage`.

        Kwargs:
            timeout (int): time to wait in milliseconds before timing out.

        Returns:
            bool: ``True`` if the operation is successful.
        """
        cdef:
            ETEXT_DESC monitor
            int res
        with nogil:
            if timeout > 0:
                monitor.cancel = NULL
                monitor.cancel_this = NULL
                monitor.set_deadline_msecs(timeout)
                res = self._baseapi.Recognize(&monitor)
            else:
                res = self._baseapi.Recognize(NULL)
        return res == 0

    """Methods to retrieve information after :meth:`SetImage`,
    :meth:`Recognize` or :meth:`TesseractRect`. (:meth:`Recognize` is called implicitly if needed.)"""

    cpdef bool RecognizeForChopTest(self, int timeout=0):
        """Variant on :meth:`Recognize` used for testing chopper."""
        cdef:
            ETEXT_DESC monitor
            int res
        with nogil:
            if timeout > 0:
                monitor.cancel = NULL
                monitor.cancel_this = NULL
                monitor.set_deadline_msecs(timeout)
                res = self._baseapi.RecognizeForChopTest(&monitor)
            else:
                res = self._baseapi.RecognizeForChopTest(NULL)
        return res == 0

    cdef TessResultRenderer *_get_renderer(self, cchar_t *outputbase):
        cdef:
            bool b
            bool font_info
            IF TESSERACT_VERSION >= 0x040000:
                bool textonly
            TessResultRenderer *temp
            TessResultRenderer *renderer = NULL

        IF TESSERACT_VERSION >= 0x030401:
            if self._baseapi.GetPageSegMode() == PSM.OSD_ONLY:
                renderer = new TessOsdRenderer(outputbase)
                return renderer

        self._baseapi.GetBoolVariable("tessedit_create_hocr", &b)
        if b:
            self._baseapi.GetBoolVariable("hocr_font_info", &font_info)
            renderer = new TessHOcrRenderer(outputbase, font_info)

        self._baseapi.GetBoolVariable("tessedit_create_pdf", &b)
        if b:
            IF TESSERACT_VERSION >= 0x040000:
                self._baseapi.GetBoolVariable("textonly_pdf", &textonly)
                temp = new TessPDFRenderer(outputbase, self._baseapi.GetDatapath(), textonly)
            ELSE:
                temp = new TessPDFRenderer(outputbase, self._baseapi.GetDatapath())

            if renderer == NULL:
                renderer = temp
            else:
                renderer.insert(temp)

        self._baseapi.GetBoolVariable("tessedit_write_unlv", &b)
        if b:
            temp = new TessUnlvRenderer(outputbase)
            if renderer == NULL:
                renderer = temp
            else:
                renderer.insert(temp)

        self._baseapi.GetBoolVariable("tessedit_create_boxfile", &b)
        if b:
            temp = new TessBoxTextRenderer(outputbase)
            if renderer == NULL:
                renderer = temp
            else:
                renderer.insert(temp)

        self._baseapi.GetBoolVariable("tessedit_create_txt", &b)
        if b:
            temp = new TessTextRenderer(outputbase)
            if renderer == NULL:
                renderer = temp
            else:
                renderer.insert(temp)

        return renderer

    def ProcessPages(self, outputbase, filename,
                     retry_config=None, int timeout=0):
        """Turns images into symbolic text.

        Set at least one of the following variables to enable renderers
        before calling this method::

            tessedit_create_hocr (bool): hOCR Renderer
                if ``font_info`` is ``True`` then it'll be included in the output.
            tessedit_create_pdf (bool): PDF Renderer
            tessedit_write_unlv (bool): UNLV Renderer
            tessedit_create_boxfile (bool): Box Text Renderer
            tessedit_create_txt (bool): Text Renderer

        .. note:

            If tessedit_page_number variable is non-negative, will only process that
            single page. Works for multi-page tiff file, or filelist.

        Args:
            outputbase (str): The name of the output file excluding
                extension. For example, "/path/to/chocolate-chip-cookie-recipe".
            filename (str): Can point to a single image, a multi-page TIFF,
                or a plain text list of image filenames.

        Kwargs:
            retry_config (str): Is useful for debugging. If specified, you can fall
                back to an alternate configuration if a page fails for some reason.
            timeout (int): Terminates processing if any single page
                takes too long (`timeout` milliseconds). Defaults to 0 (unlimited).

        Returns:
            bool: True if successful, False on error.

        Raises:
            :exc:`RuntimeError`: If no renderers enabled in api variables.
        """
        cdef:
            bytes py_outputbase = _b(outputbase)
            TessResultRenderer *renderer = self._get_renderer(py_outputbase)
            bytes py_fname = _b(filename)
            bytes py_config
            cchar_t *cconfig

        if renderer != NULL:
            if retry_config is not None:
                py_config = _b(retry_config)
                cconfig = py_config
            else:
                cconfig = NULL
            try:
                return self._baseapi.ProcessPages(py_fname, cconfig, timeout, renderer)
            finally:
                del renderer
        raise RuntimeError('No renderers enabled')

    def ProcessPage(self, outputbase, image, int page_index, filename,
                    retry_config=None, int timeout=0):
        """Turn a single image into symbolic text.

        See :meth:`ProcessPages` for desciptions of the keyword arguments
        and all other details.

        Args:
            outputbase (str): The name of the output file excluding
                extension. For example, "/path/to/chocolate-chip-cookie-recipe".
            image (:class:`PIL.Image`): The image processed.
            page_index (int): Page index (metadata).
            filename (str): `filename` and `page_index` are metadata
                used by side-effect processes, such as reading a box
                file or formatting as hOCR.

        Raises:
            RuntimeError: If `image` is invalid or no renderers are enabled.
        """
        cdef:
            bytes py_fname = _b(filename)
            cchar_t *cfname = py_fname
            bytes py_outputbase = _b(outputbase)
            TessResultRenderer *renderer = self._get_renderer(py_outputbase)
            bytes py_config
            cchar_t *cconfig
            cuchar_t *buff
            size_t size
            Pix *pix
        raw = _image_buffer(image)
        size = len(raw)
        buff = raw
        pix = pixReadMem(buff, size)
        if pix == NULL:
            raise RuntimeError('Failed to read image')
        if renderer != NULL:
            if retry_config is not None:
                py_config = _b(retry_config)
                cconfig = py_config
            else:
                cconfig = NULL
            try:
                return self._baseapi.ProcessPage(pix, page_index, cfname, cconfig, timeout, renderer)
            finally:
                pixDestroy(&pix)
                del renderer
        raise RuntimeError('No renderers enabled')

    def GetIterator(self):
        """Get a reading-order iterator to the results of :meth:`LayoutAnalysis` and/or
        :meth:`Recognize`.

        Returns:
            :class:`PyResultIterator`: reading-order iterator or `None` on failure.
        """
        cdef ResultIterator *iterator = self._baseapi.GetIterator()
        if iterator == NULL:
            return None
        return PyResultIterator.createResultIterator(iterator)

    def GetUTF8Text(self):
        """Return the recognized text coded as UTF-8 from the image."""
        cdef char *text
        with nogil:
            text = self._baseapi.GetUTF8Text()
            self._destroy_pix()
            if text == NULL:
                with gil:
                    raise RuntimeError('Failed to recognize. No image set?')
        return _free_str(text)

    def GetHOCRText(self, int page_number):
        """Return a HTML-formatted string with hOCR markup from the internal
        data structures.

        Args:
            page_number (int): Page number is 0-based but will appear in the output as 1-based.
        """
        cdef char *text
        with nogil:
            text = self._baseapi.GetHOCRText(page_number)
            self._destroy_pix()
            if text == NULL:
                with gil:
                    raise RuntimeError('Failed to recognize. No image set?')
        return _free_str(text)

    IF TESSERACT_VERSION >= 0x040000:
        def GetTSVText(self, int page_number):
            """Make a TSV-formatted string from the internal data structures.

            Args:
                page_number (int): Page number is 0-based but will appear in the output as 1-based.
            """
            cdef char *text
            with nogil:
                text = self._baseapi.GetTSVText(page_number)
                self._destroy_pix()
                if text == NULL:
                    with gil:
                        raise RuntimeError('Failed to recognize. No image set?')
            return _free_str(text)

    def GetBoxText(self, int page_number):
        """Return recognized text coded in the same
        format as a box file used in training.

        Constructs coordinates in the original image - not just the rectangle.

        Args:
            page_number (int): Page number is a 0-based page index that will appear
                in the box file.
        """
        cdef char *text
        with nogil:
            text = self._baseapi.GetBoxText(page_number)
            self._destroy_pix()
            if text == NULL:
                with gil:
                    raise RuntimeError('Failed to recognize. No image set?')
        return _free_str(text)

    def GetUNLVText(self):
        """Return the recognized text coded as UNLV format Latin-1 with
        specific reject and suspect codes.
        """
        cdef char *text
        with nogil:
            text = self._baseapi.GetUNLVText()
            self._destroy_pix()
            if text == NULL:
                with gil:
                    raise RuntimeError('Failed to recognize. No image set?')
        return _free_str(text)

    IF TESSERACT_VERSION >= 0x040000:
        def DetectOrientationScript(self):
            """Detect the orientation of the input image and apparent script (alphabet).

            Returns:
                `dict` or `None` if image was not successfully processed. dict contains:
                    - orient_deg: Orientation of detected clockwise rotation of the input image in degrees
                      (0, 90, 180, 270).
                    - orient_conf: The orientation confidence (15.0 is reasonably confident).
                    - script_name: ASCII string, the name of the script, e.g. "Latin".
                    - script_conf: Script confidence.
            """
            cdef:
                int orient_deg
                float orient_conf
                cchar_t *script_name
                float script_conf
            if self._baseapi.DetectOrientationScript(&orient_deg, &orient_conf, &script_name, &script_conf):
                return {'orient_deg': orient_deg,
                        'orient_conf': orient_conf,
                        'script_name': script_name,
                        'script_conf': script_conf}
            return None


    def MeanTextConf(self):
        """Return the (average) confidence value between 0 and 100."""
        return self._baseapi.MeanTextConf()

    def AllWordConfidences(self):
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

    def AllWords(self):
        """Return list of all detected words.

        Returns an empty list if :meth:`Recognize` was not called first.
        """
        words = []
        wi = self.GetIterator()
        if wi:
            for w in iterate_level(wi, RIL.WORD):
                words.append(w.GetUTF8Text(RIL.WORD))
        return words

    def MapWordConfidences(self):
        """Return list of word, confidence tuples"""
        return list(zip(self.AllWords(), self.AllWordConfidences()))

    def AdaptToWordStr(self, PageSegMode psm, word):
        """Apply the given word to the adaptive classifier if possible.

        Assumes that :meth:`SetImage` / :meth:`SetRectangle` have been used to set the image
        to the given word.

        Args:
            psm (int): Should be :attr:`PSM.SINGLE_WORD` or
                :attr:`PSM.CIRCLE_WORD`, as that will be used to control layout analysis.
                The currently set PageSegMode is preserved.
            word (str): The word must be SPACE-DELIMITED UTF-8 - l i k e t h i s , so it can
                tell the boundaries of the graphemes.

        Returns:
            bool: ``False`` if adaption was not possible for some reason.
        """
        cdef bytes py_word = _b(word)
        return self._baseapi.AdaptToWordStr(psm, py_word)

    def Clear(self):
        """Free up recognition results and any stored image data, without actually
        freeing any recognition data that would be time-consuming to reload.
        """
        with nogil:
            self._destroy_pix()
            self._baseapi.Clear()

    def End(self):
        """Close down tesseract and free up all memory."""
        with nogil:
            self._end_api()

    def IsValidCharacter(self, character):
        """Return True if character is defined in the UniCharset.

        Args:
            character: UTF-8 encoded character.
        """
        cdef bytes py_character = _b(character)
        return self._baseapi.IsValidCharacter(py_character)

    def GetTextDirection(self):
        """Get text direction.

        Returns:
            tuple: offset and slope
        """
        cdef:
            int out_offset
            float out_slope
        self._baseapi.GetTextDirection(&out_offset, &out_slope)
        return out_offset, out_slope

    def DetectOS(self):
        """Estimate the Orientation and Script of the image.

        Returns:
            `dict` or `None` if image was not successfully processed. dict contains:
                - orientation: Orientation ids [0..3] map to [0, 270, 180, 90] degree orientations of the
                  page respectively, where the values refer to the amount of clockwise
                  rotation to be applied to the page for the text to be upright and readable.
                - oconfidence: Orientation confidence.
                - script: Index of the script with the highest score for this orientation.
                - sconfidence: script confidence.
        """
        cdef OSResults results
        if self._baseapi.DetectOS(&results):
            return {'orientation': results.best_result.orientation_id,
                    'oconfidence': results.best_result.oconfidence,
                    'script': results.get_best_script(results.best_result.orientation_id),
                    'sconfidence': results.best_result.sconfidence}
        return None

    def GetUnichar(self, int unichar_id):
        """Return the string form of the specified unichar.

        Args:
            unichar_id (int): unichar id.
        """
        return self._baseapi.GetUnichar(unichar_id)

    def oem(self):
        """Return the last set OCR engine mode."""
        return self._baseapi.oem()

    def set_min_orientation_margin(self, double margin):
        """Set minimum orientation margin.

        Args:
            margin (float): orientation margin.
        """
        self._baseapi.set_min_orientation_margin(margin)

    def __enter__(self):
        return self

    def __exit__(self, exc_tp, exc_val, exc_tb):
        with nogil:
            self._end_api()
        return False


cdef char *_image_to_text(Pix *pix, cchar_t *lang, const PageSegMode pagesegmode,
                          cchar_t *path, OcrEngineMode oem) nogil:
    cdef:
        TessBaseAPI baseapi
        char *text

    if baseapi.Init(path, lang, oem) == -1:
        return NULL

    baseapi.SetPageSegMode(pagesegmode)
    baseapi.SetImage(pix)
    text = baseapi.GetUTF8Text()
    pixDestroy(&pix)
    baseapi.End()

    return text


def image_to_text(image, lang=_DEFAULT_LANG, PageSegMode psm=PSM_AUTO,
                  path=_DEFAULT_PATH, OcrEngineMode oem=OEM_DEFAULT):
    """Recognize OCR text from an image object.

    Args:
        image (:class:`PIL.Image`): image to be processed.

    Kwargs:
        lang (str): An ISO 639-3 language string. Defaults to 'eng'.
        psm (int): Page segmentation mode. Defaults to :attr:`PSM.AUTO`.
            See :class:`PSM` for all available psm options.
        path (str): The name of the parent directory of tessdata.
            Must end in /.
        oem (int): OCR engine mode. Defaults to :attr:`OEM.DEFAULT`.
            see :class:`OEM` for all avaialble oem options.

    Returns:
        unicode: The text extracted from the image.

    Raises:
        :exc:`RuntimeError`: When image fails to be loaded or recognition fails.
    """
    cdef:
        bytes py_path = _b(path)
        bytes py_lang = _b(lang)
        cchar_t *cpath = py_path
        cchar_t *clang = py_lang
        Pix *pix
        cuchar_t *buff
        size_t size
        char *text
        bytes raw

    raw = _image_buffer(image)
    buff = raw
    size = len(raw)

    with nogil:
        pix = pixReadMem(buff, size)
        if pix == NULL:
            with gil:
                raise RuntimeError('Failed to read picture')
        text = _image_to_text(pix, clang, psm, cpath, oem)
        if text == NULL:
            with gil:
                raise RuntimeError('Failed to init API, possibly an invalid tessdata path: {}'.format(path))

    return _free_str(text)


def file_to_text(filename, lang=_DEFAULT_LANG, PageSegMode psm=PSM_AUTO,
                 path=_DEFAULT_PATH, OcrEngineMode oem=OEM_DEFAULT):
    """Extract OCR text from an image file.

    Args:
        filename (str): Image file relative or absolute path.

    Kwargs:
        lang (str): An ISO 639-3 language string. Defaults to 'eng'
        psm (int): Page segmentation mode. Defaults to :attr:`PSM.AUTO`
            See :class:`PSM` for all available psm options.
        path (str): The name of the parent directory of tessdata.
            Must end in /.
        oem (int): OCR engine mode. Defaults to :attr:`OEM.DEFAULT`.
            see :class:`OEM` for all avaialble oem options.

    Returns:
        unicode: The text extracted from the image.

    Raises:
        :exc:`RuntimeError`: When image fails to be loaded or recognition fails.
    """
    cdef:
        bytes py_fname = _b(filename)
        bytes py_lang = _b(lang)
        bytes py_path = _b(path)
        cchar_t *cfname = py_fname
        cchar_t *clang = py_lang
        cchar_t *cpath = py_path
        Pix *pix
        char *text

    with nogil:
        pix = pixRead(cfname)
        if pix == NULL:
            with gil:
                raise RuntimeError('Failed to read picture')
        text = _image_to_text(pix, clang, psm, cpath, oem)
        if text == NULL:
            with gil:
                raise RuntimeError('Failed to init API, possibly an invalid tessdata path: {}'.format(path))

    return _free_str(text)


def tesseract_version():
    """Return tesseract-ocr and leptonica version info"""
    version_str = u"tesseract {}\n {}\n  {}"
    tess_v = TessBaseAPI.Version()
    lept_v = _free_str(getLeptonicaVersion())
    libs_v = _free_str(getImagelibVersions())
    return version_str.format(tess_v, lept_v, libs_v)


def get_languages(path=_DEFAULT_PATH):
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
        bytes py_path = _b(path)
        TessBaseAPI baseapi
        GenericVector[STRING] v
        int i
    baseapi.Init(py_path, NULL)
    path = baseapi.GetDatapath()
    baseapi.GetAvailableLanguagesAsVector(&v)
    langs = [v[i].string() for i in xrange(v.size())]
    baseapi.End()
    return path, langs
