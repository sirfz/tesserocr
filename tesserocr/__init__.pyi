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

import typing, PIL


class OEM(int):
    """An enum that defines available OCR engine modes.

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

    TESSERACT_ONLY = ...
    LSTM_ONLY = ...
    TESSERACT_LSTM_COMBINED = ...
    CUBE_ONLY = ...
    TESSERACT_CUBE_COMBINED = ...
    DEFAULT = ...


class PSM(int):
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

    OSD_ONLY = ...
    """Orientation and script detection only."""

    AUTO_OSD = ...
    """Automatic page segmentation with orientation and script detection. (OSD)"""

    AUTO_ONLY = ...
    """Automatic page segmentation, but no OSD, or OCR."""

    AUTO = ...
    """Fully automatic page segmentation, but no OSD. (tesserocr default)"""

    SINGLE_COLUMN = ...
    """Assume a single column of text of variable sizes."""

    SINGLE_BLOCK_VERT_TEXT = ...
    """Assume a single uniform block of vertically aligned text."""

    SINGLE_BLOCK = ...
    """Assume a single uniform block of text. (Default.)"""

    SINGLE_LINE = ...
    """Treat the image as a single text line."""

    SINGLE_WORD = ...
    """Treat the image as a single word."""

    CIRCLE_WORD = ...
    """Treat the image as a single word in a circle."""

    SINGLE_CHAR = ...
    """Treat the image as a single character."""

    SPARSE_TEXT = ...
    """Find as much text as possible in no particular order."""

    SPARSE_TEXT_OSD = ...
    """Sparse text with orientation and script det."""

    RAW_LINE = ...
    """Treat the image as a single text line, bypassing hacks that are Tesseract-specific."""

    COUNT = ...
    """Number of enum entries."""


class RIL(int):
    """An enum that defines available Page Iterator levels.

    Attributes:
        BLOCK: of text/image/separator line.
        PARA: within a block.
        TEXTLINE: within a paragraph.
        WORD: within a textline.
        SYMBOL: character within a word.
    """

    BLOCK = ...
    """of text/image/separator line."""

    PARA = ...
    """within a block."""

    TEXTLINE = ...
    """within a paragraph."""

    WORD = ...
    """within a textline."""

    SYMBOL = ...
    """character within a word."""


class PT(int):
    """An enum that defines available Poly Block types.

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

    UNKNOWN = ...
    """Type is not yet known. Keep as the first element."""

    FLOWING_TEXT = ...
    """Text that lives inside a column."""

    HEADING_TEXT = ...
    """Text that spans more than one column."""

    PULLOUT_TEXT = ...
    """Text that is in a cross-column pull-out region."""

    EQUATION = ...
    """Partition belonging to an equation region."""

    INLINE_EQUATION = ...
    """Partition has inline equation."""

    TABLE = ...
    """Partition belonging to a table region."""

    VERTICAL_TEXT = ...
    """Text-line runs vertically."""

    CAPTION_TEXT = ...
    """Text that belongs to an image."""

    FLOWING_IMAGE = ...
    """Image that lives inside a column."""

    HEADING_IMAGE = ...
    """Image that spans more than one column."""

    PULLOUT_IMAGE = ...
    """Image that is in a cross-column pull-out region."""

    HORZ_LINE = ...
    """Horizontal Line."""

    VERT_LINE = ...
    """Vertical Line."""

    NOISE = ...
    """Lies outside of any column."""

    COUNT = ...


class Orientation(int):
    """Enum for orientation options."""

    PAGE_UP = ...
    PAGE_RIGHT = ...
    PAGE_DOWN = ...
    PAGE_LEFT = ...


class WritingDirection(int):
    """Enum for writing direction options."""

    LEFT_TO_RIGHT = ...
    RIGHT_TO_LEFT = ...
    TOP_TO_BOTTOM = ...


class TextlineOrder(int):
    """Enum for text line order options."""

    LEFT_TO_RIGHT = ...
    RIGHT_TO_LEFT = ...
    TOP_TO_BOTTOM = ...


class Justification(int):
    """Enum for justification options."""

    UNKNOWN = ...
    LEFT = ...
    CENTER = ...
    RIGHT = ...


