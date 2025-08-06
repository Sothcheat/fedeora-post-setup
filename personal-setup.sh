#!/bin/bash

# Fedora 42 Post-Install Setup Script (Fixed Version)
set -euo pipefail
IFS=$'\n\t'

LOG_DIR="$HOME/fedora42-setup-logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/fedora42-setup-$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info() { echo -e "${GREEN}✅ [INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠️ [WARN]${NC} $*"; }
log_error() { echo -e "${RED}❌ [ERROR]${NC} $*" >&2; }
log_prompt() { echo -ne "${BLUE}❓ [INPUT]${NC} $*"; }

confirm() {
  while true; do
    log_prompt "$1 [y/n]: "
    read -r ans
    case "$ans" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

check_internet() {
  log_info "🌐 Checking internet connectivity..."
  if ! ping -c1 -W2 8.8.8.8 &>/dev/null; then
    log_error "No internet connectivity detected. Please check your network."
    exit 1
  fi
  log_info "🌐 Internet connectivity confirmed."
}

check_fedora_version() {
  log_info "🔍 Checking Fedora version..."
  if ! command -v rpm &> /dev/null; then
    log_error "This script is designed for Fedora systems only."
    exit 1
  fi
  
  fedora_version=$(rpm -E %fedora 2>/dev/null || echo "unknown")
  log_info "Detected Fedora version: $fedora_version"
  
  if [[ "$fedora_version" == "unknown" ]]; then
    log_warn "Could not detect Fedora version. Proceeding with caution..."
  fi
}

step_start() {
  echo -e "\n${CYAN}🔧 ==> Starting: $* ...${NC}"
  date +"[%Y-%m-%d %H:%M:%S] Starting: $*" >> "$LOGFILE"
}

step_end() {
  echo -e "${CYAN}✔️ ==> Completed: $*${NC}\n"
  date +"[%Y-%m-%d %H:%M:%S] Completed: $*" >> "$LOGFILE"
}

error_handler() {
  local line_number=$1
  local error_code=$2
  log_error "Script failed at line $line_number with exit code $error_code"
  log_error "Check the log file: $LOGFILE"
  exit $error_code
}

trap 'error_handler ${LINENO} $?' ERR

# === Start Script ===
clear
echo -e "${GREEN}🚀 Fedora 42 Post-Install Setup Script (Fixed)${NC}"
echo "📄 Log file: $LOGFILE"

check_internet
check_fedora_version

# Enable RPM Fusion & Flathub
step_start "📦 Enabling RPM Fusion & Flathub repositories"
# Check if RPM Fusion is already installed
if ! rpm -qa | grep -q rpmfusion-free-release; then
  sudo dnf install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
else
  log_info "RPM Fusion already installed"
fi

# Check if Flathub is already added
if ! flatpak remotes | grep -q flathub; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
else
  log_info "Flathub already configured"
fi
step_end "Repositories enabled"

# System update
step_start "🔄 System upgrade"
sudo dnf upgrade --refresh -y
step_end "System upgraded"

# GPU drivers
step_start "🖥️ GPU Drivers Installation"
while true; do
  echo -e "\nSelect your GPU brand:"
  echo "  1) NVIDIA"
  echo "  2) AMD"
  echo "  3) Intel"
  echo "  4) None / Skip"

  log_prompt "Enter choice [1-4]: "
  read -r gpu_choice

  case "$gpu_choice" in
    1)
      log_info "You chose NVIDIA GPU."
      if confirm "Proceed with NVIDIA driver installation?"; then
        step_start "Installing NVIDIA drivers"
        # Check for newer GPU series that need open kernel modules
        if lspci -nnk | grep -i nvidia | grep -E 'RTX 40|RTX 50|4090|5080|5090' &>/dev/null; then
          echo "%_with_kmod_nvidia_open 1" | sudo tee /etc/rpm/macros.nvidia-kmod >/dev/null
          log_warn "Detected RTX 4000/5000 series GPU, enabling open kernel modules."
        else
          sudo rm -f /etc/rpm/macros.nvidia-kmod 2>/dev/null || true
        fi
        sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-vaapi-driver
        sudo akmods --force
        sudo dracut --force
        sudo systemctl enable --now nvidia-persistenced.service || true
        sudo dnf install -y libva-nvidia-driver
        log_info "✅ NVIDIA drivers installed."
        step_end "NVIDIA drivers installation"
      else
        log_warn "Skipped NVIDIA driver installation."
      fi
      ;;
    2)
      log_info "You chose AMD GPU."
      if confirm "Proceed with AMD driver installation?"; then
        step_start "Installing AMD drivers"
        sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
        sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld || log_warn "Failed to swap VA drivers"
        sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld || log_warn "Failed to swap VDPAU drivers"
        log_info "✅ AMD GPU drivers installed."
        step_end "AMD drivers installation"
      else
        log_warn "Skipped AMD driver installation."
      fi
      ;;
    3)
      log_info "You chose Intel GPU."
      if confirm "Proceed with Intel driver installation?"; then
        step_start "Installing Intel drivers"
        sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
        sudo dnf install -y intel-media-driver || log_warn "Intel media driver install failed"
        sudo dnf install -y intel-vaapi-driver || log_warn "Intel VAAPI driver install failed"
        log_info "✅ Intel GPU drivers installed."
        step_end "Intel drivers installation"
      else
        log_warn "Skipped Intel driver installation."
      fi
      ;;
    4)
      log_warn "Skipping GPU driver installation as requested."
      break
      ;;
    *)
      echo "❌ Invalid option. Please enter a number between 1 and 4."
      ;;
  esac

  echo ""
  if confirm "Install drivers for another GPU (useful for hybrid setups)?"; then
    continue
  else
    break
  fi
