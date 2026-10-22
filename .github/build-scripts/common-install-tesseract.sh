#!/usr/bin/env bash
set -ex

source "$(dirname -- "${BASH_SOURCE[0]}")/tesseract-versions.env"

PREFIX="${PREFIX:-/usr/local}"

curl -L -O "https://github.com/DanBloomberg/leptonica/releases/download/${LEPTONICA_VERSION}/leptonica-${LEPTONICA_VERSION}.tar.gz"

tar -xzf leptonica-${LEPTONICA_VERSION}.tar.gz

curl -L -o "tesseract-${TESSERACT_VERSION}.tar.gz" "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/${TESSERACT_VERSION}.tar.gz"

tar -xzf tesseract-${TESSERACT_VERSION}.tar.gz