class DIR(int):
    """Enum for strong text direction values.

    Attributes:
        NEUTRAL: Text contains only neutral characters.
        LEFT_TO_RIGHT: Text contains no Right-to-Left characters.
        RIGHT_TO_LEFT: Text contains no Left-to-Right characters.
        MIX: Text contains a mixture of left-to-right and right-to-left characters.
    """

    NEUTRAL = ...
    """Text contains only neutral characters."""
    LEFT_TO_RIGHT = ...
    """Text contains no Right-to-Left characters."""
    RIGHT_TO_LEFT = ...
    """Text contains no Left-to-Right characters."""
    MIX = ...
    """Text contains a mixture of left-to-right
    and right-to-left characters."""


class LeptLogLevel(int):
    """Enum for Leptonica log messages level."""

    EXTERNAL = ...
    """Get the severity from the environment"""
    ALL = ...
    """Lowest severity: print all messages"""
    DEBUG = ...
    """Print debugging and higher messages"""
    INFO = ...
    """Print informational and higher messages"""
    WARNING = ...
    """Print warning and higher messages"""
    ERROR = ...
    """Print error and higher messages"""
    NONE = ...
    """Highest severity: print no messages"""


def boxa_to_list(boxa):
    """Convert Boxa (boxes array) to list of boxes dicts."""
    ...


class PyPageIterator:
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

    def Begin(self) -> None:
        """Move the iterator to point to the start of the page to begin an iteration."""
        ...

    def RestartParagraph(self) -> None:
        """Move the iterator to the beginning of the paragraph.

        This class implements this functionality by moving it to the zero indexed
        blob of the first (leftmost) word on the first row of the paragraph.
        """
        ...

    def IsWithinFirstTextlineOfParagraph(self) -> bool:
        """Return whether this iterator points anywhere in the first textline of a
        paragraph."""
        ...

    def RestartRow(self):
        """Move the iterator to the beginning of the text line.

        This class implements this functionality by moving it to the zero indexed
        blob of the first (leftmost) word of the row.
        """
        ...

    def Next(self, level: RIL):
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
        ...

    def IsAtBeginningOf(self, level: RIL) -> bool:
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
        ...

    def IsAtFinalElement(self, level: RIL, element: RIL) -> bool:
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
        ...

    def SetBoundingBoxComponents(self, include_upper_dots: bool, include_lower_dots: bool):
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
        ...

    def BoundingBox(self, level: RIL, padding: int = 0) -> luple[int, int, int, int]:
        """Return the bounding rectangle of the current object at the given level.

        See comment on coordinate system above.

        Args:
            level (int): Page Iteration Level. See :class:`RIL` for available levels.

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
        ...

    def BoundingBoxInternal(self, level: RIL) -> tuple[int, int, int, int]:
        """Return the bounding rectangle of the object in a coordinate system of the
        working image rectangle having its origin at (rect_left_, rect_top_) with
        respect to the original image and is scaled by a factor scale_.

        Args:
            level (int): Page Iteration Level. See :class:`RIL` for available levels.

        Returns:
            tuple or None if there is no such object at the current position.
                The returned bounding box is represented as a tuple with
                left, top, right and bottom values respectively.
        """
        ...

    def Empty(self, level: RIL) -> bool:
        """Return whether there is no object of a given level.

        Args:
            level (int): Iterator level. See :class:`RIL`.

        Returns:
            bool: ``True`` if there is no object at the given level.
        """
        ...

    def BlockType(self) -> PT:
        """Return the type of the current block. See :class:`PolyBlockType` for
        possible types.
        """
        ...

    def BlockPolygon(self) -> list[tuple[int, int]]:
        """Return the polygon outline of the current block.

        Returns:
            list or None: list of points (x,y tuples) which list the vertices
                of the polygon, and the last edge is the line segment between the last
                point and the first point.

                ``None`` will be returned if the iterator is
                at the end of the document or layout analysis was not used.
        """
        ...

    def GetBinaryImage(self, level: RIL) -> PIL.Image:
        """Return a binary image of the current object at the given level.

        The image is masked along the polygon outline of the current block, as given
        by :meth:`BlockPolygon`. (Pixels outside the mask will be white.)

        The position and size match the return from :meth:`BoundingBoxInternal`, and so
        this could be upscaled with respect to the original input image.

        Args:
            level (int): Iterator level. See :class:`RIL`.

        Returns:
            :class:`PIL.Image`: Image object or None if no image is returned.
        """
        ...

    def GetImage(self, level: RIL, padding: int, original_image: PIL.Image) -> tuple[PIL.Image, int, int]:
        """Return an image of the current object at the given level in greyscale
        if available in the input.

        The image is masked along the polygon outline of the current block, as given
        by :meth:`BlockPolygon`. (Pixels outside the mask will be white.)

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
        ...

    def Baseline(self, level: RIL) -> tuple[tuple[int, int], tuple[int, int]]:
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
        ...

    def Orientation(self) -> tuple[Orientation, WritingDirection, TextlineOrder, float]:
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
        ...

    def ParagraphInfo(self) -> tuple[Justification, bool, bool, int]:
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
        ...


