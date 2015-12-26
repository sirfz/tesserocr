from libcpp cimport bool
ctypedef const char cchar_t
ctypedef const unsigned char cuchar_t

cdef extern from "leptonica/allheaders.h" nogil:
    struct Pix
    char *getImagelibVersions()
    char *getLeptonicaVersion()
    Pix *pixRead(cchar_t *)
    Pix *pixReadMemBmp(cuchar_t *, size_t)
    int pixWriteMemBmp(unsigned char **pdata, size_t *, Pix *pix)
    void pixDestroy(Pix **)
    int setMsgSeverity(int)
    cdef enum:
        L_SEVERITY_EXTERNAL = 0   # Get the severity from the environment
        L_SEVERITY_ALL      = 1   # Lowest severity: print all messages
        L_SEVERITY_DEBUG    = 2   # Print debugging and higher messages
        L_SEVERITY_INFO     = 3   # Print informational and higher messages
        L_SEVERITY_WARNING  = 4   # Print warning and higher messages
        L_SEVERITY_ERROR    = 5   # Print error and higher messages
        L_SEVERITY_NONE     = 6   # Highest severity: print no messages

cdef extern from "tesseract/genericvector.h" nogil:
    cdef cppclass GenericVector[T]:
        int size() const
        T &operator[](int) const

cdef extern from "tesseract/strngs.h" nogil:
    cdef cppclass STRING:
       cchar_t *string() const

cdef extern from "tesseract/baseapi.h" namespace "tesseract" nogil:
    cdef enum PageSegMode:
        PSM_OSD_ONLY,                # Orientation and script detection only.
        PSM_AUTO_OSD,                # Automatic page segmentation with orientation and
                                     # script detection. (OSD)
        PSM_AUTO_ONLY,               # Automatic page segmentation, but no OSD, or OCR.
        PSM_AUTO,                    # Fully automatic page segmentation, but no OSD.
        PSM_SINGLE_COLUMN,           # Assume a single column of text of variable sizes.
        PSM_SINGLE_BLOCK_VERT_TEXT,  # Assume a single uniform block of vertically
                                     # aligned text.
        PSM_SINGLE_BLOCK,            # Assume a single uniform block of text. (Default.)
        PSM_SINGLE_LINE,             # Treat the image as a single text line.
        PSM_SINGLE_WORD,             # Treat the image as a single word.
        PSM_CIRCLE_WORD,             # Treat the image as a single word in a circle.
        PSM_SINGLE_CHAR,             # Treat the image as a single character.
        PSM_SPARSE_TEXT,             # Find as much text as possible in no particular order.
        PSM_SPARSE_TEXT_OSD,         # Sparse text with orientation and script det.
        PSM_RAW_LINE,                # Treat the image as a single text line, bypassing
                                     # hacks that are Tesseract-specific.
        PSM_COUNT                    # Number of enum entries.

    cdef cppclass TessBaseAPI:
        TessBaseAPI() except +
        @staticmethod
        cchar_t *Version()
        @staticmethod
        void ClearPersistentCache()
        cchar_t *GetDatapath()
        bool SetVariable(const char*, const char*)
        bool GetVariableAsString(const char *, STRING *)
        int Init(cchar_t *, cchar_t *)
        cchar_t *GetInitLanguagesAsString() const
        void GetLoadedLanguagesAsVector(GenericVector[STRING] *) const
        void GetAvailableLanguagesAsVector(GenericVector[STRING] *) const
        void ReadConfigFile(const char *)
        void SetPageSegMode(PageSegMode)
        PageSegMode GetPageSegMode() const
        void SetImage(cuchar_t *, int, int, int, int)
        void SetImage(Pix *)
        void SetSourceResolution(int)
        void SetRectangle(int, int, int, int)
        Pix *GetThresholdedImage()
        int GetThresholdedImageScaleFactor() const
        char *GetUTF8Text()
        int *AllWordConfidences()
        bool AdaptToWordStr(PageSegMode, const char *)
        void Clear()
        void End()
