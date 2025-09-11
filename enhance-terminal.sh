#!/bin/bash

# ZSH Terminal Enhancement Setup for Alpine Container
# This script sets up a powerful terminal with autosuggestions, syntax highlighting, and more

set -e

echo "🚀 Setting up Enhanced Terminal with ZSH"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Install ZSH and dependencies
print_info "Installing ZSH and dependencies..."
apk add --no-cache \
    zsh \
    git \
    curl \
    wget \
    ncurses \
    shadow

print_status "ZSH installed successfully"

echo 'export PROMPT_HOSTNAME="healthcare"' >> ~/.zshrc
echo 'export PS1="%n@${PROMPT_HOSTNAME} %~ %# "' >> ~/.zshrc

# Install Oh My Zsh
print_info "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    print_status "Oh My Zsh installed"
else
    print_warning "Oh My Zsh already installed"
fi

# Install Powerlevel10k theme (modern and fast)
print_info "Installing Powerlevel10k theme..."
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    print_status "Powerlevel10k theme installed"
else
    print_warning "Powerlevel10k already installed"
fi

# Install useful plugins
print_info "Installing ZSH plugins..."

# zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    print_status "zsh-autosuggestions installed"
fi

# zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    print_status "zsh-syntax-highlighting installed"
fi

# zsh-completions
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions" ]; then
    git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions
    print_status "zsh-completions installed"
fi

# Create custom .zshrc configuration
print_info "Creating custom .zshrc configuration..."
cat > ~/.zshrc << 'EOF'
# Healthcare Clinical Trials Platform - ZSH Configuration
# =====================================================

# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins configuration
plugins=(
    git
    docker
    docker-compose
    mvn
    python
    pip
    node
    npm
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    colored-man-pages
    command-not-found
    history-substring-search
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Healthcare Platform Environment Variables
# ========================================
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export M2_HOME=/usr/share/maven
export HEALTHCARE_WORKSPACE=~/workspace/healthcare-platform
export PYTHONPATH=$PYTHONPATH:~/workspace/healthcare-platform

# IBM MQ Configuration
export MQ_QMGR_NAME=CLINICAL_QM
export MQ_HOST=localhost
export MQ_PORT=1414
export MQ_APP_USER=clinical_app
export MQ_APP_PASSWORD=clinical123

# Path configuration
export PATH=$JAVA_HOME/bin:$M2_HOME/bin:$PATH

# Healthcare Platform Aliases
# ===========================

# Navigation
alias hc='cd ~/workspace/healthcare-platform'
alias hclogs='cd ~/workspace/logs'
alias hcdata='cd ~/workspace/data'

# Development shortcuts
alias ll='ls -la --color=auto'
alias la='ls -la --color=auto'
alias l='ls -l --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Python aliases
alias python='python3'
alias pip='pip3'
alias venv-activate='source .pyenv/bin/activate'

# Healthcare specific commands
alias hc-build='mvn clean package -f applications/clinical-data-gateway/pom.xml'
alias hc-run-gateway='java -jar applications/clinical-data-gateway/target/clinical-data-gateway-1.0.0.jar'
alias hc-generate-data='python operations/scripts/demo/clinical_data_generator.py'
alias hc-test-health='curl -s http://localhost:8080/api/clinical/health | jq'
alias hc-test-stats='curl -s http://localhost:8080/api/clinical/stats | jq'

# Docker aliases
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias dclogs='docker-compose logs -f'

# MQ specific aliases
alias mq-start='docker start healthcare-mq'
alias mq-stop='docker stop healthcare-mq'
alias mq-logs='docker logs -f healthcare-mq'
alias mq-console='echo "MQ Console: https://localhost:9443/ibmmq/console (admin/admin123)"'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -10'
alias gd='git diff'

# Utility aliases
alias ports='netstat -tuln'
alias mem='free -h'
alias disk='df -h'
alias processes='ps aux | grep -v grep'

# Healthcare Platform Functions
# ============================

# Activate healthcare development environment
healthcare-env() {
    echo "🏥 Activating Healthcare Clinical Trials Platform Environment"
    if [ -d "venv" ]; then
        source .pyenv/bin/activate
        echo "✅ Python virtual environment activated"
    else
        echo "⚠️  Python virtual environment not found"
    fi
    echo "📂 Current directory: $(pwd)"
    echo ""
    echo "Available commands:"
    echo "  hc-build          # Build Spring Boot gateway"
    echo "  hc-run-gateway    # Run clinical data gateway"
    echo "  hc-generate-data  # Generate clinical test data"
    echo "  hc-test-health    # Test gateway health"
    echo "  mq-start         # Start IBM MQ container"
    echo "  mq-console       # Show MQ console URL"
}

# Quick project status
healthcare-status() {
    echo "🏥 Healthcare Platform Status"
    echo "============================"
    
    # Check if in correct directory
    if [[ $(pwd) == *"healthcare-platform"* ]]; then
        echo "✅ In healthcare workspace"
    else
        echo "⚠️  Not in healthcare workspace (run 'hc' to navigate)"
    fi
    
    # Check Python virtual environment
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        echo "✅ Python virtual environment active"
    else
        echo "⚠️  Python virtual environment not active"
    fi
    
    # Check if Spring Boot app is running
    if curl -s http://localhost:8080/api/clinical/health &> /dev/null; then
        echo "✅ Clinical Data Gateway is running (port 8080)"
    else
        echo "❌ Clinical Data Gateway not running"
    fi
    
    # Check Docker
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        echo "✅ Docker is running"
        
        # Check MQ container
        if docker ps | grep healthcare-mq &> /dev/null; then
            echo "✅ IBM MQ container is running"
        else
            echo "❌ IBM MQ container not running (run 'mq-start')"
        fi
    else
        echo "❌ Docker not available"
    fi
    
    echo ""
    echo "Quick commands: healthcare-env, hc-build, mq-start"
}

# Complete healthcare demo setup
healthcare-demo() {
    echo "🚀 Setting up complete healthcare demo environment..."
    
    # Navigate to workspace
    
    # Activate Python environment
    if [ -d "venv" ]; then
        source .pyenv/bin/activate
        echo "✅ Python environment activated"
    fi
    
    # Start Docker if needed
    if ! docker info &> /dev/null; then
        echo "🐳 Starting Docker..."
        sudo service docker start
        sleep 3
    fi
    
    # Start MQ if not running
    if ! docker ps | grep healthcare-mq &> /dev/null; then
        echo "🔄 Starting IBM MQ..."
        mq-start
        sleep 10
    fi
    
    echo ""
    echo "🎯 Demo environment ready!"
    echo "Next steps:"
    echo "  1. hc-build                    # Build Spring Boot app"
    echo "  2. hc-run-gateway             # Start gateway (new terminal)"
    echo "  3. hc-generate-data --count 5 # Generate test data"
}

# Show healthcare platform help
healthcare-help() {
    echo "🏥 Healthcare Clinical Trials Platform - Command Reference"
    echo "=========================================================="
    echo ""
    echo "🔧 Environment Commands:"
    echo "  healthcare-env      # Activate development environment"
    echo "  healthcare-status   # Show current system status"
    echo "  healthcare-demo     # Setup complete demo environment"
    echo "  healthcare-help     # Show this help"
    echo ""
    echo "📂 Navigation:"
    echo "  hc                  # Go to healthcare workspace"
    echo "  hclogs              # Go to logs directory"
    echo "  hcdata              # Go to data directory"
    echo ""
    echo "🏗️  Build & Run:"
    echo "  hc-build            # Build Spring Boot gateway"
    echo "  hc-run-gateway      # Run clinical data gateway"
    echo "  hc-generate-data    # Generate clinical test data"
    echo ""
    echo "🧪 Testing:"
    echo "  hc-test-health      # Test gateway health endpoint"
    echo "  hc-test-stats       # Show gateway statistics"
    echo ""
    echo "🐳 Docker & MQ:"
    echo "  mq-start            # Start IBM MQ container"
    echo "  mq-stop             # Stop IBM MQ container"
    echo "  mq-logs             # View MQ logs"
    echo "  mq-console          # Show MQ web console URL"
    echo ""
    echo "📋 General:"
    echo "  dps                 # Docker process status"
    echo "  gs                  # Git status"
    echo "  ll                  # List files (detailed)"
}

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY

# Autosuggestion configuration
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#626262"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Completion configuration
autoload -U compinit
compinit

# Key bindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Welcome message
echo ""
echo "🏥 Healthcare Clinical Trials Platform Terminal Ready!"
echo "Type 'healthcare-help' for available commands"
echo "Type 'healthcare-env' to activate the development environment"
echo ""

# Load Powerlevel10k configuration (if exists)
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

print_status ".zshrc configuration created"

# Create Powerlevel10k configuration
print_info "Creating Powerlevel10k configuration..."
cat > ~/.p10k.zsh << 'EOF'
# Powerlevel10k Configuration for Healthcare Platform
# Generated by `p10k configure` or manually created

# Temporarily change options
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Unset all configuration options
  unset POWERLEVEL9K_*

  # Left prompt elements
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon                 # OS identifier
    dir                     # Current directory
    vcs                     # Git status
    prompt_char             # Prompt character
  )

  # Right prompt elements
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                  # Exit code of last command
    command_execution_time  # Duration of last command
    background_jobs         # Background jobs indicator
    virtualenv              # Python virtual environment
    context                 # User@hostname
    time                    # Current time
  )

  # Basic styling
  typeset -g POWERLEVEL9K_MODE=unicode
  typeset -g POWERLEVEL9K_ICON_PADDING=moderate

  # Prompt colors
  typeset -g POWERLEVEL9K_BACKGROUND=234
  typeset -g POWERLEVEL9K_FOREGROUND=248

  # Directory configuration
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=24
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=254
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=…

  # Git configuration
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=2
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=3
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=1
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=0

  # Virtual environment
  typeset -g POWERLEVEL9K_VIRTUALENV_BACKGROUND=6
  typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND=0
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=true

  # Prompt character
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS}_FOREGROUND=2
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS}_FOREGROUND=1

  # Time format
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
  typeset -g POWERLEVEL9K_TIME_BACKGROUND=8
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=15

  # Execution time
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=1
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND=8
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=0

  # Context (user@host)
  typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_BACKGROUND=8
  typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_FOREGROUND=15

  # Status
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=1
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=15

  # OS icon
  typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND=4
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=15

  # Instant prompt mode
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  # Multiline prompt
  typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=false
  typeset -g POWERLEVEL9K_RPROMPT_ON_NEWLINE=false

  # Show current time in right prompt
  typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=true
}

