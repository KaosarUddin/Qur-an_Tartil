$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendDirectory = Join-Path $projectRoot 'backend'
$backendPython = Join-Path $backendDirectory '.venv\Scripts\python.exe'

if (-not (Test-Path -LiteralPath $backendPython)) {
    throw 'Backend environment not found. Follow backend/README.md setup first.'
}

Set-Location -LiteralPath $backendDirectory
Write-Host 'Starting experimental Quran ASR at http://127.0.0.1:8000'
Write-Host 'Keep this window open while using the desktop app.'
& $backendPython -m uvicorn app.main:app --host 127.0.0.1 --port 8000
