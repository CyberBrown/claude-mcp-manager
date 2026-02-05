Testing! 

# Spark Environment (DGX Spark GB10)

## Hardware
- NVIDIA Grace Blackwell GPU with 128GB unified VRAM
- ARM Grace CPU
- Running CUDA 13
- Hostname: prometheus

## Authentication
- CLOUDFLARE_API_TOKEN: ~/.bashrc
- GitHub PAT (CyberBrown): Configured in git credential store
- GitHub SSH key:
- Gemini OAuth: ~/.gemini/oauth_creds.json
- Nexus MCP Passphrase: stale-coffee-44

## Services Running (Docker)
- claude-runner: localhost:8789 → claude-runner.shiftaltcreate.com
- gemini-runner: localhost:8790 → gemini.spark.shiftaltcreate.com
- reauth-ui: localhost:8791 → reauth.shiftaltcreate.com
- open-webui: localhost:3000
- Nemotron/vLLM: localhost:8000 → vllm.shiftaltcreate.com

## Cloudflare Tunnels
- vllm.shiftaltcreate.com → Nemotron API
- claude-runner.shiftaltcreate.com → Claude Code runner
- gemini.spark.shiftaltcreate.com → Gemini runner
- reauth.shiftaltcreate.com → OAuth refresh UI

## Deployments
- Use `bunx wrangler deploy` (no browser OAuth)
- Projects in ~/projects/

## ERPNext Access
- Use solampio-migration worker API for all ERPNext operations
- API URL: https://solampio-migration.solamp.workers.dev
- Endpoints: /api/erpnext/items, /api/erpnext/custom-fields, etc.
- Worker has credentials configured - no local .dev.vars needed

## No Browser
- Cannot do OAuth flows requiring browser
- Use API tokens, PATs, or tunneled auth UIs instead

