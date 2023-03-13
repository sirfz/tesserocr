import codecs
import errno
import glob
import itertools
import logging
import os
import re
import subprocess
import sys
from os.path import abspath, dirname
from os.path import join as pjoin
from os.path import split as psplit

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

EXTRA_COMPILE_ARGS = {
    'msvc': ['/std:c11', '-DUSE_STD_NAMESPACE'],
    'gcc': ['-std=c++11', '-DUSE_STD_NAMESPACE'],
}


def read(*parts):
    return codecs.open(pjoin(here, *parts), 'r').read()


def find_version(*file_paths):
    version_file = read(*file_paths)
    version_match = re.search('^__version__ = [\'"]([^\'"]*)[\'"]', version_file, re.M)
    if version_match:
        return version_match.group(1)
    raise RuntimeError('Unable to find version string.')


if sys.version_info >= (3, 0):
    def _read_string(s):
        return s.decode('UTF-8')
else:
    def _read_string(s):
        return s


def major_version(version):
    versions = version.split('.')
    major = int(versions[0])
    _LOGGER.info('Tesseract major version %s', major)
    return major


def version_to_int(version):
    subversion = None
    subtrahend = 0
    # Subtracts a certain amount from the version number to differentiate
    # between alpha, beta and release versions.
    if 'alpha' in version:
        version_split = version.split('alpha')
        subversion = version_split[1]
        subtrahend = 2
    elif 'beta' in version:
        version_split = version.split('beta')
        subversion = version_split[1]
        subtrahend = 1

    version = re.search(r'((?:\d+\.)+\d+)', version).group()
    # Split the groups on ".", take only the first one, and print each
    # group with leading 0 if needed. To be safe, also handle cases where
    # an extra group is added to the version string, or if one or two
    # groups are dropped.
    version_groups = (version.split('.') + [0, 0])[:3]
    version_str = '{:02}{:02}{:02}'.format(*map(int, version_groups))
    version_str = str((int(version_str, 10) - subtrahend))
    # Adds a 2 digit subversion number for the subversionrelease.
    subversion_str = '00'
    if subversion is not None and subversion != '':
        subversion = re.search(r'(?:\d+)', subversion).group()
        subversion_groups = (subversion.split('-') + [0, 0])[:1]
        subversion_str = '{:02}'.format(*map(int, subversion_groups))

    version_str += subversion_str
    return int(version_str, 16)


def package_config():
    """Use pkg-config to get library build parameters and tesseract version."""
    p = subprocess.Popen(
        [
            'pkg-config',
            '--exists',
            '--atleast-version={}'.format(_TESSERACT_MIN_VERSION),
            '--print-errors',
            'tesseract',
        ],
        stderr=subprocess.PIPE,
    )
    _, error = p.communicate()
    if p.returncode != 0:
        if isinstance(error, bytes):
            error = error.decode()

        raise Exception(error)

    p = subprocess.Popen(
        ['pkg-config', '--libs', '--cflags', 'tesseract'], stdout=subprocess.PIPE
    )
    output, _ = p.communicate()
    flags = _read_string(output).strip().split()
    p = subprocess.Popen(
        ['pkg-config', '--libs', '--cflags', 'lept'], stdout=subprocess.PIPE
    )
    output, _ = p.communicate()
    flags2 = _read_string(output).strip().split()
    options = {'-L': 'library_dirs', '-I': 'include_dirs', '-l': 'libraries'}
    config = {'library_dirs': [], 'include_dirs': [], 'libraries': []}

    for f in itertools.chain(flags, flags2):
        try:
            opt = options[f[:2]]
        except KeyError:
            continue
        val = f[2:]
        if opt == 'include_dirs' and psplit(val)[1].strip(os.sep) in (
            'leptonica',
            'tesseract',
        ):
            val = dirname(val)
        config[opt] += [val]

    p = subprocess.Popen(
        ['pkg-config', '--modversion', 'tesseract'], stdout=subprocess.PIPE
    )
    version, _ = p.communicate()
    version = _read_string(version).strip()
    _LOGGER.info('Supporting tesseract v%s', version)
    config['compile_time_env'] = {
        'TESSERACT_MAJOR_VERSION': major_version(version),
        'TESSERACT_VERSION': version_to_int(version)
    }
    _LOGGER.info('Configs from pkg-config: %s', config)
    return config


def find_library(pattern, path_list, version=''):
    """Help routine to find library."""
    result = []
    for path in path_list:
        filepattern = os.path.join(path, pattern)
        result += glob.glob(filepattern)
    # ignore debug library
    result = [i for i in result if not i.endswith('d.lib')]
    if version:
        result = [i for i in result if version in i]
    return result


