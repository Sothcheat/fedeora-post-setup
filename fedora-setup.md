# Complete Fedora 42 Workstation Setup Guide for ASUS Zenbook S16  
*Optimized for Battery, Performance, Developer Tools, Modern Visuals & Dual Boot*

## 1. Preparation

- **Backup your data:** Safeguard important files from the Zenbook and Windows partition.
- **Download Fedora 42 Workstation:** Get the latest ISO from Fedora’s official site.
- **Create a bootable USB:** Use tools such as Rufus (Windows) or Balena Etcher (cross-platform).
- **Check Secure Boot/BIOS:**
  - Enter BIOS (usually by pressing F2 at boot).
  - Disable Secure Boot if planning to use 3rd-party drivers or kernels.
  - Enable AHCI mode for best SSD compatibility.
- **Shrink Windows partition:** In Windows, use Disk Management to free space for Fedora (recommended: 60–100GB).

## 2. Installation

- **Boot from USB:** Insert USB and power on while pressing Esc or F12 to trigger boot device selection.
- **Start Fedora Live Session:** Select “Try Fedora”.
- **Start Installer:** Double-click “Install to Hard Drive”.
- **Partitioning:**
  - Choose “Custom” or “Install alongside Windows Boot Manager” for dual-boot.
  - For custom: Create root (`/`), home (`/home`), and swap partitions. Use `ext4` or `btrfs`.
- **Set up user / timezone / hostname.**
- **Install & reboot.**

## 3. First Boot & Essential Updates

- **Connect to Wi-Fi.**
- **Run initial updates:**
  ```bash
  sudo dnf update -y
  sudo dnf upgrade -y
  ```
- **Reboot after updates.**

## 4. Enable Third-Party Repositories

- Open “Software” app → Go to Software Repositories → Enable third-party (RPM Fusion, Flathub):
  ```bash
  # RPM Fusion Free & Nonfree
  sudo dnf install \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    
  # Update RPM
  sudo dnf group upgrade core -y
  sudo dnf check-update
  ```
  
## 5. Hardware Compatibility & Drivers

- **Wi-Fi, Bluetooth & Touchpad:** Included in kernel (Fedora’s fast kernel updates support new ASUS hardware).
- **Firmware Updates:**  
  - Install GNOME Firmware or use terminal:
    ```bash
    sudo fwupdmgr get-devices
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-updates
    sudo fwupdmgr update
    ```
- **Graphics Drivers:**  
  - AMD/Intel:
    ```bash
    # Basic drivers and Vulkan support
    sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
    ```
  - AMD:
    ```bash
    # AMD video acceleration (makes videos smoother)
    sudo dnf install -y mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld
    ```
  - Newer Intel:
    ```bash
    # Intel video acceleration (for newer Intel GPUs)
    sudo dnf install -y intel-media-driver
    ```
  - Older Intel:
    ```bash
    # Intel video acceleration (for Grandfather Intel GPUs)
    sudo dnf install libva-intel-driver
    ```
  - NVIDIA (if hybrid): Use RPM Fusion instructions for NVIDIA drivers.
- **Give your Computer Name**  
  - This is purely cosmetic but makes you feel more at home. Pick something fun!:
  ```bash
  # Replace with whatever you want
  sudo hostnamectl set-hostname zenya-sothcheat
  ```
- **Video Codec**
  - Fedora ships with basically no codecs because of patent issues. This fixes that.
  ```bash
  # Replace the neutered ffmpeg with the real one
  sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing

  # Install all the GStreamer plugins
  sudo dnf install -y gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame\* --exclude=gstreamer1-plugins-bad-free-devel
    
  # Install multimedia groups
  sudo dnf4 group install multimedia
  sudo dnf group install -y sound-and-video
  ```
- **Hardware acceleration**
  - This makes video playback use your GPU instead of hammering your CPU.
  ```bash
  # Install VA-API stuff
  sudo dnf install -y ffmpeg-libs libva libva-utils
  ```
  ```bash
  # If you have NVIDIA, add this too
  sudo dnf install -y nvidia-vaapi-driver
  ```
## 6. Power & Battery Life Optimization

- **Install TLP (power management):**
  ```bash
  #Add TLP Repository 
  sudo dnf install https://repo.linrunner.de/fedora/tlp/repos/releases/tlp-release.fc$(rpm -E %fedora).noarch.rpm
  
  #Install TLP
  sudo dnf install tlp tlp-rdw -y
  
  #Remove conflicting power profile demone
  sudo dnf remove tuned tuned-ppd
  
  #Enable TLP Service
  sudo systemctl enable tlp --now
  
  #Mask the following services to avoid conflicts with TLP’s Radio Device Switching options
  sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
  ```
- **Install Power Profiles Daemon (already included, but update if needed):**
  ```bash
  sudo dnf install power-profiles-daemon -y
  ```