class PyLTRResultIterator(PyPageIterator):

    def GetChoiceIterator(self) -> PyChoiceIterator:
        """Return `PyChoiceIterator` instance to iterate over symbol choices.

        Returns `None` on failure.
        """
        ...

    def GetUTF8Text(self, level: RIL) -> str:
        """Returns the UTF-8 encoded text string for the current
        object at the given level.

        Args:
            level (int): Iterator level. See :class:`RIL`.

        Returns:
            unicode: UTF-8 encoded text for the given level's current object.

        Raises:
            :exc:`RuntimeError`: If no text returned.
        """
        ...

    def SetLineSeparator(self, separator: str):
        """Set the string inserted at the end of each text line. "\n" by default."""
        ...

    def SetParagraphSeparator(self, separator: str):
        """Set the string inserted at the end of each paragraph. "\n" by default."""
        ...

    def Confidence(self, level: RIL) -> float:
        """Return the mean confidence of the current object at the given level.

        The number should be interpreted as a percent probability. (0.0-100.0)
        """
        ...

    def RowAttributes(self) -> dict[str, float]:
        """Return row_height, descenders and ascenders in a dict"""
        ...

    def WordFontAttributes(self) -> dict:
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
        ...

    def WordRecognitionLanguage(self) -> str:
        """Return the name of the language used to recognize this word.

        Returns ``None`` on error.
        """
        ...

    def WordDirection(self) -> DIR:
        """Return the overall directionality of this word.

        See :class:`DIR` for available values.
        """
        ...

    def WordIsFromDictionary(self) -> bool:
        """Return True if the current word was found in a dictionary."""
        ...

    def BlanksBeforeWord(self) -> bool:
        """Return True if the current word is numeric."""
        ...

    def WordIsNumeric(self) -> bool:
        """Return True if the current word is numeric."""
        ...

    def HasBlamerInfo(self) -> bool:
        """Return True if the word contains blamer information."""
        ...

    def GetBlamerDebug(self) -> str:
        """Return a string with blamer information for this word."""
        ...

    def GetBlamerMisadaptionDebug(self) -> str:
        """Return a string with misadaption information for this word."""
        ...

    def HasTruthString(self) -> bool:
        """Returns True if a truth string was recorded for the current word."""
        ...

    def EquivalentToTruth(self, text: str) -> bool:
        """Return True if the given string is equivalent to the truth string for
        the current word."""
        ...

    def WordTruthUTF8Text(self) -> str:
        """Return a UTF-8 encoded truth string for the current word."""
        ...

    def WordNormedUTF8Text(self) -> str:
        """Returns a UTF-8 encoded normalized OCR string for the
        current word."""
        ...

    def WordLattice(self) -> str:
        """Return a serialized choice lattice."""
        ...

    def SymbolIsSuperscript(self) -> bool:
        """Return True if the current symbol is a superscript.

        If iterating at a higher level object than symbols, eg words, then
        this will return the attributes of the first symbol in that word.
        """
        ...

    def SymbolIsSubscript(self) -> bool:
        """Return True if the current symbol is a subscript.

        If iterating at a higher level object than symbols, eg words, then
        this will return the attributes of the first symbol in that word.
        """
        ...

    def SymbolIsDropcap(self) -> bool:
        """Return True if the current symbol is a dropcap.

        If iterating at a higher level object than symbols, eg words, then
        this will return the attributes of the first symbol in that word.
        """
        ...


