#!/bin/bash

# Complete Development Environment Setup Script
# Supports: Raspberry Pi 5 and Ubuntu/Debian-based distros
# Author: Development Setup Assistant
# Version: 2.0 - Resilient Edition

# Remove set -e to continue on errors
# set -e  # Commented out - we handle errors manually now

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Success/Failure tracking
declare -a SUCCESSES=()
declare -a FAILURES=()
declare -a WARNINGS=()

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    FAILURES+=("$1")
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    WARNINGS+=("$1")
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    SUCCESSES+=("$1")
}

# Function to run command with error handling
run_with_error_handling() {
    local description="$1"
    shift
    local command="$@"
    
    log "Attempting: $description"
    if eval "$command" >/dev/null 2>&1; then
        success "$description"
        return 0
    else
        error "$description failed"
        return 1
    fi
}

# Function to install packages with fallback
install_packages() {
    local description="$1"
    shift
    local packages=("$@")
    local successful_packages=()
    local failed_packages=()
    
    log "Installing: $description"
    
    for package in "${packages[@]}"; do
        if sudo apt install -y "$package" >/dev/null 2>&1; then
            successful_packages+=("$package")
        else
            failed_packages+=("$package")
        fi
    done
    
    if [ ${#successful_packages[@]} -gt 0 ]; then
        success "$description - Installed: ${successful_packages[*]}"
    fi
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        warning "$description - Failed: ${failed_packages[*]}"
    fi
    
    return 0
}

# Check if running as root
if [ $EUID -eq 0 ]; then
   error "This script should not be run as root. Please run as a regular user."
   exit 1
fi

# Device selection
echo -e "${BLUE}=== Development Environment Setup ===${NC}"
echo "Please select your device:"
echo "1. Raspberry Pi 5"
echo "2. Ubuntu/Debian"
echo -n "Enter your choice (1 or 2): "
read -r DEVICE_CHOICE

case $DEVICE_CHOICE in
    1)
        DEVICE="rpi5"
        log "Selected: Raspberry Pi 5"
        ;;
    2)
        DEVICE="ubuntu"
        log "Selected: Ubuntu/Debian"
        ;;
    *)
        error "Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac

# Detect architecture and OS info
ARCH=$(uname -m)
case $ARCH in
    x86_64) NODE_ARCH="x64" ;;
    armv7l) NODE_ARCH="armv7l" ;;
    aarch64|arm64) NODE_ARCH="arm64" ;;
    *) 
        warning "Unknown architecture: $ARCH. Defaulting to x64"
        NODE_ARCH="x64"
        ;;
esac

# Detect OS for Python installation strategy
OS_ID=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')

log "Detected: OS=$OS_ID, Version=$OS_VERSION, Architecture=$ARCH (Node.js: $NODE_ARCH)"

# Update system
log "Updating system packages..."
if sudo apt update && sudo apt upgrade -y; then
    success "System packages updated"
else
    error "System update failed, but continuing..."
fi

# Install essential packages (split into smaller groups for better error handling)
log "Installing essential packages..."

# Core tools
install_packages "Core development tools" \
    curl wget git build-essential software-properties-common \
    apt-transport-https ca-certificates gnupg lsb-release

# System utilities
install_packages "System utilities" \
    tree htop tmux vim nano zip unzip p7zip-full \
    net-tools sqlite3 jq

# Optional tools (these might not be available on all systems)
install_packages "Optional utilities" \
    fd-find ripgrep bat exa fzf ranger ncdu tldr nmap neofetch

# Python installation with version fallback
log "Installing Python..."
PYTHON_VERSION=""

# Try Python 3.10 first
if [ "$OS_ID" = "ubuntu" ] && [ "$DEVICE" = "ubuntu" ]; then
    # Try adding deadsnakes PPA for Ubuntu
    if sudo add-apt-repository ppa:deadsnakes/ppa -y && sudo apt update; then
        install_packages "Python 3.10 (via PPA)" python3.10 python3.10-dev python3.10-venv python3.10-distutils
        if command -v python3.10 >/dev/null 2>&1; then
            PYTHON_VERSION="3.10"
            success "Python 3.10 installed via PPA"
        fi
    fi
fi

# Fallback to system Python
if [ -z "$PYTHON_VERSION" ]; then
    install_packages "System Python" python3 python3-dev python3-venv python3-pip python3-distutils
    
    # Detect installed Python version
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        success "System Python $PYTHON_VERSION installed"
    else
        error "No Python installation succeeded"
    fi
fi

