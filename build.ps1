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

        New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
        $zip = Join-Path $toolDir "fasmw17332.zip"
        Invoke-WebRequest -Uri "https://flatassembler.net/fasmw17332.zip" -OutFile $zip
        Expand-Archive -LiteralPath $zip -DestinationPath $toolDir -Force
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
