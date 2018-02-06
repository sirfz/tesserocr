from distutils.util import get_platform
import shutil
import shlex
import yaml
import os
import subprocess
import re
from setuptools.command.build_ext import build_ext
from setuptools.extension import Extension
import logging

_CYTHON_COMPILE_TIME_ENV = None

LEPTONICA_VERSION = '1.74.4'
TESSERACT_VERSION = '3.5.1'
tesseract_dll_files = []
def tesseract_build(leptonica_version=LEPTONICA_VERSION,
                    tesseract_version=TESSERACT_VERSION):
    top_dir = os.path.dirname(os.path.abspath(__file__))
    build_dir = os.path.join(top_dir, 'build', 'tesseract_build')

    # remove the old build directory
    if os.path.isdir(build_dir):
        shutil.rmtree(build_dir, ignore_errors=True)
    elif os.path.exists(build_dir):
        os.remove(build_dir)

    # create the empty build directory
    os.makedirs(build_dir, exist_ok=True)

    # create dummy.cpp file
    with open(os.path.join(build_dir, 'dummy.cpp'), 'w') as fp:
        fp.write('int main(int argc, char *argv[]) { return 0; }\n')

    # create cppan.yml cppan configuration file
    if get_platform() == 'win-amd64':
        generator = 'Visual Studio 14 2015 Win64'
    elif get_platform() == 'win32':
        generator = 'Visual Studio 14 2015'

    cppan_config = """
local_settings:
  cppan_dir: cppan
  build_dir_type: local
  build_dir: build
  build:
    generator: %s

projects:
  dummy:
    files: dummy.cpp
    dependencies:
      pvt.cppan.demo.danbloomberg.leptonica: %s
      pvt.cppan.demo.google.tesseract.libtesseract: %s
      pvt.cppan.demo.google.tesseract.tesseract: %s
""" % (generator, leptonica_version, tesseract_version, tesseract_version)

    with open(os.path.join(build_dir, 'cppan.yml'), 'w') as fp:
        fp.write(cppan_config)

    # generate cmake build files
    cmd = 'cppan --generate .'
    p = subprocess.Popen(shlex.split(cmd), cwd=build_dir,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = p.communicate()
    if output.find(b'Configuring done') < 0:
        raise RuntimeError(output.decode())

    # locate header files
    d = os.path.split(build_dir)[-1]
    dummy_build_dir = os.path.join(build_dir, 'build', 'cppan-build-%s' % d)

    # we should have only one subdir
    subdirs = [name for name in os.listdir(dummy_build_dir) \
               if os.path.isdir(os.path.join(dummy_build_dir, name))]
    assert (len(subdirs) == 1)
    # the magic number, some kind of hash key, should be relate to architectures,
    # compiler selection, debug/release, etc ...
    magic_number = subdirs[0]
    dummy_build_dir = os.path.join(dummy_build_dir, subdirs[0])
    dummy_cmakefile = os.path.join(dummy_build_dir, 'cppan', 'CMakeLists.txt')
    with open(dummy_cmakefile, 'r') as fp:
        dummy_cmakefile_contents = fp.read()

    # need to patch the gettimeofday.h and gettimeofday.c
    m = re.search(r"set\(pvt_cppan_[0-9a-zA-Z_]+libtesseract_DIR (?P<dir>.+)\)",
                  dummy_cmakefile_contents)
    if not m:
        raise RuntimeError('cannot detect libtesseract source codes')
    libtesseract_src_dir = os.path.normpath(m.group('dir'))

    patch_gettimeofday(libtesseract_src_dir)

    # build tesseract.exe
    cmd = 'cppan --build-packages pvt.cppan.demo.google.tesseract.tesseract-%s' % tesseract_version
    p = subprocess.Popen(shlex.split(cmd), cwd=build_dir,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = p.communicate()
    if p.returncode != 0:
        raise RuntimeError(output.decode())

    # build dummy.exe
    cmd = 'cppan --build .'
    p = subprocess.Popen(shlex.split(cmd), cwd=build_dir,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = p.communicate()
    # this command always returns error, why???
    if output.find(b'Build succeeded.') < 0:
        raise RuntimeError(output.decode())


    m = re.search(r"set\(pvt_cppan_[0-9a-zA-Z_]+leptonica_DIR (?P<dir>.+)\)",
                  dummy_cmakefile_contents)
    if not m:
        raise RuntimeError('cannot detect leptonica source codes')

    leptonica_top_dir = m.group('dir')
    leptonica_build_dir = leptonica_top_dir.replace('/src/', '/obj/', 1)
    m = re.search('/[0-9a-fA-F]{2}/[0-9a-fA-F]{2}/[0-9a-fA-F]{4}$',
                  leptonica_build_dir)
    if not m:
        raise RuntimeError('unexpected source location directory name')
    leptonica_hash = m.group(0).replace('/', '')
    leptonica_build_dir = os.path.normpath(os.path.join(leptonica_build_dir,
                                                        'build', magic_number,
                                                        'cppan',
                                                        leptonica_hash))
    leptonica_top_dir = os.path.normpath(leptonica_top_dir)


    # copy header files from leptonica and libtesseract source tree
    os.makedirs(os.path.join(build_dir, 'include', 'leptonica'))
    os.makedirs(os.path.join(build_dir, 'include', 'tesseract'))

    leptonica_src_dir = os.path.join(leptonica_top_dir, 'src')
    leptonica_h_files = [name for name in os.listdir(leptonica_src_dir) \
                         if name.endswith('.h') and \
                         os.path.isfile(os.path.join(leptonica_src_dir, name))]
    for name in leptonica_h_files:
        shutil.copy(os.path.join(leptonica_src_dir, name),
                    os.path.join(build_dir, 'include', 'leptonica'))

    # take care of generated header files
    leptonica_h_files = [name for name in os.listdir(leptonica_build_dir) \
                         if name.endswith('.h') and \
                            os.path.isfile(os.path.join(leptonica_build_dir, name))]
    for name in leptonica_h_files:
        shutil.copy(os.path.join(leptonica_build_dir, name),
                    os.path.join(build_dir, 'include', 'leptonica'))

    # from libtesseract source tree
    with open(os.path.join(libtesseract_src_dir, 'cppan.yml'), 'r') as fp:
        cppan_cfg = yaml.load(fp)
        subdirs = cppan_cfg['include_directories']['public']

    for subdir in subdirs:
        subdir = os.path.normpath(os.path.join(libtesseract_src_dir, subdir))
        h_files = [name for name in os.listdir(subdir) \
                   if name.endswith('.h') and \
                      os.path.isfile(os.path.join(subdir, name))]

        for name in h_files:
            shutil.copy(os.path.join(subdir, name),
                        os.path.join(build_dir, 'include', 'tesseract'))

def patch_gettimeofday(libtesseract_src_dir):
    header = os.path.join(libtesseract_src_dir, 'vs2010', 'port', 'gettimeofday.h')
    with open(header, 'r+') as fp:
        contents = fp.read()
        if contents.find('timezone_no_conflict') < 0:
            fp.truncate(0)
            fp.seek(0)
            fp.write(contents.replace('timezone', 'timezone_no_conflict'))

    src = os.path.join(libtesseract_src_dir, 'vs2010', 'port', 'gettimeofday.cpp')
    with open(src, 'r+') as fp:
        contents = fp.read()
        if contents.find('timezone_no_conflict') < 0:
            fp.truncate(0)
            fp.seek(0)
            fp.write(contents.replace('timezone', 'timezone_no_conflict'))

def package_config():
    global tesseract_dll_files
    top_dir = os.path.dirname(os.path.abspath(__file__))
    build_dir = os.path.join(top_dir, 'build', 'tesseract_build')
    tesseract_exe = os.path.join(build_dir, 'bin', 'tesseract.exe')
    if not os.path.isfile(tesseract_exe):
        tesseract_build()

    files = os.listdir(os.path.join(build_dir, 'bin'))
    dll_files = [name for name in files \
                 if os.path.isfile(os.path.join(build_dir, 'bin', name)) and \
                 name.endswith('.dll')]
    lib_files = [name for name in files if
                 os.path.isfile(os.path.join(build_dir, 'bin', name)) and \
                 name.endswith('.lib')]
    tesseract_dll_files = [os.path.join(build_dir, 'bin', name) for name in dll_files]

    # get the tesseract version from executable
    cmd = '%s -v' % tesseract_exe
    args = shlex.split(cmd, posix=False)
    p = subprocess.Popen(args, cwd=os.path.join(build_dir, 'bin'),
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = p.communicate()
    if p.returncode != 0:
        raise RuntimeError('tesseract execution failed????')
    m = re.search("tesseract ([0-9]+\.[0-9]+\.[0-9]+)", output.decode())
    if m is None:
        raise RuntimeError('unknown tesseract version number???')
    tesseract_version = m.group(1)
    tesseract_version_number = int(''.join(tesseract_version.split('.')), 16)

    config = {
        'library_dirs': [os.path.join(build_dir, 'bin')],
        'include_dirs': [os.path.join(build_dir, 'include')],
        'libraries': [os.path.splitext(lib)[0] for lib in lib_files],
        'cython_compile_time_env': {
            'TESSERACT_VERSION': tesseract_version_number
        }
    }
    return config

class my_build_ext(build_ext, object):
    def finalize_options(self):
        global _CYTHON_COMPILE_TIME_ENV
        from Cython.Build.Dependencies import cythonize
        self.distribution.ext_modules[:] = cythonize(
            self.distribution.ext_modules, compile_time_env=_CYTHON_COMPILE_TIME_ENV)
        super(my_build_ext, self).finalize_options()

    def build_extension(self, ext):
        global tesseract_dll_files
        assert(tesseract_dll_files)
        build_ext.build_extension(self, ext)

        dll_dest_dir = os.path.dirname(self.get_ext_fullpath(ext.name))
        for dll_name_pattern in tesseract_dll_files:
            dll_src_dir, dll_name = os.path.split(dll_name_pattern)
            if dll_name == '*.dll':
                raise NotImplemented('not implemented')
            else:
                if os.path.isabs(dll_name_pattern):
                    try:
                        shutil.copy(dll_name_pattern, dll_dest_dir)
                    except shutil.SameFileError:
                        pass
                    except:
                        raise
                else:
                    # how to handle relative path???
                    raise NotImplementedError('not implemented')

def get_build_args():
    """Return proper build parameters."""
    _LOGGER = logging.getLogger()
    build_args = package_config()

    if build_args['cython_compile_time_env']['TESSERACT_VERSION'] >= 0x040000:
        _LOGGER.debug('tesseract >= 4.00 requires c++11 compiler support')
        build_args['extra_compile_args'] = ['-DUSE_STD_NAMESPACE']

    _LOGGER.debug('build parameters: {}'.format(build_args))
    return build_args

def make_extension():
    global _CYTHON_COMPILE_TIME_ENV
    build_args = get_build_args()
    _CYTHON_COMPILE_TIME_ENV = build_args.pop('cython_compile_time_env')
    return Extension("tesserocr", sources=["tesserocr.pyx"], language="c++", **build_args)
