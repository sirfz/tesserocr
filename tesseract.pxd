from libcpp cimport bool
from libcpp.pair cimport pair
from libcpp.vector cimport vector
ctypedef const char cchar_t
ctypedef const char * cchar_tp
ctypedef const unsigned char cuchar_t

cdef extern from "leptonica/allheaders.h" nogil:
    struct Pix:
        int            informat

    struct Box:
        int            x
        int            y
        int            w
        int            h

    struct Boxa:
        int            n         # number of box in ptr array
        Box            **box     # box ptr array

    struct Pixa:
        int            n         # number of Pix in ptr array
        Pix            **pix     # the array of ptrs to pix
        Boxa           *boxa     # array of boxes

    struct Pta:
        int            n         # actual number of pts
        float         *x
        float         *y         # arrays of floats

    char *getImagelibVersions()
    char *getLeptonicaVersion()
    Pix *pixRead(cchar_t *)
    Pix *pixReadMem(cuchar_t *, size_t)
    int pixWriteMemJpeg(unsigned char **, size_t *, Pix *, int, int)
    int pixWriteMem(unsigned char **, size_t *, Pix *, int)
    void pixDestroy(Pix **)
    void ptaDestroy(Pta **)
    int setMsgSeverity(int)
    void pixaDestroy(Pixa **)
    void boxaDestroy(Boxa **)

    cdef enum:
        L_SEVERITY_EXTERNAL = 0   # Get the severity from the environment
        L_SEVERITY_ALL      = 1   # Lowest severity: print all messages
        L_SEVERITY_DEBUG    = 2   # Print debugging and higher messages
        L_SEVERITY_INFO     = 3   # Print informational and higher messages
        L_SEVERITY_WARNING  = 4   # Print warning and higher messages
        L_SEVERITY_ERROR    = 5   # Print error and higher messages
        L_SEVERITY_NONE     = 6   # Highest severity: print no messages

cdef extern from "tesseract/publictypes.h" nogil:
    cdef enum PolyBlockType:
        PT_UNKNOWN          # Type is not yet known. Keep as the first element.
        PT_FLOWING_TEXT     # Text that lives inside a column.
        PT_HEADING_TEXT     # Text that spans more than one column.
        PT_PULLOUT_TEXT     # Text that is in a cross-column pull-out region.
        PT_EQUATION         # Partition belonging to an equation region.
        PT_INLINE_EQUATION  # Partition has inline equation.
        PT_TABLE            # Partition belonging to a table region.
        PT_VERTICAL_TEXT    # Text-line runs vertically.
        PT_CAPTION_TEXT     # Text that belongs to an image.
        PT_FLOWING_IMAGE    # Image that lives inside a column.
        PT_HEADING_IMAGE    # Image that spans more than one column.
        PT_PULLOUT_IMAGE    # Image that is in a cross-column pull-out region.
        PT_HORZ_LINE        # Horizontal Line.
        PT_VERT_LINE        # Vertical Line.
        PT_NOISE            # Lies outside of any column.
        PT_COUNT

cdef extern from "tesseract/publictypes.h" namespace "tesseract" nogil:

    cdef enum TessOrientation "tesseract::Orientation":
        ORIENTATION_PAGE_UP
        ORIENTATION_PAGE_RIGHT
        ORIENTATION_PAGE_DOWN
        ORIENTATION_PAGE_LEFT

    cdef enum TessWritingDirection "tesseract::WritingDirection":
        WRITING_DIRECTION_LEFT_TO_RIGHT
        WRITING_DIRECTION_RIGHT_TO_LEFT
        WRITING_DIRECTION_TOP_TO_BOTTOM

    cdef enum TessTextlineOrder "tesseract::TextlineOrder":
        TEXTLINE_ORDER_LEFT_TO_RIGHT
        TEXTLINE_ORDER_RIGHT_TO_LEFT
        TEXTLINE_ORDER_TOP_TO_BOTTOM

    cdef enum TessParagraphJustification "tesseract::ParagraphJustification":
        JUSTIFICATION_UNKNOWN
        JUSTIFICATION_LEFT
        JUSTIFICATION_CENTER
        JUSTIFICATION_RIGHT