# Restore previous options
(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
EOF

print_status "Powerlevel10k configuration created"

# Make ZSH the default shell
print_info "Setting ZSH as default shell..."
if [ "$SHELL" != "$(which zsh)" ]; then
    # Add zsh to valid shells if not already there
    if ! grep -q "$(which zsh)" /etc/shells; then
        echo "$(which zsh)" >> /etc/shells
    fi
    
    # Change default shell
    chsh -s "$(which zsh)"
    print_status "ZSH set as default shell"
else
    print_warning "ZSH is already the default shell"
fi

# Create a terminal welcome script
print_info "Creating terminal welcome script..."
cat > ~/healthcare-terminal-welcome.sh << 'EOF'
#!/bin/zsh

echo ""
echo "🏥 Healthcare Clinical Trials Platform"
echo "====================================="
echo ""
echo "Terminal Features:"
echo "  ✅ ZSH with Oh My Zsh"
echo "  ✅ Powerlevel10k theme"
echo "  ✅ Auto-suggestions (type and see suggestions)"
echo "  ✅ Syntax highlighting"
echo "  ✅ Git integration"
echo "  ✅ Docker integration"
echo "  ✅ Healthcare-specific aliases and functions"
echo ""
echo "Quick Start:"
echo "  healthcare-help    # Show all available commands"
echo "  healthcare-env     # Activate development environment"
echo "  healthcare-demo    # Setup complete demo"
echo ""
echo "Tips:"
echo "  • Use TAB for autocompletion"
echo "  • Use arrow keys to navigate command history"
echo "  • Use Ctrl+R for reverse search"
echo "  • Type partial command and use arrow keys for suggestions"
echo ""
EOF

chmod +x ~/healthcare-terminal-welcome.sh

print_status "Terminal welcome script created"


# # 1. Install zsh
# apk add zsh git curl

# # 2. Install oh-my-zsh
# sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# # 3. Clone autosuggestions
# git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# # 4. Clone syntax highlighting  
# git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# # 5. Update plugins in .zshrc
# sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc


echo ""
echo "🎉 ZSH Terminal Enhancement Complete!"
echo "====================================="
echo ""
echo "✅ Installed:"
echo "  • ZSH shell"
echo "  • Oh My Zsh framework"
echo "  • Powerlevel10k theme"
echo "  • Auto-suggestions plugin"
echo "  • Syntax highlighting plugin"
echo "  • Command completions"
echo "  • Healthcare-specific aliases and functions"
echo ""
echo "🚀 Next Steps:"
echo "  1. Start a new shell session: exec zsh"
echo "  2. Run: healthcare-help"
echo "  3. Run: healthcare-env"
echo ""
echo "💡 Pro Tips:"
echo "  • Type any command and see auto-suggestions"
echo "  • Use TAB for smart completions"
echo "  • All healthcare commands start with 'hc-' or 'healthcare-'"
echo "  • Use 'healthcare-status' to check system status"
echo ""
print_status "Enhanced terminal ready!"

chmod +x setup-clipboard.sh
./setup-clipboard.sh

