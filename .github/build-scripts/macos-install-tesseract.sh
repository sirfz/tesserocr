#!/usr/bin/env bash
set -ex

source $(dirname -- "$0")/common-install-tesseract.sh

# build leptonica
cd leptonica-${LEPTONICA_VERSION}

cmake \
  -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="12.0" \
  -DCMAKE_FIND_FRAMEWORK=NEVER \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_GIF=OFF \
  -DENABLE_OPENJPEG=OFF

sudo cmake \
  --build build \
  --config Release \
  --target install

# Workaround wrong installation name (includes build type)
if [ -f ${PREFIX}/lib/pkgconfig/lept_*.pc ] ; then
    sudo mv ${PREFIX}/lib/pkgconfig/lept_*.pc ${PREFIX}/lib/pkgconfig/lept.pc
fi

cd ..

# build tesseract
# see https://github.com/orgs/Homebrew/discussions/4031#discussioncomment-4348867
export PKG_CONFIG_PATH=$(brew --prefix)/opt/icu4c/lib/pkgconfig:$PKG_CONFIG_PATH

cd tesseract-${TESSERACT_VERSION}

cmake \
  -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="12.0" \
  -DCMAKE_FIND_FRAMEWORK=NEVER \
  -DBUILD_SHARED_LIBS=ON \
  -DOPENMP_BUILD=OFF \
  -DBUILD_TRAINING_TOOLS=OFF

sudo cmake \
  --build build \
  --config Release \
  --target install

cd ..
