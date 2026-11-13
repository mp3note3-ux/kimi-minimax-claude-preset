[CmdletBinding()]
param(
    [string] $ProjectPath = (Get-Location).Path,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$resolvedProject = Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop
$projectRoot = $resolvedProject.Path
if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) {
    throw "ProjectPath must be an existing directory: $ProjectPath"
}

$presetRoot = $PSScriptRoot
$managedFiles = @(
    '.claude\agents\kimi-orchestrator.md',
    '.claude\agents\minimax-worker.md',
    '.claude\agents\minimax-bulk-worker.md',
    'Start-Kimi.ps1'
)

# Preflight all managed files before changing the target project.
$conflicts = @()
foreach ($relativePath in $managedFiles) {
    $source = Join-Path $presetRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Preset source file is missing: $source"
    }

    $destination = Join-Path $projectRoot $relativePath
    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($sourceHash -ne $targetHash -and -not $Force) {
            $conflicts += $relativePath
        }
    }
}

if ($conflicts.Count -gt 0) {
    Write-Host "The following preset-managed files already exist and differ:" -ForegroundColor Yellow
    $conflicts | ForEach-Object { Write-Host "  $_" }
    throw "Nothing was installed. Re-run with -Force to back up and replace only these preset-managed files."
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($relativePath in $managedFiles) {
    $source = Join-Path $presetRoot $relativePath
    $destination = Join-Path $projectRoot $relativePath
    $destinationDirectory = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null

    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($sourceHash -eq $targetHash) {
            Write-Host "Unchanged: $relativePath"
            continue
        }

        if ($Force) {
            Copy-Item -LiteralPath $destination -Destination "$destination.backup-$timestamp" -Force
        }
    }

    Copy-Item -LiteralPath $source -Destination $destination -Force
    Write-Host "Installed: $relativePath"
}

# Append or update a clearly marked section in CLAUDE.md without deleting
# existing project instructions.
$startMarker = '<!-- BEGIN KIMI-MINIMAX PRESET -->'
$endMarker = '<!-- END KIMI-MINIMAX PRESET -->'
$managedSection = @'
<!-- BEGIN KIMI-MINIMAX PRESET -->

## Kimi K3 administrator / MiniMax M2.5 workers

This project uses the Kimi-MiniMax Claude Code preset. Start the main session with .\Start-Kimi.ps1.

- Kimi K3 is the read-only project lead: it inspects code, plans, delegates, and reviews.
- Kimi must delegate all implementation, file edits, shell commands, testing, and MCP operations to minimax-worker or minimax-bulk-worker.
- MiniMax M2.5 workers perform the implementation and return changed-file lists, actual test results, and outstanding risks.
- Prefer one worker at a time unless independent tasks justify parallel work.
- Do not put credentials, API keys, or gateway secrets in repository files.

The Kimi agent's native tool allowlist is the enforcement boundary for its direct tool access. Do not broaden it with Bash, Edit, Write, or MCP tools unless you deliberately intend to change this policy.

<!-- END KIMI-MINIMAX PRESET -->
'@

$claudeMd = Join-Path $projectRoot 'CLAUDE.md'
if (Test-Path -LiteralPath $claudeMd -PathType Leaf) {
    $existing = [System.IO.File]::ReadAllText($claudeMd)
    $hasStart = $existing.Contains($startMarker)
    $hasEnd = $existing.Contains($endMarker)

    if ($hasStart -xor $hasEnd) {
        throw "CLAUDE.md contains an incomplete Kimi-MiniMax preset marker pair. Repair it manually before installing again."
    }

    if ($hasStart -and $hasEnd) {
        $startIndex = $existing.IndexOf($startMarker)
        $endIndex = $existing.IndexOf($endMarker)
        if ($endIndex -lt $startIndex) {
            throw "CLAUDE.md preset markers are out of order. Repair them manually before installing again."
        }

        $endAfterMarker = $endIndex + $endMarker.Length
        $oldSection = $existing.Substring($startIndex, $endAfterMarker - $startIndex)
        if ($oldSection -eq $managedSection) {
            Write-Host "Unchanged: CLAUDE.md preset section"
        }
        elseif (-not $Force) {
            throw "CLAUDE.md already contains an older or modified preset section. Re-run with -Force to back up and update that section."
        }
        else {
            Copy-Item -LiteralPath $claudeMd -Destination "$claudeMd.backup-$timestamp" -Force
            $updated = $existing.Substring(0, $startIndex) + $managedSection + $existing.Substring($endAfterMarker)
            [System.IO.File]::WriteAllText($claudeMd, $updated, [System.Text.UTF8Encoding]::new($false))
            Write-Host "Updated: CLAUDE.md preset section"
        }
    }
    else {
        $updated = $existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $managedSection + [Environment]::NewLine
        [System.IO.File]::WriteAllText($claudeMd, $updated, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Added: CLAUDE.md preset section"
    }
}
else {
    [System.IO.File]::WriteAllText($claudeMd, $managedSection + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Created: CLAUDE.md"
}

Write-Host ''
Write-Host "Kimi-MiniMax preset installed in: $projectRoot" -ForegroundColor Green
Write-Host "Next: open PowerShell in that project and run .\Start-Kimi.ps1"
Write-Host "No existing .claude/settings.json, MCP configuration, or credentials were changed."
