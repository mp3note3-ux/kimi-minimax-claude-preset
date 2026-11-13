# Kimi K3 + MiniMax M2.5 Claude Code preset

A reusable project-level Claude Code configuration for a **Kimi K3 administrator** and **MiniMax M2.5 implementation workers**.

- Kimi plans, delegates, reads code, and reviews worker reports.
- MiniMax handles implementation, shell commands, tests, and the MCP tools configured for the project/session.
- A Kimi-agent-scoped PreToolUse hook blocks all direct Kimi tools except Read, Grep, Glob, and delegation to the two named MiniMax workers.
- MiniMax agents inherit the session tool pool, including available MCP tools, and cannot spawn nested agents.
- The installer merges the preset into an existing repository without overwriting unrelated project files or settings.

## Requirements

- Claude Code CLI v2.1.242 or later recommended (for the current /tasks model display; using agent frontmatter hooks in a main session requires v2.1.116+).
- Windows PowerShell 5.1+ or PowerShell 7+ for the included installer, launcher, and read-only guard.
- A working LiteLLM/Anthropic-compatible gateway exposing model aliases kimi-k3 and minimax-m2.5.
- Configure each project's MCP servers separately. This preset never copies MCP credentials or API secrets.

## Install into an existing project

Clone this preset once:

    git clone https://github.com/mp3note3-ux/kimi-minimax-claude-preset.git "$HOME\kimi-minimax-claude-preset"

Apply it to a project:

    & "$HOME\kimi-minimax-claude-preset\Install-Preset.ps1" -ProjectPath "C:\path\to\your-project"

By default, the installer does not overwrite preset-managed files that already exist with different content. If you intentionally want to replace the managed agent files, hook, and launcher, use:

    & "$HOME\kimi-minimax-claude-preset\Install-Preset.ps1" -ProjectPath "C:\path\to\your-project" -Force

With -Force, replaced files are backed up beside the originals. Existing CLAUDE.md content and other .claude/settings.json settings are preserved. The installer adds or updates only the managed preset section and the top-level agent selection.

## Start a Kimi-led session

From the project root:

    .\Start-Kimi.ps1

The installer sets agent = kimi-orchestrator in the project's .claude/settings.json, so the Kimi agent is also the project default when you launch Claude Code normally. The launcher:
1. Changes to the project root.
2. Removes ANTHROPIC_MODEL, CLAUDE_CODE_SUBAGENT_MODEL, and CLAUDE_CODE_SUBAGENT_MODEL_FORCE only from the launcher process environment so they cannot override the intended model routing.
3. Sets a default maximum of one concurrent subagent to limit simultaneous worker activity (this is not a per-session spending limit).
4. Starts Claude Code with kimi-orchestrator and kimi-k3.

For a special CLI mode, clear the model overrides in that PowerShell window and launch Claude Code directly with the same agent selection:

    Remove-Item Env:ANTHROPIC_MODEL, Env:CLAUDE_CODE_SUBAGENT_MODEL, Env:CLAUDE_CODE_SUBAGENT_MODEL_FORCE -ErrorAction SilentlyContinue
    claude --agent kimi-orchestrator --model kimi-k3

## How the permission boundary works

The Kimi agent intentionally omits the frontmatter tools allowlist. Claude Code subagents inherit the tools available to the main conversation; using a read-only allowlist on Kimi would also deprive MiniMax of Bash, Edit, Write, and MCP tools.

Instead, the Kimi profile attaches a PreToolUse hook only to kimi-orchestrator. The hook is default-deny: it permits Kimi to use only Read, Grep, Glob, and the Agent tool when the requested subagent type is minimax-worker or minimax-bulk-worker. It also rejects a per-invocation worker model override unless it is minimax-m2.5. It blocks Kimi's direct shell, write/edit, MCP, and other tool calls. The hook is scoped to the Kimi agent; it is not installed as a session-wide settings hook, so MiniMax workers retain their own tool access.

The worker agents omit a tools allowlist so they inherit the project's available tools, including available MCP tools. They set disallowedTools: Agent to prevent nested worker spawning.

**Workspace trust is essential.** Claude Code only runs hooks in project-level agent definitions after you trust the project folder. Accept the Claude Code workspace trust prompt for the project before using the preset. If the project hooks are not trusted or do not load, do not use the Kimi session for work: its hook is the software enforcement boundary.

## Verify after installation

From the project root:

    claude plugin validate .claude/agents

Then start with .\Start-Kimi.ps1 and test both sides:

1. Run /status and confirm kimi-orchestrator is the active main agent.
2. Ask Kimi to read README.md and report its first heading. This should work.
3. Ask Kimi to run git status --short itself. The PreToolUse hook should block the direct shell tool call.
4. Ask Kimi to delegate git status --short to minimax-worker. The worker should be able to use Bash and report the output.
5. Run /tasks and confirm the child task shows minimax-m2.5.
6. If the worker needs MCP, use /mcp to confirm the project MCP server is connected, then ask MiniMax to perform a safe read-only MCP diagnostic.

If an MCP tool is missing from the worker, check that the server is connected and exposed to the session. This preset does not guess or hard-code MCP server names.

## What this preset does not do

- It does not set an AWS or LiteLLM dollar budget. Configure budget enforcement at the gateway separately.
- It does not create LiteLLM model aliases or install API credentials.
- It does not guarantee savings by itself. Kimi still uses tokens for planning, delegation, and reviewing reports.
- The Kimi restriction is enforced by Claude Code's PreToolUse hook, not by a model instruction alone. Project-level hooks require workspace trust and should be reviewed like any executable script.

## Updating the preset

Pull the latest preset repository, then rerun Install-Preset.ps1 -ProjectPath ... -Force in the preset clone. Backups are created for files that would be replaced.

## License

MIT. See LICENSE.
