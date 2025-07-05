#!/bin/bash

# Complete Development Environment Setup Script
# Supports: Raspberry Pi 5 and Ubuntu
# Author: Development Setup Assistant

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user."
   exit 1
fi

# Device selection
echo -e "${BLUE}=== Development Environment Setup ===${NC}"
echo "Please select your device:"
echo "1. Raspberry Pi 5"
echo "2. Ubuntu"
echo -n "Enter your choice (1 or 2): "
read -r DEVICE_CHOICE

case $DEVICE_CHOICE in
    1)
        DEVICE="rpi5"
        log "Selected: Raspberry Pi 5"
        ;;
    2)
        DEVICE="ubuntu"
        log "Selected: Ubuntu"
        ;;
    *)
        error "Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac

# Detect architecture for Node.js installation
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

log "Detected architecture: $ARCH (Node.js: $NODE_ARCH)"

# Update system
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
log "Installing essential packages..."
sudo apt install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    tree \
    htop \
    tmux \
    vim \
    nano \
    zip \
    unzip \
    p7zip-full \
    net-tools \
    nmap \
    ufw \
    sqlite3 \
    jq \
    fd-find \
    ripgrep

# Install Python 3.10
log "Installing Python 3.10..."
if [[ "$DEVICE" == "ubuntu" ]]; then
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt update
fi

sudo apt install -y python3.10 python3.10-dev python3.10-venv python3-pip python3.10-distutils

# Make Python 3.10 default
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1

# Install pip for Python 3.10
log "Setting up pip for Python 3.10..."
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10

# Raspberry Pi specific packages
if [[ "$DEVICE" == "rpi5" ]]; then
    log "Installing Raspberry Pi specific packages..."
    sudo apt install -y \
        rpi.gpio-common \
        python3-rpi.gpio \
        python3-gpiozero \
        i2c-tools \
        spi-tools \
        wiringpi \
        libcamera-apps
    
    # Enable I2C and SPI
    sudo raspi-config nonint do_i2c 0
    sudo raspi-config nonint do_spi 0
    
    info "GPIO and camera libraries installed for Raspberry Pi"
fi

# Install Node.js (Latest LTS)
log "Installing Node.js..."
NODE_VERSION="20.15.1"
NODE_PACKAGE="node-v${NODE_VERSION}-linux-${NODE_ARCH}"

cd /tmp
wget "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_PACKAGE}.tar.xz"
tar -xf "${NODE_PACKAGE}.tar.xz"
sudo mv "${NODE_PACKAGE}" /opt/nodejs
sudo ln -sf /opt/nodejs/bin/node /usr/local/bin/node
sudo ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm
sudo ln -sf /opt/nodejs/bin/npx /usr/local/bin/npx

# Install global npm packages
log "Installing global npm packages..."
npm install -g \
    nodemon \
    pm2 \
    typescript \
    ts-node \
    eslint \
    prettier \
    create-react-app \
    @vue/cli \
    @angular/cli \
    express-generator

# Install Docker
log "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

if [[ "$DEVICE" == "rpi5" ]]; then
    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
else
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
log "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.20.2"
sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install VSCode
log "Installing Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

sudo apt update
sudo apt install -y code

# Install Zsh and Oh My Zsh
log "Installing Zsh and Oh My Zsh..."
sudo apt install -y zsh

# Install Oh My Zsh
export RUNZSH=no
export CHSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Zsh plugins
log "Installing Zsh plugins..."
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions

# zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting

# zsh-completions
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions

# Powerlevel10k theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k

# Configure .zshrc
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

# Configure tmux
log "Configuring tmux..."
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

# Configure Git (basic setup)
log "Configuring Git..."
git config --global init.defaultBranch main
git config --global core.editor nano

# Install additional Python packages
log "Installing common Python packages..."
pip3 install --user \
    requests \
    numpy \
    pandas \
    matplotlib \
    seaborn \
    jupyter \
    notebook \
    flask \
    django \
    fastapi \
    uvicorn \
    pytest \
    black \
    flake8 \
    autopep8

