---
title: How I Installed Cosmic DE on Arch Linux
date: 2025-02-28
tags:
- Linux
- Arch-Linux
---
# Introduction

I installed [Sway](https://swaywm.org/) at first, but after some recommendations from my community, I decided to
install [Cosmic](https://system76.com/cosmic/?srsltid=AfmBOop17FtW1UOfgED-6p2ifjVtXCeS_D3amYv3cNZtSI5_i7Jk7Num).

## First steps:

When I removed sway, I did it without disabling autostart in my `bash_profile`. This caused me to not be able to
log in to my user; which, is not fine since I want to build packages!

To fix this, I went to my Home folder in my Root user, entered my user's home folder, and commented out the sway 
startup script, rebooted, and now I have a blank TTY screen.

> [!NOTE] 
> Check battery levels
```bash
cat /sys/class/power_supply/BAT0/capacity
```
I am on a laptop, and realized that I can't see any information on the battery, so I learned you can
simply find out the current level with the above command.

## Uninstall Sway:

Remove Sway and all its dependencies along with config files:
```bash
sudo pacman -Rns sway
```

## Installing Yay

> [!WARNING] 
> Skipping yay for now, I got error:  [Makefile:144]: yay error 1 saying Golang connection error.

Apparently you can fix this by skipping compiling with `yay-bin`, but I just didn't proceed with `yay` since cosmic
is available as an official package. Why add possible insecure packages, when you can just install it securely.

> [!NOTE] 
> If you want to proceed with yay:

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay-bin.git # pre-compiled version of yay
cd yay-bin
makepkg -si
```

## COSMIC

Apparently `cosmic-session` is an official package..so I am installing it using `pacman`:

```bash
pacman -Syu cosmic-session
# S: Synchronizes packages
# y: Refreshes the database for packages
# u: Upgrade all installed packages to their newest version
```
Then it prompts with the 7 providers for `vulkan-driver` which I just chose the default.

## Enable cosmic-greeter

```bash
systemctl enable cosmic-greeter.servce
```
I rebooted and was welcomed with the `cosmic-greeter`.

I think this is fitting for a future [Kubestronaut](https://www.cncf.io/training/kubestronaut/)

## System76 Driver

To have the battery be read by Cosmic, I had to install System76 Driver:

Following <https://support.System76.com/articles/system76-driver/> - Last edited 2/27/2025

I installed the driver with Arch - Manual install steps:

Install build dependencies for the System76 Firmware Daemon, System76 Driver, and the Firmware Manager:
```bash
sudo pacman -S --needed base-devel git linux-headers
```
Firmware Daemon
```bash 
git clone https://aur.archlinux.org/system76-firmware.git # 
cd system76-firmware
makepkg -srcif
sudo systemctl enable --now system76-firmware-daemon
sudo gpasswd -a $USER adm
```
Firmware Manager
```bash
git clone https://aur.archlinux.org/firmware-manager.git
cd firmware-manager
makepkg -srcif
```
Driver
```bash
git clone https://aur.archlinux.org/system76-driver.git
cd system76-driver
makepkg -srcif
sudo systemctl enable --now system76
```
Now reboot the system so that the user is added to the `adm` group.

Check if `$USER` is added to group:
```bash
groups [you-username]
```

## System76 Power
Next we follow the guidelines to install System76 Power:
<https://support.system76.com/articles/system76-software/>

```bash
git clone https://aur.archlinux.org/system76-power.git
cd system76-power
makepkg -srcif
sudo systemctl enable --now com.system76.PowerDaemon.service
sudo gpasswd -a $USER adm
```
After installing `system76-power` I had to install the GNOME Shell Extention.

I was hesitant to do so, since Cosmis is *not* GNOME, but it's necessary to see the battery %.

```bash
git clone https://aur.archlinux.org/gnome-shell-extension-system76-power-git.git
cd gnome-shell-extension-system76-power
makepkg -srcif
```
After rebooting, I was able to see my battery %! Yay!

Next install bluetooth...yay.

---


202502280642
