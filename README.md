# Fedora Post-Install Setup

Automated post-installation setup scripts for Fedora 42 Workstation and KDE Plasma.

This project includes two scripts tailored for distinct Fedora user needs:

- **`beginner-setup.sh`** — A universal beginner-friendly setup script that installs essential drivers, codecs, fonts, basic developer tools, and system utilities making Fedora ready-to-use for new Linux users.
- **`personal-setup.sh`** — A comprehensive personal development setup crafted for advanced users and developers, including IDEs, additional dev tools, productivity apps, custom themes, and more.

---

## Quick Start

Run the scripts directly from the internet with one simple command.

### Beginner-Friendly Setup

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sothcheat/fedeora-post-setup/main/beginner-setup.sh)"
```

or using `wget`:

```
/bin/bash -c "$(wget -qO- https://raw.githubusercontent.com/Sothcheat/fedeora-post-setup/main/beginner-setup.sh)"
```

### Personal Development Setup

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sothcheat/fedeora-post-setup/main/personal-setup.sh)"
```

or using `wget`:

```
/bin/bash -c "$(wget -qO- https://raw.githubusercontent.com/Sothcheat/fedeora-post-setup/main/personal-setup.sh)"
```

---

## What Each Script Installs and Configures

### Common features in both scripts:

- Enables **RPM Fusion Free & Nonfree** repositories and **Flathub** Flatpak repo.
- Updates and upgrades your entire Fedora system.
- Interactive GPU driver installation tailored for your hardware (NVIDIA, AMD, Intel).
- Installs **multimedia codecs** for smooth audio/video playback and DVD support.
- Configures programming fonts (e.g., FiraCode Nerd Font).
- Sets up **Zsh shell** with **Starship prompt** (optional).
- Enables and configures firewall (`firewalld`).
- Installs useful archiving and font utilities.

### Additional features in `personal-setup.sh` include:

- Developer toolchains for C/C++, Java (OpenJDK 21), Python, Node.js, Docker, and Podman.
- Popular IDEs: Visual Studio Code, IntelliJ IDEA Community Edition, Apache NetBeans.
- Optional KDE Plasma desktop alongside GNOME.
- Desktop themes and icon packs (Orchis GTK theme, Tela icons).
- Personal productivity apps and terminal utilities.
- Windows dual boot RTC fix and other personal tweaks.

---

## Important Notes

- **Secure Boot** must be disabled in BIOS/UEFI if installing proprietary NVIDIA drivers, or you must manually sign kernel modules for the driver to load.
- The scripts prompt interactively and require your confirmation before installing optional features.
- Log files for all script operations are saved in `~/fedora42-setup-logs/` for easy troubleshooting.
- A **restart is strongly recommended** after running the scripts to apply all driver and system changes properly.
- You should review scripts before execution if you want to make custom modifications.

---

## Manual Usage

Alternatively, clone the repository and run scripts locally:

```
git clone https://github.com/Sothcheat/fedeora-post-setup.git
cd YourRepo
chmod +x beginner-setup.sh personal-setup.sh
./beginner-setup.sh
# or
./personal-setup.sh
```

---

## Support and Contributions

Feel free to open issues or submit pull requests for bugs, feature requests, or improvements.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

© 2025 Your Name or Organization  
*Happy Fedora setup!* 🎉

