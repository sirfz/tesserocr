import logging
import os
import sys
import codecs
import re
import subprocess
import errno
from os.path import dirname, abspath
from os.path import split as psplit, join as pjoin
from setuptools import setup
from pkg_resources import parse_version
from Cython.Distutils import build_ext
from Cython.Distutils.extension import Extension

_LOGGER = logging.getLogger()
if os.environ.get('DEBUG'):
    _LOGGER.setLevel(logging.DEBUG)
else:
    _LOGGER.setLevel(logging.INFO)
_LOGGER.addHandler(logging.StreamHandler(sys.stderr))

_TESSERACT_MIN_VERSION = '3.04.00'

# find_version from pip https://github.com/pypa/pip/blob/1.5.6/setup.py#L33
here = abspath(dirname(__file__))


def read(*parts):
    return codecs.open(pjoin(here, *parts), 'r').read()


def find_version(*file_paths):
    version_file = read(*file_paths)
    version_match = re.search(r"^__version__ = ['\"]([^'\"]*)['\"]",
                              version_file, re.M)
    if version_match:
        return version_match.group(1)
    raise RuntimeError("Unable to find version string.")


def version_to_int(version):
    version = parse_version(version)
    return int(''.join(version.base_version.split('.')), 16)


def package_config():
    """Use pkg-config to get library build parameters and tesseract version."""
    p = subprocess.Popen(['pkg-config', '--exists', '--atleast-version={}'.format(_TESSERACT_MIN_VERSION),
                          '--print-errors', 'tesseract'],
                         stderr=subprocess.PIPE)
    _, error = p.communicate()
    if p.returncode != 0:
        raise Exception(error)
    p = subprocess.Popen(['pkg-config', '--libs', '--cflags', 'tesseract'], stdout=subprocess.PIPE)
    output, _ = p.communicate()
    flags = output.strip().split()
    p = subprocess.Popen(['pkg-config', '--libs', '--cflags', 'lept'], stdout=subprocess.PIPE)
    output, _ = p.communicate()
    flags2 = output.strip().split()
    options = {'-L': 'library_dirs',
               '-I': 'include_dirs',
               '-l': 'libraries'}
    config = {}
    import itertools
    for f in itertools.chain(flags, flags2):
        opt = options[f[:2]]
        val = f[2:]
        if opt == 'include_dirs' and psplit(val)[1].strip(os.sep) in {'leptonica', 'tesseract'}:
            val = dirname(val)
        config.setdefault(opt, set()).add(val)
    config = {k: list(v) for k, v in config.iteritems()}
    p = subprocess.Popen(['pkg-config', '--modversion', 'tesseract'], stdout=subprocess.PIPE)
    version, _ = p.communicate()
    config['cython_compile_time_env'] = {'TESSERACT_VERSION': version_to_int(version.strip())}
    _LOGGER.info("Configs from pkg-config: {}".format(config))
    return config


def get_tesseract_version():
    """Try to extract version from tesseract otherwise default min version."""
    config = {'libraries': ['tesseract', 'lept']}
    try:
        p = subprocess.Popen(['tesseract', '-v'], stderr=subprocess.PIPE)
        _, version = p.communicate()
        version_match = re.search(r'^tesseract (([0-9]+\.)+[0-9]+)\n', version)
        if version_match:
            version = version_match.group(1)
        else:
            _LOGGER.warn('Failed to extract tesseract version number from: {}'.format(version))
            version = _TESSERACT_MIN_VERSION
    except OSError as e:
        _LOGGER.warn('Failed to extract tesseract version from executable: {}'.format(e))
        version = _TESSERACT_MIN_VERSION
    _LOGGER.info("Supporting tesseract {}".format(config))
    version = version_to_int(version)
    config['cython_compile_time_env'] = {'TESSERACT_VERSION': version}
    return config


class BuildTesseract(build_ext):
    """Set build parameters obtained from pkg-config if available."""

    def initialize_options(self):
        build_ext.initialize_options(self)

        try:
            build_args = package_config()
        except OSError as e:
            if e.errno != errno.ENOENT:
                _LOGGER.warn('Failed to run pkg-config: {}'.format(e))
            build_args = get_tesseract_version()

        _LOGGER.debug('build parameters: {}'.format(build_args))
        for k, v in build_args.iteritems():
            setattr(self, k, v)


ext_modules = [Extension("tesserocr",
                         sources=["tesserocr.pyx"],
                         language="c++")]


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
      # cmdclass={'build_ext': CustomBuildExit},
      cmdclass={'build_ext': BuildTesseract},
      ext_modules=ext_modules,
      test_suite='tests'
      )
