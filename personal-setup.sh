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

choose_option() {
  local prompt="$1"; shift
  local options=("$@"); local opt
  while true; do
    echo -e "${CYAN}📋 ${prompt}${NC}"
    for i in "${!options[@]}"; do
      echo " $((i+1))) ${options[$i]}"
    done
    log_prompt "➡️ Enter choice [1-${#options[@]}]: "
    read -r opt
    if [[ "$opt" =~ ^[1-9][0-9]*$ ]] && (( opt >= 1 && opt <= ${#options[@]} )); then
      echo "${options[$((opt-1))]}"
      return 0
    fi
    echo "❗ Invalid option. Try again."
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

# === Start Script ===
clear
echo -e "${GREEN}🚀 Fedora 42 Post-Install Setup Script (Fixed)${NC}"
echo "📄 Log file: $LOGFILE"

check_internet

# Enable RPM Fusion & Flathub
step_start "📦 Enabling RPM Fusion & Flathub repositories"
sudo dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
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
        if lspci -nnk | grep -i nvidia | grep -E 'RTX 40|RTX 50|4090|5080|5090' &>/dev/null; then
          echo "%_with_kmod_nvidia_open 1" | sudo tee /etc/rpm/macros.nvidia-kmod >/dev/null
          log_warn "Detected RTX 4000/5000 series GPU, enabling special kernel support."
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
        sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
        sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
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
        sudo dnf install -y intel-media-driver || true
        sudo dnf install -y intel-vaapi-driver || true
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
sudo hostnamectl set-hostname fedora
step_end "Hostname set"

# Essential applications
if confirm "📦 Install essential applications (Zen Browser, Telegram, Discord, Kate, VLC, Ghostty)?"; then
  step_start "📥 Installing essential applications"
  flatpak install -y --or-update flathub app.zen_browser.zen org.telegram.desktop
  sudo dnf remove -y firefox
  sudo dnf install -y discord kate vlc
  sudo dnf copr enable -y scottames/ghostty || log_warn "Ghostty COPR repo enable failed"
  sudo dnf install -y ghostty || log_warn "Ghostty install failed"
  step_end "Essential applications installed"
else
  log_warn "Skipped installation of essential applications"
fi

# Fonts - FiraCode Nerd Font
if confirm "🔤 Install FiraCode Nerd Font?"; then
  step_start "📚 Installing FiraCode Nerd Font"
  sudo dnf install -y unzip
  mkdir -p "$HOME/.local/share/fonts"
  curl -Lf -o "$HOME/.local/share/fonts/FiraCode.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
  unzip -o "$HOME/.local/share/fonts/FiraCode.zip" -d "$HOME/.local/share/fonts/FiraCode"
  fc-cache -fv
  step_end "FiraCode Nerd Font installed"
else
  log_warn "Skipped FiraCode Nerd Font installation"
fi

# Zsh with Oh My Zsh and Oh My Posh
if confirm "🛠️ Install and configure Zsh, Oh My Zsh, and Oh My Posh prompt?"; then
  step_start "⚙️ Installing Zsh, Oh My Zsh, and Oh My Posh"

  sudo dnf install -y zsh curl unzip wget

  # Install Oh My Zsh (unattended)
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  else
    log_info "Oh My Zsh already installed"
  fi

  # Change default shell to Zsh (Fedora requires sudo):contentReference[oaicite:8]{index=8}
  current_shell=$(getent passwd "$USER" | cut -d: -f7)
  zsh_path=$(command -v zsh)
  if [[ "$current_shell" != "$zsh_path" ]]; then
    sudo chsh -s "$zsh_path" "$USER"
    log_info "Default shell changed to Zsh"
  else
    log_info "Zsh already default shell"
  fi

  # Backup existing .zshrc
  cp -n ~/.zshrc ~/.zshrc.backup-$(date +%Y%m%d_%H%M%S) || true

  # Install Zsh plugins (autosuggestions, syntax-highlighting, etc.):contentReference[oaicite:9]{index=9}:contentReference[oaicite:10]{index=10}
  ZSH_CUSTOM=${ZSH:-$HOME/.oh-my-zsh}/custom
  mkdir -p "$ZSH_CUSTOM/plugins"
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  fi
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  fi
  if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
  fi
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autocomplete" ]; then
    git clone https://github.com/marlonrichert/zsh-autocomplete.git "$ZSH_CUSTOM/plugins/zsh-autocomplete"
  fi

  # Write new .zshrc
  cat > ~/.zshrc <<'EOF'
# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"
# Disable Oh My Zsh's default theme (we use Oh My Posh instead)
ZSH_THEME=""
# Plugins (as per user configuration)
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fast-syntax-highlighting
    zsh-autocomplete
)
source $ZSH/oh-my-zsh.sh

# Oh My Posh prompt (atomic theme):contentReference[oaicite:11]{index=11}
export PATH="$HOME/.local/bin:$PATH"
eval "$(oh-my-posh init zsh --config \"$HOME/.poshthemes/atomic.omp.json\")"

# Disable Oh My Zsh auto-update prompt
DISABLE_AUTO_UPDATE="true"
EOF

  log_info ".zshrc updated with plugins and Oh My Posh configuration"

  # Install Oh My Posh binary (latest Linux amd64):contentReference[oaicite:12]{index=12}
  OMP_BIN_PATH="$HOME/.local/bin/oh-my-posh"
  mkdir -p "$(dirname "$OMP_BIN_PATH")"
  OMP_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/latest \
    | grep "browser_download_url.*linux_amd64" | cut -d '"' -f4)
  wget -qO "$OMP_BIN_PATH" "$OMP_DOWNLOAD_URL"
  chmod +x "$OMP_BIN_PATH"
  log_info "Oh My Posh binary installed to $OMP_BIN_PATH"

  # Download 'atomic' Oh My Posh theme JSON (using one-line URL):contentReference[oaicite:13]{index=13}
  mkdir -p ~/.poshthemes
  if [ ! -f ~/.poshthemes/atomic.omp.json ]; then
    wget -q -O ~/.poshthemes/atomic.omp.json https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json
    log_info "'atomic' Oh My Posh theme downloaded"
  else
    log_info "'atomic' theme already exists"
  fi

  step_end "Zsh, Oh My Zsh, and Oh My Posh installed"
else
  log_warn "Skipped Zsh, Oh My Zsh, and Oh My Posh setup"
fi

# === Ghostty terminal configuration ===
step_start "🖥️ Configuring Ghostty terminal"

GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
GHOSTTY_CONFIG_FILE="$GHOSTTY_CONFIG_DIR/config"
mkdir -p "$GHOSTTY_CONFIG_DIR"

cat > "$GHOSTTY_CONFIG_FILE" <<EOF
font-family = FiraCode Nerd Font
font-size = 14
background-opacity = 0.9
theme = Everforest Dark - Hard
EOF

log_info "Ghostty config written to $GHOSTTY_CONFIG_FILE"
step_end "Ghostty terminal configured"

# Developer Tools
if confirm "🖥️ Install development tools and languages (gcc, clang, Java JDK, git, python, node, podman, docker)?"; then
  step_start "📦 Installing development tools and languages"
  sudo dnf group install -y development-tools c-development
  sudo dnf install -y gcc clang cmake git-all python3-pip java-21-openjdk-devel nodejs podman docker || log_warn "Some dev tools failed to install"
  sudo systemctl enable --now docker || log_warn "Docker service enable failed"
  step_end "Development tools installed"
else
  log_warn "Skipped developer tools installation"
fi

# Desktop Customization snippet:
step_start "🎨 Customize Fedora"

echo "Pick your Desktop Environment that you're running on."

while true; do
  echo -e "\nSelect your Desktop Environment:"
  echo "  1) Gnome"
  echo "  2) KDE Plasma"
  echo "  3) Skip customize"
  
  log_prompt "Enter choice [1-3]: "
  read -r de_choice

  case "$de_choice" in
    1)
      log_info "You chose Gnome."
      step_start "Installing Gnome Customization Applications"
      sudo dnf install -y gnome-tweaks
      flatpak install -y --or-update flathub com.mattjakeman.ExtensionManager
      log_info "✅ Gnome Customization Applications installed."
      step_end "Gnome Customization installation"
      break  # exit loop after successful install
      ;;
    2)
      log_info "You chose KDE Plasma."
      step_start "Installing KDE Plasma Customization Applications"
      sudo dnf install -y kvantum
      log_info "✅ KDE Plasma Customization Applications installed."
      step_end "KDE Plasma Customization installation"
      break  # exit loop after successful install
      ;;
    3)
      log_warn "Skipping Fedora Customization installation as requested."
      break  # exit loop as user requested skip
      ;;
    *)
      echo "❌ Invalid option. Please enter a number between 1 and 3."
      ;;
  esac
