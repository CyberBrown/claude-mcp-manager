#!/bin/bash

LIBRARY_FILE="$HOME/mcp-management/servers-library.json"
CONFIG_FILE="$HOME/.claude.json"
ENV_FILE="$HOME/mcp-management/.env"
SYNC_CONFIG="$HOME/mcp-management/sync-config"
PULL_SCRIPT="$HOME/mcp-management/secrets-pull.sh"
MACHINES_FILE="$HOME/mcp-management/.machines.json"
REPO_DIR="$HOME/mcp-management"
CLAUDE_HOME="$HOME/.claude"
CLAUDE_HOME_REPO="$REPO_DIR/claude-home"

SYNC_FILES=(
    "CLAUDE.md"
    "settings.json"
    "settings.local.json"
    "plugins/installed_plugins.json"
    "plugins/known_marketplaces.json"
)

SYNC_DIRS=(
    "commands"
    "skills"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if .env has real values (not placeholders)
env_has_real_values() {
    if [ ! -f "$ENV_FILE" ]; then
        return 1
    fi
    # Check if any line contains placeholder text
    if grep -qE "your_|YOUR_|_here|_HERE|placeholder" "$ENV_FILE" 2>/dev/null; then
        return 1
    fi
    # Check if file has at least one non-comment, non-empty line with a real value
    if grep -qE "^[A-Za-z_][A-Za-z0-9_]*=.{10,}" "$ENV_FILE" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Function to auto-pull secrets if needed
auto_pull_secrets() {
    if env_has_real_values; then
        return 0
    fi

    # Check if sync is configured
    if [ ! -f "$SYNC_CONFIG" ]; then
        # Only show message if .env doesn't exist at all (first run)
        if [ ! -f "$ENV_FILE" ]; then
            echo -e "${YELLOW}No .env file found.${NC}"
            echo ""
            echo "Option 1: Create .env manually"
            echo "  cp ~/mcp-management/.example.env ~/mcp-management/.env"
            echo "  # Then edit with your API keys"
            echo ""
            echo "Option 2: Set up Cloudflare sync (for multi-machine)"
            echo "  See: ~/mcp-management/commands.md"
            echo ""
        fi
        return 1
    fi

    # Try to pull secrets
    echo -e "${YELLOW}Attempting to pull secrets from Cloudflare...${NC}"
    if [ -x "$PULL_SCRIPT" ]; then
        "$PULL_SCRIPT" --force
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Secrets synced successfully!${NC}"
            return 0
        fi
    fi

    echo -e "${RED}Failed to pull secrets. Please check your sync-config.${NC}"
    return 1
}

# Auto-pull secrets on startup if needed
auto_pull_secrets || true

# Load environment variables from .env file
if [ -f "$ENV_FILE" ]; then
    set -a  # automatically export all variables
    source "$ENV_FILE"
    set +a
fi

# Function to get current project path
get_project_path() {
    echo "$(pwd)"
}

# Expand environment variables in a server config JSON (stdin -> stdout)
# Handles both pure "${VAR}" strings and embedded "${VAR}" within larger strings.
# Missing env vars are kept as "${VAR}" placeholder instead of becoming null.
expand_server_config() {
    jq 'walk(
        if type == "string" then
            if startswith("${") and endswith("}") then
                env[.[2:-1]] // .
            else
                gsub("\\$\\{(?<v>[A-Za-z_][A-Za-z0-9_]*)\\}"; env[.v] // ("${" + .v + "}"))
            end
        else . end
    )'
}

# Check for unexpanded ${VAR} references in a JSON string and emit warnings.
# Takes server name as $1, expanded config JSON as $2.
check_unexpanded_vars() {
    local server_name="$1"
    local config_json="$2"
    local unexpanded
    unexpanded=$(echo "$config_json" | grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' | sort -u)
    if [ -n "$unexpanded" ]; then
        for var in $unexpanded; do
            echo -e "${YELLOW}  Warning: $server_name has unresolved $var (env var not set)${NC}"
        done
    fi
}

# Function to show usage
usage() {
    echo "Usage: mcp-manager [command] [server-names...]"
    echo ""
    echo "Commands:"
    echo "  list              - Show all available servers in library"
    echo "  active            - Show currently active servers in this project"
    echo "  enable <servers>  - Enable one or more servers in this project"
    echo "  disable <servers> - Disable one or more servers in this project"
    echo "  update            - Self-update, re-install, fix all project configs"
    echo "  verify [--fix]    - Scan all projects for corrupted/drifted configs"
    echo "  machines          - Show which machines are up to date"
    echo "  reset             - Disable all servers in this project"
    echo "  sync              - Sync secrets from Cloudflare"
    echo "  push              - Push local secrets to Cloudflare"
    echo ""
    echo "Home config sync (~/.claude/):"
    echo "  home push         - Push ~/.claude/ config to repo"
    echo "  home pull         - Pull config from repo to ~/.claude/"
    echo "  home diff         - Show differences between local and repo"
    echo "  home status       - Quick sync status summary"
    echo ""
    echo "Examples:"
    echo "  mcp-manager list"
    echo "  mcp-manager active"
    echo "  mcp-manager enable vibe-check github"
    echo "  mcp-manager disable vibe-check"
    echo "  mcp-manager update"
    echo "  mcp-manager verify"
    echo "  mcp-manager verify --fix"
    echo "  mcp-manager machines"
    echo "  mcp-manager reset"
    echo "  mcp-manager sync"
    echo "  mcp-manager push"
    echo "  mcp-manager home push"
    echo "  mcp-manager home diff"
}

# Function to sync secrets from Cloudflare
sync_secrets() {
    if [ ! -f "$SYNC_CONFIG" ]; then
        echo -e "${RED}Error: Secrets sync not configured${NC}"
        echo "See: ~/mcp-management/sync-config.example"
        exit 1
    fi

    if [ -x "$PULL_SCRIPT" ]; then
        "$PULL_SCRIPT"
    else
        echo -e "${RED}Error: Pull script not found or not executable${NC}"
        exit 1
    fi
}

# Function to push secrets to Cloudflare
push_secrets() {
    PUSH_SCRIPT="$HOME/mcp-management/secrets-push.sh"

    if [ ! -f "$SYNC_CONFIG" ]; then
        echo -e "${RED}Error: Secrets sync not configured${NC}"
        echo "See: ~/mcp-management/sync-config.example"
        exit 1
    fi

    if [ -x "$PUSH_SCRIPT" ]; then
        "$PUSH_SCRIPT"
    else
        echo -e "${RED}Error: Push script not found or not executable${NC}"
        exit 1
    fi
}

# Collect syncable relative paths from a base directory
# Usage: collect_sync_paths /path/to/base
# Outputs newline-separated relative paths
collect_sync_paths() {
    local base="$1"
    for f in "${SYNC_FILES[@]}"; do
        if [ -f "$base/$f" ]; then
            echo "$f"
        fi
    done
    for d in "${SYNC_DIRS[@]}"; do
        if [ -d "$base/$d" ]; then
            for f in "$base/$d"/*.md; do
                [ -f "$f" ] && echo "$d/$(basename "$f")"
            done
        fi
    done
}

# Push ~/.claude/ config to repo
home_push() {
    local paths
    paths=$(collect_sync_paths "$CLAUDE_HOME")

    if [ -z "$paths" ]; then
        echo -e "${RED}No syncable files found in $CLAUDE_HOME${NC}"
        return 1
    fi

    echo "Collecting files from $CLAUDE_HOME..."

    # Create dirs and copy files
    local count=0
    while IFS= read -r relpath; do
        local dir
        dir=$(dirname "$relpath")
        mkdir -p "$CLAUDE_HOME_REPO/$dir"
        cp "$CLAUDE_HOME/$relpath" "$CLAUDE_HOME_REPO/$relpath"
        echo -e "  ${GREEN}$relpath${NC}"
        ((count++))
    done <<< "$paths"

    # Remove orphaned files in repo (deleted locally)
    local repo_paths
    repo_paths=$(collect_sync_paths "$CLAUDE_HOME_REPO")
    if [ -n "$repo_paths" ]; then
        while IFS= read -r relpath; do
            if [ ! -f "$CLAUDE_HOME/$relpath" ]; then
                rm -f "$CLAUDE_HOME_REPO/$relpath"
                echo -e "  ${RED}Removed orphan: $relpath${NC}"
            fi
        done <<< "$repo_paths"
    fi

    echo ""
    echo "Copied $count file(s) to claude-home/"

    # Git commit and push
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR"
        git add claude-home/
        if git diff --cached --quiet claude-home/ 2>/dev/null; then
            echo "No changes to commit"
        else
            local hostname
            hostname=$(hostname)
            git commit -m "home: push from $hostname" --quiet
            echo -e "${GREEN}Committed${NC}"
            git push --quiet 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Pushed to remote${NC}"
            else
                echo -e "${YELLOW}Could not push (push manually later)${NC}"
            fi
        fi
        cd - > /dev/null
    fi
}

# Pull config from repo to ~/.claude/
home_pull() {
    if [ ! -d "$CLAUDE_HOME_REPO" ]; then
        echo -e "${YELLOW}No claude-home/ directory in repo yet.${NC}"
        echo "Run 'mcp-manager home push' from a machine with your config first."
        return 1
    fi

    # Pull latest
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR" && git pull --quiet 2>/dev/null
        cd - > /dev/null
    fi

    local paths
    paths=$(collect_sync_paths "$CLAUDE_HOME_REPO")

    if [ -z "$paths" ]; then
        echo -e "${YELLOW}No syncable files found in claude-home/${NC}"
        return 1
    fi

    # Backup files that differ
    local backup_dir=""
    local backed_up=0
    while IFS= read -r relpath; do
        if [ -f "$CLAUDE_HOME/$relpath" ] && ! diff -q "$CLAUDE_HOME/$relpath" "$CLAUDE_HOME_REPO/$relpath" > /dev/null 2>&1; then
            if [ -z "$backup_dir" ]; then
                backup_dir="$CLAUDE_HOME/.home-backup-$(date +%Y%m%d-%H%M%S)"
                mkdir -p "$backup_dir"
            fi
            local dir
            dir=$(dirname "$relpath")
            mkdir -p "$backup_dir/$dir"
            cp "$CLAUDE_HOME/$relpath" "$backup_dir/$relpath"
            ((backed_up++))
        fi
    done <<< "$paths"

    if [ $backed_up -gt 0 ]; then
        echo -e "${YELLOW}Backed up $backed_up changed file(s) to $backup_dir${NC}"
    fi

    # Copy from repo to local
    local count=0
    while IFS= read -r relpath; do
        local dir
        dir=$(dirname "$relpath")
        mkdir -p "$CLAUDE_HOME/$dir"
        cp "$CLAUDE_HOME_REPO/$relpath" "$CLAUDE_HOME/$relpath"
        echo -e "  ${GREEN}$relpath${NC}"
        ((count++))
    done <<< "$paths"

    echo ""
    echo "Pulled $count file(s) to $CLAUDE_HOME"
}

# Show diff between local and repo
home_diff() {
    local local_paths repo_paths all_paths
    local_paths=$(collect_sync_paths "$CLAUDE_HOME")
    repo_paths=$(collect_sync_paths "$CLAUDE_HOME_REPO" 2>/dev/null)
    all_paths=$(echo -e "${local_paths}\n${repo_paths}" | sort -u | grep -v '^$')

    if [ -z "$all_paths" ]; then
        echo "No syncable files found on either side"
        return
    fi

    local has_diff=false
    while IFS= read -r relpath; do
        local in_local=false in_repo=false
        [ -f "$CLAUDE_HOME/$relpath" ] && in_local=true
        [ -f "$CLAUDE_HOME_REPO/$relpath" ] && in_repo=true

        if $in_local && ! $in_repo; then
            echo -e "${GREEN}+ local only:  $relpath${NC}"
            has_diff=true
        elif ! $in_local && $in_repo; then
            echo -e "${RED}- repo only:   $relpath${NC}"
            has_diff=true
        elif ! diff -q "$CLAUDE_HOME/$relpath" "$CLAUDE_HOME_REPO/$relpath" > /dev/null 2>&1; then
            echo -e "${YELLOW}~ modified:    $relpath${NC}"
            diff -u "$CLAUDE_HOME_REPO/$relpath" "$CLAUDE_HOME/$relpath" 2>/dev/null | head -20
            echo ""
            has_diff=true
        fi
    done <<< "$all_paths"

    if ! $has_diff; then
        echo -e "${GREEN}Everything in sync${NC}"
    fi
}

# Quick status summary
home_status() {
    local local_paths repo_paths all_paths
    local_paths=$(collect_sync_paths "$CLAUDE_HOME")
    repo_paths=$(collect_sync_paths "$CLAUDE_HOME_REPO" 2>/dev/null)
    all_paths=$(echo -e "${local_paths}\n${repo_paths}" | sort -u | grep -v '^$')

    if [ -z "$all_paths" ]; then
        echo "No syncable files found"
        return
    fi

    local in_sync=0 modified=0 local_only=0 repo_only=0
    while IFS= read -r relpath; do
        local in_local=false in_repo=false
        [ -f "$CLAUDE_HOME/$relpath" ] && in_local=true
        [ -f "$CLAUDE_HOME_REPO/$relpath" ] && in_repo=true

        if $in_local && ! $in_repo; then
            ((local_only++))
        elif ! $in_local && $in_repo; then
            ((repo_only++))
        elif ! diff -q "$CLAUDE_HOME/$relpath" "$CLAUDE_HOME_REPO/$relpath" > /dev/null 2>&1; then
            ((modified++))
        else
            ((in_sync++))
        fi
    done <<< "$all_paths"

    echo "Home config status:"
    [ $in_sync -gt 0 ]    && echo -e "  ${GREEN}In sync:    $in_sync${NC}"
    [ $modified -gt 0 ]   && echo -e "  ${YELLOW}Modified:   $modified${NC}"
    [ $local_only -gt 0 ] && echo -e "  ${GREEN}Local only: $local_only${NC}"
    [ $repo_only -gt 0 ]  && echo -e "  ${RED}Repo only:  $repo_only${NC}"

    if [ $modified -eq 0 ] && [ $local_only -eq 0 ] && [ $repo_only -eq 0 ]; then
        echo -e "  ${GREEN}Everything in sync${NC}"
    fi
}

# Function to check for updates
check_for_updates() {
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR"
        # Fetch latest from remote quietly
        git fetch --quiet 2>/dev/null

        # Compare local and remote HEAD
        LOCAL=$(git rev-parse HEAD 2>/dev/null)
        REMOTE=$(git rev-parse @{u} 2>/dev/null)

        cd - > /dev/null

        if [ -n "$LOCAL" ] && [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
            return 0  # Update available
        fi
    fi
    return 1  # No update or couldn't check
}

# Function to list available servers
list_servers() {
    echo "Available MCP servers in library:"
    jq -r 'keys[]' "$LIBRARY_FILE" 2>/dev/null || echo "Error: Could not read library file"

    # Check for updates
    if check_for_updates; then
        echo ""
        echo -e "${YELLOW}Update available! Run 'mcp-manager update' to get the latest servers.${NC}"
    fi
}

# Function to show active servers
show_active() {
    PROJECT_PATH=$(get_project_path)

    if [ -f "$CONFIG_FILE" ]; then
        echo "Currently active MCP servers in $PROJECT_PATH:"
        jq -r --arg path "$PROJECT_PATH" '.projects[$path].mcpServers // {} | keys[]' "$CONFIG_FILE" 2>/dev/null || echo "None"
    else
        echo "No active servers (config file doesn't exist)"
    fi
}

# Function to enable servers
enable_servers() {
    PROJECT_PATH=$(get_project_path)

    # Create config file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{"projects":{}}' > "$CONFIG_FILE"
    fi

    # Read current config
    CURRENT_CONFIG=$(cat "$CONFIG_FILE")

    # Initialize project if it doesn't exist
    CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" '
        if .projects[$path] then .
        else .projects[$path] = {
            "allowedTools": [],
            "history": [],
            "mcpContextUris": [],
            "mcpServers": {},
            "enabledMcpjsonServers": [],
            "disabledMcpjsonServers": [],
            "hasTrustDialogAccepted": false,
            "ignorePatterns": [],
            "projectOnboardingSeenCount": 0,
            "hasClaudeMdExternalIncludesApproved": false,
            "hasClaudeMdExternalIncludesWarningShown": false
        } end
    ')

    # Add each requested server
    for SERVER in "$@"; do
        # Check if server exists in library
        SERVER_CONFIG=$(jq -r --arg name "$SERVER" '.[$name] // empty' "$LIBRARY_FILE")

        if [ -z "$SERVER_CONFIG" ]; then
            echo "Warning: Server '$SERVER' not found in library, skipping..."
            continue
        fi

        # Expand environment variables in the server config
        SERVER_CONFIG_EXPANDED=$(echo "$SERVER_CONFIG" | expand_server_config)
        check_unexpanded_vars "$SERVER" "$SERVER_CONFIG_EXPANDED"

        # Add server to project config
        CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" --arg name "$SERVER" --argjson config "$SERVER_CONFIG_EXPANDED" \
            '.projects[$path].mcpServers[$name] = $config')

        echo "Enabled: $SERVER"
    done

    # Write updated config
    echo "$CURRENT_CONFIG" | jq . > "$CONFIG_FILE"
    echo ""
    echo "Done! Restart Claude Code for changes to take effect."
}

# Function to disable servers
disable_servers() {
    PROJECT_PATH=$(get_project_path)

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config file found, nothing to disable"
        return
    fi

    CURRENT_CONFIG=$(cat "$CONFIG_FILE")

    for SERVER in "$@"; do
        CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" --arg name "$SERVER" \
            'del(.projects[$path].mcpServers[$name])')
        echo "Disabled: $SERVER"
    done

    echo "$CURRENT_CONFIG" | jq . > "$CONFIG_FILE"
    echo ""
    echo "Done! Restart Claude Code for changes to take effect."
}

# Remove chezmoi if present (legacy config manager, no longer used)
remove_chezmoi() {
    local removed=0
    if [ -f "$HOME/.local/bin/chezmoi" ]; then
        rm -f "$HOME/.local/bin/chezmoi"
        ((removed++))
    fi
    if [ -d "$HOME/.local/share/chezmoi" ]; then
        rm -rf "$HOME/.local/share/chezmoi"
        ((removed++))
    fi
    if [ -d "$HOME/.config/chezmoi" ]; then
        rm -rf "$HOME/.config/chezmoi"
        ((removed++))
    fi
    if [ $removed -gt 0 ]; then
        echo -e "${GREEN}Removed chezmoi ($removed items)${NC}"
    fi
}

# Record this machine's version in .machines.json
record_machine_version() {
    local hostname
    hostname=$(hostname)
    local commit
    commit=$(cd "$REPO_DIR" && git rev-parse HEAD 2>/dev/null)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local project_count=0
    if [ -f "$CONFIG_FILE" ]; then
        project_count=$(jq '[.projects // {} | to_entries[] | select((.value.mcpServers // {} | length) > 0)] | length' "$CONFIG_FILE" 2>/dev/null || echo 0)
    fi

    # Initialize machines file if missing
    if [ ! -f "$MACHINES_FILE" ]; then
        echo '{}' > "$MACHINES_FILE"
    fi

    # Update this machine's entry
    jq --arg host "$hostname" \
       --arg commit "$commit" \
       --arg ts "$timestamp" \
       --argjson count "$project_count" \
       '.[$host] = {"commit": $commit, "updated": $ts, "projects": $count}' \
       "$MACHINES_FILE" > "$MACHINES_FILE.tmp" && mv "$MACHINES_FILE.tmp" "$MACHINES_FILE"
}

# Function to update: self-update, re-install, fix ALL project configs
update_servers() {
    # Step 1: Pull latest changes from repo
    echo "Step 1: Pulling latest server library..."
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR" && git pull --quiet
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Repository updated${NC}"
        else
            echo -e "${YELLOW}Could not pull repo (continuing with local library)${NC}"
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}No git repo found at $REPO_DIR${NC}"
    fi
    echo ""

    # Step 2: Pull home config if available
    if [ -d "$CLAUDE_HOME_REPO" ]; then
        echo "Step 2: Pulling home config..."
        home_pull
    else
        echo "Step 2: No home config in repo (skipping)"
    fi
    echo ""

    # Step 3: Re-run install.sh to update bin scripts + aliases
    echo "Step 3: Re-installing scripts and aliases..."
    if [ -x "$REPO_DIR/install.sh" ]; then
        bash "$REPO_DIR/install.sh"
    else
        echo -e "${YELLOW}install.sh not found or not executable, skipping${NC}"
    fi
    echo ""

    # Step 4: Remove chezmoi if present
    echo "Step 4: Cleaning up legacy tools..."
    remove_chezmoi
    echo ""

    # Step 5: Update ALL projects' MCP configs from library
    echo "Step 5: Updating MCP configs across all projects..."
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config file found, nothing to update"
    else
        CURRENT_CONFIG=$(cat "$CONFIG_FILE")

        # Get all project paths that have mcpServers
        ALL_PROJECTS=$(echo "$CURRENT_CONFIG" | jq -r '.projects // {} | to_entries[] | select(.value.mcpServers != null and (.value.mcpServers | length) > 0) | .key' 2>/dev/null)

        if [ -z "$ALL_PROJECTS" ]; then
            echo "No projects with active servers found"
        else
            TOTAL_UPDATED=0
            TOTAL_SKIPPED=0

            while IFS= read -r PROJECT_PATH; do
                echo ""
                echo -e "  Project: ${PROJECT_PATH}"

                ACTIVE_SERVERS=$(echo "$CURRENT_CONFIG" | jq -r --arg path "$PROJECT_PATH" '.projects[$path].mcpServers // {} | keys[]' 2>/dev/null)

                for SERVER in $ACTIVE_SERVERS; do
                    # Check if server exists in library
                    SERVER_CONFIG=$(jq -r --arg name "$SERVER" '.[$name] // empty' "$LIBRARY_FILE")

                    if [ -z "$SERVER_CONFIG" ]; then
                        echo -e "    ${YELLOW}Skipped: $SERVER (custom, not in library)${NC}"
                        ((TOTAL_SKIPPED++))
                        continue
                    fi

                    # Expand environment variables
                    SERVER_CONFIG_EXPANDED=$(echo "$SERVER_CONFIG" | expand_server_config)
                    check_unexpanded_vars "$SERVER" "$SERVER_CONFIG_EXPANDED"

                    # Update server in project config
                    CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" --arg name "$SERVER" --argjson config "$SERVER_CONFIG_EXPANDED" \
                        '.projects[$path].mcpServers[$name] = $config')

                    echo -e "    ${GREEN}Updated: $SERVER${NC}"
                    ((TOTAL_UPDATED++))
                done
            done <<< "$ALL_PROJECTS"

            # Write updated config
            echo "$CURRENT_CONFIG" | jq . > "$CONFIG_FILE"
            echo ""
            echo "Updated $TOTAL_UPDATED server(s), skipped $TOTAL_SKIPPED custom server(s)."
        fi
    fi
    echo ""

    # Step 6: Record machine version
    echo "Step 6: Recording machine version..."
    record_machine_version
    local hostname
    hostname=$(hostname)
    echo -e "${GREEN}Recorded $hostname at $(cd "$REPO_DIR" && git rev-parse --short HEAD 2>/dev/null)${NC}"

    # Step 7: Commit + push .machines.json
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR"
        if git diff --quiet "$MACHINES_FILE" 2>/dev/null && git diff --cached --quiet "$MACHINES_FILE" 2>/dev/null; then
            echo "No changes to .machines.json"
        else
            git add "$MACHINES_FILE" 2>/dev/null
            git commit -m "update $hostname machine version" --quiet 2>/dev/null
            git push --quiet 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Pushed .machines.json${NC}"
            else
                echo -e "${YELLOW}Could not push .machines.json (push manually later)${NC}"
            fi
        fi
        cd - > /dev/null
    fi

    echo ""
    echo "Update complete! Restart Claude Code for changes to take effect."
}

# Verify all project configs against the library
verify_configs() {
    local fix_mode=false
    if [ "$1" = "--fix" ]; then
        fix_mode=true
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config file found, nothing to verify"
        return
    fi

    echo "Scanning all projects in ~/.claude.json..."
    echo ""

    CURRENT_CONFIG=$(cat "$CONFIG_FILE")
    ALL_PROJECTS=$(echo "$CURRENT_CONFIG" | jq -r '.projects // {} | to_entries[] | select(.value.mcpServers != null and (.value.mcpServers | length) > 0) | .key' 2>/dev/null)

    if [ -z "$ALL_PROJECTS" ]; then
        echo "No projects with active servers found"
        return
    fi

    TOTAL_ISSUES=0
    TOTAL_FIXED=0

    while IFS= read -r PROJECT_PATH; do
        echo -e "Project: ${PROJECT_PATH}"

        ACTIVE_SERVERS=$(echo "$CURRENT_CONFIG" | jq -r --arg path "$PROJECT_PATH" '.projects[$path].mcpServers // {} | keys[]' 2>/dev/null)

        for SERVER in $ACTIVE_SERVERS; do
            ISSUES=""

            # Get current config for this server
            CURRENT_SERVER=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" --arg name "$SERVER" '.projects[$path].mcpServers[$name]')

            # Check 1: @anthropic-ai/mcp-* corruption pattern
            # This detects when Claude Code corrupts server configs with its own internal package refs
            HAS_CORRUPTION=$(echo "$CURRENT_SERVER" | jq 'if .args then (.args | map(select(type == "string" and contains("@anthropic-ai/mcp-"))) | length > 0) else false end' 2>/dev/null)
            if [ "$HAS_CORRUPTION" = "true" ]; then
                ISSUES="${ISSUES}CORRUPT(@anthropic-ai/mcp-* in args) "
            fi

            # Check 2: Null values in config
            HAS_NULLS=$(echo "$CURRENT_SERVER" | jq '[.. | select(. == null)] | length > 0' 2>/dev/null)
            if [ "$HAS_NULLS" = "true" ]; then
                ISSUES="${ISSUES}NULL_VALUES "
            fi

            # Check 3: Config drift vs library
            LIBRARY_CONFIG=$(jq -r --arg name "$SERVER" '.[$name] // empty' "$LIBRARY_FILE")

            if [ -z "$LIBRARY_CONFIG" ]; then
                # Server not in library - info only, no fix
                echo -e "  ${YELLOW}INFO: $SERVER (custom, not in library)${NC}"
                continue
            fi

            # Expand library config for comparison
            LIBRARY_EXPANDED=$(echo "$LIBRARY_CONFIG" | expand_server_config)

            # Compare key fields: args, env, url, type, command
            DRIFT=$(jq -n \
                --argjson current "$CURRENT_SERVER" \
                --argjson library "$LIBRARY_EXPANDED" \
                '
                def compare_field(f):
                    ($current[f] // null) != ($library[f] // null);
                [
                    (if compare_field("args") then "args" else empty end),
                    (if compare_field("env") then "env" else empty end),
                    (if compare_field("url") then "url" else empty end),
                    (if compare_field("type") then "type" else empty end),
                    (if compare_field("command") then "command" else empty end)
                ] | if length > 0 then join(",") else empty end
                ' 2>/dev/null)

            if [ -n "$DRIFT" ]; then
                ISSUES="${ISSUES}DRIFT($DRIFT) "
            fi

            # Report findings
            if [ -n "$ISSUES" ]; then
                ((TOTAL_ISSUES++))
                echo -e "  ${RED}$SERVER: $ISSUES${NC}"

                if $fix_mode; then
                    # Replace with correct library version
                    CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" --arg name "$SERVER" --argjson config "$LIBRARY_EXPANDED" \
                        '.projects[$path].mcpServers[$name] = $config')
                    echo -e "    ${GREEN}FIXED${NC}"
                    ((TOTAL_FIXED++))
                fi
            else
                echo -e "  ${GREEN}$SERVER: OK${NC}"
            fi
        done
        echo ""
    done <<< "$ALL_PROJECTS"

    # Write fixes if any
    if $fix_mode && [ $TOTAL_FIXED -gt 0 ]; then
        echo "$CURRENT_CONFIG" | jq . > "$CONFIG_FILE"
    fi

    echo "---"
    echo "Total issues: $TOTAL_ISSUES"
    if $fix_mode; then
        echo "Fixed: $TOTAL_FIXED"
    elif [ $TOTAL_ISSUES -gt 0 ]; then
        echo "Run 'mcp-manager verify --fix' to repair"
    fi
}

# Show machine version status
show_machines() {
    if [ ! -f "$MACHINES_FILE" ]; then
        echo "No machines tracked yet. Run 'mcp-manager update' to record this machine."
        return
    fi

    # Get repo HEAD commit
    local head_commit
    if [ -d "$REPO_DIR/.git" ]; then
        head_commit=$(cd "$REPO_DIR" && git rev-parse HEAD 2>/dev/null)
    fi

    if [ -z "$head_commit" ]; then
        echo -e "${RED}Could not determine repo HEAD commit${NC}"
        return
    fi

    local head_short
    head_short=$(cd "$REPO_DIR" && git rev-parse --short HEAD 2>/dev/null)
    echo "Repo HEAD: $head_short"
    echo ""

    # Iterate machines
    jq -r 'to_entries[] | "\(.key)\t\(.value.commit)\t\(.value.updated)\t\(.value.projects)"' "$MACHINES_FILE" 2>/dev/null | \
    while IFS=$'\t' read -r host commit updated projects; do
        local short_commit="${commit:0:7}"
        if [ "$commit" = "$head_commit" ]; then
            echo -e "  ${GREEN}$host: UP TO DATE ($short_commit, $updated, $projects projects)${NC}"
        else
            echo -e "  ${YELLOW}$host: STALE ($short_commit, $updated, $projects projects)${NC}"
        fi
    done
}

# Function to reset (disable all)
reset_servers() {
    PROJECT_PATH=$(get_project_path)

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config file found"
        return
    fi

    CURRENT_CONFIG=$(cat "$CONFIG_FILE")
    CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" \
        '.projects[$path].mcpServers = {}')

    echo "$CURRENT_CONFIG" | jq . > "$CONFIG_FILE"
    echo "All servers disabled in $PROJECT_PATH"
    echo ""
    echo "Restart Claude Code for changes to take effect."
}

# Main script logic
case "$1" in
    list)
        list_servers
        ;;
    active)
        show_active
        ;;
    enable)
        shift
        if [ $# -eq 0 ]; then
            echo "Error: Please specify at least one server to enable"
            usage
            exit 1
        fi
        enable_servers "$@"
        ;;
    disable)
        shift
        if [ $# -eq 0 ]; then
            echo "Error: Please specify at least one server to disable"
            usage
            exit 1
        fi
        disable_servers "$@"
        ;;
    update)
        update_servers
        ;;
    verify)
        shift
        verify_configs "$1"
        ;;
    machines)
        show_machines
        ;;
    reset)
        reset_servers
        ;;
    sync)
        sync_secrets
        ;;
    push)
        push_secrets
        ;;
    home)
        shift
        case "$1" in
            push)   home_push ;;
            pull)   home_pull ;;
            diff)   home_diff ;;
            status) home_status ;;
            *)
                echo "Usage: mcp-manager home [push|pull|diff|status]"
                exit 1
                ;;
        esac
        ;;
    *)
        usage
        ;;
esac
