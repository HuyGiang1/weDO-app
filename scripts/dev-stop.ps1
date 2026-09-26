[CmdletBinding()]
param([switch]$StopInfra)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runtimeDir = Join-Path $repoRoot '.dev-runtime'
$backendPidFile = Join-Path $runtimeDir 'backend-process.json'

function Get-ProcessTree([int]$RootProcessId) {
    $all = Get-CimInstance Win32_Process
    $pending = [System.Collections.Generic.Queue[int]]::new()
    $pending.Enqueue($RootProcessId)
    $result = [System.Collections.Generic.List[int]]::new()
    while ($pending.Count -gt 0) {
        $current = $pending.Dequeue()
        $result.Add($current)
        foreach ($child in $all | Where-Object { $_.ParentProcessId -eq $current }) {
            $pending.Enqueue([int]$child.ProcessId)
        }
    }
    return $result
}

if (Test-Path $backendPidFile) {
    $record = Get-Content -Raw $backendPidFile | ConvertFrom-Json
    $process = Get-Process -Id $record.processId -ErrorAction SilentlyContinue
    if ($process) {
        $startedAt = $process.StartTime.ToUniversalTime().ToString('o')
        if ($startedAt -eq $record.startedAtUtc) {
            $processIds = Get-ProcessTree $record.processId | Sort-Object -Descending
            foreach ($processId in $processIds) {
                Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
            }
            Write-Host "Stopped backend process tree rooted at PID $($record.processId)."
        } else {
            Write-Warning "PID $($record.processId) has been reused; it was not stopped."
        }
    } else {
        Write-Host 'Recorded backend process is no longer running.'
    }
    Remove-Item -Force $backendPidFile
} else {
    Write-Host 'No backend process was recorded by dev-run.'
}

if ($StopInfra) {
    Push-Location $repoRoot
    try { docker compose -f infra/docker-compose.yml stop } finally { Pop-Location }
}
