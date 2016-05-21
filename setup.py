import os.path
import codecs
import re
from setuptools import setup
from setuptools.extension import Extension
from Cython.Distutils import build_ext
# from Cython.Distutils.extension import Extension

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


def get_tesseract_version():
    import tesseractversion
    return tesseractversion.version()


class CustomBuildExit(build_ext):
    """Set cython_compile_time_env after building tesseractversion."""

    def build_extension(self, ext):
        r = build_ext.build_extension(self, ext)
        if ext.name == "tesseractversion":
            # Hack to set cython_compile_time_env to properly cythonize tesserocr
            self.cython_compile_time_env = {"TESSERACT_VERSION": get_tesseract_version()}
        return r


ext_modules = [Extension("tesseractversion",
                         sources=["tesseractversion.pyx"],
                         libraries=["tesseract"],
                         language="c++"),
               Extension("tesserocr",
                         sources=["tesserocr.pyx"],
                         libraries=["tesseract", "lept"],
                         language="c++",
                         )]


setup(name='tesserocr',
      version=find_version('tesserocr.pyx'),
      description='A simple, Pillow-friendly, Python wrapper around tesseract-ocr API using Cython',
      long_description=read('README.rst'),
      url='https://github.com/sirfz/tesserocr',
      author='Fayez Zouheiry',
      author_email='iamfayez@gmail.com',
      license='MIT',
      classifiers=[
          'Development Status :: 5 - Production/Stable',
          'Intended Audience :: Developers',
          'Topic :: Multimedia :: Graphics :: Capture :: Scanners',
          'Topic :: Multimedia :: Graphics :: Graphics Conversion',
          'Topic :: Scientific/Engineering :: Image Recognition',
          'License :: OSI Approved :: MIT License',
          'Operating System :: POSIX',
          'Programming Language :: Python :: 2',
          'Programming Language :: Python :: 2.7',
          'Programming Language :: Cython'
      ],
      keywords='Tesseract,tesseract-ocr,OCR,optical character recognition,PIL,Pillow,Cython',
      cmdclass={'build_ext': CustomBuildExit},
      ext_modules=ext_modules,
      test_suite='tests'
      )
