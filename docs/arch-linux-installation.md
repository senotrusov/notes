<!--
  Copyright 2025 Stanislav Senotrusov

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->

# Arch Linux installation notes

This guide presents a practical approach to installing [Arch Linux](https://archlinux.org/). It walks through disk layout, optional full-disk encryption, ext4 or Btrfs filesystems, and setup of the systemd-boot bootloader. It also includes steps for installing proprietary NVIDIA drivers.

While I typically configure my desktop environment and dotfiles separately, this guide provides a brief set of commands for installing the GNOME desktop environment for convenience.

This document is not intended to replace the [official Arch Wiki Installation Guide](https://wiki.archlinux.org/title/Installation_guide), which remains the most comprehensive and authoritative reference. Instead, it offers a personal and opinionated workflow, a set of practical notes meant to complement the Arch Wiki. Use both together to make informed decisions and adapt the process to your system.

!!! warning

    This guide includes steps that will erase all data on your disk. If that is not your intention, please adjust the disk preparation, partitioning, and formatting steps accordingly.

This guide is provided under the terms of the [Apache License, Version 2.0](LICENSE.txt).

## Recommended setup method

If you have access to a second computer, the most convenient way to install Arch is to boot the target machine from a flash drive and connect to it via SSH from the other computer. This allows you to keep this documentation open and copy commands easily between systems. Instructions for enabling SSH on the live environment are included below.

You can also complete the installation directly on the target machine if you prefer working locally.

## Safe use of shell variables

Throughout this guide, variables are written with safety checks such as "${target:?}" to prevent accidental command execution when a variable is unset or empty. This practice is especially helpful when copying commands over SSH or when several shell tabs are open, since it reduces the chance of running a command with incomplete parameters.

For manual input, you may simplify how you reference variables and use $target directly. Just make sure that every variable has been assigned correctly, contains the expected value, and does not include spaces before you run any commands.

## Download the Arch ISO and Write the ISO to a USB Drive

This section assumes you are using a Linux computer to create the bootable installation medium. If you are on Windows, macOS, or Android, please refer to the [USB flash installation medium](https://wiki.archlinux.org/title/USB_flash_installation_medium) article for instructions on preparing the USB drive. The Arch ISO file and additional download options are available on the [Arch Linux Downloads page](https://archlinux.org/download/).

### Download the ISO

Use `curl` to fetch the installation image from a reliable mirror. Note that Arch Linux releases a new installation ISO every month.

```sh
curl -O https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
```

### Verify the SHA256 Checksum

Checking the SHA256 hash confirms the file's integrity against the official signature. Visit the [Arch Linux Download page](https://archlinux.org/download/#checksums) to find the correct hash for your ISO.

Replace `SIGNATURE` with the copied hash and run the command to verify the download:

```sh
sha256sum -c <(echo SIGNATURE archlinux-x86_64.iso)
```

If the output is `archlinux-x86_64.iso: OK`, the file is valid.

### Write the ISO to a USB Drive

Identify your target USB device carefully to avoid erasing the wrong disk, then set the device path variable.

```sh
sudo fdisk -l
```

Set the device path variable, replacing `sdX` with your USB drive's actual device name (e.g., `sdb`):

```sh
flash="/dev/sdX"
```

Use the `dd` utility to write the ISO to the USB device, which will permanently erase all existing data on the drive.

```sh
sudo dd if=archlinux-x86_64.iso of="${flash:?}" bs=4M status=progress oflag=sync
```

### Verify the USB Copy (Optional)

To ensure the data was written correctly to the physical device, remove and reinsert the USB drive to clear any potential cache, and then compare the written data byte-by-byte with the original ISO file.

```sh
sudo cmp -n "$(stat -c %s archlinux-x86_64.iso)" archlinux-x86_64.iso "${flash:?}" && echo OK || echo ERROR
```

## Boot from USB Flash Drive

Adjust your system's firmware settings (BIOS/UEFI) to select the USB drive as the boot device.

Disable Secure Boot in your firmware settings, as the official Arch Linux installation images do not support it. Secure Boot configuration for the installed system is a separate, advanced topic that is not covered here; consult the [Arch Wiki on Secure Boot](https://wiki.archlinux.org/title/Secure_Boot) if required.

As soon as the live environment loads to a shell prompt, the USB drive can be safely removed. For more details on the process, see the [Installation guide: Boot the live environment](https://wiki.archlinux.org/title/Installation_guide#Boot_the_live_environment).

## Improve Console Readability

Change the console font for better legibility, especially on high-resolution displays. Select one of the following commands to set the font size to 24, 28, or 32:

```sh
setfont ter-124b
setfont ter-128b
setfont ter-132b
```
 
For more details on configuring the console font, refer to the [Installation guide: Set the console keyboard layout and font](https://wiki.archlinux.org/title/Installation_guide#Set_the_console_keyboard_layout_and_font) and [Linux console#Fonts](https://wiki.archlinux.org/title/Linux_console#Fonts).

## Verify Network Connectivity

A network connection is mandatory for installation. Wired connections usually work automatically.

Test connectivity to ensure the live environment can reach the internet:

```sh
ping -c 3 archlinux.org
```

For wireless setup or troubleshooting, consult the [installation guide](https://wiki.archlinux.org/title/Installation_guide#Connect_to_the_internet) and [network configuration](https://wiki.archlinux.org/title/Network_configuration).

## Connect to the live environment by SSH (optional)

Using SSH from another machine can simplify the process by allowing for easy command copy-pasting and simultaneous research. Refer to [Install Arch Linux via SSH](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH) for more information.

### Set a temporary root password

Set a temporary root password for the live environment to allow SSH login; this password will not persist after the installation.

```sh
passwd
```

### Establish an SSH session

=== "Connect with mDNS"

    If your client machine supports mDNS (Multicast DNS), you can connect using the default hostname `archiso.local`.

    ```sh
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@archiso.local
    ```

=== "Connect with an IP address"

    If mDNS fails, find the live environment's IP address on the network.

    ```sh
    ip addr
    ```

    Use the assigned IP address to connect from your client machine, replacing `IP_ADDRESS`:

    ```sh
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l root IP_ADDRESS
    ```

## Perform Basic System Checks

Confirm the live environment is correctly configured before proceeding.

### Confirm UEFI Boot Mode

Verify that the system has booted in UEFI mode, as this guide assumes UEFI for `systemd-boot` installation.

```sh
cat /sys/firmware/efi/fw_platform_size
```

If the file exists and contains `64`, the system is in 64-bit UEFI mode. If it doesn't exist, you are likely in legacy BIOS mode and must switch to UEFI in the firmware settings and reboot.

### Check System Time

Verify the current time and that NTP synchronization is active, which is typically handled automatically by `systemd-timesyncd` in the live environment.

```sh
timedatectl
```

The time zone here only affects the live environment and will be configured for the installed system later. See [update the system clock](https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock) for details.

## Assign Variables for Disk Identification

List available block devices to identify your installation target disk.

```sh
fdisk -l
```

!!! danger

    The device you select will be completely erased in the following steps. Choose carefully to avoid deleting data from the wrong device.

=== "NVMe Drives"

    Replace `/dev/nvme0n1` with the NVMe device you want to use, and assign the partition names to variables. All data on the selected device will be permanently deleted.

    ```sh
    target=/dev/nvme0n1
    efi="${target:?}p1"
    root_physical="${target:?}p2"
    root_actual="${root_physical:?}"
    ```

=== "SATA HDDs/SSDs"

    Replace `/dev/nvme0n1` with the SATA device you want to use, and assign the partition names to variables. All data on the selected device will be permanently deleted.

    ```sh
    target=/dev/sdb
    efi="${target:?}1"
    root_physical="${target:?}2"
    root_actual="${root_physical:?}"
    ```

*Note: The `root_actual` variable will be updated later if LUKS encryption is applied.*