- **Set battery charging limit (if supported):**
  - For ASUS, add/edit in `/etc/tlp.conf`:
    ```
    START_CHARGE_THRESH_BAT0=75
    STOP_CHARGE_THRESH_BAT0=80
    ```
  - Reboot and check with `tlp-stat`.
  - Note: ASUS kernel support may still vary; success depends on firmware/hardware.

- **Disable unused startup applications:** Use GNOME Tweaks or Startup Applications.
- **Faster Boot**
  ```bash
  sudo systemctl disable NetworkManager-wait-online.service
  ```
- **Encrypted DNS**
  - This encrypts your DNS queries so your ISP can't see what websites you're visiting.
  - First add the cloudflared repository and install it with:
  ```bash
  #Add Cloudflared repository
  sudo dnf config-manager addrepo --from-repofile=https://pkg.cloudflare.com/cloudflared.repo

  # Install cloudflared
  sudo dnf install -y cloudflared  
  ```
  - Then do the rest:
  ```
  # Create a systemd service for cloudflared
    sudo tee /etc/systemd/system/cloudflared.service > /dev/null <<'EOF'
    [Unit]
    Description=Cloudflared DNS-over-HTTPS proxy
    After=network.target

    [Service]
    ExecStart=/usr/bin/cloudflared proxy-dns --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query
    Restart=on-failure
    User=nobody
    CapabilityBoundingSet=CAP_NET_BIND_SERVICE
    AmbientCapabilities=CAP_NET_BIND_SERVICE
    NoNewPrivileges=true

    [Install]
    WantedBy=multi-user.target
    EOF

  # Reload and enable the service
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable --now cloudflared

  # Configure systemd-resolved to use 127.0.0.1 (cloudflared)
    sudo mkdir -p /etc/systemd/resolved.conf.d
    sudo tee /etc/systemd/resolved.conf.d/dns-over-https.conf > /dev/null <<'EOF'
    [Resolve]
    DNS=127.0.0.1
    FallbackDNS=1.1.1.1
    DNSSEC=yes
    Cache=yes
    EOF

  # Tell NetworkManager to use systemd-resolved
    sudo tee /etc/NetworkManager/conf.d/dns.conf > /dev/null <<'EOF'
    [main]
    dns=systemd-resolved
    EOF

  # Restart services
    sudo systemctl restart cloudflared
    sudo systemctl restart systemd-resolved
    sudo systemctl restart NetworkManager

  # Test DNS resolution
    dig +short example.com

  # Check current DNS status
    resolvectl status
  ```

## 7. Modern Visuals & Desktop Tuning

- **Customize GNOME:**
  - Open GNOME Extensions app and add desired extensions for workspaces, battery monitoring, and productivity enhancements.
  - Use GNOME Tweaks for fonts, icons, and behavior.
  ```bash
  sudo dnf install gnome-tweaks
  ```
  - Extension Manager is essential Don't even think about skipping this one. Makes managing extensions actually easy:
  ```bash
  sudo flatpak install -y flathub com.mattjakeman.ExtensionManager
  ```
  - Terminal Transparency it's just better with it for me:
  ```bash
  gsettings set org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$PTYXIS_PROFILE/ opacity .80
  ```
- **Install additional desktop environments:**  
  ```bash
  sudo dnf groupinstall "KDE Plasma Workspaces"
  sudo dnf groupinstall "Xfce Desktop"
  ```
  - (Optional, KDE/XFCE spins can further enhance battery life.)
  
## 8. Essential Developer Tools

- **Install build essentials and compilers:**
  ```bash
  sudo dnf groupinstall "Development Tools"
  sudo dnf groupinstall "C Development Tools and Libraries"
  sudo dnf install gcc clang cmake git -y
  ```
- **Python, Java, Node.js, etc.:**
  - Python: `sudo dnf install python3-pip`
  - Java: `sudo dnf install java-latest-openjdk`
  - Node.js: `sudo dnf install nodejs`
- **IDEs and editors:**
  - GNOME Software/Flathub: VS Code, PyCharm, IntelliJ IDEA.
  - VS Code: 
  ```bash
  # Import Microsoft GPG key
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
  
  # Install VS Code
  sudo dnf check-update
  sudo dnf install -y code
  ```
  - IntelliJ IDEA:

### Method 1: **Install IntelliJ IDEA using the official tarball (manual installation)**

1. **Download IntelliJ IDEA**

Go to the official JetBrains website and download the Linux tarball:

