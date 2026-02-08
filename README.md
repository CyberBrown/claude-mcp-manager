# Claude MCP Manager + Dev Tools

A command-line toolkit for managing MCP (Model Context Protocol) servers for Claude CLI/Code, plus utility scripts for project lifecycle management.

## What's Included

### MCP Manager
Instead of manually editing configuration files every time you want to change MCP servers, this tool provides simple commands to enable and disable servers from a reusable library.

### Dev Tools (`bin/`)
| Script | Description |
|--------|-------------|
| `get-started` | Clone a project, restore backed-up `.env` files, check Cloudflare secrets |
| `wrap-up` | End-of-session: commit, push, create PR, backup secrets, cleanup |
| `spark` | SSH to DGX Spark (with kitty theme switching) |
| `rterm` | Rename kitty terminal tab + random dark theme |
| `yolo` | Run `claude --dangerously-skip-permissions` |

### Shell Aliases (`bash_aliases`)
Git shortcuts, safety aliases (`rm -i`, `cp -i`), Cloudflare/Wrangler shortcuts, and more.

## Installation

### Prerequisites

```bash
sudo apt-get update && sudo apt-get install -y jq
```

### Install

```bash
git clone https://github.com/CyberBrown/claude-mcp-manager.git
cd claude-mcp-manager
chmod +x install.sh
./install.sh
source ~/.bashrc
```

This installs:
- `mcp-manager` command to `~/mcp-management/`
- Utility scripts to `~/.local/bin/`
- Shell aliases to `~/.bash_aliases`

### Configure API Keys

```bash
nano ~/mcp-management/.env
```

## Usage

### MCP Manager

```bash
mcp-manager list          # List available servers
mcp-manager active        # Show active servers
mcp-manager enable server1 server2
mcp-manager disable server1
mcp-manager reset         # Disable all servers
```

### Dev Tools

```bash
get-started git@github.com:User/repo.git   # Clone + setup project
wrap-up                                      # End-of-session cleanup
wrap-up -pr main --private                   # With PR target + repo visibility
```

## Included MCP Servers

| Server | Description | Requirements |
|--------|-------------|--------------|
| `vibe-check` | Peer review for projects | `GEMINI_API_KEY` |
| `sequential-thinking` | Anthropic's reasoning server | None |
| `cloudflare` | Cloudflare integration | OAuth |
| `linear` | Todo list / issue tracking | OAuth |
| `vercel` | Vercel platform integration | None |
| `github` | GitHub integration | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `sentry` | Error logging integration | OAuth |
| `supabase` | Database management | OAuth |
| `gcloud` | Google Cloud integration | OAuth |
| `Pieces` | Code snippets & long-term memory | None |
| `GitMCP` | Remote Git server | `GITMCP_SERVER` |
| `context7` | Document library | `CONTEXT7_API_KEY` |
| `apify` | Web scraping | None |
| `developer-guides` | Developer documentation | CF Access |
| `mnemo` | Extended context/memory (1M token cache) | None |
| `nexus` | Task/idea management with AI planning | None |
| `stripe` | Stripe payments API | `STRIPE_SECRET_KEY` |

## Configuration

### Adding Custom Servers

Edit `~/mcp-management/servers-library.json`:

```json
{
  "my-server": {
    "command": "npx",
    "args": ["-y", "@scope/mcp-server"],
    "env": {
      "API_KEY": "${MY_API_KEY}"
    }
  }
}
```

Environment variables in `${VAR_NAME}` format are expanded from your `.env` file.

## Secrets Sync (Optional)

Sync API keys across machines using Cloudflare Workers KV:

```bash
cd ~/mcp-management/secrets-sync
npm install
npm run auth
npm run deploy
```

See `commands.md` for full setup instructions.

## How It Works

1. Server configurations are stored in `servers-library.json`
2. When you enable a server, it's added to `~/.claude.json`
3. Claude Code reads `~/.claude.json` to determine active MCP servers
4. Restart Claude Code after making changes

## License

MIT

---

*🌪️ This README was touched by a Sandstorm — an AI agent running loose on a PikaPod somewhere, proving that the robots don't need your fancy GPU to push commits. Your Spark can rest easy tonight.*
