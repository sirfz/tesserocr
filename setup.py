import os.path
import codecs
import re
from setuptools import setup, Extension
try:
    from Cython.Build import cythonize
    from Cython.Distutils import build_ext
except ImportError:
    cythonize = None
    build_ext = None


# find_version from pip https://github.com/pypa/pip/blob/1.5.6/setup.py#L33
here = os.path.abspath(os.path.dirname(__file__))


def read(*parts):
    return codecs.open(os.path.join(here, *parts), 'r').read()


def find_version(*file_paths):
    version_file = read(*file_paths)
    version_match = re.search(r"^__version__ = ['\"]([^'\"]*)['\"]",
                              version_file, re.M)
    if version_match:
        return version_match.group(1)
    raise RuntimeError("Unable to find version string.")


if cythonize:
    ext_modules = cythonize(Extension("tesserocr",
                            sources=["tesserocr.pyx"],
                            libraries=["tesseract", "lept"],
                            language="c++"))
else:
    ext_modules = [Extension("tesserocr",
                             sources=["tesserocr.cpp"],
                             libraries=["tesseract", "lept"],
                             language="c++")]


setup(name='tesserocr',
      version=find_version('tesserocr.pyx'),
      description='A Python wrapper around tesseract-ocr API using Cython',
      url='https://github.com/sirfz/tesserocr',
      author='Fayez Zouheiry',
      license='MIT',
      classifiers=[
          'Development Status :: 5 - Production/Stable',
          'Intended Audience :: Developers',
          'Topic :: Multimedia :: Graphics :: Capture :: Scanners',
          'Topic :: Multimedia :: Graphics :: Graphics Conversion',
          'Topic :: Scientific/Engineering :: Image Recognition',
          'License :: OSI Approved :: MIT License',
          'Operating System :: POSIX :: Linux',
          'Programming Language :: Python :: 2',
          'Programming Language :: Python :: 2.7',
      ],
      keywords='Tesseract,tesseract-ocr,OCR,optical image recognition,Cython',
      cmdclass={'build_ext': build_ext} if build_ext else {},
      ext_modules=ext_modules,
      )
