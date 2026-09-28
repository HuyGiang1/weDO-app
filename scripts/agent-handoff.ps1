param(
    [switch]$IncludeDiffStat = $true
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "=== weDO Agent Handoff Snapshot ===" -ForegroundColor Cyan
Write-Host "Branch : $(git branch --show-current)"
Write-Host "HEAD   : $(git rev-parse HEAD)"
Write-Host ""

Write-Host "--- Git Status (--short) ---" -ForegroundColor Yellow
git status --short

if ($IncludeDiffStat) {
    Write-Host ""
    Write-Host "--- Git Diff (--stat) ---" -ForegroundColor Yellow
    git diff --stat
}

Write-Host ""
Write-Host "--- Git Stash List ---" -ForegroundColor Yellow
git stash list

Write-Host ""
Write-Host "--- Required Reading Order ---" -ForegroundColor Green
Write-Host "1. .agents/skills/wedo-milestone-delivery/SKILL.md"
Write-Host "2. docs/AGENT_PROJECT_CONTEXT.md"
Write-Host "3. docs/AGENT_CURRENT_HANDOFF.md"
Write-Host "4. docs/AGENT_DECISION_LOG.md"
