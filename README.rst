=========
tesserocr
=========

A simple, |Pillow|_-friendly,
wrapper around the ``tesseract-ocr`` API for Optical Character Recognition
(OCR).

.. image:: https://travis-ci.com/sirfz/tesserocr.svg?branch=master
    :target: https://travis-ci.com/sirfz/tesserocr
    :alt: TravisCI build status

.. image:: https://img.shields.io/pypi/v/tesserocr.svg?maxAge=2592000
    :target: https://pypi.python.org/pypi/tesserocr
    :alt: Latest version on PyPi

.. image:: https://img.shields.io/pypi/pyversions/tesserocr.svg?maxAge=2592000
    :alt: Supported python versions

**tesserocr** integrates directly with Tesseract's C++ API using Cython
which allows for a simple Pythonic and easy-to-read source code. It
enables real concurrent execution when used with Python's ``threading``
module by releasing the GIL while processing an image in tesseract.

**tesserocr** is designed to be |Pillow|_-friendly but can also be used
with image files instead.

.. |Pillow| replace:: ``Pillow``
.. _Pillow: http://python-pillow.github.io/

Requirements
============

Requires libtesseract (>=3.04) and libleptonica (>=1.71).

On Debian/Ubuntu:

::

    $ apt-get install tesseract-ocr libtesseract-dev libleptonica-dev pkg-config

You may need to `manually compile tesseract`_ for a more recent version. Note that you may need
to update your ``LD_LIBRARY_PATH`` environment variable to point to the right library versions in
case you have multiple tesseract/leptonica installations.

|Cython|_ (>=0.23) is required for building and optionally |Pillow|_ to support ``PIL.Image`` objects.

.. _manually compile tesseract: https://github.com/tesseract-ocr/tesseract/wiki/Compiling
.. |Cython| replace:: ``Cython``
.. _Cython: http://cython.org/

Installation
============
Linux and BSD/MacOS
-------------------
::

    $ pip install tesserocr

The setup script attempts to detect the include/library dirs (via |pkg-config|_ if available) but you
can override them with your own parameters, e.g.:

::

    $ CPPFLAGS=-I/usr/local/include pip install tesserocr

or

::

    $ python setup.py build_ext -I/usr/local/include

Tested on Linux and BSD/MacOS

.. |pkg-config| replace:: **pkg-config**
.. _pkg-config: https://pkgconfig.freedesktop.org/

Windows
-------

The proposed downloads consist of stand-alone packages containing all the Windows libraries needed for execution. This means that no additional installation of tesseract is required on your system.

The recommended method of installation is via Conda as described below.

Conda
`````

You can use the `conda-forge <https://anaconda.org/conda-forge/tesserocr>`_ channel to install from Conda:

::

    > conda install -c conda-forge tesserocr

pip
```

Download the wheel file corresponding to your Windows platform and Python installation from `simonflueckiger/tesserocr-windows_build/releases <https://github.com/simonflueckiger/tesserocr-windows_build/releases>`_ and install them via:

::

    > pip install <package_name>.whl

Build from source
`````````````````

If you need Windows tessocr package and your Python version is not supported by above mentioned project,
you can try to follow `step by step instructions for Windows 64bit` in `Windows.build.md`_.

.. _Windows.build.md: Windows.build.md

tessdata
========

You may need to point to the tessdata path if it cannot be detected automatically. This can be done by setting the ``TESSDATA_PREFIX`` environment variable or by passing the path to ``PyTessBaseAPI`` (e.g.: ``PyTessBaseAPI(path='/usr/share/tessdata')``). The path should contain ``.traineddata`` files which can be found at https://github.com/tesseract-ocr/tessdata.

Make sure you have the correct version of traineddata for your ``tesseract --version``.

You can list the current supported languages on your system using the ``get_languages`` function:

.. code:: python

    from tesserocr import get_languages

    print(get_languages('/usr/share/tessdata'))  # or any other path that applies to your system

Usage
=====

Initialize and re-use the tesseract API instance to score multiple
images:

.. code:: python

    from tesserocr import PyTessBaseAPI

    images = ['sample.jpg', 'sample2.jpg', 'sample3.jpg']

    with PyTessBaseAPI() as api:
        for img in images:
            api.SetImageFile(img)
            print(api.GetUTF8Text())
            print(api.AllWordConfidences())
    # api is automatically finalized when used in a with-statement (context manager).
    # otherwise api.End() should be explicitly called when it's no longer needed.

``PyTessBaseAPI`` exposes several tesseract API methods. Make sure you
read their docstrings for more info.

Basic example using available helper functions:

.. code:: python

    import tesserocr
    from PIL import Image

    print(tesserocr.tesseract_version())  # print tesseract-ocr version
    print(tesserocr.get_languages())  # prints tessdata path and list of available languages

    image = Image.open('sample.jpg')
    print(tesserocr.image_to_text(image))  # print ocr text from image
    # or
    print(tesserocr.file_to_text('sample.jpg'))

``image_to_text`` and ``file_to_text`` can be used with ``threading`` to
concurrently process multiple images which is highly efficient.

Advanced API Examples
---------------------

GetComponentImages example:
```````````````````````````