done
step_end "GPU Drivers Installation Completed"

# Multimedia codecs
step_start "🎵 Installing Multimedia Codecs"
sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
sudo dnf install -y gstreamer1-plugins-{bad-*,good-*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame* --exclude=gstreamer1-plugins-bad-free-devel
sudo dnf group install -y sound-and-video
sudo dnf update -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
log_info "✅ Multimedia codecs installed."
step_end "Codecs installed"

# Hostname
step_start "🏷️ Setting hostname to 'fedora'"
current_hostname=$(hostnamectl --static)
if [[ "$current_hostname" != "fedora" ]]; then
  sudo hostnamectl set-hostname fedora
  log_info "Hostname changed from '$current_hostname' to 'fedora'"
else
  log_info "Hostname already set to 'fedora'"
fi
step_end "Hostname set"

# Essential applications
if confirm "📦 Install essential applications (Zen Browser, Telegram, Discord, Kate, VLC, Ghostty)?"; then
  step_start "📥 Installing essential applications"
  
  # Install Flatpak applications
  flatpak install -y --or-update flathub app.zen_browser.zen org.telegram.desktop || log_warn "Some Flatpak apps failed to install"
  
  # Remove Firefox if exists
  sudo dnf remove -y firefox || log_info "Firefox not installed or already removed"
  
  # Install DNF packages
  sudo dnf install -y discord kate vlc || log_warn "Some DNF packages failed to install"
  
  # Install Ghostty from COPR
  if ! sudo dnf copr enable -y scottames/ghostty; then
    log_warn "Ghostty COPR repo enable failed"
  else
    sudo dnf install -y ghostty || log_warn "Ghostty install failed"
  fi
  
  step_end "Essential applications installed"
else
  log_warn "Skipped installation of essential applications"
fi

# Fonts - FiraCode Nerd Font
if confirm "🔤 Install FiraCode Nerd Font?"; then
  step_start "📚 Installing FiraCode Nerd Font"
  
  # Check if already installed
  if fc-list | grep -i "firacode nerd font" &>/dev/null; then
    log_info "FiraCode Nerd Font already installed"
  else
    sudo dnf install -y unzip curl
    mkdir -p "$HOME/.local/share/fonts"
    
    # Download and install FiraCode Nerd Font
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    FONT_ZIP="$HOME/.local/share/fonts/FiraCode.zip"
    
    if curl -Lf -o "$FONT_ZIP" "$FONT_URL"; then
      unzip -o "$FONT_ZIP" -d "$HOME/.local/share/fonts/FiraCode"
      rm -f "$FONT_ZIP"
      fc-cache -fv
      log_info "✅ FiraCode Nerd Font installed successfully"
    else
      log_error "Failed to download FiraCode Nerd Font"
    fi
  fi
  
  step_end "FiraCode Nerd Font installation"
else
  log_warn "Skipped FiraCode Nerd Font installation"
fi

# Developer Tools
if confirm "🖥️ Install development tools and languages (gcc, clang, Java JDK, git, python, node, podman, docker)?"; then
  step_start "📦 Installing development tools and languages"
  
  # Install development groups and tools
  sudo dnf group install -y development-tools c-development || log_warn "Development groups install failed"
  sudo dnf install -y gcc clang cmake git python3-pip java-21-openjdk-devel nodejs npm podman docker || log_warn "Some dev tools failed to install"
  
  # Enable and start docker service
  if sudo systemctl enable docker; then
    sudo systemctl start docker || log_warn "Docker service start failed"
    # Add user to docker group
    sudo usermod -aG docker "$USER" || log_warn "Failed to add user to docker group"
    log_info "Docker configured. You may need to log out and back in to use docker without sudo."
  else
    log_warn "Docker service enable failed"
  fi
  
  step_end "Development tools installed"
else
  log_warn "Skipped developer tools installation"
fi

# Zsh with Oh My Zsh and Oh My Posh
if confirm "🛠️ Install and configure Zsh, Oh My Zsh, and Oh My Posh prompt?"; then
  step_start "⚙️ Installing Zsh, Oh My Zsh, and Oh My Posh"

  # Install required packages
  sudo dnf install -y zsh curl wget git unzip

  # Install Oh My Zsh (unattended)
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Installing Oh My Zsh..."
    export RUNZSH=no
    export CHSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  else
    log_info "Oh My Zsh already installed"
  fi

  # Set ZSH_CUSTOM path
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  
  # Install Zsh plugins
  log_info "Installing Zsh plugins..."
  
  # zsh-autosuggestions
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  fi
  
  # zsh-syntax-highlighting
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  fi
  
  # fast-syntax-highlighting
  if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
  fi
  
  # zsh-autocomplete
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autocomplete" ]; then
    git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git "$ZSH_CUSTOM/plugins/zsh-autocomplete"
  fi

  # Install Oh My Posh
  log_info "Installing Oh My Posh..."
  OMP_BIN_PATH="$HOME/.local/bin/oh-my-posh"
  mkdir -p "$(dirname "$OMP_BIN_PATH")"
  
  # Get latest Oh My Posh release URL
  OMP_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/latest \
    | grep "browser_download_url.*posh-linux-amd64" | cut -d '"' -f4)
  
  if [[ -n "$OMP_DOWNLOAD_URL" ]]; then
    curl -Lf -o "$OMP_BIN_PATH" "$OMP_DOWNLOAD_URL"
    chmod +x "$OMP_BIN_PATH"
    log_info "Oh My Posh binary installed to $OMP_BIN_PATH"
  else
    log_error "Failed to get Oh My Posh download URL"
    exit 1
  fi

  # Download atomic theme
  mkdir -p ~/.poshthemes
  if [ ! -f ~/.poshthemes/atomic.omp.json ]; then
    curl -Lf -o ~/.poshthemes/atomic.omp.json https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json
    log_info "Atomic Oh My Posh theme downloaded"
  else
    log_info "Atomic theme already exists"
  fi

  # Backup existing .zshrc
  if [ -f ~/.zshrc ]; then
    cp ~/.zshrc ~/.zshrc.backup-$(date +%Y%m%d_%H%M%S)
    log_info "Backed up existing .zshrc"
  fi

  # Create new .zshrc with proper configuration
  cat > ~/.zshrc <<'EOF'