# Generate SSH key if it doesn't exist
log "Setting up SSH key..."
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
    info "SSH key generated at ~/.ssh/id_rsa.pub"
else
    info "SSH key already exists"
fi

# Configure firewall
log "Configuring firewall..."
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 3000  # Common dev port
sudo ufw allow 5000  # Flask default
sudo ufw allow 8000  # Django/FastAPI default

# Install database tools
log "Installing database tools..."
sudo apt install -y postgresql-client mysql-client redis-tools

# Create common development directories
log "Creating development directories..."
mkdir -p "$HOME/Projects"
mkdir -p "$HOME/Scripts"
mkdir -p "$HOME/.local/bin"

# Install neofetch for system info
log "Installing neofetch..."
sudo apt install -y neofetch

# Install additional useful tools
log "Installing additional tools..."
sudo apt install -y \
    bat \
    exa \
    fzf \
    ranger \
    ncdu \
    tldr

# Create a development environment activation script
log "Creating development environment activation script..."
cat > "$HOME/.local/bin/devenv" << 'EOF'
#!/bin/bash
echo "=== Development Environment Info ==="
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "Python: $(python --version)"
echo "pip: $(pip --version)"
echo "Git: $(git --version)"
echo "Docker: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"
echo "VSCode: $(code --version | head -1)"
echo "Zsh: $(zsh --version)"
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
echo "Your SSH public key:"
cat ~/.ssh/id_rsa.pub
EOF

chmod +x "$HOME/.local/bin/devenv"

# Change default shell to zsh
log "Changing default shell to Zsh..."
sudo chsh -s $(which zsh) $USER

# Final cleanup
log "Cleaning up..."
sudo apt autoremove -y
sudo apt autoclean

# Create a summary file
cat > "$HOME/installation_summary.txt" << EOF
=== Development Environment Installation Summary ===
Date: $(date)
Device: $DEVICE
Architecture: $ARCH

Installed Software:
- Zsh with Oh My Zsh and plugins (autosuggestions, syntax-highlighting, completions)
- Python 3.10 with pip and common packages
- Node.js ${NODE_VERSION} with global packages
- VSCode with repository setup
- Docker and Docker Compose
- Git with basic configuration
- Essential development tools (tmux, vim, htop, tree, etc.)
- Database clients (PostgreSQL, MySQL, Redis)
- Network and system tools
- SSH key generated

Configuration Files Created:
- ~/.zshrc (Zsh configuration)
- ~/.tmux.conf (Tmux configuration)
- ~/.ssh/id_rsa (SSH key pair)

Development Directories:
- ~/Projects (for your projects)
- ~/Scripts (for your scripts)

Commands to try:
- devenv (show environment info)
- tmux (terminal multiplexer)
- htop (system monitor)
- tree (directory structure)
- neofetch (system information)

Next Steps:
1. Reboot or log out and back in for group changes to take effect
2. Run 'devenv' to see your environment info
3. Configure Git with your name and email:
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
4. Add your SSH key to GitHub/GitLab if needed
EOF

# Success message
echo ""
echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "✅ Zsh with Oh My Zsh and plugins"
echo "✅ Python 3.10 with common packages"
echo "✅ Node.js with global packages"
echo "✅ VSCode"
echo "✅ Docker and Docker Compose"
echo "✅ Git configuration"
echo "✅ Development tools and utilities"
echo "✅ SSH key generated"
echo "✅ Firewall configured"
echo "✅ Development directories created"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "1. Please reboot or log out and back in for all changes to take effect"
echo "2. Your default shell has been changed to Zsh"
echo "3. Run 'devenv' command to see your environment info"
echo "4. Check ~/installation_summary.txt for detailed information"
echo ""
echo -e "${BLUE}Your SSH public key (for GitHub/GitLab):${NC}"
cat ~/.ssh/id_rsa.pub
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
