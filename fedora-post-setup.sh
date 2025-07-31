#!/bin/bash
# Fedora 42 Post-Install Setup Script for Workstation and KDE
# Optimized for Battery, Performance, Developer Tools & Essential Apps
# Run as a user with sudo privileges

set -euo pipefail

echo "====================================================================="
echo "⚙️  Starting Fedora 42 Workstation/KDE Post-Installation Setup Script"
echo "====================================================================="

### 1. Enable Third-Party Repositories FIRST
echo "📦 Enabling RPM Fusion Free & Nonfree repositories..."
sudo dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

echo "🖥️ Adding Flathub repository for Flatpak apps..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

### 2. Full System Upgrade with enabled repos
echo "🔄 Fully updating system with all repos enabled..."
sudo dnf upgrade --refresh -y

### 3. Hardware Compatibility & GPU Driver Installation

echo
echo "🖥️ Please select your GPU type:"
echo "  1) Intel/AMD only"
echo "  2) NVIDIA only"
echo "  3) Hybrid Intel/AMD + NVIDIA (Optimus)"
read -rp "Enter choice [1/2/3]: " gpu_choice

case "$gpu_choice" in
  1)
    echo "💻 Installing Intel/AMD GPU drivers..."
    sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
    sudo dnf install -y mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld
    sudo dnf install -y intel-media-driver || true
    ;;
  2)
    echo "💻 Installing NVIDIA proprietary drivers..."
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
    sudo dnf install -y nvidia-vaapi-driver
    ;;
  3)
    echo "💻 Installing Hybrid Intel/AMD + NVIDIA drivers..."
    sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
    sudo dnf install -y mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld
    sudo dnf install -y intel-media-driver || true

    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
    sudo dnf install -y nvidia-vaapi-driver

    echo "⚠️ Note: For hybrid GPU switching, consider installing prime-select or using GNOME extensions."
    ;;
  *)
    echo "⚠️ Invalid selection, skipping GPU driver installation."
    ;;
esac

### 4. Set Hostname
echo "🏷️ Setting hostname to 'fedora'..."
sudo hostnamectl set-hostname fedora

### 5. Install TLP power management (without config)
echo "🔋 Installing TLP (power management) only..."
sudo dnf install -y https://repo.linrunner.de/fedora/tlp/repos/releases/tlp-release.fc$(rpm -E %fedora).noarch.rpm
sudo dnf install -y tlp tlp-rdw

# Remove conflicting packages/services
sudo dnf remove -y tuned tuned-ppd || true
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket || true

sudo systemctl enable --now tlp

### 6. Essential Applications Installation

echo "📦 Installing Essential Applications..."

# Flatpak apps (Zen Browser and Telegram Desktop)
sudo flatpak install -y flathub app.zen_browser.zen
sudo flatpak install -y flathub org.telegram.desktop

# DNF apps: Discord, Kate, VLC
sudo dnf install -y discord kate vlc

# Enable and install Ghostty from COPR repository
sudo dnf copr enable -y scottames/ghostty
sudo dnf install -y ghostty

### 7. FiraCode Nerd Fonts Installation

echo "🔤 Installing FiraCode Nerd Font..."
mkdir -p ~/.local/share/fonts
curl -L -o ~/.local/share/fonts/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
unzip -o ~/.local/share/fonts/FiraCode.zip -d ~/.local/share/fonts/FiraCode
fc-cache -fv

### 8. Zsh, Starship prompt, and Ghostty configuration

echo "🛠️ Installing Zsh, setting as default shell, and configuring Starship..."

sudo dnf install -y zsh

# Set zsh as default shell for current user if not already set
current_shell=$(getent passwd "$USER" | cut -d: -f7)
zsh_path=$(which zsh)

if [[ "$current_shell" != "$zsh_path" ]]; then
  echo "⚙️ Changing shell to Zsh for user $USER..."
  chsh -s "$zsh_path"
else
  echo "⚙️ Zsh already default shell."
fi

echo "🚀 Installing Starship prompt..."
curl -fsSL https://starship.rs/install.sh | sh -s -- -y

echo "🎨 Applying Gruvbox Rainbow Powerline Starship preset..."
mkdir -p ~/.config
starship preset gruvbox-rainbow -o ~/.config/starship.toml

if ! grep -q 'starship init zsh' ~/.zshrc; then
  echo 'eval "$(starship init zsh)"' >> ~/.zshrc
fi

echo "⚙️ Note: Please configure Ghostty terminal settings manually as per your preference."

### 9. Development Tools & Languages Installation (Fixed for Fedora 42)

echo "🛠️ Installing Development Tools and Programming Languages..."

