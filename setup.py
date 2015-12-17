from setuptools import setup, Extension
from Cython.Build import cythonize

ext_modules = cythonize(Extension("tesserocr",
                        sources=["*.pyx"],
                        libraries=["tesseract", "lept"],
                        language="c++"))

setup(name="tesserocr",
      version="1.0",
      description='A Python wrapper for tesseract-ocr API',
      author='Fayez Zouheiry',
      install_requires=['cython', 'Pillow'],
      zip_safe=False,
      ext_modules=ext_modules,
      )
