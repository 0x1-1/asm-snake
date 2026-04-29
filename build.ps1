param(
    [switch]$NoBootstrap
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildDir = Join-Path $root "build"
$source = Join-Path $root "snake.asm"
$output = Join-Path $buildDir "asm-snake.exe"
$toolDir = Join-Path $root ".tools"
$fasmExe = $null
$fasmDownloads = @(
    @{
        Name = "FASM 1.73.32 official package"
        Uri = "https://flatassembler.net/fasmw17332.zip"
        FileName = "fasmw17332.zip"
    },
    @{
        Name = "FASM 1.70.02 SourceForge mirror"
        Uri = "https://master.dl.sourceforge.net/project/fasm/flat%20assembler%20for%20Windows/flat%20assembler%201.70/fasmw17002.zip?viasf=1"
        FileName = "fasmw17002.zip"
    }
)

function Test-ZipArchive {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return $bytes.Length -ge 4 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B
}

function Install-Fasm {
    New-Item -ItemType Directory -Force -Path $toolDir | Out-Null

    foreach ($download in $fasmDownloads) {
        $zip = Join-Path $toolDir $download.FileName
        try {
            Write-Host "Downloading $($download.Name)..."
            Invoke-WebRequest -Uri $download.Uri -OutFile $zip -MaximumRedirection 10

            if (-not (Test-ZipArchive -Path $zip)) {
                throw "Downloaded file is not a zip archive."
            }

            Expand-Archive -LiteralPath $zip -DestinationPath $toolDir -Force

            $installedFasm = Join-Path $toolDir "FASM.EXE"
            if (Test-Path -LiteralPath $installedFasm) {
                return
            }

            throw "Archive did not contain FASM.EXE."
        }
        catch {
            Write-Warning "Could not install $($download.Name): $($_.Exception.Message)"
            Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        }
    }

    throw "Could not download FASM from any configured source."
}

$pathFasm = Get-Command "fasm.exe" -ErrorAction SilentlyContinue
if ($pathFasm) {
    $fasmExe = $pathFasm.Source
}

if (-not $fasmExe) {
    $localFasm = Join-Path $toolDir "FASM.EXE"
    if (-not (Test-Path -LiteralPath $localFasm)) {
        if ($NoBootstrap) {
            throw "fasm.exe was not found. Install FASM, put FASM.EXE under .tools, or run without -NoBootstrap."
        }

        Install-Fasm
    }

    $fasmExe = $localFasm
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$includeDir = Join-Path (Split-Path -Parent $fasmExe) "INCLUDE"
if (Test-Path -LiteralPath $includeDir) {
    $env:INCLUDE = $includeDir
}

& $fasmExe $source $output
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Built $output"
