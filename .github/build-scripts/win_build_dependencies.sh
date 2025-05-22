#!/bin/bash

# Script to compile Tesseract OCR and its dependencies on Windows for GitHub Actions.

set -e

echo "Starting Tesseract OCR dependency build process..."

# Define directories relative to the current working directory (expected to be repo root)
INSTALL_DIR="$(pwd)/deps"
TESSDATA_DIR="$(pwd)/tessdata_prefix"

echo "Installation directory: $INSTALL_DIR"
echo "Tessdata directory: $TESSDATA_DIR"

mkdir -p "$INSTALL_DIR"
mkdir -p "$TESSDATA_DIR"

# Set PATH to include our future install directory's bin, primarily for Tesseract itself if needed during build or tests
# This is for the bash session; GITHUB_ENV will be used for subsequent steps in the workflow.
export PATH="$INSTALL_DIR/bin:$PATH"

echo "Activating Visual Studio environment..."
VS_COMMUNITY_2019_PATH="C:/Program Files (x88)/Microsoft Visual Studio/2019/Community/VC/Auxiliary/Build/vcvars64.bat"
VS_COMMUNITY_2022_PATH="C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat"
VS_ENTERPRISE_2019_PATH="C:/Program Files (x88)/Microsoft Visual Studio/2019/Enterprise/VC/Auxiliary/Build/vcvars64.bat"
VS_ENTERPRISE_2022_PATH="C:/Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Auxiliary/Build/vcvars64.bat"

if [ -f "$VS_COMMUNITY_2019_PATH" ]; then
    echo "Found VS 2019 Community. Calling vcvars64.bat..."
    cmd.exe /C "call \"$VS_COMMUNITY_2019_PATH\" x64 && set" > vs_env.txt
elif [ -f "$VS_COMMUNITY_2022_PATH" ]; then
    echo "Found VS 2022 Community. Calling vcvars64.bat..."
    cmd.exe /C "call \"$VS_COMMUNITY_2022_PATH\" x64 && set" > vs_env.txt
elif [ -f "$VS_ENTERPRISE_2019_PATH" ]; then
    echo "Found VS 2019 Enterprise. Calling vcvars64.bat..."
    cmd.exe /C "call \"$VS_ENTERPRISE_2019_PATH\" x64 && set" > vs_env.txt
elif [ -f "$VS_ENTERPRISE_2022_PATH" ]; then
    echo "Found VS 2022 Enterprise. Calling vcvars64.bat..."
    cmd.exe /C "call \"$VS_ENTERPRISE_2022_PATH\" x64 && set" > vs_env.txt
else
    echo "ERROR: Could not find vcvars64.bat in common locations. MSVC environment not set."
    # Attempt to find vswhere, which is usually available on GHA runners
    if command -v vswhere &> /dev/null; then
        echo "Trying to locate MSVC using vswhere..."
        VS_PATH=$(vswhere -latest -property installationPath)
        if [ -n "$VS_PATH" ] && [ -f "$VS_PATH/VC/Auxiliary/Build/vcvars64.bat" ]; then
            echo "Found MSVC at $VS_PATH. Calling vcvars64.bat..."
            cmd.exe /C "call \"$VS_PATH/VC/Auxiliary/Build/vcvars64.bat\" x64 && set" > vs_env.txt
        else
            echo "ERROR: vswhere did not find a suitable MSVC installation or vcvars64.bat."
            exit 1
        fi
    else
        echo "ERROR: vswhere not found. Cannot dynamically locate MSVC."
        exit 1
    fi
fi

# Parse the output of "set" to export variables to the current bash session
# This is a common workaround for sourcing batch file environment in bash
echo "Applying MSVC environment to bash session..."
while IFS='=' read -r name value || [[ -n "$name" ]]; do
    # Ensure value is not empty and handle CRLF if present
    value=$(echo "$value" | tr -d '\r')
    if [ -n "$value" ]; then
        export "$name=$value"
    fi
done < vs_env.txt
rm vs_env.txt
echo "MSVC environment applied."


echo "Checking for required tools (curl, unzip, cmake, tar)..."
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl is not installed. Please install curl."
    exit 1
fi
if ! command -v unzip &> /dev/null; then
    echo "ERROR: unzip is not installed. Please install unzip."
    exit 1
fi
if ! command -v cmake &> /dev/null; then
    echo "ERROR: cmake is not installed. Please install cmake."
    exit 1
fi
if ! command -v tar &> /dev/null; then
    echo "ERROR: tar is not installed. Please install tar (usually included with Git Bash)."
    exit 1
fi
echo "Required tools found."

