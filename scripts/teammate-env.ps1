[CmdletBinding()]
param([switch]$Initialize)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repo '.env.teammate'
$template = Join-Path $repo 'infra/teammate.env.example'

function New-LocalRandom([int]$Count = 32) {
    $bytes = New-Object byte[] $Count
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return [Convert]::ToBase64String($bytes)
}

if ($Initialize -and !(Test-Path -LiteralPath $envPath)) {
    $text = [IO.File]::ReadAllText($template)
    $lines = foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^([A-Z][A-Z0-9_]*)=GENERATE_LOCALLY$') {
            $key = $Matches[1]
            $value = if ($key -eq 'WEDO_MEDIA_ACCESS_KEY') {
                (New-LocalRandom 16).Replace('+', 'A').Replace('/', 'B').TrimEnd('=')
            } elseif ($key -eq 'WEDO_LOCAL_TEST_PASSWORD') {
                'Dev!' + (New-LocalRandom 24)
            } else { New-LocalRandom }
            "$key=$value"
        } else { $line }
    }
    [IO.File]::WriteAllText($envPath, ($lines -join "`n"), (New-Object Text.UTF8Encoding $false))
    Write-Host 'Created ignored .env.teammate with new local-only random values.'
} elseif ($Initialize) {
    Write-Host 'Kept existing .env.teammate; no secret or seed-password rotation.'
}
if (!(Test-Path -LiteralPath $envPath)) {
    throw 'Run .\scripts\teammate-env.ps1 -Initialize first.'
}
foreach ($line in [IO.File]::ReadAllLines($envPath)) {
    if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') {
        $key = $Matches[1]
        $value = $Matches[2]
        if ($value -eq 'GENERATE_LOCALLY') { throw "Uninitialized variable: $key" }
        Set-Item -Path "Env:$key" -Value $value
    }
}
if ($env:WEDO_LOCAL_TEST_DATA_ENABLED -eq 'true' -and
    $env:WEDO_DB_URL -notmatch '^jdbc:postgresql://(127\.0\.0\.1|localhost):15432/wedo$') {
    throw 'Synthetic seeding is restricted to the documented localhost:15432/wedo database.'
}
Write-Host 'Loaded local environment. Values were not printed. Do not commit .env.teammate.'
