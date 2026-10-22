=========
tesserocr
=========

A simple, |Pillow|_-friendly,
wrapper around the ``tesseract-ocr`` API for Optical Character Recognition
(OCR).

.. image:: https://github.com/sirfz/tesserocr/actions/workflows/build.yml/badge.svg
    :target: https://github.com/sirfz/tesserocr/actions/workflows/build.yml
    :alt: Github Actions build status

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

**Python 3.9+** is required. tesserocr no longer supports Python 2.

Requires libtesseract (>=3.04) and libleptonica (>=1.71).

On Debian/Ubuntu:

::

    $ apt-get install tesseract-ocr libtesseract-dev libleptonica-dev pkg-config

You may need to `manually compile tesseract`_ for a more recent version. Note that you may need
to update your ``LD_LIBRARY_PATH`` environment variable to point to the right library versions in
case you have multiple tesseract/leptonica installations.

|Cython|_ (>=3.1.8,<3.4) is required for building and optionally |Pillow|_ to support ``PIL.Image`` objects.

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

64-bit Windows wheels are built by this project's GitHub Actions workflow and bundle Tesseract,
Leptonica, and their runtime DLL dependencies. No separate Tesseract or Conda installation is
required to use these wheels. Language data must still be installed separately (see `tessdata`_).

Conda
`````

You can use the `conda-forge <https://anaconda.org/conda-forge/tesserocr>`_ channel to install from Conda:

::

    > conda install -c conda-forge tesserocr

Or alternatively the independently-maintained `simonflueckiger <https://anaconda.org/simonflueckiger/tesserocr>`_ channel:

::

    > conda install -c simonflueckiger tesserocr

pip
```

For releases with Windows wheels on PyPI:

::

    > pip install tesserocr

Wheels from workflow runs are also available as GitHub Actions artifacts. Download and unpack
the artifact, then install the matching wheel with ``pip install <package_name>.whl``.
Alternatively, download a wheel matching your Windows platform and Python version from
`simonflueckiger/tesserocr-windows_build/releases <https://github.com/simonflueckiger/tesserocr-windows_build/releases>`_
and install it with ``pip install <package_name>.whl``.

Build from source
`````````````````

If a wheel is not available for your platform or Python version, follow the
`step by step instructions for Windows 64bit` in `Windows.build.md`_.

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

Thread safety and free-threaded Python
-------------------------------------

``tesserocr`` supports free-threaded CPython without enabling the GIL on import.
``image_to_text`` and ``file_to_text`` can process independent images concurrently.
The same ownership rules apply with or without the GIL:

* Use a separate ``PyTessBaseAPI`` instance per worker. Instances and their
  iterators have no internal lock. Do not call an active instance from another
  thread or re-enter it from a signal handler, including ``Clear`` and ``End``.
* Keep the API alive while using its iterators. Calls such as ``Init``,
  ``SetImage``, ``Recognize``, ``Clear`` and ``End`` invalidate existing iterators.
* Some Tesseract parameters, particularly in ``classify`` and ``textord``, are
  process-wide even with separate API instances. Configure these before starting
  parallel native work and do not change them while it runs. This applies to
  ``SetVariable``, ``SetDebugVariable``, config files and ``InitFull`` variables.
* Leptonica's log level and Tesseract's persistent cache are also process-wide.
  Set ``set_leptonica_log_level`` and call ``ClearPersistentCache`` only while
  no native work is running. Use separate processes for independent settings
  that must change during OCR.

``Recognize``, ``GetUTF8Text``, ``image_to_text`` and ``file_to_text`` use
Tesseract's cooperative cancellation to propagate Python signal exceptions
(such as ``KeyboardInterrupt``) after recognition unwinds safely. Python handles
signals only on the main thread: interrupting the main thread does not cancel
OCR running in a worker. Layout analysis and other native operations without
cancellation checkpoints may delay signal handling until they return.

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
        print(f'Found {len(boxes)} textline image components.')
        for i, (im, box, _, _) in enumerate(boxes):
            # im is a PIL image object
            # box is a dict with x, y, w and h keys
            api.SetRectangle(box['x'], box['y'], box['w'], box['h'])
            ocrResult = api.GetUTF8Text()
            conf = api.MeanTextConf()
            print(f"Box[{i}]: x={box['x']}, y={box['y']}, w={box['w']}, h={box['h']}, "
                  f"confidence: {conf}, text: {ocrResult}")

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
        print("Orientation: {:d}".format(orientation))
        print("WritingDirection: {:d}".format(direction))
        print("TextlineOrder: {:d}".format(order))
        print("Deskew angle: {:.4f}".format(deskew_angle))

or more simply with ``OSD_ONLY`` page segmentation mode:

.. code:: python

    from tesserocr import PyTessBaseAPI, PSM

    with PyTessBaseAPI(psm=PSM.OSD_ONLY) as api:
        api.SetImageFile("/usr/src/tesseract/testing/eurotext.tif")

        os = api.DetectOS()
        print("Orientation: {orientation}\nOrientation confidence: {oconfidence}\n"
              "Script: {script}\nScript confidence: {sconfidence}".format(**os))

more human-readable info with tesseract 4+ (demonstrates LSTM engine usage):

.. code:: python

    from tesserocr import PyTessBaseAPI, PSM, OEM

    with PyTessBaseAPI(psm=PSM.OSD_ONLY, oem=OEM.LSTM_ONLY) as api:
        api.SetImageFile("/usr/src/tesseract/testing/eurotext.tif")

        os = api.DetectOrientationScript()
        print("Orientation: {orient_deg}\nOrientation confidence: {orient_conf}\n"
              "Script: {script_name}\nScript confidence: {script_conf}".format(**os))

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
                print(f'symbol {symbol}, conf: {conf}', end='')
            indent = False
            ci = r.GetChoiceIterator()
            for c in ci:
                if indent:
                    print('\t\t ', end='')
                print('\t- ', end='')
                choice = c.GetUTF8Text()  # c == ci
                print(f'{choice} conf: {c.Confidence()}')
                indent = True
            print('---------------------------------------------')
