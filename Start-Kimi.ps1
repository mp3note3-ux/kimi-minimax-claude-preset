[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $ClaudeArgs
)

$ErrorActionPreference = 'Stop'

Set-Location -LiteralPath $PSScriptRoot

$agentFile = Join-Path $PSScriptRoot '.claude\agents\kimi-orchestrator.md'
if (-not (Test-Path -LiteralPath $agentFile)) {
    throw "Kimi preset is not installed. Run Install-Preset.ps1 for this project first."
}

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "Claude Code CLI was not found on PATH. Install Claude Code and reopen PowerShell."
}

# These variables can override the model selected by the project launcher or
# the model frontmatter on a subagent. Remove them only in this process tree.
$overrides = @(
    'ANTHROPIC_MODEL',
    'CLAUDE_CODE_SUBAGENT_MODEL',
    'CLAUDE_CODE_SUBAGENT_MODEL_FORCE'
)
foreach ($name in $overrides) {
    Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
}

# Keep worker concurrency conservative by default. This is a concurrency cap, not a per-session spend cap.
$env:CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS = '1'

Write-Host "Starting Kimi K3 as the read-only project administrator."
Write-Host "MiniMax M2.5 workers handle implementation, shell commands, tests, and available MCP tools."

& claude --agent kimi-orchestrator --model kimi-k3 @ClaudeArgs
exit $LASTEXITCODE
