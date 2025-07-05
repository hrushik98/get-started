# 🚀 Dev Environment Setup Scripts

> *Because life's too short to manually install the same tools 50+ times*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://badges.frapsoft.com/bash/v1/bash.png?v=103)](https://github.com/ellerbrock/open-source-badges/)
[![Tested on](https://img.shields.io/badge/Tested%20on-Ubuntu%20|%20Raspberry%20Pi%205-green.svg)](https://github.com/)

**One script to rule them all.** Stop wasting hours setting up your development environment every time you switch distros, get a new machine, or accidentally nuke your system (we've all been there 😅).

## 🎯 What This Does

This repository contains battle-tested scripts that transform a fresh Linux installation into a fully-equipped development powerhouse in minutes, not hours.

### 🔧 What Gets Installed

<details>
<summary><b>🐚 Shell & Terminal</b></summary>

- **Zsh** with Oh My Zsh framework
- **Powerlevel10k** theme for that aesthetic terminal
- **Essential plugins**: autosuggestions, syntax highlighting, completions
- **Tmux** with sensible configuration
- **Pre-configured aliases** for maximum productivity

</details>

<details>
<summary><b>🐍 Python Ecosystem</b></summary>

- **Python 3.10** (with proper alternatives setup)
- **pip** and essential packages
- **Common libraries**: requests, pandas, numpy, matplotlib, flask, django, fastapi
- **Development tools**: pytest, black, flake8, jupyter

</details>

<details>
<summary><b>⚡ Node.js Ecosystem</b></summary>

- **Node.js LTS** (architecture-aware installation)
- **Global packages**: nodemon, pm2, typescript, create-react-app
- **Framework CLIs**: Vue, Angular, Express generator

</details>

<details>
<summary><b>🐳 Containerization</b></summary>

- **Docker** with proper user permissions
- **Docker Compose** latest version
- **Pre-configured aliases** for common operations

</details>

<details>
<summary><b>💻 Development Tools</b></summary>

- **Visual Studio Code** with repository setup
- **Git** with sensible defaults
- **Build tools**: build-essential, compilation tools
- **Database clients**: PostgreSQL, MySQL, Redis
- **System tools**: htop, tree, neofetch, bat, exa, fzf

</details>

<details>
<summary><b>🍓 Raspberry Pi Specific (when detected)</b></summary>

- **GPIO libraries**: RPi.GPIO, gpiozero
- **Hardware interfaces**: I2C, SPI tools
- **Camera support**: libcamera-apps
- **Hardware enablement**: I2C/SPI interface activation

</details>

<details>
<summary><b>🔒 Security & Networking</b></summary>

- **UFW firewall** with sensible defaults
- **SSH key generation** (if not exists)
- **Network tools**: net-tools, nmap
- **Common dev ports** pre-opened (3000, 5000, 8000)

</details>

## 🚀 Quick Start

### One-Liner Installation

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/dev-setup-scripts/main/setup.sh | bash
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dev-setup-scripts.git
cd dev-setup-scripts

# Make the script executable
chmod +x setup.sh

# Run the setup
./setup.sh
```

### 🎮 Interactive Setup

The script will ask you to choose your platform:

```
=== Development Environment Setup ===
Please select your device:
1. Raspberry Pi 5
2. Ubuntu
Enter your choice (1 or 2): 
```

That's it! Grab a coffee ☕ and watch the magic happen.

## 📋 What Happens Next

1. **System Update** - Updates all existing packages
2. **Platform Detection** - Configures based on your hardware
3. **Software Installation** - Installs all the goodies listed above
4. **Configuration** - Sets up dotfiles and sensible defaults
5. **Environment Setup** - Creates development directories and aliases
6. **Summary Generation** - Creates a detailed installation report

### 📁 Directory Structure Created

```
~/
├── Projects/          # Your main development folder
├── Scripts/           # Custom scripts and utilities
├── .oh-my-zsh/       # Zsh configuration
├── .ssh/             # SSH keys (generated if needed)
└── installation_summary.txt  # Detailed setup report
```

## 🔧 Post-Installation

After the script completes:

1. **Reboot** your system (important for group changes)
2. **Configure Git** with your details:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```
3. **Add SSH key** to GitHub/GitLab (key is displayed at the end)
4. **Run `devenv`** to see your environment info

## 🎨 Useful Aliases Added

| Alias | Command | Description |
|-------|---------|-------------|
| `ll` | `ls -alF` | Detailed file listing |
| `gs` | `git status` | Quick git status |
| `dps` | `docker ps` | List running containers |
| `dc` | `docker-compose` | Docker compose shorthand |
| `venv` | `python -m venv` | Create virtual environment |
| `update` | `sudo apt update && sudo apt upgrade` | System update |

## 🛠️ Customization

### Adding Your Own Software

Edit the script and add your packages to the installation sections:

```bash
# Add to the essential packages section
sudo apt install -y \
    your-package-here \
    another-package
```

### Custom Dotfiles

The script creates basic configurations. You can override them by:

1. Forking this repository
2. Modifying the configuration sections
3. Adding your custom dotfiles

### Environment Variables

Add custom environment variables in the `.zshrc` section:

```bash
export YOUR_CUSTOM_VAR="value"
export PATH="$PATH:/your/custom/path"
```

## 🐛 Troubleshooting

### Common Issues

<details>
<summary><b>Permission Denied Errors</b></summary>

Make sure you're not running as root:
```bash
# Wrong ❌
sudo ./setup.sh

# Correct ✅
./setup.sh
```

</details>

<details>
<summary><b>Docker Permission Issues</b></summary>

After installation, you need to log out and back in for Docker group changes to take effect, or run:
```bash
newgrp docker
```

</details>

<details>
<summary><b>VSCode Not Starting</b></summary>

If VSCode doesn't start, try installing manually:
```bash
sudo apt update
sudo apt install code
```

</details>

<details>
<summary><b>Zsh Not Default Shell</b></summary>

If Zsh isn't your default shell after reboot:
```bash
chsh -s $(which zsh)
```

</details>

### Getting Help

1. Check the `installation_summary.txt` file in your home directory
2. Run `devenv` to see environment info
3. Open an issue in this repository with:
   - Your Linux distribution and version
   - Error messages (if any)
   - Hardware details (especially for Raspberry Pi)

## 🧪 Tested On

- ✅ Ubuntu 20.04 LTS
- ✅ Ubuntu 22.04 LTS  
- ✅ Ubuntu 24.04 LTS
- ✅ Raspberry Pi OS (64-bit) on Pi 5
- ✅ Linux Mint 21
- ⚠️ Debian 12 (mostly working)

*Want to test on your distro? PRs welcome!*

## 🤝 Contributing

Found a bug? Want to add support for your favorite distro? Contributions are welcome!

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Test** your changes on a fresh VM/container
4. **Commit** your changes (`git commit -m 'Add amazing feature'`)
5. **Push** to the branch (`git push origin feature/amazing-feature`)
6. **Open** a Pull Request

### Adding New Distros

To add support for a new distribution:

1. Test the script on the new distro
2. Add any distro-specific package names or installation methods
3. Update the README with test results
4. Add any special configuration needed

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⭐ Star History

If this saved you time, consider giving it a star! ⭐

## 🙏 Acknowledgments

- The **Oh My Zsh** community for the amazing framework
- **Homebrew** for inspiration on package management
- **Docker** team for containerization awesomeness
- Coffee ☕ for making this possible

---

<div align="center">

**Made with ❤️ by developers, for developers**

*Stop configuring, start building* 🚀

</div>
