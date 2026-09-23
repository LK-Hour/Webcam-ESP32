$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$idfRoot = 'C:\Espressif\frameworks\esp-idf-v5.5.5'
$idfPython = 'C:\Espressif\python_env\idf5.5_py3.11_env\Scripts\python.exe'
$boardMacFile = Join-Path $PSScriptRoot 'board_mac.txt'
$expectedMac = if (Test-Path -LiteralPath $boardMacFile -PathType Leaf) {
    (Get-Content -LiteralPath $boardMacFile -Raw).Trim()
} else {
    $null
}
$webcamId = 'USB\VID_303A&PID_8000*'

try {
    if (-not (Test-Path -LiteralPath $idfPython -PathType Leaf)) {
        throw "ESP-IDF Python was not found at $idfPython"
    }

    Write-Host 'Connect the board to its USB-to-UART/programming USB-C port.'
    Write-Host 'Waiting for the programming port. Press Ctrl+C to stop waiting.'
    do {
        $programmingDevices = @(
            Get-PnpDevice -PresentOnly -Class Ports -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.InstanceId -like 'USB\VID_1A86&PID_55D3*' -and $_.Status -eq 'OK'
                }
        )
        if ($programmingDevices.Count -gt 1) {
            throw 'More than one CH343 programming port was found. Disconnect the other device and try again.'
        }
        if ($programmingDevices.Count -eq 1 -and
            $programmingDevices[0].FriendlyName -match '\((COM\d+)\)') {
            $port = $Matches[1]
            break
        }
        Start-Sleep -Seconds 2
    } while ($true)

    Write-Host "Checking board on $port..."
    $probe = (& $idfPython -m esptool --chip esp32s3 --port $port flash_id | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not identify the ESP32-S3 on $port."
    }
    if ($expectedMac -and $probe -notmatch [regex]::Escape("MAC: $expectedMac")) {
        throw "The device on $port does not match the board MAC in tools/board_mac.txt."
    }

    $env:IDF_TOOLS_PATH = 'C:\Espressif'
    $env:IDF_PYTHON_ENV_PATH = Split-Path -Parent (Split-Path -Parent $idfPython)
    . (Join-Path $idfRoot 'export.ps1') | Out-Null

    Write-Host "Building and flashing the webcam firmware on $port..."
    Push-Location $projectRoot
    try {
        $cacheFile = Join-Path $projectRoot 'build\CMakeCache.txt'
        if (Test-Path -LiteralPath $cacheFile -PathType Leaf) {
            $cacheEntry = Get-Content -LiteralPath $cacheFile |
                Where-Object { $_ -like 'CMAKE_HOME_DIRECTORY:INTERNAL=*' } |
                Select-Object -First 1
            if ($cacheEntry) {
                $configuredProject = ($cacheEntry -split '=', 2)[1]
                $currentProject = $projectRoot.Replace('\', '/')
                if ($configuredProject -ne $currentProject) {
                    Write-Host "Build files refer to $configuredProject. Cleaning generated build files for the new project path..."
                    & $idfPython (Join-Path $idfRoot 'tools\idf.py') fullclean
                    if ($LASTEXITCODE -ne 0) {
                        throw 'Could not clean the stale build directory.'
                    }
                }
            }
        }
        & $idfPython (Join-Path $idfRoot 'tools\idf.py') -p $port flash
        if ($LASTEXITCODE -ne 0) {
            throw 'ESP-IDF could not build or flash the webcam firmware.'
        }
    } finally {
        Pop-Location
    }

    Write-Host ''
    Write-Host 'Flash complete. Move the USB-C cable to the board''s native USB/webcam port.'
    Write-Host 'Waiting for the webcam to appear. Press Ctrl+C to stop waiting.'
    do {
        Start-Sleep -Seconds 2
        $webcam = Get-PnpDevice -PresentOnly -Class Camera -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceId -like $webcamId -and $_.Status -eq 'OK' }
    } until ($webcam)

    Write-Host 'Webcam detected. Opening Windows Camera...'
    Start-Process 'microsoft.windows.camera:'
    exit 0
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