cdef extern from "tesseract/unichar.h" nogil:
    cdef enum StrongScriptDirection:
        DIR_NEUTRAL        # Text contains only neutral characters.
        DIR_LEFT_TO_RIGHT  # Text contains no Right-to-Left characters.
        DIR_RIGHT_TO_LEFT  # Text contains no Left-to-Right characters.
        DIR_MIX            # Text contains a mixture of left-to-right
                           # and right-to-left characters.

cdef extern from "tesseract/genericvector.h" nogil:
    cdef cppclass GenericVector[T]:
        int size() const
        int push_back(T)
        bool empty() const
        T &operator[](int) const

cdef extern from "tesseract/strngs.h" nogil:
    cdef cppclass STRING:
       cchar_t *string() const
       STRING &operator=(cchar_t *)

cdef extern from "tesseract/ocrclass.h" nogil:
    ctypedef bool (*CANCEL_FUNC)(void *, int)
    cdef cppclass ETEXT_DESC:
        ETEXT_DESC() except +
        CANCEL_FUNC cancel               # returns true to cancel
        void *cancel_this                # this or other data for cancel
        void set_deadline_msecs(int)

cdef extern from "tesseract/pageiterator.h" namespace "tesseract" nogil:
    cdef cppclass PageIterator:
        void Begin()
        void RestartParagraph()
        bool IsWithinFirstTextlineOfParagraph() const
        void RestartRow()
        bool Next(PageIteratorLevel)
        bool IsAtBeginningOf(PageIteratorLevel) const
        bool IsAtFinalElement(PageIteratorLevel, PageIteratorLevel) const
        void SetBoundingBoxComponents(bool, bool)
        bool BoundingBox(PageIteratorLevel, const int, int *, int *, int *, int *) const
        bool BoundingBoxInternal(PageIteratorLevel, int *, int *, int *, int *) const
        bool Empty(PageIteratorLevel) const
        PolyBlockType BlockType() const
        Pta *BlockPolygon() const
        Pix *GetBinaryImage(PageIteratorLevel) const
        Pix *GetImage(PageIteratorLevel, int, Pix *, int *, int *) const
        bool Baseline(PageIteratorLevel, int *, int *, int *, int *) const
        void Orientation(TessOrientation *, TessWritingDirection *, TessTextlineOrder *, float *) const
        void ParagraphInfo(TessParagraphJustification *, bool *, bool *, int *) const

