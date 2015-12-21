from setuptools import setup, Extension
from Cython.Build import cythonize
from Cython.Distutils import build_ext

ext_modules = cythonize([Extension("tesserocr",
                        sources=["*.pyx"],
                        libraries=["tesseract", "lept"],
                        language="c++")])

setup(name="tesserocr",
      version="1.0",
      description='A Python wrapper for tesseract-ocr API',
      author='Fayez Zouheiry',
      install_requires=['cython', 'Pillow'],
      zip_safe=False,
      cmd_class={'build_ext': build_ext},
      ext_modules=ext_modules,
      )
