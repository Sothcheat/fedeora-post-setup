# Fedora Post Setup

Automated post-installation setup script for Fedora 42 Workstation and KDE Plasma.

This script installs essential applications, development tools, themes, fonts, configures shells and prompts, sets up GPU drivers, and much more to streamline your Fedora setup.

**Note:** This is my personal development setup tailored for C++ and Java. If you want to customize the process—skip certain applications, change configurations, or tweak the setup—you can perform a manual installation instead, allowing you to tailor the script to your preferences.

## Quick Start

The simplest way to run the setup script is to use this one-line command in your terminal. It downloads and runs the latest script directly from GitHub:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sothcheat/fedeora-noble-setup/main/setup.sh)"
```

Alternatively, if you prefer `wget`:

```bash
/bin/bash -c "$(wget -qO- https://raw.githubusercontent.com/Sothcheat/fedeora-noble-setup/main/setup.sh)"
```

## What happens when you run the script?

- Enables RPM Fusion Free & Nonfree repositories and Flathub Flatpak repository.
- Fully upgrades your Fedora system.
- Installs GPU drivers based on your hardware selection.
- Sets hostname, installs TLP power management.
- Installs essential applications including browsers, chat apps, media players, and Ghostty terminal.
- Installs FiraCode Nerd Font.
- Configures Zsh shell with Starship prompt.
- Installs groups of development tools and languages (GCC, Clang, Java, Git, Python, NodeJS, Docker, Podman).
- Optionally installs KDE Plasma desktop.
- Applies desktop environment themes and icon packs for GNOME or KDE.
- Installs Visual Studio Code and IntelliJ IDEA Community Edition.
- Applies Windows dual boot RTC fix.
- Cleans up package caches.
- And much more...

## Manual Installation (Optional)

If you want to clone the repository and run the script manually, use these commands:

```bash
git clone https://github.com/Sothcheat/fedeora-noble-setup.git
cd fedeora-noble-setup
chmod +x setup.sh
./setup.sh
```

## Important Notes

- Ensure you have an active internet connection before running the script.
- The script will ask you interactive questions to customize hardware-specific installs and desktop environment preferences.
- You will be prompted for your password to run `sudo` commands.
- Review the script if you want to audit or modify it before running.
- Logs of all actions are saved in `~/fedora42-setup-logs/` with timestamps.
- After running, a reboot is recommended to apply all changes.

## Support & Contributions

Feel free to open issues or submit pull requests if you find bugs or want to suggest improvements.

## License

This project is licensed under the [MIT License](LICENSE).

---

© 2025 Sothcheat Bunna

**Happy Fedora setup!**