class PyResultIterator(PyLTRResultIterator):
    """Wrapper around Tesseract's ``ResultIterator`` class.

    .. note::

        You can iterate through the elements of a level using the :func:`iterate_level`
        helper function:

        >>> for e in iterate_level(api.GetIterator(), RIL.WORD):
        ...     word = e.GetUTF8Text()

    See :class:`PyPageIterator` for more details.
    """

    def IsAtBeginningOf(self, level: RIL) -> bool:
        """Return whether we're at the logical beginning of the
        given level. (as opposed to :class:`PyResultIterator`'s left-to-right
        top-to-bottom order).

        Otherwise, this acts the same as :meth:`PyPageIterator.IsAtBeginningOf`.
        """
        ...

    def ParagraphIsLtr(self) -> bool:
        """Return whether the current paragraph's dominant reading direction
        is left-to-right (as opposed to right-to-left).
        """
        ...

    def GetBestLSTMSymbolChoices(self) -> list[typing.Any]:
        """Returns the LSTM choices for every LSTM timestep for the current word."""
        ...


class PyChoiceIterator:

    def Next(self) -> bool:
        """Move to the next choice for the symbol and returns False if there
        are none left."""
        ...

    def GetUTF8Text(self) -> str:
        """Return the UTF-8 encoded text string for the current
        choice."""
        ...

    def Confidence(self) -> float:
        """Return the confidence of the current choice.

        The number should be interpreted as a percent probability. (0.0f-100.0f)
        """
        ...


def iterate_choices(citerator: PyChoiceIterator):
    """Helper generator function to iterate :class:`PyChoiceIterator`."""
    ...


def iterate_level(iterator: PyPageIterator, level: RIL):
    """Helper generator function to iterate a :class:`PyPageIterator`
    level.

    Args:
        iterator: Instance of :class:`PyPageIterator`
        level: Page iterator level :class:`RIL`
    """
    ...


