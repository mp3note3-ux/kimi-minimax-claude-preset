# Kimi K3 + MiniMax M2.5 Claude Code preset

A reusable, project-level Claude Code setup for a **Kimi K3 administrator** and **MiniMax M2.5 implementation workers**.

- Kimi plans, delegates, reads code, and reviews worker reports.
- MiniMax handles implementation, shell commands, tests, and connected MCP tools.
- Kimi's native agent tool allowlist excludes direct file writes, shell commands, and MCP tools.
- The included PowerShell installer merges the preset into an existing repository without replacing unrelated project files.

## Requirements

- Claude Code CLI v2.1.242 or later (for /tasks model verification; Agent(agent_type) allowlist syntax requires v2.1.63 or later).
- Windows PowerShell 5.1+ or PowerShell 7+ for the included scripts.
- A working LiteLLM/Anthropic-compatible gateway exposing the model aliases kimi-k3 and minimax-m2.5.
- The target project must already have its own MCP servers configured if workers need them. This preset does not install or copy credentials.

## Install into an existing project

Clone this preset once:

    git clone https://github.com/mp3note3-ux/kimi-minimax-claude-preset.git "$HOME\tools\kimi-minimax-claude-preset"

Apply it to a project:

    & "$HOME\tools\kimi-minimax-claude-preset\Install-Preset.ps1" -ProjectPath "C:\path\to\your-project"

By default, the installer does not overwrite existing files with the same managed names. If you intentionally want to replace the preset-managed agent files and launcher, use:

    & "$HOME\tools\kimi-minimax-claude-preset\Install-Preset.ps1" -ProjectPath "C:\path\to\your-project" -Force

With -Force, existing managed files are backed up beside the originals before replacement. Existing project CLAUDE.md content is preserved; the preset section is added once or updated in place.

## Start a Kimi-led session

From the project root:

    .\Start-Kimi.ps1

The launcher:
1. Changes to the project root.
2. Removes ANTHROPIC_MODEL, CLAUDE_CODE_SUBAGENT_MODEL, and CLAUDE_CODE_SUBAGENT_MODEL_FORCE only from the launcher process environment so they cannot override the project's model routing.
3. Starts Claude Code with kimi-orchestrator and kimi-k3.

You can pass additional Claude Code CLI arguments to the launcher:

    .\Start-Kimi.ps1 --resume

You can also launch directly after clearing the conflicting environment variables in that PowerShell window:

    Remove-Item Env:ANTHROPIC_MODEL, Env:CLAUDE_CODE_SUBAGENT_MODEL, Env:CLAUDE_CODE_SUBAGENT_MODEL_FORCE -ErrorAction SilentlyContinue
    claude --agent kimi-orchestrator --model kimi-k3

Important: the main-agent profile is activated by Start-Kimi.ps1 (or claude --agent kimi-orchestrator --model kimi-k3). Running plain claude does not automatically select this profile.

## Routing and permissions

| Role | Model | Intended capabilities |
|---|---|---|
| Main administrator | kimi-k3 | Read/search code; spawn only the two named MiniMax workers |
| Routine worker | minimax-m2.5 | Read, edit, write, shell, tests, and available project MCP tools |
| Bulk worker | minimax-m2.5 | Multi-file implementation, batch work, shell, tests, and available project MCP tools |

Kimi's tools frontmatter is an allowlist:

    tools: Agent(minimax-worker, minimax-bulk-worker), Read, Grep, Glob

This allows Kimi to inspect code and delegate only to the named worker types. It does not grant Kimi Bash, Edit, Write, or MCP tools.

The MiniMax worker definitions intentionally do not set a restrictive tools allowlist. They inherit the tool pool configured for the project/session, including available MCP tools, and deny nested agent spawning. Configure the MCP servers in the target project or user Claude Code configuration as appropriate.

The installer does not modify .claude/settings.json with global Bash, Edit, or Write deny rules. Such session-wide permission rules would also affect MiniMax workers and defeat the intended split.

## Verify after installation

From the project root:

    claude plugin validate .claude/agents

Then start the session with .\Start-Kimi.ps1 and check:

1. Run /status and confirm the project agent is active.
2. Ask Kimi to delegate a harmless read-only task to minimax-worker.
3. Run /tasks and confirm the child task shows minimax-m2.5.
4. Ask Kimi to run git status --short directly. It should not have a Bash tool available.
5. Ask MiniMax to run the same harmless command. It should have its own Bash tool available (subject to normal Claude Code permissions).

If a worker cannot see an MCP tool, check that the MCP server is connected in /mcp and that the target project's server is available to subagents. This preset does not guess or hard-code MCP server names.

## What this preset does not do

- It does not set an AWS or LiteLLM dollar budget. Configure budget enforcement at the gateway separately.
- It does not create LiteLLM model aliases or install API credentials.
- It does not guarantee savings by itself. Kimi still uses tokens for planning, delegation, and reviewing reports.
- Tool restrictions apply to Claude Code's tool calls, not to separate programs that a process could run outside Claude Code. Keep the Kimi allowlist narrow and do not add shell or MCP tools to it.

## Updating the preset

Pull the latest preset repository, then rerun Install-Preset.ps1 -ProjectPath ... -Force in the preset clone. Backups are created for files that would be replaced.

## License

MIT. See LICENSE.
