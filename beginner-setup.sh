#!/bin/bash

# Fedora 42 Post-Install Setup Script with Advanced Logging and Interactivity

set -euo pipefail
IFS=$'\n\t'

# === Logging, Colors, Prompts ===
LOG_DIR="$HOME/fedora42-setup-logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/fedora42-setup-$(date +%Y%m%d_%H%M%S).log"
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
      [Yy]* ) return 0 ;;
      [Nn]* ) return 1 ;;
      * ) echo "Please answer y or n." ;;
    esac
  done
}
step_start() { echo -e "\n${CYAN}🔧 ==> Starting: $* ...${NC}"; }
step_end()   { echo -e "${CYAN}✔️ ==> Completed: $*${NC}\n"; }

# === Script ===

clear
echo -e "${GREEN}🚀 Fedora 42 Universal Post-Install (Beginner Edition)${NC}"
echo "📄 Log file: $LOGFILE"

step_start "🌐 Checking Internet Connectivity"
if ! ping -c1 -W2 8.8.8.8 &>/dev/null; then
  log_error "No internet detected. Connect and re-run this script."
  exit 1
fi
log_info "Internet OK."
step_end "Network checked"

step_start "📦 Enabling RPM Fusion & Flathub repositories"
sudo dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
step_end "Repos enabled"

step_start "🔄 System Upgrade (all software)"
sudo dnf upgrade --refresh -y
step_end "System upgraded"

# === GPU Drivers - User Select ===
step_start "🖥️ GPU Drivers Installation"
echo "Welcome! For the best graphics, select your GPU (you may run this for each if hybrid):"
while true; do
  echo -e "  1) NVIDIA\n  2) AMD\n  3) Intel\n  4) None / Skip"
  log_prompt "Enter choice [1-4]: "
  read -r gpu_choice
  case "$gpu_choice" in
    1)
      log_info "NVIDIA selected."
      echo "⚠️ This may take several minutes (kernel modules)."
      if confirm "Install NVIDIA drivers now?"; then
        step_start "Installing NVIDIA drivers"
        if lspci -nnk | grep -i nvidia | grep -E 'RTX 40|RTX 50|4090|5080|5090' &>/dev/null; then
          echo "%_with_kmod_nvidia_open 1" | sudo tee /etc/rpm/macros.nvidia-kmod >/dev/null
          log_warn "Special open kernel module enabled (RTX 4000/5000 series)."
        else
          sudo rm -f /etc/rpm/macros.nvidia-kmod 2>/dev/null || true
        fi
        sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-vaapi-driver
        sudo akmods --force
        sudo dracut --force
        sudo systemctl enable --now nvidia-persistenced.service || true
        sudo dnf install libva-nvidia-driver
        log_info "✅ NVIDIA drivers installed. Please reboot for changes."
        step_end "NVIDIA drivers"
      else
        log_warn "Skipped NVIDIA install."
      fi ;;
    2)
      log_info "AMD selected."
      echo "⚠️ Installing AMD graphics drivers & media acceleration."
      if confirm "Install AMD GPU drivers?"; then
        step_start "AMD GPU drivers"
        sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
        sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld
        sudo dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
        log_info "✅ AMD drivers installed."
        step_end "AMD drivers"
      else
        log_warn "Skipped AMD install."
      fi ;;
    3)
      log_info "Intel selected."
      echo "⚠️ Installing Intel graphics drivers for both new and old generations."
      if confirm "Install Intel GPU drivers?"; then
        step_start "Intel GPU drivers"
        sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
        sudo dnf install -y intel-media-driver || true
        sudo dnf install -y intel-vaapi-driver || true
        log_info "✅ Intel drivers installed."
        step_end "Intel drivers"
      else
        log_warn "Skipped Intel install."
      fi ;;
    4)
      log_warn "Skipped GPU drivers installation as requested."
      break ;;
    *) echo "❌ Invalid option. Choose 1, 2, 3 or 4."; continue ;;
  esac
  echo ""
  if confirm "Install drivers for another GPU (for hybrid setups)?"; then continue; else break; fi
done
step_end "GPU Drivers Installation"