class PyTessBaseAPI:
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
        path (str): The name of the tessdata directory (version>=4) or the parent of it (version<=3)
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
        psm (int): the desired PageSegMode. Defaults to :attr:`PSM.AUTO`
            See :class:`PSM` for all available options.
        init (bool): if ``False``, the tesseract API won't be initialized. You need
            to call one of `Init` or `InitFull` to initialize the API. Defaults to ``True``
        oem (int): OCR engine mode. Defaults to :attr:`OEM.DEFAULT`.
            See :class:`OEM` for all available options.
        configs (list): List of config files to load variables from.
        variables (dict): Extra variables to be set.
        set_only_non_debug_params (bool): If ``True``, only params that do not contain
            "debug" in the name will be set.

    Raises:
        :exc:`RuntimeError`: If `init` is ``True`` and API initialization fails.
    """

    @staticmethod
    def Version() -> str:
        ...

    @staticmethod
    def ClearPersistentCache():
        ...

    def GetDatapath(self) -> str:
        """Return tessdata directory(version>=4) or parent of tessdata directory(version<=3)"""
        ...

    def SetOutputName(self, name) -> None:
        """Set the name of the bonus output files. Needed only for debugging."""
        ...

    def SetVariable(self, name: str, val: str) -> bool:
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
        ...

    def SetDebugVariable(self, name: str, val: str) -> bool:
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
        ...

    def GetIntVariable(self, name: str) -> int:
        """Return the value of the given int parameter if it exists among Tesseract parameters.

        Returns ``None`` if the parameter was not found.
        """
        ...

    def GetBoolVariable(self, name: str) -> bool:
        """Return the value of the given bool parameter if it exists among Tesseract parameters.

        Returns ``None`` if the parameter was not found.
        """
        ...

    def GetDoubleVariable(self, name: str) -> float:
        """Return the value of the given double parameter if it exists among Tesseract parameters.

        Returns ``None`` if the parameter was not found.
        """
        ...

    def GetStringVariable(self, name: str) -> str:
        """Return the value of the given string parameter if it exists among Tesseract parameters.

        Returns ``None`` if the parameter was not found.
        """
        ...

    def GetVariableAsString(self, name: str) -> str:
        """Return the value of named variable as a string (regardless of type),
        if it exists.

        Returns ``None`` if parameter was not found.
        """
        ...

    def InitFull(self,
                 path: str = ...,
                 lang: str = ...,
                 oem: OEM = OEM.DEFAULT,
                 configs: typing.Optional[list] = None,
                 variables: typing.Optional[dict] = None,
                 set_only_non_debug_params: bool = False,
                 psm: PSM = PSM.AUTO) -> None:
        """Initialize the API with the given parameters (advanced).

        It is entirely safe (and eventually will be efficient too) to call
        :meth:`Init` multiple times on the same instance to change language, or just
        to reset the classifier.

        Page Segmentation Mode is set to :attr:`PSM.AUTO` after initialization by default.

        Args:
            path (str): The name of the tessdata directory (version>=4) or the parent of it (version<=3)
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
                See :class:`OEM` for all available options.
            configs (list): List of config files to load variables from.
            variables (dict): Extra variables to be set.
            set_only_non_debug_params (bool): If ``True``, only params that do not contain
                "debug" in the name will be set.
            psm (int): the desired PageSegMode. Defaults to :attr:`PSM.AUTO`
                See :class:`PSM` for all available options.

        Raises:
            :exc:`RuntimeError`: If API initialization fails.
        """
        ...

    def Init(self, path: str = ..., lang: str = ...,
             oem: OEM = OEM.DEFAULT, psm: PSM = PSM.AUTO) -> None:
        """Initialize the API with the given data path, language and OCR engine mode.

        See :meth:`InitFull` for more initialization info and options.

        Args:
            path (str): The name of the tessdata directory (version>=4) or the parent of it (version<=3)
                Must end in /. Uses default installation path if not specified.
            lang (str): An ISO 639-3 language string. Defaults to 'eng'.
                See :meth:`InitFull` for full description of this parameter.
            oem (int): OCR engine mode. Defaults to :attr:`OEM.DEFAULT`.
                See :class:`OEM` for all available options.
            psm (int): the desired PageSegMode. Defaults to :attr:`PSM.AUTO`
                See :class:`PSM` for all available options.

        Raises:
            :exc:`RuntimeError`: If API initialization fails.
        """
        ...

    def GetInitLanguagesAsString(self) -> None:
        """Return the languages string used in the last valid initialization.

        If the last initialization specified "deu+hin" then that will be
        returned. If hin loaded eng automatically as well, then that will
        not be included in this list. To find the languages actually
        loaded use :meth:`GetLoadedLanguages`.
        """
        ...

    def GetLoadedLanguages(self) -> list[str]:
        """Return the loaded languages as a list of STRINGs.

        Includes all languages loaded by the last Init, including those loaded
        as dependencies of other loaded languages.
        """
        ...

    def GetAvailableLanguages(self) -> list[str]:
        """Return list of available languages in the init data path"""
        ...

    def InitForAnalysePage(self) -> list[str]:
        """Init only for page layout analysis.

        Use only for calls to :meth:`SetImage` and :meth:`AnalysePage`.
        Calls that attempt recognition will generate an error.
        """
        ...

    def ReadConfigFile(self, filename: str) -> None:
        """Read a "config" file containing a set of param, value pairs.

        Searches the standard places: tessdata/configs, tessdata/tessconfigs.

        Args:
            filename: config file name. Also accepts relative or absolute path name.
        """
        ...

    def SetPageSegMode(self, psm: PSM) -> None:
        """Set page segmentation mode.

        Args:
            psm (int): page segmentation mode.
                See :class:`PSM` for all available psm options.
        """
        ...

    def GetPageSegMode(self) -> PSM:
        """Return the current page segmentation mode."""
        ...

    def TesseractRect(self, imagedata: str,
                      bytes_per_pixel: int, bytes_per_line: int,
                      left: int, top: int, width: int, height: int) -> str:
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
        ...

    def ClearAdaptiveClassifier(self) -> None:
        """Call between pages or documents etc to free up memory and forget
        adaptive data.
        """
        ...

    def SetImageBytes(self, imagedata: str, width: int, height: int,
                      bytes_per_pixel: int, bytes_per_line: int) -> None:
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
        ...

    def SetImageBytesBmp(self, imagedata: str) -> None:
        """Provide an image for Tesseract to recognize.

        Args:
            imagedata (:bytes): Raw bytes of a BMP image.

        Raises:
            :exc:`RuntimeError`: If for any reason the api failed
                to load the given image.
        """
        ...

    def SetImage(self, image: PIL.Image) -> None:
        """Provide an image for Tesseract to recognize.

        This method can be called multiple times after :meth:`Init`.

        Args:
            image (:class:PIL.Image): Image object.

        Raises:
            :exc:`RuntimeError`: If for any reason the api failed
                to load the given image.
        """
        ...

    def SetImageFile(self, filename: str) -> None:
        """Set image from file for Tesseract to recognize.

        Args:
            filename (str): Image file relative or absolute path.

        Raises:
            :exc:`RuntimeError`: If for any reason the api failed
                to load the given image.
        """
        ...

    def SetSourceResolution(self, ppi: int) -> None:
        """Set the resolution of the source image in pixels per inch so font size
        information can be calculated in results.

        Call this after :meth:`SetImage`.
        """
        ...

    def SetRectangle(self, left: int, top: int, width: int, height: int) -> None:
        """Restrict recognition to a sub-rectangle of the image. Call after :meth:`SetImage`.

        Each SetRectangle clears the recogntion results so multiple rectangles
        can be recognized with the same image.

        Args:
            left (int): position from left
            top (int): position from top
            width (int): width
            height (int): height
        """
        ...

    def GetThresholdedImage(self) -> PIL.Image:
        """Return a copy of the internal thresholded image from Tesseract.

        May be called any time after SetImage.
        """
        ...

    def GetRegions(self) -> list[tuple[PIL.Image, dict]]:
        """Get the result of page layout analysis as a list of
        image, box bounds {x, y, width, height} tuples in reading order.

        Can be called before or after :meth:`Recognize`.

        Returns:
            list: List of tuples containing the following values respectively::

                image (:class:`PIL.Image`): Image object.
                bounding box (dict): dict with x, y, w, h keys.
        """
        ...

    def GetTextlines(self, raw_image: bool = False, raw_padding: int = 0,
                     blockids: bool = True, paraids: bool = False) -> list[tuple[PIL.Image, dict, int, int]]:
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
        ...

    def GetStrips(self, blockids: bool = True) -> list[tuple[PIL.Image, dict, int]]:
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
        ...

    def GetWords(self) -> list[tuple[PIL.Image, dict]]:
        """Get the words as a list of image, box bounds
        {x, y, width, height} tuples in reading order.

        Can be called before or after :meth:`Recognize`.

        Returns:
            list: List of tuples containing the following values respectively::
                image (:class:`PIL.Image`): Image object.
                bounding box (dict): dict with x, y, w, h keys.
        """
        ...

    def GetConnectedComponents(self) -> list[tuple[PIL.Image, dict]]:
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
        ...

    def GetComponentImages(self, level: RIL,
                           text_only: bool, raw_image: bool = False,
                           raw_padding: int = 0,
                           blockids: bool = True, paraids: bool = False) -> list[tuple[PIL.Image, dict, int, int]]:
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
        ...

    def GetThresholdedImageScaleFactor(self) -> int:
        """Return the scale factor of the thresholded image that would be returned by
        GetThresholdedImage().

        Returns:
            int: 0 if no thresholder has been set.
        """
        ...

    def AnalyseLayout(self, merge_similar_words: bool = False) -> PyPageIterator:
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
        ...

    def Recognize(self, timeout: int = 0) -> bool:
        """Recognize the image from :meth:`SetImage`, generating Tesseract
        internal structures. Returns ``True`` on success.

        Optional. The `Get*Text` methods below will call :meth:`Recognize` if needed.

        After :meth:`Recognize`, the output is kept internally until the next :meth:`SetImage`.

        Kwargs:
            timeout (int): time to wait in milliseconds before timing out.

        Returns:
            bool: ``True`` if the operation is successful.
        """
        ...

    """Methods to retrieve information after :meth:`SetImage`,
    :meth:`Recognize` or :meth:`TesseractRect`. (:meth:`Recognize` is called implicitly if needed.)"""

    def RecognizeForChopTest(self, timeout: int = 0) -> bool:
        """Variant on :meth:`Recognize` used for testing chopper."""
        ...

    def ProcessPages(self, outputbase: str, filename: str,
                     retry_config: typing.Optional[str] = None, timeout: int = 0) -> bool:
        """Turns images into symbolic text.

        Set at least one of the following variables to enable renderers
        before calling this method::

            tessedit_create_alto (bool): ALTO Renderer
                Make sure to set ``document_title`` to the image filename if you
                want to have the ALTO-XML reference it.
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
                Must not be empty. Use "-" or "stdout" to write to the current
                process' standard output.
            filename (str): Can point to a single image, a multi-page TIFF,
                or a plain text list of image filenames. If Tesseract is built
                with libcurl support, and ``str`` is a URL starting with "http:"
                or "https:" then the image file is downloaded from that location
                to the current working directory first.

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
        ...

    def ProcessPage(self, outputbase: str, image: PIL.Image, page_index: int, filename: str,
                    retry_config: str = None, timeout: int = 0) -> bool:
        """Turn a single image into symbolic text.

        See :meth:`ProcessPages` for descriptions of the keyword arguments
        and all other details (esp. output renderers).

        Args:
            outputbase (str): The name of the output file excluding
                extension. For example, "/path/to/chocolate-chip-cookie-recipe".
                Must not be empty. Use "-" or "stdout" to write to the current
                process' standard output.
            image (:class:`PIL.Image`): The image processed.
            page_index (int): Page index (metadata).
            filename (str): `filename` and `page_index` are metadata
                used by side-effect processes, such as reading a box
                file or formatting as hOCR.

        Raises:
            RuntimeError: If `image` is invalid or no renderers are enabled.
        """
        ...

    def GetIterator(self) -> PyResultIterator:
        """Get a reading-order iterator to the results of :meth:`LayoutAnalysis` and/or
        :meth:`Recognize`.

        Returns:
            :class:`PyResultIterator`: reading-order iterator or `None` on failure.
        """
        ...

    def GetUTF8Text(self) -> str:
        """Return the recognized text coded as UTF-8 from the image."""
        ...

    def GetBestLSTMSymbolChoices(self) -> list:
        """Return Symbol choices as multi-dimensional array of tupels. The
        first dimension contains words. The second dimension contains the LSTM
        timesteps of the respective word. They are either accumulated over
        characters or pure which depends on the value set in lstm_choice_mode:
        1 = pure; 2 = accumulated. The third dimension contains the symbols
        and their probability as tupels for the respective timestep.
        Returns an empty list if :meth:`Recognize` was not called first.
        """
        ...

    def GetHOCRText(self, page_number: int) -> str:
        """Return a HTML-formatted string with hOCR markup from the internal
        data structures.

        Args:
            page_number (int): Page number is 0-based but will appear in the output as 1-based.
        """
        ...

    def GetTSVText(self, page_number: int) -> str:
        """Make a TSV-formatted string from the internal data structures.

        Args:
            page_number (int): Page number is 0-based but will appear in the output as 1-based.
        """
        ...

    def GetBoxText(self, page_number: int) -> str:
        """Return recognized text coded in the same
        format as a box file used in training.

        Constructs coordinates in the original image - not just the rectangle.

        Args:
            page_number (int): Page number is a 0-based page index that will appear
                in the box file.
        """
        ...

    def GetUNLVText(self) -> str:
        """Return the recognized text coded as UNLV format Latin-1 with
        specific reject and suspect codes.
        """
        ...

    def DetectOrientationScript(self) -> dict:
        """Detect the orientation of the input image and apparent script (alphabet).

        Returns:
            `dict` or `None` if image was not successfully processed. dict contains:
                - orient_deg: Orientation of detected clockwise rotation of the input image in degrees
                  (0, 90, 180, 270).
                - orient_conf: The orientation confidence (15.0 is reasonably confident).
                - script_name: ASCII string, the name of the script, e.g. "Latin".
                - script_conf: Script confidence.
        """
        ...

    def MeanTextConf(self) -> int:
        """Return the (average) confidence value between 0 and 100."""
        ...

    def AllWordConfidences(self) -> list[int]:
        """Return all word confidences (between 0 and 100) as a list.

        The number of confidences should correspond to the number of space-
        delimited words in `GetUTF8Text`.
        """
        ...

    def AllWords(self) -> list[str]:
        """Return list of all detected words.

        Returns an empty list if :meth:`Recognize` was not called first.
        """
        ...

    def MapWordConfidences(self) -> list[tuple[str, int]]:
        """Return list of word, confidence tuples"""
        ...

    def AdaptToWordStr(self, psm: PSM, word: str) -> bool:
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
        ...

    def Clear(self) -> None:
        """Free up recognition results and any stored image data, without actually
        freeing any recognition data that would be time-consuming to reload.
        """
        ...

    def End(self) -> None:
        """Close down tesseract and free up all memory."""
        ...

    def IsValidCharacter(self, character: str) -> bool:
        """Return True if character is defined in the UniCharset.

        Args:
            character: UTF-8 encoded character.
        """
        ...

    def GetTextDirection(self) -> tuple[int, float]:
        """Get text direction.

        Returns:
            tuple: offset and slope
        """
        ...

    def DetectOS(self) -> dict:
        """Estimate the Orientation and Script of the image.

        Returns:
            `dict` or `None` if image was not successfully processed. dict contains:
                - orientation: Orientation ids [0..3] map to [0, 270, 180, 90] degree orientations of the
                  page respectively, where the values refer to the amount of clockwise
                  rotation to be applied to the page for the text to be upright and readable.
                - oconfidence: Orientation confidence.
                - script: Index of the script with the highest score for this orientation.
                  (This is _not_ the index of :meth:`get_languages`, which is in alphabetical order.)
                - sconfidence: script confidence.
        """
        ...

    def GetUnichar(self, unichar_id: int) -> str:
        """Return the string form of the specified unichar.

        Args:
            unichar_id (int): unichar id.
        """
        ...

    def oem(self) -> OEM:
        """Return the last set OCR engine mode."""
        ...

    def set_min_orientation_margin(self, margin: float) -> None:
        """Set minimum orientation margin.

        Args:
            margin (float): orientation margin.
        """
        ...


