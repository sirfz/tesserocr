# tesserocr
A simple wrapper around the `tesseract-ocr` API for extracting OCR text from images.

`tesserocr` is optimized for speed and allows real concurrent execution when used with `threading` by releasing the GIL while processing an image.

Requirements
------------
Requires libtesseract and libleptonica.

On Debian/Ubuntu:

`apt-get install tesseract-ocr libtesseract-dev libleptonica-dev`

Usage
-----
```python
import tesserocr
from PIL import Image

print tesserocr.tesseract_version()  # print tesseract-ocr version

image = Image.open('sample.jpg')
print tesserocr.image_to_text(image)  # print ocr text from image
```
