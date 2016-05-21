
cdef extern from "tesseract/baseapi.h" nogil:
    cdef int TESSERACT_VERSION


def version():
    return TESSERACT_VERSION
