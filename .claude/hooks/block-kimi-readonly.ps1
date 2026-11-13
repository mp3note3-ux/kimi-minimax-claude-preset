$ErrorActionPreference = 'Stop'

function Deny-ToolCall {
    param([Parameter(Mandatory = $true)][string] $Reason)

    @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    } | ConvertTo-Json -Depth 8 -Compress
    exit 0
}

try {
    $rawInput = [Console]::In.ReadToEnd()
    $event = $rawInput | ConvertFrom-Json -ErrorAction Stop
}
catch {
    [Console]::Error.WriteLine('Kimi read-only guard: unable to parse hook input; denying the tool call.')
    exit 2
}

$agentType = [string]$event.agent_type
if ([string]::IsNullOrWhiteSpace($agentType)) {
    Deny-ToolCall 'Kimi read-only guard could not identify the active agent. The tool call is blocked for safety.'
}

# This hook is attached only to kimi-orchestrator. Do not restrict MiniMax workers.
if ($agentType -ne 'kimi-orchestrator') {
    exit 0
}

$toolName = [string]$event.tool_name

# Kimi may inspect project files and source code directly.
if ($toolName -in @('Read', 'Grep', 'Glob')) {
    exit 0
}

# Kimi may delegate only to the two approved MiniMax worker profiles.
if ($toolName -in @('Agent', 'Task')) {
    $subagentType = [string]$event.tool_input.subagent_type
    if ($subagentType -in @('minimax-worker', 'minimax-bulk-worker')) {
        exit 0
    }

    Deny-ToolCall 'Kimi may spawn only minimax-worker or minimax-bulk-worker. Delegate implementation to one of those workers.'
}

# Default-deny every other direct tool: Bash, PowerShell, Edit, Write,
# NotebookEdit, MCP tools, web tools, skills, and any future tool names.
Deny-ToolCall "Kimi is the read-only administrator. Direct tool '$toolName' is blocked; delegate implementation, shell commands, testing, and MCP operations to MiniMax."