.. code:: python

    from PIL import Image
    from tesserocr import PyTessBaseAPI, RIL

    image = Image.open('/usr/src/tesseract/testing/phototest.tif')
    with PyTessBaseAPI() as api:
        api.SetImage(image)
        results = api.GetComponentImages(RIL.TEXTLINE, True)
        print('Found {} textline image components.'.format(len(results)))
        for i, (img, box, _, _) in enumerate(results):
            # img is a PIL image object of the binarized line
            # box is a dict with x, y, w and h keys (w.r.t. full image)
            img.save('phototest_line{0}_{x}x{y}+{w}x{h}.png'.format(i, **box), format='PNG')

GetIterator example:
````````````````````

.. code:: python

    from PIL import Image
    from tesserocr import PyTessBaseAPI, RIL

    image = Image.open('/usr/src/tesseract/testing/phototest.tif')
    with PyTessBaseAPI() as api:
        api.SetImage(image)
        api.Recognize()
        
        it = api.GetIterator()
        for line in iterate_level(it, RIL.TEXTLINE):
            text = line.GetUTF8Text(RIL.TEXTLINE)
            conf = line.Confidence(RIL.TEXTLINE)
            bbox = line.BoundingBox(RIL.TEXTLINE)
            bbox = {'x': int(bbox[0]),
                    'y': int(bbox[1]),
                    'w': int(bbox[2])-int(bbox[0]),
                    'h': int(bbox[3])-int(bbox[1])}
            print(u"Box[{0}]: x={x}, y={y}, w={w}, h={h}, "
                  "confidence: {1}, text: {2}".format(i, conf, text, **bbox))

Layout analysis with orientation and deskewing:
```````````````````````````````````````````````

.. code:: python

    import math
    from PIL import Image
    from tesserocr import PyTessBaseAPI, PSM
    from tesserocr import Orientation, WritingDirection, TextlineOrder

    with PyTessBaseAPI(psm=PSM.AUTO) as api:
        image = Image.open("/usr/src/tesseract/testing/eurotext.tif")
        api.SetImage(image)

        it = api.AnalyseLayout()
        orientation, direction, order, deskew_angle = it.Orientation()
        print("Orientation: {}".format(membername(Orientation, orientation)))
        print("WritingDirection: {}".format(membername(WritingDirection, direction)))
        print("TextlineOrder: {:d}".format(membername(TextlineOrder, order)))
        print("Deskew angle: {:.1f}°".format(deskew_angle * 180 / math.pi))
    
    def membername(class_, val):
        """Convert a member value into a member name string."""
        return next((k for k, v in class_.__dict__.items() if v == val), str(val))

Orientation and script detection legacy model:
``````````````````````````````````````````````

.. code:: python

    from tesserocr import PyTessBaseAPI, PSM, OEM

    with PyTessBaseAPI(psm=PSM.OSD_ONLY, 
                       oem=OEM.TESSERACT_ONLY, 
                       lang="osd") as api:
        api.SetImageFile("/usr/src/tesseract/testing/eurotext.tif")

        os = api.DetectOS()
        print("Orientation: {orientation}\n"
              "Orientation confidence: {oconfidence}\n"
              "Script: {script}\n"
              "Script confidence: {sconfidence}".format(**os))
        # the same with more human-readable info:
        os = api.DetectOrientationScript()
        print("Orientation: {orient_deg}°\n"
              "Orientation confidence: {orient_conf}\n"
              "Script: {script_name}\n"
              "Script confidence: {script_conf}".format(**os))

Iterator over the classifier choices for a single symbol:
`````````````````````````````````````````````````````````

.. code:: python

    from __future__ import print_function

    from tesserocr import PyTessBaseAPI, RIL, iterate_level

    with PyTessBaseAPI() as api:
        api.SetImageFile('/usr/src/tesseract/testing/phototest.tif')
        api.SetVariable("lstm_choice_mode", "2")
        api.SetRectangle(37, 228, 548, 31)
        api.Recognize()

        ri = api.GetIterator()
        level = RIL.SYMBOL
        for r in iterate_level(ri, level):
            symb = r.GetUTF8Text(level)  # r == ri
            conf = r.Confidence(level)
            if symbol:
                print(u'symbol {}, conf: {}'.format(symb, conf), end='')
            indent = False
            ci = r.GetChoiceIterator()
            for c in ci:
                if indent:
                    print('\t\t ', end='')
                print('\t- ', end='')
                choice = c.GetUTF8Text()  # c == ci
                confid = c.Confidence()
                print(u'alt {} conf: {}'.format(choice, confid))
                indent = True
            print('---------------------------------------------')