cdef extern from "tesseract/ltrresultiterator.h" namespace "tesseract" nogil:
    IF TESSERACT_VERSION >= 0x4000000:
        cdef cppclass LTRResultIterator(PageIterator):
            char *GetUTF8Text(PageIteratorLevel) const
            void SetLineSeparator(cchar_t *)
            void SetParagraphSeparator(cchar_t *)
            float Confidence(PageIteratorLevel) const
            void RowAttributes(float *, float *, float *) const
            cchar_t *WordFontAttributes(bool *, bool *, bool *, bool *, bool *, bool *, int *, int *) const
            cchar_t *WordRecognitionLanguage() const
            StrongScriptDirection WordDirection() const
            bool WordIsFromDictionary() const
            int BlanksBeforeWord() const
            bool WordIsNumeric() const
            bool HasBlamerInfo() const
            cchar_t *GetBlamerDebug() const
            cchar_t *GetBlamerMisadaptionDebug() const
            bool HasTruthString() const
            bool EquivalentToTruth(cchar_t *) const
            char *WordTruthUTF8Text() const
            char *WordNormedUTF8Text() const
            cchar_t *WordLattice(int *) const
            bool SymbolIsSuperscript() const
            bool SymbolIsSubscript() const
            bool SymbolIsDropcap() const
    ELIF TESSERACT_VERSION >= 0x3040100:
        cdef cppclass LTRResultIterator(PageIterator):
            char *GetUTF8Text(PageIteratorLevel) const
            void SetLineSeparator(cchar_t *)
            void SetParagraphSeparator(cchar_t *)
            float Confidence(PageIteratorLevel) const
            void RowAttributes(float *, float *, float *) const
            cchar_t *WordFontAttributes(bool *, bool *, bool *, bool *, bool *, bool *, int *, int *) const
            cchar_t *WordRecognitionLanguage() const
            StrongScriptDirection WordDirection() const
            bool WordIsFromDictionary() const
            bool WordIsNumeric() const
            bool HasBlamerInfo() const
            cchar_t *GetBlamerDebug() const
            cchar_t *GetBlamerMisadaptionDebug() const
            bool HasTruthString() const
            bool EquivalentToTruth(cchar_t *) const
            char *WordTruthUTF8Text() const
            char *WordNormedUTF8Text() const
            cchar_t *WordLattice(int *) const
            bool SymbolIsSuperscript() const
            bool SymbolIsSubscript() const
            bool SymbolIsDropcap() const
    ELSE:
        cdef cppclass LTRResultIterator(PageIterator):
            char *GetUTF8Text(PageIteratorLevel) const
            void SetLineSeparator(cchar_t *)
            void SetParagraphSeparator(cchar_t *)
            float Confidence(PageIteratorLevel) const
            cchar_t *WordFontAttributes(bool *, bool *, bool *, bool *, bool *, bool *, int *, int *) const
            cchar_t *WordRecognitionLanguage() const
            StrongScriptDirection WordDirection() const
            bool WordIsFromDictionary() const
            bool WordIsNumeric() const
            bool HasBlamerInfo() const
            cchar_t *GetBlamerDebug() const
            cchar_t *GetBlamerMisadaptionDebug() const
            bool HasTruthString() const
            bool EquivalentToTruth(cchar_t *) const
            char *WordTruthUTF8Text() const
            char *WordNormedUTF8Text() const
            cchar_t *WordLattice(int *) const
            bool SymbolIsSuperscript() const
            bool SymbolIsSubscript() const
            bool SymbolIsDropcap() const

    cdef cppclass ChoiceIterator:
        ChoiceIterator(const LTRResultIterator &) except +
        bool Next()
        cchar_t *GetUTF8Text() const
        float Confidence() const

cdef extern from "tesseract/resultiterator.h" namespace "tesseract" nogil:
    IF TESSERACT_VERSION >= 0x4000000:
        cdef cppclass ResultIterator(LTRResultIterator):
            bool ParagraphIsLtr() const
            vector[vector[pair[cchar_tp, float]]] *GetBestLSTMSymbolChoices() const
    ELSE:
        cdef cppclass ResultIterator(LTRResultIterator):
            bool ParagraphIsLtr() const

cdef extern from "tesseract/renderer.h" namespace "tesseract" nogil:
    cdef cppclass TessResultRenderer:
        void insert(TessResultRenderer *)

    cdef cppclass TessTextRenderer(TessResultRenderer):
        TessTextRenderer(cchar_t *) except +

    cdef cppclass TessHOcrRenderer(TessResultRenderer):
        TessHOcrRenderer(cchar_t *, bool) except +

    IF TESSERACT_VERSION >= 0x3999800:
        cdef cppclass TessPDFRenderer(TessResultRenderer):
            TessPDFRenderer(cchar_t *, cchar_t *, bool) except +
    ELSE:
        cdef cppclass TessPDFRenderer(TessResultRenderer):
            TessPDFRenderer(cchar_t *, cchar_t *) except +

    cdef cppclass TessUnlvRenderer(TessResultRenderer):
        TessUnlvRenderer(cchar_t *) except +

    cdef cppclass TessBoxTextRenderer(TessResultRenderer):
        TessBoxTextRenderer(cchar_t *) except +

    IF TESSERACT_VERSION >= 0x3040100:
        cdef cppclass TessOsdRenderer(TessResultRenderer):
            TessOsdRenderer(cchar_t *) except +

