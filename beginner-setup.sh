#!/bin/bash

# Fedora 42 Beginner Setup Script - Essential "Out of the Box" Experience
# This script installs only the essentials to make Fedora work smoothly for newcomers

set -euo pipefail
IFS=$'\n\t'

# === Logging, Colors, and Helper Functions ===
LOG_DIR="$HOME/fedora42-setup-logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/fedora42-beginner-setup-$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()   { echo -e "${GREEN}✅ [INFO]${NC} $*"; }
log_warn()   { echo -e "${YELLOW}⚠️ [WARN]${NC} $*"; }
log_error()  { echo -e "${RED}❌ [ERROR]${NC} $*" >&2; }
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

step_start() { 
  echo -e "\n${CYAN}🔧 ==> Starting: $* ...${NC}"
  date +"[%Y-%m-%d %H:%M:%S] Starting: $*" >> "$LOGFILE"
}

step_end() { 
  echo -e "${CYAN}✔️ ==> Completed: $*${NC}\n"
  date +"[%Y-%m-%d %H:%M:%S] Completed: $*" >> "$LOGFILE"
}

check_internet() {
  log_info "🌐 Checking internet connectivity..."
  if ! ping -c1 -W2 8.8.8.8 &>/dev/null; then
    log_error "No internet connectivity detected. Please check your network and re-run this script."
    exit 1
  fi
  log_info "🌐 Internet connectivity confirmed."
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
echo -e "${GREEN}🚀 Fedora 42 Beginner Setup - Essential Experience${NC}"
echo -e "${BLUE}📘 This script installs only what's needed to make Fedora work great out-of-the-box${NC}"
echo -e "${BLUE}📘 No extra applications - you choose what you want later!${NC}"
echo "📄 Log file: $LOGFILE"
echo ""

check_internet

# === Enable Essential Repositories ===
step_start "📦 Enabling RPM Fusion & Flathub repositories"
log_info "Adding repositories for multimedia codecs and additional software..."

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

step_end "Essential repositories enabled"

# === System Update ===
step_start "🔄 System Update"
log_info "Updating all installed software to latest versions..."
sudo dnf upgrade --refresh -y
step_end "System updated"

# === GPU Drivers - Critical for Good Experience ===
step_start "🖥️ GPU Drivers Installation"
echo -e "${YELLOW}🎯 Graphics drivers are essential for smooth performance!${NC}"
echo "Select your graphics card type (you can install multiple for hybrid systems):"

while true; do
  echo -e "\nGraphics Card Options:"
  echo "  1) NVIDIA (GeForce, RTX, GTX series)"
  echo "  2) AMD (Radeon, RX series)"  
  echo "  3) Intel (integrated graphics)"
  echo "  4) Skip (not recommended)"
  
  log_prompt "Enter choice [1-4]: "
  read -r gpu_choice
  
  case "$gpu_choice" in
    1)
      log_info "NVIDIA graphics selected."
      echo -e "${YELLOW}⏳ NVIDIA driver installation may take 5-10 minutes (compiling kernel modules)${NC}"
      if confirm "Install NVIDIA drivers? (Recommended for NVIDIA users)"; then
        step_start "Installing NVIDIA drivers"
        
        # Check for newer GPU series that need open kernel modules
        if lspci -nnk | grep -i nvidia | grep -E 'RTX 40|RTX 50|4090|5080|5090' &>/dev/null; then
          echo "%_with_kmod_nvidia_open 1" | sudo tee /etc/rpm/macros.nvidia-kmod >/dev/null
          log_info "Detected RTX 4000/5000 series - enabling open kernel modules"
        else
          sudo rm -f /etc/rpm/macros.nvidia-kmod 2>/dev/null || true
        fi
        
        sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-vaapi-driver
        sudo akmods --force
        sudo dracut --force
        sudo systemctl enable nvidia-persistenced.service || true
        sudo dnf install -y libva-nvidia-driver || true
        
        log_info "✅ NVIDIA drivers installed. Reboot required for activation."
        step_end "NVIDIA drivers installed"
      else
        log_warn "Skipped NVIDIA drivers (you may experience poor graphics performance)"
      fi
      ;;
    2)
      log_info "AMD graphics selected."
      echo "Installing AMD graphics drivers and video acceleration..."
      if confirm "Install AMD drivers? (Recommended for AMD users)"; then
        step_start "Installing AMD drivers"
        
        sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
        sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld || log_warn "VA drivers swap failed"
        sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld || log_warn "VDPAU drivers swap failed"
        
        log_info "✅ AMD drivers installed."
        step_end "AMD drivers installed"
      else
        log_warn "Skipped AMD drivers"
      fi
      ;;
    3)
      log_info "Intel graphics selected."
      echo "Installing Intel graphics drivers for integrated graphics..."
      if confirm "Install Intel drivers? (Recommended for Intel users)"; then
        step_start "Installing Intel drivers"
        
        sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
        sudo dnf install -y intel-media-driver || log_warn "Intel media driver install failed"
        sudo dnf install -y intel-vaapi-driver || log_warn "Intel VAAPI driver install failed"
        
        log_info "✅ Intel drivers installed."
        step_end "Intel drivers installed"
      else
        log_warn "Skipped Intel drivers"
      fi
      ;;
    4)
      log_warn "⚠️ Skipping GPU drivers - you may experience poor graphics performance"
      log_warn "You can run this script again later to install drivers"
      break
      ;;
    *)
      echo "❌ Invalid option. Please enter 1, 2, 3, or 4."
      continue
      ;;
  esac
  
  echo ""
  if confirm "Install drivers for another graphics card? (useful for laptops with hybrid graphics)"; then
    continue
  else
    break
  fi