# Set up Python alternatives if we have a specific version
if [ -n "$PYTHON_VERSION" ] && [ "$PYTHON_VERSION" != "3" ]; then
    run_with_error_handling "Setting Python alternatives" \
        "sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python$PYTHON_VERSION 1 && \
         sudo update-alternatives --install /usr/bin/python python /usr/bin/python$PYTHON_VERSION 1"
fi

# Install/upgrade pip
log "Setting up pip..."
if command -v python3 >/dev/null 2>&1; then
    if curl -sS https://bootstrap.pypa.io/get-pip.py | python3; then
        success "pip installed/upgraded"
    else
        warning "pip installation via get-pip.py failed, trying apt"
        install_packages "pip via apt" python3-pip
    fi
else
    error "Cannot install pip - no Python found"
fi

# Raspberry Pi specific packages
if [ "$DEVICE" = "rpi5" ]; then
    log "Installing Raspberry Pi specific packages..."
    install_packages "Raspberry Pi GPIO tools" \
        rpi.gpio-common i2c-tools spi-tools wiringpi
    
    install_packages "Raspberry Pi Python libraries" \
        python3-rpi.gpio python3-gpiozero
    
    install_packages "Raspberry Pi camera support" \
        libcamera-apps
    
    # Enable I2C and SPI (ignore failures)
    if command -v raspi-config >/dev/null 2>&1; then
        run_with_error_handling "Enabling I2C interface" "sudo raspi-config nonint do_i2c 0"
        run_with_error_handling "Enabling SPI interface" "sudo raspi-config nonint do_spi 0"
    else
        warning "raspi-config not found - cannot enable I2C/SPI"
    fi
fi

# Install Node.js
log "Installing Node.js..."
NODE_VERSION="20.15.1"
NODE_PACKAGE="node-v${NODE_VERSION}-linux-${NODE_ARCH}"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_PACKAGE}.tar.xz"

cd /tmp || exit 1
if wget "$NODE_URL" && tar -xf "${NODE_PACKAGE}.tar.xz"; then
    if sudo mv "${NODE_PACKAGE}" /opt/nodejs 2>/dev/null || sudo rm -rf /opt/nodejs && sudo mv "${NODE_PACKAGE}" /opt/nodejs; then
        sudo ln -sf /opt/nodejs/bin/node /usr/local/bin/node
        sudo ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm
        sudo ln -sf /opt/nodejs/bin/npx /usr/local/bin/npx
        success "Node.js $NODE_VERSION installed"
        
        # Install global npm packages
        log "Installing global npm packages..."
        npm install -g nodemon pm2 typescript ts-node eslint prettier >/dev/null 2>&1 && \
        success "Core npm packages installed" || warning "Some npm packages failed to install"
        
        npm install -g create-react-app @vue/cli @angular/cli express-generator >/dev/null 2>&1 && \
        success "Framework npm packages installed" || warning "Some framework packages failed to install"
    else
        error "Failed to move Node.js to /opt/"
    fi
else
    error "Failed to download/extract Node.js"
fi

# Install Docker
log "Installing Docker..."
if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
    
    # Determine the correct repository
    if [ "$DEVICE" = "rpi5" ]; then
        DOCKER_REPO="deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    else
        DOCKER_REPO="deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    fi
    
    echo "$DOCKER_REPO" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    if sudo apt update; then
        install_packages "Docker" docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Add user to docker group
        if sudo usermod -aG docker $USER; then
            success "User added to docker group"
        else
            warning "Failed to add user to docker group"
        fi
        
        # Install Docker Compose standalone
        DOCKER_COMPOSE_VERSION="2.20.2"
        COMPOSE_URL="https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
        if sudo curl -L "$COMPOSE_URL" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose; then
            success "Docker Compose installed"
        else
            warning "Docker Compose installation failed"
        fi
    else
        error "Failed to update apt after adding Docker repository"
    fi
else
    error "Failed to add Docker GPG key"
fi

# Install VSCode
log "Installing Visual Studio Code..."
if wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg; then
    if sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/ && \
       sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'; then
        
        if sudo apt update; then
            install_packages "Visual Studio Code" code
        else
            warning "Failed to update apt after adding VSCode repository"
        fi
    else
        error "Failed to add VSCode repository"
    fi
else
    error "Failed to download VSCode GPG key"
fi

# Install Zsh and Oh My Zsh
log "Installing Zsh..."
install_packages "Zsh shell" zsh

