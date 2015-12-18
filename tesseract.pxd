cdef extern from "leptonica/allheaders.h" nogil:
    struct Pix
    Pix *pixRead(const char *)
    Pix *pixReadMemBmp(const unsigned char *, size_t)
    void pixDestroy(Pix **)

cdef extern from "tesseract/baseapi.h" namespace "tesseract" nogil:
    cdef enum PageSegMode:
        PSM_OSD_ONLY,       # Orientation and script detection only.
        PSM_AUTO_OSD,       # Automatic page segmentation with orientation and
                            # script detection. (OSD)
        PSM_AUTO_ONLY,      # Automatic page segmentation, but no OSD, or OCR.
        PSM_AUTO,           # Fully automatic page segmentation, but no OSD.
        PSM_SINGLE_COLUMN,  # Assume a single column of text of variable sizes.
        PSM_SINGLE_BLOCK_VERT_TEXT,  # Assume a single uniform block of vertically
                                     # aligned text.
        PSM_SINGLE_BLOCK,   # Assume a single uniform block of text. (Default.)
        PSM_SINGLE_LINE,    # Treat the image as a single text line.
        PSM_SINGLE_WORD,    # Treat the image as a single word.
        PSM_CIRCLE_WORD,    # Treat the image as a single word in a circle.
        PSM_SINGLE_CHAR,    # Treat the image as a single character.
        PSM_SPARSE_TEXT,    # Find as much text as possible in no particular order.
        PSM_SPARSE_TEXT_OSD,  # Sparse text with orientation and script det.
        PSM_RAW_LINE,       # Treat the image as a single text line, bypassing
                            # hacks that are Tesseract-specific.
        PSM_COUNT           # Number of enum entries.

    cdef cppclass TessBaseAPI:
        TessBaseAPI() except +
        @staticmethod
        const char *Version()
        int Init(const char *, const char *)
        void SetPageSegMode(PageSegMode)
        void SetImage(Pix *)
        char *GetUTF8Text()
        void Clear()
        void End()
