#!/usr/bin/env bash
set -ex

source $(dirname -- "$0")/common-install-tesseract.sh

# build leptonica
cd leptonica-${LEPTONICA_VERSION}

cmake \
  -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_GIF=OFF \
  -DENABLE_OPENJPEG=OFF

cmake \
  --build build \
  --config Release \
  --target install

# Workaround wrong installation name (includes build type)
if [ -f ${PREFIX}/lib/pkgconfig/lept_*.pc ] ; then
    mv ${PREFIX}/lib/pkgconfig/lept_*.pc ${PREFIX}/lib/pkgconfig/lept.pc
fi

cd ..

# build tesseract
cd tesseract-${TESSERACT_VERSION}

cmake \
  -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR="${PREFIX}/lib" \
  -DBUILD_SHARED_LIBS=ON \
  -DOPENMP_BUILD=OFF \
  -DBUILD_TRAINING_TOOLS=OFF

cmake \
  --build build \
  --config Release \
  --target install

cd ..
