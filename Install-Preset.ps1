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
    '.claude\hooks\block-kimi-readonly.ps1',
    'Start-Kimi.ps1'
)

$startMarker = '<!-- BEGIN KIMI-MINIMAX PRESET -->'
$endMarker = '<!-- END KIMI-MINIMAX PRESET -->'
$managedSection = @'
<!-- BEGIN KIMI-MINIMAX PRESET -->

## Kimi K3 administrator / MiniMax M2.5 workers

This project uses the Kimi-MiniMax Claude Code preset. Start the main session with .\Start-Kimi.ps1.

- Kimi K3 is the read-only project lead: it inspects code, plans, delegates, and reviews.
- Kimi delegates all implementation, file edits, shell commands, tests, and MCP operations to minimax-worker or minimax-bulk-worker.
- MiniMax M2.5 workers perform implementation and return changed-file lists, actual test results, and outstanding risks.
- Prefer one worker at a time unless independent tasks justify parallel work.
- Do not put credentials, API keys, or gateway secrets in repository files.

The Kimi agent uses an agent-scoped PreToolUse hook as its direct-tool enforcement boundary. Do not remove the hook or broaden Kimi's direct tool access unless you deliberately intend to change this policy.

<!-- END KIMI-MINIMAX PRESET -->
'@

# Preflight all source files before changing the destination project.
foreach ($relativePath in $managedFiles) {
    $source = Join-Path $presetRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Preset source file is missing: $source"
    }
}

$conflicts = @()

# Check collisions with preset-managed files.
foreach ($relativePath in $managedFiles) {
    $source = Join-Path $presetRoot $relativePath
    $destination = Join-Path $projectRoot $relativePath
    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($sourceHash -ne $targetHash -and -not $Force) {
            $conflicts += $relativePath
        }
    }
}

# Preflight the existing CLAUDE.md marker pair and managed-section collision.
$claudeMd = Join-Path $projectRoot 'CLAUDE.md'
$claudeMdAction = 'create'
$existingClaude = ''
if (Test-Path -LiteralPath $claudeMd -PathType Leaf) {
    $existingClaude = [System.IO.File]::ReadAllText($claudeMd)
    $hasStart = $existingClaude.Contains($startMarker)
    $hasEnd = $existingClaude.Contains($endMarker)

    if ($hasStart -xor $hasEnd) {
        throw "CLAUDE.md contains an incomplete Kimi-MiniMax preset marker pair. Repair it manually before installing."
    }

    if ($hasStart -and $hasEnd) {
        $startIndex = $existingClaude.IndexOf($startMarker)
        $endIndex = $existingClaude.IndexOf($endMarker)
        if ($endIndex -lt $startIndex) {
            throw "CLAUDE.md preset markers are out of order. Repair them manually before installing."
        }

        $endAfterMarker = $endIndex + $endMarker.Length
        $oldSection = $existingClaude.Substring($startIndex, $endAfterMarker - $startIndex)
        if ($oldSection -eq $managedSection) {
            $claudeMdAction = 'unchanged'
        }
        elseif ($Force) {
            $claudeMdAction = 'update'
        }
        else {
            $conflicts += 'CLAUDE.md (managed preset section)'
        }
    }
    else {
        $claudeMdAction = 'append'
    }
}

# Preflight .claude/settings.json. Preserve every existing property except
# the project default agent, which this preset intentionally sets.
$settingsPath = Join-Path $projectRoot '.claude\settings.json'
$settingsAction = 'create'
$settingsObject = $null
if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    $settingsText = [System.IO.File]::ReadAllText($settingsPath)
    try {
        $settingsObject = $settingsText | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Cannot safely merge .claude/settings.json because it is not valid JSON. Fix it or merge agent = kimi-orchestrator manually, then rerun the installer."
    }

    $agentProperty = $settingsObject.PSObject.Properties['agent']
    if ($null -eq $agentProperty) {
        $settingsAction = 'merge'
    }
    elseif ([string]$agentProperty.Value -eq 'kimi-orchestrator') {
        $settingsAction = 'unchanged'
    }
    elseif ($Force) {
        $settingsAction = 'replace'
    }
    else {
        $conflicts += '.claude/settings.json (existing agent setting)'
    }
}
else {
    $settingsObject = [pscustomobject]@{ agent = 'kimi-orchestrator' }
}

if ($conflicts.Count -gt 0) {
    Write-Host "The following preset-managed items already exist and differ:" -ForegroundColor Yellow
    $conflicts | ForEach-Object { Write-Host "  $_" }
    throw "Nothing was installed. Review the conflicts, or rerun with -Force to back up and replace the conflicting preset-managed items."
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# Copy the preset-managed files. With -Force, back up changed files first.
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

# Apply the CLAUDE.md section without removing unrelated instructions.
switch ($claudeMdAction) {
    'create' {
        [System.IO.File]::WriteAllText($claudeMd, $managedSection + [Environment]::NewLine, $utf8NoBom)
        Write-Host 'Created: CLAUDE.md'
    }
    'append' {
        $updated = $existingClaude.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $managedSection + [Environment]::NewLine
        [System.IO.File]::WriteAllText($claudeMd, $updated, $utf8NoBom)
        Write-Host 'Added: CLAUDE.md preset section'
    }
    'update' {
        Copy-Item -LiteralPath $claudeMd -Destination "$claudeMd.backup-$timestamp" -Force
        $startIndex = $existingClaude.IndexOf($startMarker)
        $endIndex = $existingClaude.IndexOf($endMarker) + $endMarker.Length
        $updated = $existingClaude.Substring(0, $startIndex) + $managedSection + $existingClaude.Substring($endIndex)
        [System.IO.File]::WriteAllText($claudeMd, $updated, $utf8NoBom)
        Write-Host 'Updated: CLAUDE.md preset section'
    }
    'unchanged' {
        Write-Host 'Unchanged: CLAUDE.md preset section'
    }
}

# Merge the project default agent while preserving all other settings.
switch ($settingsAction) {
    'create' {
        $settingsObject | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding utf8
        Write-Host 'Created: .claude/settings.json'
    }
    'merge' {
        $settingsObject | Add-Member -NotePropertyName agent -NotePropertyValue 'kimi-orchestrator' -Force
        [System.IO.File]::WriteAllText($settingsPath, ($settingsObject | ConvertTo-Json -Depth 100), $utf8NoBom)
        Write-Host 'Set: .claude/settings.json agent = kimi-orchestrator'
    }
    'replace' {
        Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.backup-$timestamp" -Force
        $settingsObject.agent = 'kimi-orchestrator'
        [System.IO.File]::WriteAllText($settingsPath, ($settingsObject | ConvertTo-Json -Depth 100), $utf8NoBom)
        Write-Host 'Updated: .claude/settings.json agent = kimi-orchestrator'
    }
    'unchanged' {
        Write-Host 'Unchanged: .claude/settings.json agent = kimi-orchestrator'
    }
}

Write-Host ''
Write-Host "Kimi-MiniMax preset installed in: $projectRoot" -ForegroundColor Green
Write-Host 'Next: trust this workspace in Claude Code, then run .\Start-Kimi.ps1'
Write-Host 'Existing unrelated settings, MCP configuration, credentials, and CLAUDE.md instructions were preserved.'