cdef extern from "tesseract/osdetect.h" nogil:
    struct OSBestResult:
        int orientation_id
        int script_id
        float sconfidence
        float oconfidence

    ctypedef int (*get_best_script)(int)

    struct OSResults:
        get_best_script get_best_script
        OSBestResult best_result

cdef extern from "tesseract/baseapi.h" namespace "tesseract" nogil:

    IF TESSERACT_VERSION >= 0x3999800:
        cdef enum OcrEngineMode:
            OEM_TESSERACT_ONLY
            OEM_LSTM_ONLY
            OEM_TESSERACT_LSTM_COMBINED
            OEM_DEFAULT
    ELSE:
        cdef enum OcrEngineMode:
            OEM_TESSERACT_ONLY
            OEM_CUBE_ONLY
            OEM_TESSERACT_CUBE_COMBINED
            OEM_DEFAULT

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

    cdef enum PageIteratorLevel:
        RIL_BLOCK,     # of text/image/separator line.
        RIL_PARA,      # within a block.
        RIL_TEXTLINE,  # within a paragraph.
        RIL_WORD,      # within a textline.
        RIL_SYMBOL     # character within a word.

    IF TESSERACT_VERSION >= 0x3999800:
        cdef cppclass TessBaseAPI:
            TessBaseAPI() except +
            @staticmethod
            cchar_t *Version()
            @staticmethod
            void ClearPersistentCache()
            void SetInputName(cchar_t *)
            cchar_t *GetInputName()
            void SetInputImage(Pix *)
            Pix *GetInputImage()
            int GetSourceYResolution()
            cchar_t *GetDatapath()
            void SetOutputName(cchar_t *)
            bool SetVariable(cchar_t *, cchar_t *)
            bool SetDebugVariable(cchar_t *, cchar_t *)
            bool GetIntVariable(cchar_t *, int *) const
            bool GetBoolVariable(cchar_t *, bool *) const
            bool GetDoubleVariable(cchar_t *, double *) const
            cchar_t *GetStringVariable(cchar_t *) const
            bool GetVariableAsString(cchar_t *, STRING *)
            int Init(cchar_t *, cchar_t *, OcrEngineMode mode,
                    char **, int,
                    const GenericVector[STRING] *,
                    const GenericVector[STRING] *,
                    bool)
            int Init(cchar_t *, cchar_t *, OcrEngineMode)
            int Init(cchar_t *, cchar_t *)
            cchar_t *GetInitLanguagesAsString() const
            void GetLoadedLanguagesAsVector(GenericVector[STRING] *) const
            void GetAvailableLanguagesAsVector(GenericVector[STRING] *) const
            void InitForAnalysePage()
            void ReadConfigFile(cchar_t *)
            void SetPageSegMode(PageSegMode)
            PageSegMode GetPageSegMode() const
            char *TesseractRect(cuchar_t *, int, int, int, int, int, int)
            void ClearAdaptiveClassifier()
            void SetImage(cuchar_t *, int, int, int, int)
            void SetImage(Pix *)
            void SetSourceResolution(int)
            void SetRectangle(int, int, int, int)
            Pix *GetThresholdedImage()
            Boxa *GetRegions(Pixa **)
            Boxa *GetTextlines(const bool, const int, Pixa **, int **, int **)
            Boxa *GetStrips(Pixa **, int **)
            Boxa *GetWords(Pixa **)
            Boxa *GetConnectedComponents(Pixa **)
            Boxa *GetComponentImages(const PageIteratorLevel,
                                    const bool, const bool,
                                    const int,
                                    Pixa **, int **, int **)
            int GetThresholdedImageScaleFactor() const
            PageIterator *AnalyseLayout(bool)
            int Recognize(ETEXT_DESC *)
            int RecognizeForChopTest(ETEXT_DESC *)
            bool ProcessPages(cchar_t *, cchar_t *, int, TessResultRenderer *)
            bool ProcessPage(Pix *, int, cchar_t *, cchar_t *, int, TessResultRenderer *)
            ResultIterator *GetIterator()
            char *GetUTF8Text()
            char *GetHOCRText(int)
            char *GetTSVText(int)
            char *GetBoxText(int)
            char *GetUNLVText()
            bool DetectOrientationScript(int *, float *, cchar_t **, float *)
            int MeanTextConf()
            int *AllWordConfidences()
            bool AdaptToWordStr(PageSegMode, cchar_t *)
            void Clear()
            void End()
            int IsValidWord(cchar_t *)
            bool IsValidCharacter(cchar_t *)
            bool GetTextDirection(int *, float *)
            bool DetectOS(OSResults *);
            cchar_t *GetUnichar(int)
            const OcrEngineMode oem() const
            void set_min_orientation_margin(double)
    ELSE:
        cdef cppclass TessBaseAPI:
            TessBaseAPI() except +
            @staticmethod
            cchar_t *Version()
            @staticmethod
            void ClearPersistentCache()
            void SetInputName(cchar_t *)
            cchar_t *GetInputName()
            void SetInputImage(Pix *)
            Pix *GetInputImage()
            int GetSourceYResolution()
            cchar_t *GetDatapath()
            void SetOutputName(cchar_t *)
            bool SetVariable(cchar_t *, cchar_t *)
            bool SetDebugVariable(cchar_t *, cchar_t *)
            bool GetIntVariable(cchar_t *, int *) const
            bool GetBoolVariable(cchar_t *, bool *) const
            bool GetDoubleVariable(cchar_t *, double *) const
            cchar_t *GetStringVariable(cchar_t *) const
            bool GetVariableAsString(cchar_t *, STRING *)
            int Init(cchar_t *, cchar_t *, OcrEngineMode mode,
                    char **, int,
                    const GenericVector[STRING] *,
                    const GenericVector[STRING] *,
                    bool)
            int Init(cchar_t *, cchar_t *, OcrEngineMode)
            int Init(cchar_t *, cchar_t *)
            cchar_t *GetInitLanguagesAsString() const
            void GetLoadedLanguagesAsVector(GenericVector[STRING] *) const
            void GetAvailableLanguagesAsVector(GenericVector[STRING] *) const
            void InitForAnalysePage()
            void ReadConfigFile(cchar_t *)
            void SetPageSegMode(PageSegMode)
            PageSegMode GetPageSegMode() const
            char *TesseractRect(cuchar_t *, int, int, int, int, int, int)
            void ClearAdaptiveClassifier()
            void SetImage(cuchar_t *, int, int, int, int)
            void SetImage(Pix *)
            void SetSourceResolution(int)
            void SetRectangle(int, int, int, int)
            Pix *GetThresholdedImage()
            Boxa *GetRegions(Pixa **)
            Boxa *GetTextlines(const bool, const int, Pixa **, int **, int **)
            Boxa *GetStrips(Pixa **, int **)
            Boxa *GetWords(Pixa **)
            Boxa *GetConnectedComponents(Pixa **)
            Boxa *GetComponentImages(const PageIteratorLevel,
                                    const bool, const bool,
                                    const int,
                                    Pixa **, int **, int **)
            int GetThresholdedImageScaleFactor() const
            PageIterator *AnalyseLayout(bool)
            int Recognize(ETEXT_DESC *)
            int RecognizeForChopTest(ETEXT_DESC *)
            bool ProcessPages(cchar_t *, cchar_t *, int, TessResultRenderer *)
            bool ProcessPage(Pix *, int, cchar_t *, cchar_t *, int, TessResultRenderer *)
            ResultIterator *GetIterator()
            char *GetUTF8Text()
            char *GetHOCRText(int)
            char *GetBoxText(int)
            char *GetUNLVText()
            int MeanTextConf()
            int *AllWordConfidences()
            bool AdaptToWordStr(PageSegMode, cchar_t *)
            void Clear()
            void End()
            int IsValidWord(cchar_t *)
            bool IsValidCharacter(cchar_t *)
            bool GetTextDirection(int *, float *)
            bool DetectOS(OSResults *);
            cchar_t *GetUnichar(int)
            const OcrEngineMode oem() const
            void set_min_orientation_margin(double)
