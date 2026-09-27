[CmdletBinding()]
param(
    [string]$DeviceId = 'R58M36JQYVY',
    [string]$PubCache
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runtimeDir = Join-Path $repoRoot '.dev-runtime'
$logsDir = Join-Path $repoRoot '.dev-logs'
$launcherLock = Join-Path $runtimeDir 'dev-run.lock'
$backendPidFile = Join-Path $runtimeDir 'backend-process.json'
$backendLog = Join-Path $logsDir 'backend.out.log'
$backendErrorLog = Join-Path $logsDir 'backend.err.log'
$backendUrl = 'http://127.0.0.1:8080/api/v1/health'

New-Item -ItemType Directory -Force -Path $runtimeDir, $logsDir | Out-Null

function Test-ProcessAlive([int]$ProcessId) {
    return $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
}

if (Test-Path $launcherLock) {
    $existing = Get-Content -Raw $launcherLock | ConvertFrom-Json
    if (Test-ProcessAlive $existing.processId) {
        throw "A weDO launcher is already running (PID $($existing.processId)). Stop Flutter with Ctrl+C before starting another one."
    }
    Remove-Item -Force $launcherLock
}

@{ processId = $PID; startedAtUtc = [DateTime]::UtcNow.ToString('o') } |
    ConvertTo-Json | Set-Content -Encoding UTF8 $launcherLock

function Wait-Until([scriptblock]$Condition, [int]$TimeoutSeconds, [string]$FailureMessage) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw $FailureMessage
}

function Get-AdbPath {
    $sdkAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (Test-Path $sdkAdb) { return $sdkAdb }
    $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($null -eq $adbCommand) { $adbCommand = Get-Command adb -ErrorAction SilentlyContinue }
    if ($null -eq $adbCommand) {
        throw 'ADB was not found. Install Android platform-tools or add adb to PATH.'
    }
    return $adbCommand.Source
}

function Test-BackendHealth {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 $backendUrl
        return $response.StatusCode -eq 200 -and $response.Content -match '"status"\s*:\s*"UP"'
    } catch {
        return $false
    }
}

try {
    if ($PubCache) {
        if (-not (Test-Path $PubCache)) { throw "PUB_CACHE path does not exist: $PubCache" }
        $env:PUB_CACHE = (Resolve-Path $PubCache).Path
    }

    if ($null -eq (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker CLI was not found. Install Docker Desktop and retry.'
    }

    $dockerReady = $false
    try { docker info --format '{{.ServerVersion}}' | Out-Null; $dockerReady = $LASTEXITCODE -eq 0 } catch { }
    if (-not $dockerReady) {
        $desktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
        if (Test-Path $desktop) {
            Start-Process -FilePath $desktop -WindowStyle Hidden
            Write-Host 'Starting Docker Desktop...'
            Wait-Until { try { docker info --format '{{.ServerVersion}}' | Out-Null; $LASTEXITCODE -eq 0 } catch { $false } } 90 'Docker Engine did not become ready within 90 seconds.'
        } else {
            throw 'Docker Engine is unavailable. Start Docker Desktop, then retry.'
        }
    }

    Push-Location $repoRoot
    try { docker compose -f infra/docker-compose.yml up -d } finally { Pop-Location }
    Wait-Until { (docker inspect --format '{{.State.Health.Status}}' wedo-postgres 2>$null) -eq 'healthy' } 60 'PostgreSQL did not become healthy within 60 seconds.'

    if (-not (Test-BackendHealth)) {
        $listener = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
        if ($listener) { throw 'Port 8080 is occupied by a process that does not pass the weDO health check.' }

        $mavenWrapper = Join-Path $repoRoot 'backend\mvnw.cmd'
        $previousSeedSetting = $env:WEDO_LOCAL_TEST_DATA_ENABLED
        try {
            $env:WEDO_LOCAL_TEST_DATA_ENABLED = 'true'
            $backend = Start-Process -FilePath $env:ComSpec `
                -ArgumentList @('/d', '/c', "`"$mavenWrapper`" spring-boot:run") `
                -WorkingDirectory (Join-Path $repoRoot 'backend') `
                -WindowStyle Hidden `
                -RedirectStandardOutput $backendLog `
                -RedirectStandardError $backendErrorLog `
                -PassThru
        } finally {
            $env:WEDO_LOCAL_TEST_DATA_ENABLED = $previousSeedSetting
        }
        @{ processId = $backend.Id; startedAtUtc = $backend.StartTime.ToUniversalTime().ToString('o') } |
            ConvertTo-Json | Set-Content -Encoding UTF8 $backendPidFile
        Write-Host "Started backend (PID $($backend.Id)); logs: $logsDir"
        Wait-Until { Test-BackendHealth } 120 "Backend did not become healthy within 120 seconds. See $backendErrorLog"
    } else {
        Write-Host 'Using the already healthy backend on port 8080.'
    }

    $adb = Get-AdbPath
    $devices = & $adb devices
    $line = $devices | Where-Object { $_ -match "^$([regex]::Escape($DeviceId))\s+" } | Select-Object -First 1
    if ($null -eq $line) { throw "Android device $DeviceId was not found. Connect it and enable USB debugging." }
    if ($line -match '\s+unauthorized\s*$') { throw "Android device $DeviceId is unauthorized. Accept the USB-debugging prompt on the device." }
    if ($line -match '\s+offline\s*$') { throw "Android device $DeviceId is offline. Reconnect it and retry." }
    if ($line -notmatch '\s+device\s*$') { throw "Android device $DeviceId is unavailable: $line" }

    & $adb -s $DeviceId reverse tcp:8080 tcp:8080
    if ($LASTEXITCODE -ne 0) { throw 'ADB reverse for tcp:8080 failed.' }

    Push-Location (Join-Path $repoRoot 'mobile')
    try {
        flutter run -d $DeviceId --dart-define=WEDO_API_BASE_URL=http://127.0.0.1:8080
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item -Force $launcherLock -ErrorAction SilentlyContinue
}
