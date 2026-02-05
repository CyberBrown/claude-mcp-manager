# Common aliases - synced via claude-mcp-manager

# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# ls improvements
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"

# Git shortcuts
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias gco="git checkout"
alias gb="git branch"
alias glog="git log --oneline --graph --decorate -20"

# Safety
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# Shortcuts
alias c="clear"
alias h="history"
alias j="jobs -l"
alias ports="netstat -tulanp"

# Development
alias py="python3"
alias pip="pip3"
alias serve="python3 -m http.server 8000"

# Cloudflare
alias wr="wrangler"
alias wrd="wrangler dev"
alias wrdl="wrangler dev --local"
alias wrp="wrangler deploy"

# Projects
alias proj="cd ~/projects"
