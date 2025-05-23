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
    [string]$ZlibVersion = "1.3.1",
    [string]$LibPngVersion = "1.6.48", # Current version
    [string]$LibJpegTurboVersion = "3.0.2",
    [string]$LibTiffVersion = "4.6.0",
    [string]$LibWebPVersion = "1.3.2"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop" # This will cause the script to exit on any terminating error

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
$env:PATH = "$env:INSTALL_DIR\bin;$env:PATH"
$env:CMAKE_PREFIX_PATH = $env:INSTALL_DIR
$env:TESSDATA_PREFIX = "$env:GITHUB_WORKSPACE\tessdata"

# Temporary directory for downloads and builds
$TempBuildDir = "$env:RUNNER_TEMP\build_deps"
if (Test-Path $TempBuildDir) {
    Write-Host "Removing existing temporary build directory: $TempBuildDir"
    Remove-Item -Recurse -Force $TempBuildDir
}
New-Item -ItemType Directory -Path $TempBuildDir -Force | Out-Null
Write-Host "Created temporary build directory: $TempBuildDir"

# Helper function to download and extract
function Get-Archive {
    param (
        [string]$Url,
        [string]$OutFile, # This is the name of the file as it will be saved locally
        [string]$ExtractTo = "."
    )
    $FullOutFile = Join-Path $TempBuildDir $OutFile
    $FullExtractTo = Join-Path $TempBuildDir $ExtractTo

    Write-Host "Downloading $Url to $FullOutFile..."
    try {
        if ($Url -like "*sourceforge.net*") {
            Invoke-WebRequest -Uri $Url -OutFile $FullOutFile -UseBasicParsing -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $Url -OutFile $FullOutFile -ErrorAction Stop
        }
        $fileInfo = Get-Item $FullOutFile
        if ($fileInfo.Length -eq 0) {
            throw "Downloaded file '$FullOutFile' is empty (0 bytes)."
        }
        Write-Host "Downloaded '$FullOutFile' successfully. Size: $($fileInfo.Length) bytes."
    }
    catch {
        Write-Error "Failed to download '$Url'. Error: $($_.Exception.Message)"
        throw
    }

    Write-Host "Extracting $FullOutFile to $FullExtractTo (using tar.exe)..."
    try {
        # Use tar for all archives; bsdtar on Windows runners usually handles zip files as well.
        tar -xf $FullOutFile -C $FullExtractTo
        Write-Host "Successfully extracted (using tar) $FullOutFile to $FullExtractTo."
    }
    catch {
        Write-Error "The 'tar -xf' command encountered an issue for '$FullOutFile'."
        Write-Error "Underlying PowerShell Exception (if any): $($_.Exception.ToString())"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "tar.exe exited with code $LASTEXITCODE. This indicates a failure by tar itself."
        }
        if (Test-Path $FullOutFile) {
            $fileInfoOnFail = Get-Item $FullOutFile
            Write-Warning "File '$FullOutFile' still exists at time of extraction failure. Size: $($fileInfoOnFail.Length) bytes."
        }
        throw "Extraction failed for $FullOutFile using tar.exe. Exit code: $LASTEXITCODE"
    }
    finally {
        if (Test-Path $FullOutFile) {
            Remove-Item $FullOutFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Build zlib ---
Write-Host "Building zlib $ZlibVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://zlib.net/zlib-$($ZlibVersion).tar.gz" -OutFile "zlib-$($ZlibVersion).tar.gz" -ExtractTo "."
Push-Location "zlib-$ZlibVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build libpng ---
Write-Host "Building libpng $LibPngVersion..."
# Switched to .tar.gz for libpng
$LibPngArchiveFileName = "libpng-$($LibPngVersion).tar.gz" 
$LibPngDirName = "libpng-$($LibPngVersion)" # Standard directory name from tar.gz
$LibPngUrl = "https://downloads.sourceforge.net/project/libpng/libpng16/$($LibPngVersion)/$($LibPngArchiveFileName)"

Push-Location $TempBuildDir
Get-Archive -Url $LibPngUrl -OutFile $LibPngArchiveFileName -ExtractTo "." # OutFile matches the archive name
Push-Location $LibPngDirName # Navigate into the extracted directory (e.g., libpng-1.6.48)
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DPNG_SHARED=ON -DPNG_STATIC=OFF -DZLIB_ROOT=$env:INSTALL_DIR
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build libjpeg-turbo ---
Write-Host "Building libjpeg-turbo $LibJpegTurboVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/$($LibJpegTurboVersion).tar.gz" -OutFile "libjpeg-turbo-$($LibJpegTurboVersion).tar.gz" -ExtractTo "."
Push-Location "libjpeg-turbo-$LibJpegTurboVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DENABLE_SHARED=ON -DENABLE_STATIC=OFF -DWITH_JPEG8=1
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build libwebp ---
Write-Host "Building libwebp $LibWebPVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$($LibWebPVersion).tar.gz" -OutFile "libwebp-$($LibWebPVersion).tar.gz" -ExtractTo "."
Push-Location "libwebp-$LibWebPVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build libtiff ---
Write-Host "Building libtiff $LibTiffVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://download.osgeo.org/libtiff/tiff-$($LibTiffVersion).tar.gz" -OutFile "libtiff-$($LibTiffVersion).tar.gz" -ExtractTo "."
Push-Location "tiff-$LibTiffVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -Djbig=OFF -Dlerc=OFF -Dlzma=OFF -Dzstd=OFF -Dwebp=ON
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Build Leptonica ---
Write-Host "Building Leptonica $LeptonicaVersion..."
Push-Location $TempBuildDir
Get-Archive -Url "https://github.com/DanBloomberg/leptonica/archive/$($LeptonicaVersion).tar.gz" -OutFile "leptonica-$($LeptonicaVersion).tar.gz" -ExtractTo "."
Push-Location "leptonica-$LeptonicaVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
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
Get-Archive -Url "https://github.com/tesseract-ocr/tesseract/archive/$($TesseractVersion).tar.gz" -OutFile "tesseract-$($TesseractVersion).tar.gz" -ExtractTo "."
Push-Location "tesseract-$TesseractVersion"
New-Item -ItemType Directory -Path "build.msvs" -Force | Out-Null
Push-Location "build.msvs"
cmake .. -DCMAKE_INSTALL_PREFIX=$env:INSTALL_DIR `
           -DCMAKE_BUILD_TYPE=Release `
           -DBUILD_SHARED_LIBS=ON `
           -DOPENMP_BUILD=OFF `
           -DBUILD_TRAINING_TOOLS=OFF `
           -DSW_BUILD=OFF
cmake --build . --config Release --target install
Pop-Location; Pop-Location; Pop-Location

# --- Download Tessdata ---
Write-Host "Downloading Tesseract language data (tessdata_fast)..."
if (-not (Test-Path $env:TESSDATA_PREFIX)) {
    New-Item -ItemType Directory -Path $env:TESSDATA_PREFIX -Force | Out-Null
}
$TessdataRepo = "https://github.com/tesseract-ocr/tessdata_fast"
Invoke-WebRequest -Uri "$TessdataRepo/raw/main/eng.traineddata" -OutFile "$env:TESSDATA_PREFIX\eng.traineddata"
Invoke-WebRequest -Uri "$TessdataRepo/raw/main/osd.traineddata" -OutFile "$env:TESSDATA_PREFIX\osd.traineddata"

Pop-Location # Back to original location before $TempBuildDir
Write-Host "Attempting to remove temporary build directory: $TempBuildDir"
Remove-Item -Recurse -Force $TempBuildDir

Write-Host "Windows dependencies installation complete."