if command -v zsh >/dev/null 2>&1; then
    log "Installing Oh My Zsh..."
    export RUNZSH=no
    export CHSH=no
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >/dev/null 2>&1; then
        success "Oh My Zsh installed"
        
        # Install Zsh plugins
        ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
        
        log "Installing Zsh plugins..."
        
        # zsh-autosuggestions
        if git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions >/dev/null 2>&1; then
            success "zsh-autosuggestions plugin installed"
        else
            warning "Failed to install zsh-autosuggestions"
        fi
        
        # zsh-syntax-highlighting
        if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting >/dev/null 2>&1; then
            success "zsh-syntax-highlighting plugin installed"
        else
            warning "Failed to install zsh-syntax-highlighting"
        fi
        
        # zsh-completions
        if git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions >/dev/null 2>&1; then
            success "zsh-completions plugin installed"
        else
            warning "Failed to install zsh-completions"
        fi
        
        # Powerlevel10k theme
        if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k >/dev/null 2>&1; then
            success "Powerlevel10k theme installed"
        else
            warning "Failed to install Powerlevel10k theme"
        fi
        
    else
        error "Oh My Zsh installation failed"
    fi
else
    error "Zsh not found, skipping Oh My Zsh installation"
fi

# Configure .zshrc (only if Oh My Zsh was installed)
if [ -d "$HOME/.oh-my-zsh" ]; then
    log "Configuring Zsh..."
    cat > "$HOME/.zshrc" << 'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    docker
    docker-compose
    node
    npm
    python
    pip
    tmux
    vscode
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export PATH="$HOME/.local/bin:$PATH"
export PATH="/usr/local/bin:$PATH"

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias h='history'
alias c='clear'
alias python='python3'
alias pip='pip3'

# Docker aliases
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dc='docker-compose'
alias dcu='docker-compose up'
alias dcd='docker-compose down'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# Python virtual environment
alias venv='python -m venv'
alias activate='source venv/bin/activate'

# Node.js aliases
alias ns='npm start'
alias ni='npm install'
alias nt='npm test'
alias nb='npm run build'

# System aliases
alias update='sudo apt update && sudo apt upgrade'
alias install='sudo apt install'
alias search='apt search'
alias sysinfo='neofetch'

# Enable autocompletion
autoload -U compinit && compinit
EOF
    success "Zsh configuration created"
else
    warning "Oh My Zsh not installed, skipping .zshrc configuration"
fi

# Configure tmux
log "Configuring tmux..."
if command -v tmux >/dev/null 2>&1; then
    cat > "$HOME/.tmux.conf" << 'EOF'
# Enable mouse mode
set -g mouse on

# Set default terminal mode to 256color mode
set -g default-terminal "screen-256color"

# Enable activity alerts
setw -g monitor-activity on
set -g visual-activity on

# Center the window list
set -g status-justify centre

# Increase scrollback lines
set -g history-limit 10000

# No delay for escape key press
set -sg escape-time 0

# Reload tmux config
bind r source-file ~/.tmux.conf

# Better window splitting
bind | split-window -h
bind - split-window -v
EOF
    success "Tmux configuration created"
else
    warning "Tmux not installed, skipping configuration"
fi

# Configure Git (basic setup)
if command -v git >/dev/null 2>&1; then
    run_with_error_handling "Git configuration" \
        "git config --global init.defaultBranch main && git config --global core.editor nano"
else
    warning "Git not found, skipping configuration"
fi

