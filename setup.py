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
from setuptools.command.build_ext import build_ext
from setuptools.extension import Extension


_LOGGER = logging.getLogger()
if os.environ.get('DEBUG'):
    _LOGGER.setLevel(logging.DEBUG)
else:
    _LOGGER.setLevel(logging.INFO)
_LOGGER.addHandler(logging.StreamHandler(sys.stderr))

_TESSERACT_MIN_VERSION = '3.04.00'
_CYTHON_COMPILE_TIME_ENV = None

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


if sys.version_info >= (3, 0):
    def _read_string(s):
        return s.decode('UTF-8')
else:
    def _read_string(s):
        return s


def version_to_int(version):
    subversion = None
    subtrahend = 0
    # Subtracts a certain amount from the version number to differentiate between
    # alpha, beta and release versions.
    if "alpha" in version:
        version_split = version.split("alpha")
        subversion = version_split[1]
        subtrahend = 2
    elif "beta" in version:
        version_split = version.split("beta")
        subversion = version_split[1]
        subtrahend = 1
    version = re.search(r'((?:\d+\.)+\d+)', version).group()
    # Split the groups on ".", take only the first one, and print each group with leading 0 if needed
    # To be safe, also handle cases where an extra group is added to the version string, or if one or two groups
    # are dropped.
    version_groups = (version.split('.') + [0, 0])[:3]
    version_str = "{:02}{:02}{:02}".format(*map(int, version_groups))
    version_str = str((int(version_str, 10)-subtrahend))
    # Adds a 2 digit subversion number for the subversionrelease.
    subversion_str="00"
    if subversion is not None and subversion is not "":
        subversion = re.search(r'(?:\d+)', subversion).group()
        subversion_groups = (subversion.split('-') + [0, 0])[:1]
        subversion_str = "{:02}".format(*map(int, subversion_groups))
    version_str+=subversion_str
    return int(version_str, 16)


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
    flags = _read_string(output).strip().split()
    p = subprocess.Popen(['pkg-config', '--libs', '--cflags', 'lept'], stdout=subprocess.PIPE)
    output, _ = p.communicate()
    flags2 = _read_string(output).strip().split()
    options = {'-L': 'library_dirs',
               '-I': 'include_dirs',
               '-l': 'libraries'}
    config = {'library_dirs': [],
              'include_dirs': [],
              'libraries': []}
    import itertools
    for f in itertools.chain(flags, flags2):
        try:
            opt = options[f[:2]]
        except KeyError:
            continue
        val = f[2:]
        if opt == 'include_dirs' and psplit(val)[1].strip(os.sep) in ('leptonica', 'tesseract'):
            val = dirname(val)
        config[opt] += [val]
    p = subprocess.Popen(['pkg-config', '--modversion', 'tesseract'], stdout=subprocess.PIPE)
    version, _ = p.communicate()
    version = _read_string(version).strip()
    _LOGGER.info("Supporting tesseract v{}".format(version))
    config['cython_compile_time_env'] = {'TESSERACT_VERSION': version_to_int(version)}
    _LOGGER.info("Configs from pkg-config: {}".format(config))
    return config


def get_tesseract_version():
    """Try to extract version from tesseract otherwise default min version."""
    config = {'libraries': ['tesseract', 'lept']}
    try:
        p = subprocess.Popen(['tesseract', '-v'], stderr=subprocess.PIPE, stdout=subprocess.PIPE)
        stdout_version, version = p.communicate()
        version = _read_string(version).strip()
        if version == '':
            version = _read_string(stdout_version).strip()
        version_match = re.search(r'^tesseract ((?:\d+\.)+\d+).*', version, re.M)
        if version_match:
            version = version_match.group(1)
        else:
            _LOGGER.warn('Failed to extract tesseract version number from: {}'.format(version))
            version = _TESSERACT_MIN_VERSION
    except OSError as e:
        _LOGGER.warn('Failed to extract tesseract version from executable: {}'.format(e))
        version = _TESSERACT_MIN_VERSION
    _LOGGER.info("Supporting tesseract v{}".format(version))
    version = version_to_int(version)
    config['cython_compile_time_env'] = {'TESSERACT_VERSION': version}
    _LOGGER.info("Building with configs: {}".format(config))
    return config


def get_build_args():
    """Return proper build parameters."""
    try:
        build_args = package_config()
    except Exception as e:
        if isinstance(e, OSError):
            if e.errno != errno.ENOENT:
                _LOGGER.warn('Failed to run pkg-config: {}'.format(e))
        else:
            _LOGGER.warn('pkg-config failed to find tesseract/lept libraries: {}'.format(e))
        build_args = get_tesseract_version()

    if build_args['cython_compile_time_env']['TESSERACT_VERSION'] >= 0x3050200:
        _LOGGER.debug('tesseract >= 03.05.02 requires c++11 compiler support')
        build_args['extra_compile_args'] = ['-std=c++11', '-DUSE_STD_NAMESPACE']

    _LOGGER.debug('build parameters: {}'.format(build_args))
    return build_args


def make_extension():
    global _CYTHON_COMPILE_TIME_ENV
    build_args = get_build_args()
    _CYTHON_COMPILE_TIME_ENV = build_args.pop('cython_compile_time_env')
    return Extension("tesserocr", sources=["tesserocr.pyx"], language="c++", **build_args)


class my_build_ext(build_ext, object):
    def finalize_options(self):
        from Cython.Build.Dependencies import cythonize
        self.distribution.ext_modules[:] = cythonize(
            self.distribution.ext_modules, compile_time_env=_CYTHON_COMPILE_TIME_ENV)
        super(my_build_ext, self).finalize_options()


setup(name='tesserocr',
      version=find_version('tesserocr.pyx'),
      description='A simple, Pillow-friendly, Python wrapper around tesseract-ocr API using Cython',
      long_description=read('README.rst'),
      long_description_content_type='text/x-rst',
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
          'Programming Language :: Python :: 2.7',
          'Programming Language :: Python :: 3',
          'Programming Language :: Python :: 3.4',
          'Programming Language :: Python :: 3.5',
          'Programming Language :: Python :: 3.6',
          'Programming Language :: Python :: 3.7',
          'Programming Language :: Python :: Implementation :: CPython',
          'Programming Language :: Python :: Implementation :: PyPy',
          'Programming Language :: Cython'
      ],
      keywords='Tesseract,tesseract-ocr,OCR,optical character recognition,PIL,Pillow,Cython',
      cmdclass={'build_ext': my_build_ext},
      ext_modules=[make_extension()],
      test_suite='tests',
      setup_requires=['Cython>=0.23'],
      )