sudo dnf group install -y development-tools c-development

sudo dnf install -y gcc clang cmake git-all python3-pip java-21-openjdk-devel nodejs podman docker

sudo systemctl enable --now docker

### 10. Desktop Environment Support (KDE optional)

echo -n "🎨 Would you like to install KDE Plasma desktop environment? (y/N) "
read -r install_kde
install_kde=${install_kde,,}

if [[ "$install_kde" == "y" ]]; then
  echo "📦 Installing KDE Plasma Workspaces..."
  sudo dnf group install -y "KDE Plasma Workspaces"
else
  echo "Skipping KDE Plasma installation..."
fi

### 11. Desktop Environment Customization Choice and Themes/Icons Installation

echo
echo "🎯 Choose your desktop environment for customization:"
echo "  1) GNOME Workstation"
echo "  2) KDE Plasma"
read -rp "Enter choice [1/2]: " de_choice

# Install themes/icons (compatible with both GNOME and KDE)
echo "🎨 Installing Orchis theme and Tela icon theme (works for both GNOME & KDE)..."

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
echo "🧹 Cleaning up temporary theme folders..."
rm -rf Orchis-kde Tela-icon-theme

if [[ "$de_choice" == "1" ]]; then
  echo "🖼️ Installing GNOME Tweaks (for GNOME Workstation)..."
  sudo dnf install -y gnome-tweaks

  echo "📦 Installing GNOME Extension Manager (Flatpak)..."
  sudo flatpak install -y flathub com.mattjakeman.ExtensionManager

  echo "📝 To apply Orchis GTK and Tela icons, use GNOME Tweaks > Appearance."

elif [[ "$de_choice" == "2" ]]; then
  echo "🎨 Installing Kvantum theme engine (for KDE)..."
  sudo dnf install -y kvantum

  # Kvantum and KDE cache rebuild (if needed)
  if command -v kbuildsycoca5 &>/dev/null; then
    echo "♻️ Rebuilding KDE appearance cache..."
    kbuildsycoca5
  fi

  echo "📝 To apply Orchis KDE and Tela icons, use KDE System Settings > Appearance."
else
  echo "⚠️ Invalid option selected. Skipping desktop environment customization tools."
fi

### 12. Faster Boot Optimization

echo "🚀 Disabling NetworkManager-wait-online.service for faster boot..."
sudo systemctl disable NetworkManager-wait-online.service

### 13. Firewall & Security

echo "🔥 Enabling and starting FirewallD..."
sudo systemctl enable --now firewalld

### 14. Fonts and Archive Utilities

echo "📂 Installing fonts and archive utilities..."
sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig p7zip p7zip-plugins unrar

### 15. Visual Studio Code Installation

echo "💻 Installing Visual Studio Code..."

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

### 16. IntelliJ IDEA Community Edition — Official Latest Tarball Installation

echo "💻 Downloading and installing latest IntelliJ IDEA Community Edition..."

IDEA_URL="https://download.jetbrains.com/idea/ideaIC.tar.gz"
INSTALL_DIR="/opt/intellij-idea-community"
TMP_TAR="/tmp/ideaIC-latest.tar.gz"

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "🔄 Downloading latest IntelliJ IDEA Community Edition..."
  sudo curl -L -o "$TMP_TAR" "$IDEA_URL"

  echo "📂 Extracting IntelliJ IDEA to $INSTALL_DIR..."
  sudo mkdir -p "$INSTALL_DIR"
  sudo tar -xzf "$TMP_TAR" -C "$INSTALL_DIR" --strip-components=1

  echo "🧹 Cleaning up downloaded archive..."
  rm "$TMP_TAR"

  # Create desktop entry for IntelliJ IDEA Community Edition
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
    echo "✅ Created desktop entry for IntelliJ IDEA."
  fi
else
  echo "⚠️ IntelliJ IDEA already installed at $INSTALL_DIR"
fi

### 17. Windows RTC (Dual Boot) Settings

echo "⏰ Setting Windows RTC compatibility to local time = 0 (Windows side fix)..."
sudo timedatectl set-local-rtc 0 --adjust-system-clock

### 18. System Cleanup

echo "🧹 Cleaning up package cache and orphaned packages..."
sudo dnf clean all
sudo dnf autoremove -y

echo
echo "====================================================================="
echo "✅ Fedora 42 Workstation & KDE Post-Install Setup Complete!"
echo "👉 Please reboot your system to apply all changes."
echo "👉 Remember to configure Ghostty terminal manually for best experience."
echo "👉 For advanced TLP configuration, use your separate TLP setup script."
echo "====================================================================="