# Build zlib
echo "Building zlib..."
curl -L https://zlib.net/zlib1211.zip -o zlib1211.zip
unzip -q zlib1211.zip
cd zlib-1.2.11
mkdir -p build.msvs && cd build.msvs
cmake .. -G "Visual Studio 17 2022" -A x64 -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
cmake --build . --config Release --target install
cd ../..
rm -rf zlib-1.2.11 zlib1211.zip
echo "zlib build complete."

# Build libpng
echo "Building libpng..."
curl -L https://vorboss.dl.sourceforge.net/project/libpng/libpng16/1.6.37/lpng1637.zip -o lpng1637.zip
unzip -q lpng1637.zip
cd lpng1637
mkdir -p build.msvs && cd build.msvs
cmake .. -G "Visual Studio 17 2022" -A x64 -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -DZLIB_ROOT="$INSTALL_DIR" -DPNG_SHARED=ON -DPNG_STATIC=OFF
cmake --build . --config Release --target install
cd ../..
rm -rf lpng1637 lpng1637.zip
echo "libpng build complete."

# Build Leptonica
LEPTONICA_VERSION="1.83.1"
echo "Building Leptonica ${LEPTONICA_VERSION}..."
curl -L "https://github.com/DanBloomberg/leptonica/releases/download/${LEPTONICA_VERSION}/leptonica-${LEPTONICA_VERSION}.tar.gz" -o "leptonica-${LEPTONICA_VERSION}.tar.gz"
tar -xzf "leptonica-${LEPTONICA_VERSION}.tar.gz"
cd "leptonica-${LEPTONICA_VERSION}"
mkdir -p build.msvs && cd build.msvs
cmake .. -G "Visual Studio 17 2022" -A x64 \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_PREFIX_PATH="$INSTALL_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_PROG=OFF \
    -DSW_BUILD=OFF \
    -DBUILD_SHARED_LIBS=ON
cmake --build . --config Release --target install
cd ../..
rm -rf "leptonica-${LEPTONICA_VERSION}" "leptonica-${LEPTONICA_VERSION}.tar.gz"
echo "Leptonica build complete."

# Build Tesseract OCR
TESSERACT_VERSION="5.3.4"
echo "Building Tesseract OCR ${TESSERACT_VERSION}..."
curl -L "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/${TESSERACT_VERSION}.tar.gz" -o "tesseract-${TESSERACT_VERSION}.tar.gz"
tar -xzf "tesseract-${TESSERACT_VERSION}.tar.gz"
cd "tesseract-${TESSERACT_VERSION}"
mkdir -p build.msvs && cd build.msvs
cmake .. -G "Visual Studio 17 2022" -A x64 \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_PREFIX_PATH="$INSTALL_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TRAINING_TOOLS=OFF \
    -DSW_BUILD=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DOPENMP_BUILD=OFF \
    -DLeptonica_DIR="$INSTALL_DIR/lib/cmake/leptonica"
cmake --build . --config Release --target install
cd ../..
rm -rf "tesseract-${TESSERACT_VERSION}" "tesseract-${TESSERACT_VERSION}.tar.gz"
echo "Tesseract OCR build complete."

# Download Tessdata
echo "Downloading Tesseract OCR training data (eng, osd)..."
curl -L "https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata" --output "${TESSDATA_DIR}/eng.traineddata"
curl -L "https://github.com/tesseract-ocr/tessdata_fast/raw/main/osd.traineddata" --output "${TESSDATA_DIR}/osd.traineddata"
echo "Tessdata download complete."

# Export Environment Variables for GitHub Actions
echo "Exporting environment variables for GitHub Actions..."

# Convert paths to Windows format for GITHUB_ENV
INSTALL_DIR_WIN=$(cygpath -w "$INSTALL_DIR")
TESSDATA_DIR_WIN=$(cygpath -w "$TESSDATA_DIR")

echo "INCLUDE=${INSTALL_DIR_WIN}\\include" >> $GITHUB_ENV
echo "LIBPATH=${INSTALL_DIR_WIN}\\lib" >> $GITHUB_ENV
echo "TESSDATA_PREFIX=${TESSDATA_DIR_WIN}" >> $GITHUB_ENV
# For PATH, GHA on Windows expects "Path"
echo "Path=${INSTALL_DIR_WIN}\\bin;%Path%" >> $GITHUB_ENV

echo "Dependency build process finished successfully."
echo "Include path: ${INSTALL_DIR_WIN}\\include"
echo "Library path: ${INSTALL_DIR_WIN}\\lib"
echo "Tessdata prefix: ${TESSDATA_DIR_WIN}"
echo "Bin path added to Path: ${INSTALL_DIR_WIN}\\bin"

# List contents of install directory for verification
ls -R "$INSTALL_DIR"
echo "Script finished."