# Path to Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME=""

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# Caution: this setting can cause issues with multiline prompts (zsh 5.7.1 and newer seem to work)
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications.
# For more details, see 'man strftime' or search for strftime
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $HOME/.oh-my-zsh/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fast-syntax-highlighting
    zsh-autocomplete
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though users
# are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Add ~/.local/bin to PATH if it exists
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Oh My Posh initialization (atomic theme)
if command -v oh-my-posh &> /dev/null; then
    eval "$(oh-my-posh init zsh --config ~/.poshthemes/atomic.omp.json)"
fi

# Custom configurations can be added below this line
EOF

  log_info ".zshrc configured with Oh My Zsh plugins and Oh My Posh"

  # Change default shell to Zsh
  current_shell=$(getent passwd "$USER" | cut -d: -f7)
  zsh_path=$(command -v zsh)
  if [[ "$current_shell" != "$zsh_path" ]]; then
    if sudo chsh -s "$zsh_path" "$USER"; then
      log_info "Default shell changed to Zsh"
      log_warn "You'll need to log out and back in (or restart) for the shell change to take effect."
    else
      log_warn "Failed to change default shell. You can manually run: sudo chsh -s $zsh_path $USER"
    fi
  else
    log_info "Zsh already set as default shell"
  fi

  step_end "Zsh, Oh My Zsh, and Oh My Posh installed and configured"
