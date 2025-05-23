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
    [string]$LibPngVersion = "1.6.48",
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
        # Check file size
        $fileInfo = Get-Item $FullOutFile
        if ($fileInfo.Length -eq 0) {
            throw "Downloaded file '$FullOutFile' is empty (0 bytes)."
        }
        Write-Host "Downloaded '$FullOutFile' successfully. Size: $($fileInfo.Length) bytes."
    }
    catch {
        Write-Error "Failed to download '$Url'. Error: $($_.Exception.Message)"
        throw # Rethrow to stop the script as per $ErrorActionPreference = "Stop"
    }

    Write-Host "Extracting $FullOutFile to $FullExtractTo..."
    try {
        if ($FullOutFile.EndsWith(".zip")) {
            Expand-Archive -Path $FullOutFile -DestinationPath $FullExtractTo -Force -ErrorAction Stop
        }
        elseif ($FullOutFile.EndsWith(".tar.gz") -or $FullOutFile.EndsWith(".tgz") -or $FullOutFile.EndsWith(".tar.bz2") -or $FullOutFile.EndsWith(".tar")) {
            tar -xf $FullOutFile -C $FullExtractTo # tar usually gives good errors on failure
        }
        else {
            throw "Unrecognized archive format for file: $FullOutFile"
        }
        Write-Host "Successfully extracted $FullOutFile."
    }
    catch {
        Write-Error "Failed to extract '$FullOutFile'."
        Write-Error "Underlying Exception: $($_.Exception.ToString())" # More detailed exception
        # Additional diagnostics
        if (Test-Path $FullOutFile) {
            $fileInfoOnFail = Get-Item $FullOutFile
            Write-Warning "File '$FullOutFile' exists at time of extraction failure. Size: $($fileInfoOnFail.Length) bytes."
            if ($FullOutFile.EndsWith(".zip")) {
                Write-Host "Attempting to validate ZIP file '$FullOutFile'..."
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $zip = [System.IO.Compression.ZipFile]::OpenRead($FullOutFile)
                    Write-Host "ZIP file opened. Number of entries: $($zip.Entries.Count)."
                    # foreach ($entry in $zip.Entries) { Write-Host " - $($entry.FullName)" } # Can be too verbose
                    $zip.Dispose()
                    Write-Host "ZIP file '$FullOutFile' appears to be structurally valid."
                } catch {
                    Write-Warning "Could not validate ZIP file '$FullOutFile'. Error: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Warning "File '$FullOutFile' does not exist at extraction failure phase (was it removed prematurely?)."
        }
        throw # Rethrow to stop the script
    }
    finally {
        # Clean up the downloaded archive file
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
$LibPngFileNameOnDisk = "libpng-$($LibPngVersion).zip"
$LibPngSourceFileNameInUrl = "lpng$($LibPngVersion -replace '\.','').zip"
$LibPngDirName = "lpng$($LibPngVersion -replace '\.','')"
$LibPngUrl = "https://downloads.sourceforge.net/project/libpng/libpng16/$($LibPngVersion)/$($LibPngSourceFileNameInUrl)"

Push-Location $TempBuildDir
Get-Archive -Url $LibPngUrl -OutFile $LibPngFileNameOnDisk -ExtractTo "."
Push-Location $LibPngDirName
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