# Install Python packages
if command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; then
    log "Installing common Python packages..."
    PIP_CMD="pip3"
    if ! command -v pip3 >/dev/null 2>&1; then
        PIP_CMD="pip"
    fi
    
    # Install packages one by one to handle failures gracefully
    python_packages=(
        "requests"
        "numpy"
        "pandas"
        "matplotlib"
        "seaborn"
        "jupyter"
        "notebook"
        "flask"
        "django"
        "fastapi"
        "uvicorn"
        "pytest"
        "black"
        "flake8"
        "autopep8"
    )
    
    successful_py_packages=()
    failed_py_packages=()
    
    for pkg in "${python_packages[@]}"; do
        if $PIP_CMD install --user "$pkg" >/dev/null 2>&1; then
            successful_py_packages+=("$pkg")
        else
            failed_py_packages+=("$pkg")
        fi
    done
    
    if [ ${#successful_py_packages[@]} -gt 0 ]; then
        success "Python packages installed: ${successful_py_packages[*]}"
    fi
    
    if [ ${#failed_py_packages[@]} -gt 0 ]; then
        warning "Python packages failed: ${failed_py_packages[*]}"
    fi
else
    warning "No pip found, skipping Python package installation"
fi

# Generate SSH key if it doesn't exist
log "Setting up SSH key..."
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    if ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""; then
        success "SSH key generated at ~/.ssh/id_rsa.pub"
    else
        error "SSH key generation failed"
    fi
else
    success "SSH key already exists"
fi

# Configure firewall
log "Configuring firewall..."
if command -v ufw >/dev/null 2>&1; then
    sudo ufw --force enable >/dev/null 2>&1
    sudo ufw default deny incoming >/dev/null 2>&1
    sudo ufw default allow outgoing >/dev/null 2>&1
    sudo ufw allow ssh >/dev/null 2>&1
    sudo ufw allow 3000 >/dev/null 2>&1  # Common dev port
    sudo ufw allow 5000 >/dev/null 2>&1  # Flask default
    sudo ufw allow 8000 >/dev/null 2>&1  # Django/FastAPI default
    success "Firewall configured"
else
    warning "UFW not available, skipping firewall configuration"
fi

# Install database tools
install_packages "Database clients" postgresql-client mysql-client redis-tools

# Create common development directories
log "Creating development directories..."
if mkdir -p "$HOME/Projects" "$HOME/Scripts" "$HOME/.local/bin"; then
    success "Development directories created"
else
    warning "Failed to create some development directories"
fi

# Create a development environment activation script
log "Creating development environment script..."
cat > "$HOME/.local/bin/devenv" << 'EOF'
#!/bin/bash
echo "=== Development Environment Info ==="
command -v node >/dev/null && echo "Node.js: $(node --version)" || echo "Node.js: Not installed"
command -v npm >/dev/null && echo "npm: $(npm --version)" || echo "npm: Not installed"
command -v python >/dev/null && echo "Python: $(python --version 2>&1)" || echo "Python: Not installed"
command -v pip >/dev/null && echo "pip: $(pip --version 2>&1 | cut -d' ' -f1-2)" || echo "pip: Not installed"
command -v git >/dev/null && echo "Git: $(git --version)" || echo "Git: Not installed"
command -v docker >/dev/null && echo "Docker: $(docker --version)" || echo "Docker: Not installed"
command -v docker-compose >/dev/null && echo "Docker Compose: $(docker-compose --version)" || echo "Docker Compose: Not installed"
command -v code >/dev/null && echo "VSCode: $(code --version 2>/dev/null | head -1)" || echo "VSCode: Not installed"
command -v zsh >/dev/null && echo "Zsh: $(zsh --version 2>&1)" || echo "Zsh: Not installed"
echo ""
echo "Useful aliases:"
echo "  gs, ga, gc, gp - Git shortcuts"
echo "  dps, dpa, dc - Docker shortcuts"
echo "  ll, la - List files"
echo "  venv, activate - Python virtual environment"
echo ""
echo "Development directories:"
echo "  ~/Projects - Your projects"
echo "  ~/Scripts - Your scripts"
echo ""
if [ -f ~/.ssh/id_rsa.pub ]; then
    echo "Your SSH public key:"
    cat ~/.ssh/id_rsa.pub
fi
EOF

chmod +x "$HOME/.local/bin/devenv" && success "devenv script created" || warning "Failed to create devenv script"

# Change default shell to zsh
if command -v zsh >/dev/null 2>&1; then
    run_with_error_handling "Setting Zsh as default shell" "sudo chsh -s $(which zsh) $USER"
else
    warning "Zsh not found, keeping current shell"
fi

# Final cleanup
log "Cleaning up..."
sudo apt autoremove -y >/dev/null 2>&1 && sudo apt autoclean >/dev/null 2>&1
success "System cleanup completed"

# Create a detailed summary file
cat > "$HOME/installation_summary.txt" << EOF
=== Development Environment Installation Summary ===
Date: $(date)
Device: $DEVICE
OS: $OS_ID $OS_VERSION
Architecture: $ARCH

=== SUCCESSFUL INSTALLATIONS (${#SUCCESSES[@]}) ===
EOF

for success_item in "${SUCCESSES[@]}"; do
    echo "✅ $success_item" >> "$HOME/installation_summary.txt"
done

if [ ${#WARNINGS[@]} -gt 0 ]; then
    cat >> "$HOME/installation_summary.txt" << EOF

=== WARNINGS (${#WARNINGS[@]}) ===
EOF
    for warning_item in "${WARNINGS[@]}"; do
        echo "⚠️  $warning_item" >> "$HOME/installation_summary.txt"
    done
fi

if [ ${#FAILURES[@]} -gt 0 ]; then
    cat >> "$HOME/installation_summary.txt" << EOF

=== FAILURES (${#FAILURES[@]}) ===
EOF
    for failure_item in "${FAILURES[@]}"; do
        echo "❌ $failure_item" >> "$HOME/installation_summary.txt"
    done
fi

cat >> "$HOME/installation_summary.txt" << EOF

=== ENVIRONMENT STATUS ===
Node.js: $(command -v node >/dev/null && node --version || echo "Not installed")
npm: $(command -v npm >/dev/null && npm --version || echo "Not installed")
Python: $(command -v python >/dev/null && python --version 2>&1 || echo "Not installed")
pip: $(command -v pip >/dev/null && pip --version 2>&1 | cut -d' ' -f1-2 || echo "Not installed")
Git: $(command -v git >/dev/null && git --version || echo "Not installed")
Docker: $(command -v docker >/dev/null && docker --version || echo "Not installed")
VSCode: $(command -v code >/dev/null && echo "Installed" || echo "Not installed")
Zsh: $(command -v zsh >/dev/null && zsh --version 2>&1 || echo "Not installed")

=== CONFIGURATION FILES ===
- ~/.zshrc (Zsh configuration)
- ~/.tmux.conf (Tmux configuration)
- ~/.ssh/id_rsa (SSH key pair)

=== DEVELOPMENT DIRECTORIES ===
- ~/Projects (for your projects)
- ~/Scripts (for your scripts)

=== NEXT STEPS ===
1. Reboot or log out and back in for group changes to take effect
2. Run 'devenv' to see your environment info
3. Configure Git with your name and email:
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
4. Add your SSH key to GitHub/GitLab if needed

=== TROUBLESHOOTING ===
- If Docker doesn't work: log out and back in, or run 'newgrp docker'
- If Zsh isn't default: run 'chsh -s \$(which zsh)'
- Check this file for what succeeded/failed: ~/installation_summary.txt
EOF

# Final status report
echo ""
echo -e "${BLUE}=== INSTALLATION COMPLETE ===${NC}"
echo ""

# Summary statistics
total_tasks=$((${#SUCCESSES[@]} + ${#FAILURES[@]} + ${#WARNINGS[@]}))
success_rate=$(( ${#SUCCESSES[@]} * 100 / total_tasks ))

echo -e "${GREEN}✅ Successes: ${#SUCCESSES[@]}${NC}"
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warnings: ${#WARNINGS[@]}${NC}"
fi
if [ ${#FAILURES[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failures: ${#FAILURES[@]}${NC}"
fi
echo -e "${BLUE}📊 Success Rate: ${success_rate}%${NC}"

echo ""
echo -e "${BLUE}Key Software Status:${NC}"
command -v node >/dev/null && echo -e "${GREEN}✅ Node.js: $(node --version)${NC}" || echo -e "${RED}❌ Node.js: Not available${NC}"
command -v python >/dev/null && echo -e "${GREEN}✅ Python: $(python --version 2>&1)${NC}" || echo -e "${RED}❌ Python: Not available${NC}"
command -v git >/dev/null && echo -e "${GREEN}✅ Git: Available${NC}" || echo -e "${RED}❌ Git: Not available${NC}"
command -v docker >/dev/null && echo -e "${GREEN}✅ Docker: Available${NC}" || echo -e "${RED}❌ Docker: Not available${NC}"
command -v code >/dev/null && echo -e "${GREEN}✅ VSCode: Available${NC}" || echo -e "${RED}❌ VSCode: Not available${NC}"
command -v zsh >/dev/null && echo -e "${GREEN}✅ Zsh: Available${NC}" || echo -e "${RED}❌ Zsh: Not available${NC}"

echo ""
echo -e "${YELLOW}Important Next Steps:${NC}"
echo "1. 🔄 Reboot or log out and back in for all changes to take effect"
echo "2. 📝 Check detailed report: ~/installation_summary.txt"
echo "3. 🔧 Run 'devenv' command to see your environment info"
echo "4. 🔑 Configure Git with your credentials"

if [ -f ~/.ssh/id_rsa.pub ]; then
    echo ""
    echo -e "${BLUE}🔑 Your SSH public key (for GitHub/GitLab):${NC}"
    cat ~/.ssh/id_rsa.pub
fi

echo ""
echo -e "${GREEN}🚀 Setup completed! Check the summary above and in ~/installation_summary.txt${NC}"

if [ ${#FAILURES[@]} -gt 0 ]; then
    echo -e "${YELLOW}💡 Some components failed to install. This is normal on some systems.${NC}"
    echo -e "${YELLOW}   You can manually install failed components or run the script again.${NC}"
fi
