#!/bin/bash
# Fedora 42 Post-Install Setup Script with Advanced Logging and Interactivity
# Supports Workstation (GNOME) and KDE
# Run as a user with sudo privileges

set -euo pipefail
IFS=$'\n\t'

# === Setup Logging ===

LOG_DIR="$HOME/fedora42-setup-logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/fedora42-setup-$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$LOGFILE") 2>&1

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# === Functions ===

log_info()   { echo -e "${GREEN}✅ [INFO]${NC} $*"; }
log_warn()   { echo -e "${YELLOW}⚠️ [WARN]${NC} $*"; }
log_error()  { echo -e "${RED}❌ [ERROR]${NC} $*" >&2; }
log_prompt() { echo -ne "${BLUE}❓ [INPUT]${NC} $*"; }

confirm() {
  # Loop until yes/no answer received
  while true; do
    log_prompt "$1 [y/n]: "
    read -r ans
    case "$ans" in
      [Yy]* ) return 0 ;;
      [Nn]* ) return 1 ;;
      * ) echo "Please answer y or n." ;;
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
  local prompt="$1"
  shift
  local options=("$@")
  local opt

  while true; do
    echo -e "${CYAN}📋 ${prompt}${NC}"
    for i in "${!options[@]}"; do
      echo "  $((i+1))) ${options[$i]}"
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
echo -e "${GREEN}🚀 Fedora 42 Post-Install Setup Script (with advanced logging and interactivity)${NC}"
echo "📄 Log file: $LOGFILE"

check_internet

step_start "📦 Enabling RPM Fusion & Flathub repositories"
sudo dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
step_end "Repositories enabled"

step_start "🔄 System upgrade (including all repos)"
sudo dnf upgrade --refresh -y
step_end "System upgraded"

# GPU Driver Installation
gpu_choice=$(choose_option "Select your GPU type:" \
  "Intel/AMD only" "NVIDIA only" "Hybrid Intel/AMD + NVIDIA (Optimus)" "Skip GPU driver installation")

step_start "🖥️ Installing GPU drivers - choice: $gpu_choice"
case "$gpu_choice" in
  "Intel/AMD only")
    sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
    sudo dnf install -y mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld
    sudo dnf install -y intel-media-driver || true
    ;;
  "NVIDIA only")
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-vaapi-driver
    ;;
  "Hybrid Intel/AMD + NVIDIA (Optimus)")
    sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU \
                        mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld intel-media-driver || true
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-vaapi-driver
    log_warn "For hybrid setups, consider installing prime-select or managing GPU switching with GNOME extensions."
    ;;
  "Skip GPU driver installation")
    log_warn "User chose to skip GPU driver installation."
    ;;
  *)
    log_error "Unknown GPU option: $gpu_choice. Skipping GPU driver installation."
    ;;
esac
step_end "GPU driver installation phase"

step_start "🏷️ Setting hostname to 'fedora'"
sudo hostnamectl set-hostname fedora
step_end "Hostname set"

# Install TLP minimal
step_start "🔋 Installing TLP (power management)"
sudo dnf install -y https://repo.linrunner.de/fedora/tlp/repos/releases/tlp-release.fc$(rpm -E %fedora).noarch.rpm
sudo dnf install -y tlp tlp-rdw
sudo dnf remove -y tuned tuned-ppd || true
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket || true
sudo systemctl enable --now tlp
step_end "TLP installed and enabled"

# Essential applications prompt
if confirm "📦 Would you like to install essential applications (Zen Browser, Telegram, Discord, Kate, VLC, Ghostty)?"; then
  step_start "📥 Installing essential applications"
  sudo flatpak install -y flathub app.zen_browser.zen org.telegram.desktop
  sudo dnf install -y discord kate vlc
  sudo dnf copr enable -y scottames/ghostty
  sudo dnf install -y ghostty
  step_end "Essential applications installed"
else
  log_warn "Skipped installation of essential applications"
fi

# Install FiraCode Nerd Font prompt
if confirm "🔤 Install FiraCode Nerd Font?"; then
  step_start "📚 Installing FiraCode Nerd Font"
  mkdir -p ~/.local/share/fonts
  curl -Lf -o ~/.local/share/fonts/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
  unzip -o ~/.local/share/fonts/FiraCode.zip -d ~/.local/share/fonts/FiraCode
  fc-cache -fv
  step_end "FiraCode Nerd Font installed"
else
  log_warn "Skipped FiraCode Nerd Font installation"
fi

# Zsh + Starship prompt
if confirm "🛠️ Install and configure Zsh with Starship prompt?"; then
  step_start "⚙️ Installing Zsh and Starship prompt"
  sudo dnf install -y zsh
  current_shell=$(getent passwd "$USER" | cut -d: -f7)
  zsh_path=$(which zsh)
  if [[ "$current_shell" != "$zsh_path" ]]; then
    chsh -s "$zsh_path"
    log_info "Default shell changed to Zsh"
  else
    log_info "Zsh already default shell"
  fi
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
  mkdir -p ~/.config
  starship preset gruvbox-rainbow -o ~/.config/starship.toml
  if ! grep -q 'starship init zsh' ~/.zshrc; then
    echo 'eval "$(starship init zsh)"' >> ~/.zshrc
  fi
  step_end "Zsh and Starship prompt installed and configured"
else
  log_warn "Skipped Zsh and Starship prompt setup"
fi