# === Multimedia Codecs (Universal) ===
step_start "🎵 Installing Multimedia Codecs (audio, video, DVD, MP3, etc.)"
sudo dnf swap ffmpeg-free ffmpeg --allowerasing
sudo dnf install -y gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame\* --exclude=gstreamer1-plugins-bad-free-devel
sudo dnf group install -y sound-and-video
sudo dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
log_info "✅ Multimedia codecs installed — enjoy smooth playback."
step_end "Codecs installed"

# === Set Hostname (Optional, customizable) ===
step_start "🏷️ Setting hostname to 'fedora'"
sudo hostnamectl set-hostname fedora
step_end "Hostname set"

# === Fonts - FiraCode Nerd Font ===
if confirm "🔤 Install FiraCode Nerd Font (for easy-reading programming fonts)?"; then
  step_start "📚 Installing FiraCode Nerd Font"
  mkdir -p ~/.local/share/fonts
  curl -Lf -o ~/.local/share/fonts/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
  unzip -o ~/.local/share/fonts/FiraCode.zip -d ~/.local/share/fonts/FiraCode
  fc-cache -fv
  step_end "FiraCode installed"
else
  log_warn "Skipped FiraCode Nerd Font install."
fi

# === Zsh & Starship Prompt for Terminal (Friendly) ===
if confirm "🛠️ Make terminal beginner-friendly with Zsh + Starship?"; then
  step_start "⚙️ Installing Zsh & Starship"
  sudo dnf install -y zsh
  chsh -s "$(which zsh)"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
  mkdir -p ~/.config
  starship preset gruvbox-rainbow -o ~/.config/starship.toml
  if ! grep -q 'starship init zsh' ~/.zshrc; then
    echo 'eval "$(starship init zsh)"' >> ~/.zshrc
  fi
  log_info "Next time you open a terminal, you'll see a colorful prompt!"
  step_end "Zsh & Starship setup"
else
  log_warn "Skipped Zsh and Starship setup."
fi

# === Minimal Dev Tools (Beginner-Friendly) ===
if confirm "🖥️ Install basic developer tools (gcc, clang, git, python, cmake)?"; then
  step_start "📦 Installing basic development tools"
  sudo dnf group install -y development-tools c-development
  sudo dnf install -y gcc clang cmake git-all python3-pip
  step_end "Development tools installed"
else
  log_warn "Skipped development tools install."
fi

# === Faster Boot (Network Wait Disable) ===
if confirm "⚡ Make Fedora boot faster (skip network wait)?"; then
  step_start "Disabling NetworkManager-wait-online.service"
  sudo systemctl disable NetworkManager-wait-online.service
  step_end "NetworkManager-wait-online.service disabled"
else
  log_warn "Skipped boot optimization."
fi

# === Firewall ON (Best Practice) ===
step_start "🔥 Enabling FirewallD (protection on by default)"
sudo systemctl enable --now firewalld
step_end "Firewall enabled"

# === Fonts and Archive Utilities ===
step_start "📂 Installing fonts & archive utilities"
sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig p7zip p7zip-plugins unrar
step_end "Fonts & archive utilities installed"

# === Visual Studio Code (Universal Editor for Beginners & Pros) ===
if confirm "💻 Install Visual Studio Code (coding, docs, notes)?"; then
  step_start "Installing VS Code"
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
  sudo dnf install -y code
  step_end "Visual Studio Code installed"
else
  log_warn "Skipped Visual Studio Code installation."
fi

# Windows RTC dual boot fix
step_start "⏰ Setting Windows RTC compatibility to local time = 0"
sudo timedatectl set-local-rtc 0 --adjust-system-clock
step_end "Windows RTC setting updated"

# === Final Cleanup ===
step_start "🧹 Cleaning package caches"
sudo dnf clean all
sudo flatpak uninstall --unused -y
step_end "System cleanup done"

# === Final Message ===
echo -e "${GREEN}🎉 All done! Please reboot your computer to finalize driver and system setup. Enjoy Fedora! 🚀${NC}"
echo "For more software, you can use 'dnf' or 'flatpak' commands, or explore the Fedora Software app."

exit 0
