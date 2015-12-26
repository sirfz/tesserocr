from setuptools import setup, Extension
from Cython.Build import cythonize
from Cython.Distutils import build_ext

ext_modules = Extension("tesserocr",
                        sources=["*.pyx"],
                        libraries=["tesseract", "lept"],
                        language="c++")

setup(name="tesserocr",
      version="1.2",
      description='A Python wrapper for tesseract-ocr API',
      author='Fayez Zouheiry',
      install_requires=['Cython', 'Pillow'],
      zip_safe=False,
      cmdclass={'build_ext': build_ext},
      ext_modules=cythonize(ext_modules),
      )
