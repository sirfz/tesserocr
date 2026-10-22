$ErrorActionPreference = "Stop"

$versions = Get-Content (Join-Path $PSScriptRoot "tesseract-versions.env") -Raw | ConvertFrom-StringData
$prefix = Join-Path $env:RUNNER_TEMP "tesserocr-deps"
# Use the runner's Miniconda only for native libraries, not for building Python wheels.
$env:PATH = "$env:CONDA\Library\bin;$env:PATH"
# Avoid libarchive's GPL/LZO variant.
& "$env:CONDA\Scripts\conda.exe" create --yes --prefix $prefix --override-channels --channel conda-forge `
    "tesseract=$($versions.TESSERACT_VERSION)" "leptonica=$($versions.LEPTONICA_VERSION)" "libarchive=*=lgpl_*"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

"$prefix\Library\bin" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
"LIBPATH=$prefix\Library\lib;$env:LIBPATH" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
"INCLUDE=$prefix\Library\include;$env:INCLUDE" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

# Preserve the license notices for the DLLs vendored by cibuildwheel's delvewheel repair.
New-Item -ItemType Directory -Path ".wheel-licenses" -Force | Out-Null
Get-ChildItem "$prefix\conda-meta\*.json" | ForEach-Object {
    $package = Get-Content $_.FullName -Raw | ConvertFrom-Json
    $licenses = Join-Path $package.link.source "info\licenses"
    if (Test-Path $licenses) {
        Copy-Item $licenses ".wheel-licenses\$($package.name)" -Recurse -Force
    }
}
foreach ($name in @("tesseract", "leptonica")) {
    if (-not (Test-Path ".wheel-licenses\$name")) {
        throw "Missing license notices for $name"
    }
}
