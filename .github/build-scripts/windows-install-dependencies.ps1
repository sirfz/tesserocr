#Requires -Version 5
<#
.SYNOPSIS
    Installs Tesseract and its dependencies on Windows.
.DESCRIPTION
    This script downloads the source code for zlib, libpng, libjpeg-turbo, libwebp, libtiff,
    leptonica, and tesseract, compiles them using CMake and MSVC, and installs them
    to a specified directory.
.NOTES
    Author: GitHub Copilot
    Prerequisites:
        - Git for Windows
        - CMake
        - Visual Studio (with C++ toolset)
        - NASM (for libjpeg-turbo, add to PATH or ensure CMake finds it)
#>

param (
    [string]$InstallDir = "$env:GITHUB_WORKSPACE\win64",
    [string]$TesseractVersion = "5.3.4",
    [string]$LeptonicaVersion = "1.83.1",
    [string]$ZlibVersion = "1.3.1", # Latest stable as of early 2024
    [string]$LibPngVersion = "1.6.48", # Updated to 1.6.48 as of 2025-05-23
    [string]$LibJpegTurboVersion = "3.0.2", # Latest stable as of early 2024
    [string]$LibTiffVersion = "4.6.0", # Latest stable as of early 2024
    [string]$LibWebPVersion = "1.3.2"  # Latest stable as of early 2024
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "--- Configuration ---"
Write-Host "Install directory: $InstallDir"
Write-Host "Tesseract version: $TesseractVersion"
Write-Host "Leptonica version: $LeptonicaVersion"
Write-Host "Zlib version: $ZlibVersion"
Write-Host "LibPng version: $LibPngVersion"
Write-Host "LibJpeg-Turbo version: $LibJpegTurboVersion"
Write-Host "LibTiff version: $LibTiffVersion"
Write-Host "LibWebP version: $LibWebPVersion"
Write-Host "---------------------"

# Ensure install directory exists
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Set environment variables for the build process
$env:INSTALL_DIR = $InstallDir
$env:PATH = "$env:INSTALL_DIR\bin;$env:PATH" # Prepend so our compiled tools are found first if needed
$env:CMAKE_PREFIX_PATH = $env:INSTALL_DIR # Help CMake find dependencies
$env:TESSDATA_PREFIX = "$env:GITHUB_WORKSPACE\tessdata"

# Temporary directory for downloads and builds
$TempBuildDir = "$env:RUNNER_TEMP\build_deps"
if (Test-Path $TempBuildDir) {
    Remove-Item -Recurse -Force $TempBuildDir
}
New-Item -ItemType Directory -Path $TempBuildDir -Force | Out-Null

# Helper function to download and extract
function Get-Archive {
    param (
        [string]$Url,
        [string]$OutFile,
        [string]$ExtractTo = "."
    )
    $FullOutFile = Join-Path $TempBuildDir $OutFile
    $FullExtractTo = Join-Path $TempBuildDir $ExtractTo
    Write-Host "Downloading $Url to $FullOutFile..."
    Invoke-WebRequest -Uri $Url -OutFile $FullOutFile
    Write-Host "Extracting $FullOutFile to $FullExtractTo..."
    tar -xf $FullOutFile -C $FullExtractTo
    Remove-Item $FullOutFile # Clean up archive
}

# --- Build zlib ---
Write-Host "Building zlib $ZlibVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://zlib.net/zlib-$($ZlibVersion).tar.gz" -OutFile "zlib.tar.gz" -ExtractTo "."
Push-Location "zlib-$ZlibVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build libpng ---
Write-Host "Building libpng $LibPngVersion..."
$LibPngFileName = "lpng$($LibPngVersion -replace '\.','').zip" # e.g., lpng1648.zip
$LibPngDirName = "lpng$($LibPngVersion -replace '\.','')"     # e.g., lpng1648
$LibPngUrl = "https://sourceforge.net/projects/libpng/files/libpng16/$($LibPngVersion)/$($LibPngFileName)/download"

Push-Location $TempBuildDir
Get-Archive -Url $LibPngUrl -OutFile "libpng.zip" -ExtractTo "."
Push-Location $LibPngDirName # Navigate into the correct extracted folder, e.g., lpng1648
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DPNG_SHARED=ON -DPNG_STATIC=OFF -DZLIB_ROOT=$env:INSTALL_DIR
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build libjpeg-turbo ---
# Requires NASM to be in PATH for optimal SIMD builds. GitHub Windows runners usually have it.
Write-Host "Building libjpeg-turbo $LibJpegTurboVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/$($LibJpegTurboVersion).tar.gz" -OutFile "libjpeg-turbo.tar.gz" -ExtractTo "."
Push-Location "libjpeg-turbo-$LibJpegTurboVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DENABLE_SHARED=ON -DENABLE_STATIC=OFF -DWITH_JPEG8=1
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build libwebp ---
Write-Host "Building libwebp $LibWebPVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$($LibWebPVersion).tar.gz" -OutFile "libwebp.tar.gz" -ExtractTo "."
Push-Location "libwebp-$LibWebPVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build libtiff ---
Write-Host "Building libtiff $LibTiffVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://download.osgeo.org/libtiff/tiff-$($LibTiffVersion).tar.gz" -OutFile "libtiff.tar.gz" -ExtractTo "."
Push-Location "tiff-$LibTiffVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
# TIFF's CMake can be particular. Ensure it finds zlib and jpeg.
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -Djbig=OFF -Dlerc=OFF -Dlzma=OFF -Dzstd=OFF -Dwebp=ON # Enable WebP if found
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build Leptonica ---
Write-Host "Building Leptonica $LeptonicaVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://github.com/DanBloomberg/leptonica/archive/$($LeptonicaVersion).tar.gz" -OutFile "leptonica.tar.gz" -ExtractTo "."
Push-Location "leptonica-$LeptonicaVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
# Match flags from linux script where applicable
# Leptonica's CMake should find zlib, png, jpeg, tiff, webp via CMAKE_PREFIX_PATH
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR `
           -DCMAKE_BUILD_TYPE=Release `
           -DBUILD_SHARED_LIBS=ON `
           -DENABLE_GIF=OFF `
           -DENABLE_OPENJPEG=OFF `
           -DSW_BUILD=OFF `
           -DBUILD_PROG=OFF
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build Tesseract ---
Write-Host "Building Tesseract $TesseractVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://github.com/tesseract-ocr/tesseract/archive/$($TesseractVersion).tar.gz" -OutFile "tesseract.tar.gz" -ExtractTo "."
Push-Location "tesseract-$TesseractVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
# Match flags from linux script
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR `
           -DCMAKE_BUILD_TYPE=Release `
           -DBUILD_SHARED_LIBS=ON `
           -DOPENMP_BUILD=OFF `
           -DBUILD_TRAINING_TOOLS=OFF `
           -DSW_BUILD=OFF # Optional: disable software renderer if not needed by tesseract core
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Download Tessdata (using Tesseract 5.x.x compatible data) ---
# Using tessdata_fast for Tesseract 5.x
Write-Host "Downloading Tesseract language data (tessdata_fast)..."
if (-not (Test-Path $env:TESSDATA_PREFIX)) {
    New-Item -ItemType Directory -Path $env:TESSDATA_PREFIX -Force | Out-Null
}
$TessdataRepo = "https://github.com/tesseract-ocr/tessdata_fast"
Invoke-WebRequest -Uri "$TessdataRepo/raw/main/eng.traineddata" -OutFile "$env:TESSDATA_PREFIX\eng.traineddata"
Invoke-WebRequest -Uri "$TessdataRepo/raw/main/osd.traineddata" -OutFile "$env:TESSDATA_PREFIX\osd.traineddata"

# Clean up temporary build directory
Pop-Location # Back to original location before $TempBuildDir
Remove-Item -Recurse -Force $TempBuildDir

Write-Host "Windows dependencies installation complete."
