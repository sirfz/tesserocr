# tesserocr
A simple wrapper around the `tesseract-ocr` API for Optical Image Recognition (OCR).

`tesserocr` integrates directly with Tesseract's C++ API using Cython and
allows real concurrent execution when used with `threading` by releasing the GIL while
processing an image in tesseract.

`tesserocr` is designed to be `Pillow`-friendly but can also be used with image files instead.

Requirements
------------
Requires libtesseract (>=3.02) and libleptonica.

On Debian/Ubuntu:

    $ apt-get install tesseract-ocr libtesseract-dev libleptonica-dev

Optionally requires `Cython` for building (otherwise the generated .cpp file is compiled)
and `Pillow` to support `PIL.Image` objects.

Installation
------------
    $ python setup.py install

Usage
-----
Initialize and re-use the tesseract API instance to score multiple images:

```python
from tesserocr import PyTessBaseAPI

images = ['sample.jpg', 'sample2.jpg', 'sample3.jpg']

with PyTessBaseAPI() as api:
    for img in images:
        api.SetImageFile(img)
        print api.GetUTF8Text()
        print api.AllWordConfidences()
# api is automatically finalized when used in a with-statement (context manager).
# otherwise api.End() should be explicitly called when it's no longer needed.
```

`PyTessBaseAPI` exposes several tesseract API methods. Make sure you read their docstrings for more info.

Basic example using available helper functions:

```python
import tesserocr
from PIL import Image

print tesserocr.tesseract_version()  # print tesseract-ocr version
print tesserocr.get_languages()  # prints tessdata path and list of available languages

image = Image.open('sample.jpg')
print tesserocr.image_to_text(image)  # print ocr text from image
# or
print tesserocr.file_to_text('sample.jpg')
```

`image_to_text` and `file_to_text` can be used with `threading` to concurrently process multiple images which is
highly efficient.