# Development tools installation
if confirm "🖥️ Install developer tools and programming languages (gcc, clang, Java JDK, git-all, python, nodejs, podman, docker)?"; then
  step_start "📦 Installing development tools and languages"
  sudo dnf group install -y development-tools c-development
  sudo dnf install -y gcc clang cmake git-all python3-pip java-21-openjdk-devel nodejs podman docker
  sudo systemctl enable --now docker
  step_end "Development tools installed"
else
  log_warn "Skipped developer tools installation"
fi

# KDE install prompt and desktop customization
if confirm "🎨 Would you like to install KDE Plasma desktop environment?"; then
  step_start "🖥️ Installing KDE Plasma desktop"
  sudo dnf group install -y "KDE Plasma Workspaces"
  step_end "KDE Plasma installed"
else
  log_warn "Skipped KDE Plasma desktop installation"
fi

# Desktop environment customization choice
de_choice=$(choose_option "🖼️ Choose your desktop environment for customization:" "GNOME Workstation" "KDE Plasma")

step_start "🎨 Installing Orchis theme and Tela icon theme (works on GNOME & KDE)"

cd "$HOME"
if [[ ! -d Orchis-kde ]]; then
  git clone https://github.com/vinceliuice/Orchis-kde.git
fi
cd Orchis-kde
./install.sh

cd "$HOME"
if [[ ! -d Tela-icon-theme ]]; then
  git clone https://github.com/vinceliuice/Tela-icon-theme.git
fi
cd Tela-icon-theme
sudo ./install.sh -d /usr/share/icons

cd "$HOME"
rm -rf Orchis-kde Tela-icon-theme
step_end "Orchis theme & Tela icon theme installed"

if [[ "$de_choice" == "GNOME Workstation" ]]; then
  step_start "🖼️ Installing GNOME customization tools"
  sudo dnf install -y gnome-tweaks
  sudo flatpak install -y flathub com.mattjakeman.ExtensionManager
  step_end "GNOME customization tools installed"
  echo "💡 Use GNOME Tweaks to select Orchis GTK theme and Tela icons."
elif [[ "$de_choice" == "KDE Plasma" ]]; then
  step_start "🎨 Installing KDE customization tools"
  sudo dnf install -y kvantum
  if command -v kbuildsycoca5 &>/dev/null; then
    kbuildsycoca5
  fi
  step_end "KDE customization tools installed"
  echo "💡 Use KDE System Settings to apply Orchis theme and Tela icon pack."
fi

# Faster boot optimization
if confirm "⚡ Disable NetworkManager-wait-online.service for faster boot?"; then
  step_start "Disabling NetworkManager-wait-online.service"
  sudo systemctl disable NetworkManager-wait-online.service
  step_end "Disabled NetworkManager-wait-online.service"
else
  log_warn "Skipped disabling NetworkManager-wait-online.service"
fi

# Enable firewall
step_start "🔥 Enabling FirewallD"
sudo systemctl enable --now firewalld
step_end "FirewallD enabled"

# Fonts and archive utilities
step_start "📂 Installing fonts and archive utilities"
sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig p7zip p7zip-plugins unrar
step_end "Fonts and archive utilities installed"

# Visual Studio Code
step_start "💻 Installing Visual Studio Code"
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo tee /etc/yum.repos.d/vscode.repo > /dev/null <<'EOF'
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
sudo dnf install -y code
step_end "Visual Studio Code installed"

# IntelliJ IDEA latest community edition
step_start "💻 Downloading and installing latest IntelliJ IDEA Community Edition"
IDEA_URL="https://download.jetbrains.com/idea/ideaIC.tar.gz"
INSTALL_DIR="/opt/intellij-idea-community"
TMP_TAR="/tmp/ideaIC-latest.tar.gz"

if [[ ! -d "$INSTALL_DIR" ]]; then
  sudo curl -L -o "$TMP_TAR" "$IDEA_URL"
  sudo mkdir -p "$INSTALL_DIR"
  sudo tar -xzf "$TMP_TAR" -C "$INSTALL_DIR" --strip-components=1
  rm "$TMP_TAR"
  local_desktop_entry="$HOME/.local/share/applications/jetbrains-idea.desktop"
  if [[ ! -f "$local_desktop_entry" ]]; then
    cat > "$local_desktop_entry" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA Community Edition
Icon=$INSTALL_DIR/bin/idea.png
Exec=$INSTALL_DIR/bin/idea.sh %f
Comment=Integrated Development Environment
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-idea
EOF
    log_info "Created desktop entry for IntelliJ IDEA."
  fi
else
  log_warn "IntelliJ IDEA already installed at $INSTALL_DIR. Skipping download."
fi
step_end "IntelliJ IDEA installed"

# Windows RTC dual boot fix
step_start "⏰ Setting Windows RTC compatibility to local time = 0"
sudo timedatectl set-local-rtc 0 --adjust-system-clock
step_end "Windows RTC setting updated"

# System cleanup
step_start "🧹 Cleaning package caches and removing orphaned packages"
sudo dnf clean all
sudo dnf autoremove -y
step_end "System cleanup complete"

echo -e "${GREEN}=====================================================================${NC}"
echo -e "${GREEN}🎉 Fedora 42 Workstation & KDE Post-Install Setup Complete!${NC}"
echo -e "📄 Log file saved as: ${LOGFILE}"
echo -e "⌛ Please reboot your system to apply all changes."
echo -e "🔧 Remember to configure Ghostty terminal and other manual settings as needed."
echo -e "🛠️ Use your separate TLP config script for advanced battery management."
echo -e "${GREEN}=====================================================================${NC}"

if confirm "🔄 Reboot now?"; then
  sudo reboot
else
  echo "💤 Reboot postponed by user. Please reboot later."
fi