done

step_end "Fedora Customization installation completed."

# Disable NetworkManager-wait-online for faster boot
if confirm "⚡ Disable NetworkManager-wait-online.service for faster boot?"; then
  step_start "Disabling NetworkManager-wait-online.service"
  sudo systemctl disable NetworkManager-wait-online.service || log_warn "Disable NetworkManager-wait-online.service failed"
  step_end "Disabled NetworkManager-wait-online.service"
else
  log_warn "Skipped disabling NetworkManager-wait-online.service"
fi

# Enable firewall
step_start "🔥 Enabling FirewallD"
sudo systemctl enable --now firewalld || log_warn "FirewallD enable failed"
step_end "FirewallD enabled"

# Fonts and archive utilities
step_start "📂 Installing fonts and archive utilities"
sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig p7zip p7zip-plugins unrar || log_warn "Some font/archive utilities failed to install"
step_end "Fonts and archive utilities installed"

# Visual Studio Code
step_start "💻 Installing Visual Studio Code"
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
sudo dnf check-update
sudo dnf install -y code || log_warn "VS Code install failed"
step_end "Visual Studio Code installed"

# Apache NetBeans IDE via Flatpak
step_start "📦 Installing Apache NetBeans IDE via Flatpak"
flatpak install -y --or-update flathub org.apache.netbeans
step_end "Apache NetBeans IDE installed"

# IntelliJ IDEA Community Edition install
step_start "💻 Downloading and installing IntelliJ IDEA Community Edition"
flatpak install -y --or-update flathub com.jetbrains.IntelliJ-IDEA-Community
step_end "IntelliJ IDEA installed"

# Windows RTC dual boot fix
if confirm "⚡️Are you dual boot with Windows or not?"; then
  step_start "⏰ Setting Windows RTC compatibility to local time = 0"
  sudo timedatectl set-local-rtc 0 --adjust-system-clock || log_warn "timedatectl failed"
  step_end "Windows RTC setting updated"
else
  log_warn "Skipped dual boot fix."
fi

# System Cleanup
step_start "🧹 Cleaning up package caches"
sudo dnf clean all
flatpak uninstall --unused -y
step_end "Cleanup complete"

# Final message
echo -e "${GREEN}🎉 All done! Please restart your computer to finalize the setup. Enjoy Fedora! 🚀${NC}"
echo "If you need help, consult the README or ask in the community."

exit 0