def get_tesseract_version():
    """Try to extract version from tesseract otherwise default min version."""
    config = {'libraries': ['tesseract', 'lept']}
    try:
        p = subprocess.Popen(
            ['tesseract', '-v'], stderr=subprocess.PIPE, stdout=subprocess.PIPE
        )
        stdout_version, version = p.communicate()
        version = _read_string(version).strip()
        if version == '':
            version = _read_string(stdout_version).strip()

        version_match = re.search(r'^tesseract ((?:\d+\.)+\d+).*', version, re.M)
        if version_match:
            version = version_match.group(1)
        else:
            _LOGGER.warning(
                'Failed to extract tesseract version number from: %s', version
            )
            version = _TESSERACT_MIN_VERSION
    except OSError as e:
        _LOGGER.warning('Failed to extract tesseract version from executable: %s', e)
        version = _TESSERACT_MIN_VERSION

    _LOGGER.info('Supporting tesseract v%s', version)
    config['compile_time_env'] = {
        'TESSERACT_MAJOR_VERSION': major_version(version),
        'TESSERACT_VERSION': version_to_int(version)
    }
    if sys.platform == 'win32':
        libpaths = os.getenv('LIBPATH', None)
        if libpaths:
            libpaths = list(filter(None, libpaths.split(';')))
        else:
            libpaths = []

        if version:
            lib_version = ''.join(version.split('.')[:2])
        else:
            lib_version = None

        tess_lib = find_library('tesseract*.lib', libpaths, lib_version)
        if len(tess_lib) >= 1:
            base = os.path.basename(sorted(tess_lib, reverse=True)[0])
            tess_lib = os.path.splitext(base)[0]
        else:
            error = 'Tesseract library not found in LIBPATH: {}'.format(libpaths)
            raise RuntimeError(error)

        lept_lib = find_library('lept*.lib', libpaths)
        if len(lept_lib) >= 1:
            base = os.path.basename(sorted(lept_lib, reverse=True)[0])
            lept_lib = os.path.splitext(base)[0]
        else:
            error = 'Leptonica library not found in LIBPATH: {}'.format(libpaths)
            raise RuntimeError(error)

        includepaths = os.getenv('INCLUDE', None)
        if includepaths:
            includepaths = list(filter(None, includepaths.split(';')))
        else:
            includepaths = []

        config['libraries'] = [tess_lib, lept_lib]
        config['library_dirs'] = libpaths
        config['include_dirs'] = includepaths

    _LOGGER.info('Building with configs: %s', config)
    return config


def get_build_args():
    """Return proper build parameters."""
    try:
        build_args = package_config()
    except Exception as e:
        if isinstance(e, OSError):
            if e.errno != errno.ENOENT:
                _LOGGER.warning('Failed to run pkg-config: %s', e)
        else:
            _LOGGER.warning(
                'pkg-config failed to find tesseract/leptonica libraries: %s', e
            )
        build_args = get_tesseract_version()

    _LOGGER.debug('build parameters: %s', build_args)
    return build_args


def make_extension():
    global _CYTHON_COMPILE_TIME_ENV
    build_args = get_build_args()
    _CYTHON_COMPILE_TIME_ENV = build_args.pop('compile_time_env')
    return Extension(
        'tesserocr', sources=['tesserocr.pyx'], language='c++', **build_args
    )


class my_build_ext(build_ext, object):
    def build_extensions(self):
        compiler = self.compiler.compiler_type
        _LOGGER.info('Detected compiler: %s', compiler)
        extra_args = EXTRA_COMPILE_ARGS.get(compiler, EXTRA_COMPILE_ARGS['gcc'])
        if isinstance(_CYTHON_COMPILE_TIME_ENV, dict):
            version = _CYTHON_COMPILE_TIME_ENV.get('TESSERACT_VERSION', 0)
        else:
            version = 0

        for extension in self.extensions:
            if version >= 0x3050200:
                _LOGGER.debug('tesseract >= 03.05.02 requires c++11 compiler support')
                extension.extra_compile_args = extra_args

        build_ext.build_extensions(self)

    def finalize_options(self):
        from Cython.Build.Dependencies import cythonize

        self.distribution.ext_modules[:] = cythonize(
            self.distribution.ext_modules, compile_time_env=_CYTHON_COMPILE_TIME_ENV
        )
        super(my_build_ext, self).finalize_options()


setup(
    name='tesserocr',
    version=find_version('tesserocr.pyx'),
    description='A simple, Pillow-friendly, Python wrapper around '
    'tesseract-ocr API using Cython',
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
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Programming Language :: Python :: Implementation :: CPython',
        'Programming Language :: Python :: Implementation :: PyPy',
        'Programming Language :: Cython',
    ],
    keywords='Tesseract,tesseract-ocr,OCR,optical character recognition,'
    'PIL,Pillow,Cython',
    cmdclass={'build_ext': my_build_ext},
    ext_modules=[make_extension()],
    test_suite='tests',
    setup_requires=['Cython>=0.23'],
)
