=========
tesserocr
=========

A simple, |Pillow|_-friendly,
wrapper around the ``tesseract-ocr`` API for Optical Character Recognition
(OCR).

.. image:: https://travis-ci.org/sirfz/tesserocr.svg?branch=master
    :target: https://travis-ci.org/sirfz/tesserocr
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

Conda
`````

You can use the channel `simonflueckiger <https://anaconda.org/simonflueckiger/tesserocr>`_ to install from Conda:

::

    > conda install -c simonflueckiger tesserocr

or to get **tesserocr** compiled with **tesseract 4.0.0**:

::

    > conda install -c simonflueckiger/label/tesseract-4.0.0-master tesserocr

pip
```

Download the wheel file corresponding to your Windows platform and Python installation from `simonflueckiger/tesserocr-windows_build/releases <https://github.com/simonflueckiger/tesserocr-windows_build/releases>`_ and install them via:

::

    > pip install <package_name>.whl

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
            print api.GetUTF8Text()
            print api.AllWordConfidences()
    # api is automatically finalized when used in a with-statement (context manager).
    # otherwise api.End() should be explicitly called when it's no longer needed.

``PyTessBaseAPI`` exposes several tesseract API methods. Make sure you
read their docstrings for more info.

Basic example using available helper functions:

.. code:: python

    import tesserocr
    from PIL import Image

    print tesserocr.tesseract_version()  # print tesseract-ocr version
    print tesserocr.get_languages()  # prints tessdata path and list of available languages

    image = Image.open('sample.jpg')
    print tesserocr.image_to_text(image)  # print ocr text from image
    # or
    print tesserocr.file_to_text('sample.jpg')

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
        boxes = api.GetComponentImages(RIL.TEXTLINE, True)
        print 'Found {} textline image components.'.format(len(boxes))
        for i, (im, box, _, _) in enumerate(boxes):
            # im is a PIL image object
            # box is a dict with x, y, w and h keys
            api.SetRectangle(box['x'], box['y'], box['w'], box['h'])
            ocrResult = api.GetUTF8Text()
            conf = api.MeanTextConf()
            print (u"Box[{0}]: x={x}, y={y}, w={w}, h={h}, "
                   "confidence: {1}, text: {2}").format(i, conf, ocrResult, **box)

Orientation and script detection (OSD):
```````````````````````````````````````

.. code:: python

    from PIL import Image
    from tesserocr import PyTessBaseAPI, PSM

    with PyTessBaseAPI(psm=PSM.AUTO_OSD) as api:
        image = Image.open("/usr/src/tesseract/testing/eurotext.tif")
        api.SetImage(image)
        api.Recognize()

        it = api.AnalyseLayout()
        orientation, direction, order, deskew_angle = it.Orientation()
        print "Orientation: {:d}".format(orientation)
        print "WritingDirection: {:d}".format(direction)
        print "TextlineOrder: {:d}".format(order)
        print "Deskew angle: {:.4f}".format(deskew_angle)

or more simply with ``OSD_ONLY`` page segmentation mode:

.. code:: python

    from tesserocr import PyTessBaseAPI, PSM

    with PyTessBaseAPI(psm=PSM.OSD_ONLY) as api:
        api.SetImageFile("/usr/src/tesseract/testing/eurotext.tif")

        os = api.DetectOS()
        print ("Orientation: {orientation}\nOrientation confidence: {oconfidence}\n"
               "Script: {script}\nScript confidence: {sconfidence}").format(**os)

more human-readable info with tesseract 4+ (demonstrates LSTM engine usage):

.. code:: python

    from tesserocr import PyTessBaseAPI, PSM, OEM

    with PyTessBaseAPI(psm=PSM.OSD_ONLY, oem=OEM.LSTM_ONLY) as api:
        api.SetImageFile("/usr/src/tesseract/testing/eurotext.tif")

        os = api.DetectOrientationScript()
        print ("Orientation: {orient_deg}\nOrientation confidence: {orient_conf}\n"
               "Script: {script_name}\nScript confidence: {script_conf}").format(**os)

Iterator over the classifier choices for a single symbol:
`````````````````````````````````````````````````````````

.. code:: python

    from tesserocr import PyTessBaseAPI, RIL, iterate_level

    with PyTessBaseAPI() as api:
        api.SetImageFile('/usr/src/tesseract/testing/phototest.tif')
        api.SetVariable("save_blob_choices", "T")
        api.SetRectangle(37, 228, 548, 31)
        api.Recognize()

        ri = api.GetIterator()
        level = RIL.SYMBOL
        for r in iterate_level(ri, level):
            symbol = r.GetUTF8Text(level)  # r == ri
            conf = r.Confidence(level)
            if symbol:
                print u'symbol {}, conf: {}'.format(symbol, conf),
            indent = False
            ci = r.GetChoiceIterator()
            for c in ci:
                if indent:
                    print '\t\t ',
                print '\t- ',
                choice = c.GetUTF8Text()  # c == ci
                print u'{} conf: {}'.format(choice, c.Confidence())
                indent = True
            print '---------------------------------------------'