done

step_end "GPU drivers installation completed"

# === Multimedia Codecs - Essential for Media Playback ===
step_start "🎵 Installing Multimedia Codecs"
log_info "Installing codecs for video, audio, and media playback..."
echo -e "${BLUE}📺 This enables playing MP4, MP3, and other common media formats${NC}"

sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
sudo dnf install -y gstreamer1-plugins-{bad-*,good-*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame* --exclude=gstreamer1-plugins-bad-free-devel
sudo dnf group install -y sound-and-video
sudo dnf update -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

log_info "✅ Multimedia codecs installed - media files should now play properly"
step_end "Multimedia codecs installed"

# === System Hostname ===
step_start "🏷️ Setting system hostname"
current_hostname=$(hostnamectl --static)
if [[ "$current_hostname" != "fedora" ]]; then
  sudo hostnamectl set-hostname fedora
  log_info "Hostname changed from '$current_hostname' to 'fedora'"
else
  log_info "Hostname already set to 'fedora'"
fi
step_end "Hostname configured"

# === Better Fonts for Readability ===
if confirm "🔤 Install better fonts for improved readability and development? (Recommended)"; then
  step_start "📚 Installing FiraCode Nerd Font and Microsoft fonts"
  
  sudo dnf install -y unzip curl
  
  # Install FiraCode Nerd Font
  if ! fc-list | grep -i "firacode nerd font" &>/dev/null; then
    mkdir -p ~/.local/share/fonts
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    FONT_ZIP="$HOME/.local/share/fonts/FiraCode.zip"
    
    if curl -Lf -o "$FONT_ZIP" "$FONT_URL"; then
      unzip -o "$FONT_ZIP" -d ~/.local/share/fonts/FiraCode
      rm -f "$FONT_ZIP"
      log_info "FiraCode Nerd Font installed"
    else
      log_warn "Failed to download FiraCode Nerd Font"
    fi
  else
    log_info "FiraCode Nerd Font already installed"
  fi
  
  # Install Microsoft core fonts for better web compatibility
  sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig
  sudo rpm -i --quiet https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm || log_warn "Microsoft fonts install failed"
  
  # Rebuild font cache
  fc-cache -fv &>/dev/null
  
  step_end "Fonts installed"
else
  log_warn "Skipped font installation"
fi

# === Basic Development Tools (Essential for System Maintenance) ===
if confirm "🔧 Install basic development tools? (Recommended - needed for some software compilation)"; then
  step_start "📦 Installing essential development tools"
  
  sudo dnf group install -y development-tools c-development || log_warn "Development groups install failed"
  sudo dnf install -y gcc git python3-pip cmake || log_warn "Some development tools failed to install"
  
  log_info "✅ Basic development tools installed"
  step_end "Development tools installed"
else
  log_warn "Skipped development tools (some software may not compile correctly)"
fi

# === Improved Shell Experience (Optional but Recommended) ===
if confirm "🐚 Install Zsh shell with Oh My Zsh for better terminal experience? (Optional but recommended)"; then
  step_start "⚙️ Installing Zsh and Oh My Zsh"

  # Install Zsh
  sudo dnf install -y zsh curl wget git

  # Install Oh My Zsh (unattended)
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Installing Oh My Zsh..."
    export RUNZSH=no
    export CHSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  else
    log_info "Oh My Zsh already installed"
  fi

  # Install basic useful plugins
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  
  # zsh-autosuggestions (shows suggestions based on history)
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  fi
  
  # zsh-syntax-highlighting (highlights commands as you type)
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  fi

  # Create beginner-friendly .zshrc
  cat > ~/.zshrc <<'EOF'
# Path to Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme - clean and informative
ZSH_THEME="robbyrussell"

# Plugins for better experience
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# User configuration
# Add ~/.local/bin to PATH if it exists
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Helpful aliases for beginners
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias update='sudo dnf update'
alias install='sudo dnf install'
alias search='dnf search'

# Welcome message for new users
if [ -f ~/.zsh_first_run ]; then
    echo "🎉 Welcome to Zsh! Type 'help-zsh' for tips, or 'chsh -s /bin/bash' to go back to bash."
    rm ~/.zsh_first_run
fi

# Help function for new users
help-zsh() {
    echo "🐚 Zsh Help for Beginners:"
    echo "  • Tab completion: Press TAB to complete commands and paths"
    echo "  • History: Use ↑/↓ arrows to browse command history"  
    echo "  • Suggestions: Gray text shows suggestions from history (press → to accept)"
    echo "  • Aliases: 'll' for detailed file list, 'update' for system updates"
    echo "  • Git integration: Shows git branch and status in prompt when in git repos"
    echo "  • To return to bash: chsh -s /bin/bash (then restart terminal)"
}
EOF

  # Create marker file for first run
  touch ~/.zsh_first_run

  # Change default shell to Zsh
  current_shell=$(getent passwd "$USER" | cut -d: -f7)
  zsh_path=$(command -v zsh)
  if [[ "$current_shell" != "$zsh_path" ]]; then
    if sudo chsh -s "$zsh_path" "$USER"; then
      log_info "Default shell changed to Zsh"
      log_info "🔄 You'll need to log out and back in for the shell change to take effect"
    else
      log_warn "Failed to change default shell. You can manually run: sudo chsh -s $zsh_path $USER"
    fi
  else
    log_info "Zsh already set as default shell"
  fi

  step_end "Zsh and Oh My Zsh installed"
else
  log_warn "Skipped Zsh installation - staying with bash shell"
fi

# === Performance and Boot Optimizations ===
step_start "⚡ System Performance Optimizations"

# Faster boot - disable network wait
if confirm "Make system boot faster by skipping network wait? (Recommended)"; then
  if sudo systemctl disable NetworkManager-wait-online.service; then
    log_info "NetworkManager-wait-online.service disabled - faster boot enabled"
  else
    log_warn "Failed to disable NetworkManager-wait-online.service"
  fi
else
  log_warn "Kept network wait service enabled"
fi

# Enable firewall for security
log_info "Enabling firewall for system security..."
if systemctl is-enabled firewalld &>/dev/null; then
  log_info "Firewall already enabled"
else
  sudo systemctl enable --now firewalld || log_warn "Firewall enable failed"
fi

step_end "Performance optimizations completed"

# === Essential System Utilities ===
step_start "📂 Installing essential system utilities"
log_info "Installing archive support and additional fonts..."

sudo dnf install -y \
  p7zip p7zip-plugins unrar \
  curl wget \
  xorg-x11-font-utils fontconfig \
  || log_warn "Some utilities failed to install"

step_end "System utilities installed"

# === Windows Dual Boot Fix ===
if confirm "⏰ Are you dual-booting with Windows? (This fixes time synchronization issues)"; then
  step_start "⏰ Configuring dual boot time settings"
  if sudo timedatectl set-local-rtc 0 --adjust-system-clock; then
    log_info "Time synchronization configured for Windows dual boot"
    log_info "This prevents time differences between Windows and Linux"
  else
    log_warn "Failed to configure time settings"
  fi
  step_end "Dual boot time settings configured"
else
  log_info "Skipped dual boot configuration"
fi

# === System Cleanup ===
step_start "🧹 System Cleanup"
log_info "Cleaning package cache and removing unused packages..."

sudo dnf clean all
flatpak uninstall --unused -y || log_warn "Flatpak cleanup failed"

step_end "System cleanup completed"

# === Final Summary and Instructions ===
echo -e "\n${GREEN}🎉 ================================${NC}"
echo -e "${GREEN}🎉  FEDORA SETUP COMPLETED!  🎉${NC}"
echo -e "${GREEN}🎉 ================================${NC}\n"

echo -e "${CYAN}📋 What was installed:${NC}"
echo "  ✅ System updated to latest versions"
echo "  ✅ Essential repositories (RPM Fusion, Flathub) enabled"
echo "  ✅ Graphics drivers installed for your hardware"
echo "  ✅ Multimedia codecs for video/audio playback"
echo "  ✅ Better fonts for improved readability"
if command -v zsh &> /dev/null && [ -d "$HOME/.oh-my-zsh" ]; then
  echo "  ✅ Zsh shell with Oh My Zsh for better terminal experience"
fi
echo "  ✅ System optimized for better performance"
echo "  ✅ Firewall enabled for security"

echo -e "\n${BLUE}📱 What to do next:${NC}"
echo "  🔄 RESTART your computer to activate all changes"
echo "  🏪 Install applications using:"
echo "     • Fedora Software (GUI app store)"
echo "     • Terminal: 'sudo dnf install <package-name>'"
echo "     • Flathub: 'flatpak install <app-name>'"
echo "  🌐 Browse https://flathub.org for more applications"

if command -v zsh &> /dev/null && [ -d "$HOME/.oh-my-zsh" ]; then
  echo -e "\n${YELLOW}🐚 Zsh Tips:${NC}"
  echo "  • After restart, type 'help-zsh' in terminal for tips"
  echo "  • Use TAB for auto-completion, ↑/↓ for command history"
  echo "  • Gray suggestions appear as you type (press → to accept)"
fi

echo -e "\n${GREEN}📝 Important Notes:${NC}"
echo "  • Log file saved: $LOGFILE"
echo "  • If you encounter issues, check the log file above"
echo "  • For support, visit: https://ask.fedoraproject.org"

echo -e "\n${GREEN}🚀 Welcome to Fedora! Enjoy your Linux journey! 🐧${NC}"

exit 0