[Community Edition](https://www.jetbrains.com/idea/download/#section=linux)

[Ultimate Edition](https://www.jetbrains.com/idea/download/#section=linux)

Choose the **"tar.gz"** package.

2. **Extract the archive**

Open a terminal and navigate to the folder where you downloaded the tarball, then extract it, for example to `/opt` (you need sudo for this):

```bash
sudo tar -xzf ideaIC-*.tar.gz -C /opt
```

*Replace `ideaIC-*.tar.gz` with your downloaded file name. For Ultimate edition, it might be `ideaIU-*.tar.gz`.*

3. **Run IntelliJ IDEA**

Navigate to the `bin` directory inside the extracted folder, then launch the app:

```bash
cd /opt/idea-IC/bin
./idea.sh
```

4. (Optional) **Create a desktop shortcut**

Inside IntelliJ IDEA, use **Tools > Create Desktop Entry** to make launching easier later.

### Method 2: **Install via Flatpak**

If you’re open to Flatpak (an alternative to Snap), you can install IntelliJ IDEA Community Edition from Flathub:

1. **Make sure Flatpak is installed**

```bash
sudo dnf install flatpak
```

2. **Add the Flathub repository if you haven't already**

```bash
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

3. **Install IntelliJ IDEA Community Edition**

```bash
flatpak install flathub com.jetbrains.IntelliJ-IDEA-Community
```

4. **Run IntelliJ IDEA**

You can start it from your desktop menu or with:

```bash
flatpak run com.jetbrains.IntelliJ-IDEA-Community
```

- **Docker, Podman, Virtualization, Git:**
  ```bash
  sudo dnf install podman docker -y
  sudo systemctl enable --now docker
  sudo dnf install -y git
  ```
- **Flatpak / Snap support:**
  ```bash
  sudo flatpak remote-delete fedora
  sudo dnf install flatpak -y
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  # Update Everything
  sudo flatpak update --appstream
  ```
  - **Flatpak auto-updates**
  You can keep your Flatpak apps up to date automatically. This setup updates your Flatpaks every 24 hours and especially helpful if you disable GNOME Software on startup.
  ```
  # Create the service unit
  sudo tee /etc/systemd/system/flatpak-update.service > /dev/null <<'EOF'
  [Unit]
  Description=Update Flatpak apps automatically
  
  [Service]
  Type=oneshot
  ExecStart=/usr/bin/flatpak update -y --noninteractive
  EOF
  
  # Create the timer unit
  sudo tee /etc/systemd/system/flatpak-update.timer > /dev/null <<'EOF'
  [Unit]
  Description=Run Flatpak update every 24 hours
  Wants=network-online.target
  Requires=network-online.target
  After=network-online.target
  
  [Timer]
  OnBootSec=120
  OnUnitActiveSec=24h
  
  [Install]
  WantedBy=timers.target
  EOF
  
  # Reload systemd and enable the timer
  sudo systemctl daemon-reload
  sudo systemctl enable --now flatpak-update.timer
  
  # Check the status to verify everything is working
  sudo systemctl status flatpak-update.timer
  ```

## 9. Additional Productivity & Usability Steps

- **Set up GNOME favorites and shortcuts.**
- **Configure night light, Bluetooth, sound devices.**
- **Printer/scanner setup:**  
  - Open “Settings” → “Printers”.
- **Enable firewall:**  
  ```bash
  sudo systemctl enable --now firewalld
  ```
- **Achieve Support**
  - Because you'll definitely need to extract a .rar file someday.
  ```bash
  sudo dnf install -y p7zip p7zip-plugins unrar
  ```
- **Microsoft Fonts (Unfortunately Still Needed)**
  - Web pages and documents still look weird without these.
  ```bash
  # Install dependencies
  sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig

  # Install the fonts
  sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm

  # Update font cache
  sudo fc-cache -fv
  ```
- **AppImage Support**
  - Some apps only come as AppImages. This makes them work.
  ```bash
  # Install FUSE
  sudo dnf install -y fuse libfuse2

  # Optional: AppImage manager (actually pretty useful)
  sudo flatpak install -y flathub it.mijorus.gearlever
  ```
- **Backups:**  
  - Use Deja Dup (default) or install Timeshift for system snapshots.
  
- **My Favorite Browser:**  
  - [Zen-Browser](https://zen-browser.app/)
  ```bash
  sudo flatpak install flathub app.zen_browser.zen
  ```

## 10. Dual Boot Maintenance

- **Accessing Windows:** Fedora’s GRUB will handle booting.
- **Windows updates:** Boot into Windows occasionally to keep it updated.
- **Time differences:** If time is inconsistent between OSes, in Fedora run:
  ```bash
  sudo timedatectl set-local-rtc 1 --adjust-system-clock
  ```

## 11. Ongoing Best Practices

- **Update frequently:**  
  ```bash
  sudo dnf upgrade --refresh
  ```
- **Check for firmware updates monthly.**
- **Search Fedora and Zenbook user forums for device-specific tweaks.**
- **Monitor battery health with TLP and GNOME battery indicator.**
- **Periodically review running services and remove unused apps for optimal performance.**
- **System Cleanup**  
  ```bash
  # Clean package cache
  sudo dnf clean all

  # Remove orphaned packages
  sudo dnf autoremove -y

  # Remove old kernels (if you have too many)
  # sudo dnf remove $(dnf repoquery --installonly --latest-limit=-3 -q)
  ```
---