else
  log_warn "Skipped Zsh, Oh My Zsh, and Oh My Posh setup"
fi

# === Ghostty terminal configuration ===
if command -v ghostty &> /dev/null; then
  step_start "🖥️ Configuring Ghostty terminal"

  GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
  GHOSTTY_CONFIG_FILE="$GHOSTTY_CONFIG_DIR/config"
  mkdir -p "$GHOSTTY_CONFIG_DIR"

  cat > "$GHOSTTY_CONFIG_FILE" <<EOF
# Font configuration
font-family = FiraCode Nerd Font
font-size = 14

# Appearance
background-opacity = 0.9
theme = Everforest Dark - Hard
cursor-style = block
cursor-style-blink = true

# Window settings
window-padding-x = 4
window-padding-y = 4
window-decoration = true

# Terminal behavior
scrollback-limit = 10000
mouse-hide-while-typing = true

# Performance
unfocused-split-opacity = 0.7
link-url = true
copy-on-select = false
confirm-close-surface = false
EOF

  log_info "Ghostty config written to $GHOSTTY_CONFIG_FILE"
  step_end "Ghostty terminal configured"
else
  log_warn "Ghostty not found, skipping configuration"
fi

# Desktop Customization
step_start "🎨 Desktop Environment Customization"

echo "Select your Desktop Environment for customization:"

while true; do
  echo -e "\nSelect your Desktop Environment:"
  echo "  1) GNOME"
  echo "  2) KDE Plasma"
  echo "  3) Skip customization"
  
  log_prompt "Enter choice [1-3]: "
  read -r de_choice

  case "$de_choice" in
    1)
      log_info "You chose GNOME."
      step_start "Installing GNOME Customization Applications"
      sudo dnf install -y gnome-tweaks || log_warn "GNOME Tweaks install failed"
      flatpak install -y --or-update flathub com.mattjakeman.ExtensionManager || log_warn "Extension Manager install failed"
      log_info "✅ GNOME Customization Applications installed."
      step_end "GNOME Customization installation"
      break
      ;;
    2)
      log_info "You chose KDE Plasma."
      step_start "Installing KDE Plasma Customization Applications"
      sudo dnf install -y kvantum qt5ct || log_warn "Some KDE customization tools failed to install"
      log_info "✅ KDE Plasma Customization Applications installed."
      step_end "KDE Plasma Customization installation"
      break
      ;;
    3)
      log_warn "Skipping Desktop Environment customization."
      break
      ;;
    *)
      echo "❌ Invalid option. Please enter a number between 1 and 3."
      ;;
  esac
done

step_end "Desktop Environment Customization completed"

# Performance optimizations
step_start "⚡ System Performance Optimizations"