def image_to_text(image: PIL.Image, lang: str = ..., psm: PSM = PSM.AUTO,
                  path: str = ..., oem: OEM = OEM.DEFAULT) -> str:
    """Recognize OCR text from an image object.

    Args:
        image (:class:`PIL.Image`): image to be processed.

    Kwargs:
        lang (str): An ISO 639-3 language string. Defaults to 'eng'.
        psm (int): Page segmentation mode. Defaults to :attr:`PSM.AUTO`.
            See :class:`PSM` for all available psm options.
        path (str): The name of the tessdata directory (version>=4) or the parent of it (version<=3)
            Must end in /.
        oem (int): OCR engine mode. Defaults to :attr:`OEM.DEFAULT`.
            see :class:`OEM` for all available oem options.

    Returns:
        unicode: The text extracted from the image.

    Raises:
        :exc:`RuntimeError`: When image fails to be loaded or recognition fails.
    """
    ...


def file_to_text(filename: str, lang: str = ..., psm: PSM = PSM.AUTO,
                 path: str = ..., oem: OEM = OEM.DEFAULT) -> str:
    """Extract OCR text from an image file.

    Args:
        filename (str): Image file relative or absolute path.

    Kwargs:
        lang (str): An ISO 639-3 language string. Defaults to 'eng'
        psm (int): Page segmentation mode. Defaults to :attr:`PSM.AUTO`
            See :class:`PSM` for all available psm options.
        path (str): The name of the tessdata directory (version>=4) or the parent of it (version<=3)
            Must end in /.
        oem (int): OCR engine mode. Defaults to :attr:`OEM.DEFAULT`.
            see :class:`OEM` for all available oem options.

    Returns:
        unicode: The text extracted from the image.

    Raises:
        :exc:`RuntimeError`: When image fails to be loaded or recognition fails.
    """
    ...


def tesseract_version() -> str:
    """Return tesseract-ocr and leptonica version info"""
    ...


def get_languages(path=...) -> tuple[str, list[str]]:
    """Return available languages in the given path.

    Args:
        path (str): The name of the tessdata directory (version>=4) or the parent of it (version<=3)
            Must end in /. Default tesseract-ocr datapath is used
            if no path is provided.

    Returns
        tuple: Tuple with two elements:
            - path (str): tessdata directory path
            - languages (list): list of available languages as ISO 639-3 strings.
    """
    ...


def set_leptonica_log_level(level: LeptLogLevel):
    """Set Leptonica's emitted log messages level.

    See :class:`LeptLogLevel` for available options.
    """
    ...