# Disable NetworkManager-wait-online for faster boot
if confirm "Disable NetworkManager-wait-online.service for faster boot?"; then
  if sudo systemctl disable NetworkManager-wait-online.service; then
    log_info "NetworkManager-wait-online.service disabled"
  else
    log_warn "Failed to disable NetworkManager-wait-online.service"
  fi
else
  log_warn "Skipped disabling NetworkManager-wait-online.service"
fi

# Enable and configure firewall
if systemctl is-enabled firewalld &>/dev/null; then
  log_info "FirewallD already enabled"
else
  sudo systemctl enable --now firewalld || log_warn "FirewallD enable failed"
fi

# Install additional system utilities
sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig p7zip p7zip-plugins unrar || log_warn "Some utilities failed to install"

step_end "System optimizations completed"

# Development IDEs
if confirm "💻 Install development IDEs (VS Code, NetBeans, IntelliJ IDEA Community)?"; then
  step_start "📦 Installing Development IDEs"
  
  # Visual Studio Code
  log_info "Installing Visual Studio Code..."
  if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    sudo dnf check-update || true
  fi
  sudo dnf install -y code || log_warn "VS Code install failed"

  # NetBeans via Flatpak
  log_info "Installing Apache NetBeans IDE..."
  flatpak install -y --or-update flathub org.apache.netbeans || log_warn "NetBeans install failed"

  # IntelliJ IDEA Community Edition
  log_info "Installing IntelliJ IDEA Community Edition..."
  flatpak install -y --or-update flathub com.jetbrains.IntelliJ-IDEA-Community || log_warn "IntelliJ IDEA install failed"

  step_end "Development IDEs installed"
else
  log_warn "Skipped development IDEs installation"
fi

# Windows dual boot RTC fix
if confirm "⏰ Are you dual booting with Windows? (This will fix time synchronization issues)"; then
  step_start "⏰ Configuring dual boot time settings"
  if sudo timedatectl set-local-rtc 0 --adjust-system-clock; then
    log_info "RTC configured for UTC (Linux standard)"
    log_info "This should resolve time sync issues with Windows dual boot"
  else
    log_warn "Failed to configure RTC settings"
  fi
  step_end "Dual boot time settings configured"
else
  log_warn "Skipped dual boot configuration"
fi

# System Cleanup
step_start "🧹 System Cleanup"
log_info "Cleaning DNF package cache..."
sudo dnf clean all
log_info "Removing unused Flatpak applications..."
flatpak uninstall --unused -y || log_warn "Flatpak cleanup failed"
log_info "Cleaning font cache..."
fc-cache -fv &>/dev/null || log_warn "Font cache rebuild failed"
step_end "System cleanup completed"

# Final message and summary
echo -e "\n${GREEN}🎉 ==================================${NC}"
echo -e "${GREEN}🎉 FEDORA SETUP COMPLETED! 🎉${NC}"
echo -e "${GREEN}🎉 ==================================${NC}\n"

echo -e "${CYAN}📋 Setup Summary:${NC}"
echo "  ✅ System updated and repositories configured"
echo "  ✅ GPU drivers installed (if selected)"
echo "  ✅ Multimedia codecs installed"
echo "  ✅ Essential applications installed (if selected)"
if command -v zsh &> /dev/null && [ -d "$HOME/.oh-my-zsh" ]; then
  echo "  ✅ Zsh, Oh My Zsh, and Oh My Posh configured"
fi
if command -v code &> /dev/null; then
  echo "  ✅ Development tools and IDEs installed"
fi
echo "  ✅ System optimized for performance"

echo -e "\n${YELLOW}⚠️ Important Notes:${NC}"
echo "  • Please RESTART your computer to finalize all changes"
if [[ $(getent passwd "$USER" | cut -d: -f7) == *"zsh"* ]]; then
  echo "  • Your default shell has been changed to Zsh"
  echo "  • Oh My Posh with atomic theme will be active after restart"
fi
echo "  • Check the log file for any warnings: $LOGFILE"

echo -e "\n${GREEN}🚀 Enjoy your customized Fedora system!${NC}"

exit 0
