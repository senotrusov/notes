---
tags:
  - Arch Linux
hide:
  - tags
---
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

# Arch Linux installation guide

This guide presents a practical approach to installing [Arch Linux](https://archlinux.org/). It walks through disk layout, optional full-disk encryption, ext4 or Btrfs filesystems, and setup of the systemd-boot bootloader. It also includes steps for installing proprietary NVIDIA drivers.

While I typically configure my desktop environment and dotfiles separately, this guide provides a brief set of commands for installing the GNOME desktop environment for convenience.

This document is not intended to replace the [official Arch Wiki Installation Guide](https://wiki.archlinux.org/title/Installation_guide), which remains the most comprehensive and authoritative reference. Instead, it offers a personal and opinionated workflow, a set of practical notes meant to complement the Arch Wiki. Use both together to make informed decisions and adapt the process to your system.

!!! danger

    This guide includes steps that will erase all data on your disk. Adjust the disk preparation, partitioning, and formatting steps if this is not your intention.

This guide is provided under the terms of the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

## Recommended setup method

If you have access to a second computer, the most convenient way to install Arch is to boot the target machine from a flash drive and connect to it via SSH from the other computer. This approach allows you to keep this documentation open and copy commands easily between systems. Instructions for enabling SSH on the live environment are included below.

You can also complete the installation directly on the target machine if you prefer working locally.

## Safe use of shell variables

This guide uses parameter expansion syntax, such as `${target:?}`, to prevent unintended command operation if a variable is unset or empty. This safety check is particularly useful when copying commands over SSH or when several shell tabs are open, as it reduces the chance of running a command with incomplete parameters.

For manual input, you may simplify variable references to `$target`. However, ensure that every variable is correctly assigned and contains the expected value before running any command.

## Download the Arch ISO and write it to a USB drive

This section assumes you are using a Linux computer to create the bootable installation medium. If you are on Windows, macOS, or Android, refer to the [USB flash installation medium](https://wiki.archlinux.org/title/USB_flash_installation_medium) article. The Arch ISO file and additional download options are available on the [Arch Linux Downloads page](https://archlinux.org/download/).

### Download the ISO

Use `curl` to fetch the latest installation image from a reliable mirror. Arch Linux releases a new ISO every month.

```sh
curl -O https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
```

### Verify the SHA256 checksum

Verify the SHA256 hash to ensure the downloaded file matches the official signature and has not been tampered with.

=== "Using the one-liner"

    This method relies on the [archlinux.org](https://archlinux.org/) website to securely provide the correct checksum.

    ```sh
    curl -s https://archlinux.org/download/ |
      grep -m1 "SHA256" |
      grep -oE "[a-f0-9]{64}" |
      sed "s/$/  archlinux-x86_64.iso/" |
      sha256sum -c -
    ```

    If the output is `archlinux-x86_64.iso: OK`, the file is valid.

    !!! warning

        Although this one-liner is convenient, it may break if the download page changes its formatting. If you encounter issues, use the manual method.

=== "Manually obtaining the checksum"

    Visit the [Arch Linux download page](https://archlinux.org/download/#checksums) and copy the SHA256 hash for the ISO.

    Replace `SIGNATURE` with the copied hash, then verify the file:

    ```sh
    sha256sum -c <(echo SIGNATURE archlinux-x86_64.iso)
    ```

    If the output is `archlinux-x86_64.iso: OK`, the file is valid.

### Write the ISO to a USB drive

Identify the target USB device using `fdisk -l`, then set the device path variable to prepare the bootable medium.

```sh
sudo fdisk -l
```

!!! danger

    The device you select will be completely erased in the following steps. Choose carefully to avoid data loss.

Set the device path variable, replacing `sdX` with your USB drive's actual device name (e.g., `sdb` or `mmcblk0`):

```sh
flash="/dev/sdX"
```

Use `dd` to write the ISO to the USB device. This operation is permanent and destructive.

```sh
sudo dd if=archlinux-x86_64.iso of="${flash:?}" bs=4M status=progress oflag=sync
```

### Verify the USB copy (optional)

To ensure the data was written correctly, compare the written data byte-by-byte with the original ISO file. Remove and reinsert the USB drive first to clear any potential cache.

```sh
sudo cmp -n "$(stat -c %s archlinux-x86_64.iso)" archlinux-x86_64.iso "${flash:?}" && echo OK || echo ERROR
```

## Boot from USB flash drive

Access your system's firmware (BIOS/UEFI) settings to select the USB drive as the boot device.

!!! warning

    **Disable Secure Boot** in your firmware settings. The official Arch Linux installation images do not support Secure Boot. Secure Boot configuration for the installed system is an advanced topic; consult the [Arch Wiki on Secure Boot](https://wiki.archlinux.org/title/Secure_Boot) if required.

The USB drive can be safely removed once the live environment loads to a shell prompt.

## Improve console readability

Change the console font for better legibility, which is especially useful on high-resolution displays.

```sh
setfont ter-124b  # 24-pixel font
setfont ter-128b  # 28-pixel font
setfont ter-132b  # 32-pixel font
```

!!! info

    For more details, see [Installation guide: Set the console keyboard layout and font](https://wiki.archlinux.org/title/Installation_guide#Set_the_console_keyboard_layout_and_font) and [Linux console#Fonts](https://wiki.archlinux.org/title/Linux_console#Fonts).

## Verify network connectivity

A stable network connection is mandatory for the installation. Test connectivity to ensure the live environment can reach the internet.

```sh
ping -c 3 archlinux.org
```

Wired connections typically work automatically.

!!! info

    For wireless setup or troubleshooting, consult the [Installation guide#Connect to the internet](https://wiki.archlinux.org/title/Installation_guide#Connect_to_the_internet) and [network configuration](https://wiki.archlinux.org/title/Network_configuration).

## Connect to the live environment by SSH (optional)

Using SSH from another machine can simplify the process by allowing for easy command copy-pasting and simultaneous research.

!!! info

    Refer to [Install Arch Linux via SSH](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH) for more information.

### Set a temporary root password

Set a temporary root password for the live environment. This password allows SSH login and will not persist after the installation.

```sh
passwd
```

### Establish an SSH session

=== "Connect with mDNS"

    If your client machine supports mDNS (Multicast DNS), connect using the default hostname `archiso.local`.

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

## Perform basic system checks

### Confirm UEFI boot mode

Confirm the system booted in UEFI mode, which is required for `systemd-boot`.

```sh
cat /sys/firmware/efi/fw_platform_size
```

If the file exists and contains `64`, the system is in 64-bit UEFI mode. If the file is absent, reboot the system and switch to UEFI mode in the firmware settings.

### Check system time

Verify the current time and that NTP synchronization is active (handled automatically by `systemd-timesyncd` in the live environment).

!!! info

    For more details, see the Arch Wiki on [updating the system clock](https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock).

```sh
timedatectl
```

The time zone set here only affects the live environment and will be configured for the installed system later.

## Assign variables for disk identification

Identify the target disk by listing available block devices and assign the device path and partition names to shell variables.

```sh
fdisk -l
```

!!! danger

    The device you select will be completely erased in the following steps. Choose carefully to avoid data loss. Back up all necessary data.

Use the appropriate tab for your disk type.

!!! info

    For more information on disk partitioning, see the [Installation guide: Partition the disks](https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks) and [Parted](https://wiki.archlinux.org/title/Parted).

=== "NVMe Drives"

    Replace `/dev/nvme0n1` with the NVMe device you want to use, and assign the partition names to variables.

    ```sh
    target=/dev/nvme0n1
    efi="${target:?}p1"
    root_physical="${target:?}p2"
    root_actual="${root_physical:?}"
    ```

=== "SATA HDDs/SSDs"

    Replace `/dev/sdb` with the SATA device you want to use, and assign the partition names to variables.

    ```sh
    target=/dev/sdb
    efi="${target:?}1"
    root_physical="${target:?}2"
    root_actual="${root_physical:?}"
    ```

*Note: The `root_actual` variable will be updated later if LUKS encryption is applied.*

## Check disk settings and prepare for partitioning

### Ensure 4K block size on NVMe drives

Aligning your NVMe drive to a 4K (4096 bytes) logical sector size, if supported, improves performance and durability.

First, check the current logical sector size:

```sh
fdisk -l "${target:?}"
```

Next, verify the supported LBA formats to determine the optimal `FORMAT_ID`.

=== "smartctl"

    ```sh
    smartctl -c "${target:?}"
    ```

    Examine the `Supported LBA Sizes` list at the end of the output.

=== "nvme id-ns"

    ```sh
    nvme id-ns -H "${target:?}"
    ```

    Check the `LBA Format` list at the end of the output.

If a 4K format is supported but not active, reformat the drive to the optimal LBA Format ID.

!!! danger

    This operation is destructive and erases all data.

```sh
nvme format --lbaf=FORMAT_ID "${target:?}"
```

!!! info

    See [Advanced Format#NVMe solid state drives](https://wiki.archlinux.org/title/Advanced_Format#NVMe_solid_state_drives) for more details.

### Verify TRIM support

Verify TRIM support, which allows the OS to communicate unused data blocks to a Solid State Drive (SSD) to maintain performance and lifespan. Non-zero values for `DISC-GRAN` and `DISC-MAX` confirm that TRIM support is present.

```sh
lsblk --discard "${target:?}"
```

!!! info

    See [Solid state drive#TRIM](https://wiki.archlinux.org/title/Solid_state_drive#TRIM) for more details.

## Create partitions

Launch `parted` for interactive partitioning:

```sh
parted "${target:?}"
```

**Create a GPT partition table**\
Create a GPT (GUID Partition Table), the modern standard required for UEFI.

```parted
mklabel gpt
```

**Set the unit to MiB for optimal alignment**\
Set the unit to mebibytes (`MiB`) to ensure partitions are aligned to mebibyte boundaries for optimal performance.

```parted
unit MiB
```

**Create the EFI system partition (ESP)**\
Create a 1 GiB (1024 MiB) FAT32 partition starting at 4 MiB.

!!! info

    See the [EFI system partition](https://wiki.archlinux.org/title/EFI_system_partition) page for more information.

```parted
mkpart efi fat32 4 1028
```

**Set the ESP flag**\
Mark the first partition as the EFI System Partition, which is necessary for UEFI bootloaders.

```parted
set 1 esp on
```

**Create the root partition**\
Create the root partition using all remaining disk space, starting immediately after the ESP.

```parted
mkpart root 1028 100%
```

**Check partition alignment**\
Verify optimal alignment for partitions 1 and 2, which is essential for SSD performance.

```parted
align-check opt 1
```

```parted
align-check opt 2
```

**Review and exit**\
Review the partition table and exit `parted`.

```parted
print
```

```parted
quit
```

## Set up LUKS encryption (optional)

Encrypt the root partition (`$root_physical`) with LUKS2. If you skip this step, the `$root_actual` variable remains identical to `$root_physical`.

!!! info

    For details, see [dm-crypt/Encrypting an entire system](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system) and [Dm-crypt](https://wiki.archlinux.org/title/Dm-crypt).

### Format the root partition with LUKS2

Format the root partition (`$root_physical`) with LUKS2. The `--sector-size 4096` option aligns encryption with 4K physical sectors for better performance on modern drives.

When prompted, use a strong passphrase and store it securely. You cannot recover the encrypted data if you lose the passphrase.

```sh
cryptsetup luksFormat --batch-mode --verify-passphrase --type luks2 --sector-size 4096 "${root_physical:?}"
```

### Open the LUKS container and set persistent options

Open the encrypted partition and map it to `/dev/mapper/luks-root`. The performance and discard options enabled here will persist across future unlocks.

!!! info

    For performance and TRIM options, see [Dm-crypt/Specialties#Discard/TRIM support for solid state drives (SSD)](https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)) and [Dm-crypt/Specialties#Disable workqueue for increased solid state drive (SSD) performance](https://wiki.archlinux.org/title/Dm-crypt/Specialties#Disable_workqueue_for_increased_solid_state_drive_(SSD)_performance).

```sh
cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --allow-discards --persistent open "${root_physical:?}" luks-root
```

### Update `root_actual` variable

Assign the variable to point to the decrypted LUKS container for subsequent filesystem operations.

```sh
root_actual="/dev/mapper/luks-root"
```

## Format and mount file systems

Format the partitions with the chosen filesystems and mount them to the installation directory (`/mnt`).

!!! info

    See [Installation guide: Format the partitions](https://wiki.archlinux.org/title/Installation_guide#Format_the_partitions), [Installation guide: Mount the file systems](https://wiki.archlinux.org/title/Installation_guide#Mount_the_file_systems), and [File systems](https://wiki.archlinux.org/title/File_systems) for more details.

### Root partition

Choose either Btrfs with subvolumes or the traditional ext4 filesystem.

#### Root with Btrfs and subvolumes

Format the partition for Btrfs. Btrfs subvolumes enable flexible organization and snapshotting.

!!! info

    See [Btrfs](https://wiki.archlinux.org/title/Btrfs) and [Btrfs#Getting started](https://wiki.archlinux.org/title/Btrfs#Getting_started) for more information on Btrfs and subvolume setup.

**Format the partition:**

```sh
mkfs.btrfs "${root_actual:?}"
```

**Create and mount subvolumes:**

Temporarily mount the top-level volume, create the standard subvolumes (`@` for root, `@home`, `@swap`), then unmount.

```sh
mount "${root_actual:?}" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@swap
umount /mnt
```

Mount the subvolumes to their final locations. The `noatime` option improves performance by disabling file access time updates, and `flushoncommit` prioritizes data integrity.

```sh
mount -o noatime,flushoncommit,subvol=/@ "${root_actual:?}" /mnt
mount -m -o noatime,flushoncommit,subvol=/@home "${root_actual:?}" /mnt/home
mount -m -o noatime,flushoncommit,subvol=/@swap "${root_actual:?}" /mnt/swap
```

#### Root with ext4

Ext4 is a traditional, robust, and mature filesystem.

!!! info

    See the [ext4](https://wiki.archlinux.org/title/ext4) Arch Wiki page for more information.

**Format and mount:**

```sh
mkfs.ext4 "${root_actual:?}"
mount -o noatime,commit=30 "${root_actual:?}" /mnt
```

The `commit=30` option sets the maximum time (in seconds) that data is held in memory before being written to disk, balancing data loss risk and I/O performance.

### EFI system partition

Format the ESP as FAT32, which is required for UEFI booting.

**Format the EFI partition as FAT32:**

```sh
mkfs.fat -F 32 -S 4096 "${efi:?}"
```

**Mount the EFI partition to `/mnt/boot`:**

Mount the ESP with secure permissions (`umask=0077`) to protect the boot files.

```sh
mount -m -o noatime,umask=0077 "${efi:?}" /mnt/boot
```

### Double-check mounts

Verify that all partitions, including subvolumes, are correctly mounted under `/mnt`.

```sh
mount | grep /mnt
```

## Install essential packages

Install the base system and all necessary packages using `pacstrap`. This includes the kernel, firmware, boot manager tools, network manager, and the chosen desktop environment (GNOME) and drivers (NVIDIA).

!!! info

    See the [Installation guide: Install essential packages](https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages) for a complete list of recommended packages.

```sh
pacstrap -K /mnt \
  base linux linux-firmware efibootmgr \
  intel-ucode \
  amd-ucode \
  nvidia-open \
  btrfs-progs compsize \
  networkmanager \
  sudo man-db man-pages micro nano \
  gnome gnome-terminal \
  firefox noto-fonts noto-fonts-cjk noto-fonts-emoji
```

The `-K` flag ensures a proper `pacman` keyring setup in the new system. Adjust the package list as needed (e.g., remove `btrfs-progs`, `gnome`, or `nvidia-open` if not required).

## Patch the system in `/mnt` before chroot

### Fstab (file system table)

Generate the `fstab` file, which the system uses at boot to determine which filesystems to mount. The `-U` option ensures partitions are identified by their UUIDs for reliable mounting.

!!! info

    For details on configuring this file, see the [Installation guide: Fstab](https://wiki.archlinux.org/title/Installation_guide#Fstab).

```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

**Check and edit `fstab`**

Review the generated file and update it as needed, such as removing Btrfs `subvolid=` entries and relying on `subvol=` path-based mounting for better snapshot flexibility.

```sh
cat /mnt/etc/fstab
nano -/ /mnt/etc/fstab
```

### Configure systemd-boot

Install the `systemd-boot` boot manager to the EFI System Partition (ESP) and create the basic configuration files.

!!! info

    For more information on the boot manager, see [systemd-boot](https://wiki.archlinux.org/title/Systemd-boot).

```sh
bootctl --esp-path=/mnt/boot install
```

**Configure `loader.conf`**

Set `arch.conf` as the default boot entry in the global bootloader configuration file.

```sh
echo "default arch.conf" >>/mnt/boot/loader/loader.conf
```

**Create boot entry `arch.conf`**

Define the boot process for the Arch Linux kernel.

!!! info

    Consult the [systemd-boot loader configuration](https://wiki.archlinux.org/title/Systemd-boot#Loader_configuration) for advanced options.

**1. Get UUID**

First, retrieve the UUID of the physical root partition.

```sh
root_device_uuid="$(blkid -s UUID -o value "${root_physical:?}")"
```

**2. Define kernel arguments**

Define the kernel arguments, including the decryption device (`cryptdevice`) if LUKS is used, or simply the root filesystem UUID otherwise.

*If using LUKS encryption (Option A):*

```sh
kernel_args="cryptdevice=UUID=${root_device_uuid}:luks-root root=/dev/mapper/luks-root"
```

*If not using LUKS (Option B):*

```sh
kernel_args="root=UUID=${root_device_uuid}"
```

**3. Append Btrfs subvolume flag (if Btrfs is used)**

If you used the Btrfs subvolume setup, append the flag specifying the root subvolume.

```sh
kernel_args="${kernel_args:?} rootflags=subvol=/@"
```

**4. Create the configuration file**

The microcode files (`intel-ucode.img` and `amd-ucode.img`) must be listed before the main `initramfs-linux.img` so they are loaded first. **Ensure these microcode files are copied to `/mnt/boot` by `pacstrap` (they are dependencies of the `intel-ucode` and `amd-ucode` packages).**

!!! info

    Read more about [Microcode and systemd-boot](https://wiki.archlinux.org/title/Microcode#systemd-boot) to ensure proper loading.

```sh
tee /mnt/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options ${kernel_args:?} rw
EOF
```

## Chroot into the new system and configure

Change the root directory into the newly installed system to perform final, system-specific configurations.

!!! info

    See the [Installation guide: Chroot](https://wiki.archlinux.org/title/Installation_guide#Chroot) page for more information on this process.

```sh
arch-chroot /mnt
```

### Time configuration

Set the system time zone and enable automatic synchronization.

!!! info

    For more details, see [Installation guide: Time](https://wiki.archlinux.org/title/Installation_guide#Time) and [System time](https://wiki.archlinux.org/title/System_time).

List available time zones with:

```sh
timedatectl list-timezones
```

Set the system time zone by linking to the desired zone info file:

```sh
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
```

Synchronize the hardware clock from the system time to generate `/etc/adjtime`, and enable NTP for ongoing time updates.

```sh
hwclock --systohc
systemctl enable systemd-timesyncd.service
```

### Network configuration

Set a unique hostname for your system.

!!! info

    For more on network setup, consult the [Installation guide: Network configuration](https://wiki.archlinux.org/title/Installation_guide#Network_configuration) and [Network configuration#Set the hostname](https://wiki.archlinux.org/title/Network_configuration#Set_the_hostname).

```sh
echo myhostname >/etc/hostname
```

Enable NetworkManager to manage network connections.

!!! info

    Read more about [NetworkManager](https://wiki.archlinux.org/title/NetworkManager#Enable_NetworkManager) for advanced configuration.

```sh
systemctl enable NetworkManager.service
```

### Enable GNOME display manager (GDM) (if installed)

If you installed the GNOME desktop environment, enable its display manager to start the graphical environment on boot.

!!! info

    See [GDM#Enable GDM](https://wiki.archlinux.org/title/GDM#Enable_GDM) for more details.

```sh
systemctl enable gdm.service
```

### Set root password and create user

Set the password for the root user. This password is crucial for security and is also required if the system fails to boot properly, allowing you to access the system through the `systemd emergency boot target` for troubleshooting and repair.

!!! info

    See [Installation guide: Root password](https://wiki.archlinux.org/title/Installation_guide#Root_password) for more context.

```sh
passwd
```

Create a standard non-root user (e.g., `foo`) and add them to the `wheel` group for `sudo` privileges.

!!! info

    For more information on user management, see [Users and groups](https://wiki.archlinux.org/title/Users_and_groups).

```sh
useradd --create-home --groups wheel foo
passwd foo
```

Configure `sudo` to allow members of the `wheel` group to perform privileged commands.

```sh
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/allow-wheel
```

### Swap setup

Swap space manages memory overcommit and provides a backing store for less-used memory, preventing immediate Out-of-Memory (OOM) situations.

!!! info

    See [Swap](https://wiki.archlinux.org/title/Swap) for a detailed guide on swap space configuration.

#### Btrfs swap file

Create an 8 GiB swap file within the dedicated `@swap` subvolume and append it to `fstab`.

```sh
btrfs filesystem mkswapfile --size 8g --uuid clear /swap/swapfile
echo "/swap/swapfile none swap defaults 0 0" >>/etc/fstab
```

!!! info

    See [Btrfs: Swap file](https://wiki.archlinux.org/title/Btrfs#Swap_file) for more details.

#### Ext4 swap file

If using ext4, create an 8 GiB swap file in the root filesystem.

```sh
mkdir -p /swap
mkswap -U clear --size 8G --file /swap/swapfile
echo "/swap/swapfile none swap defaults 0 0" >>/etc/fstab
```

### Configure Mkinitcpio

The initial ramdisk environment (`initramfs`) requires specific configuration to ensure successful system booting, especially when using LUKS encryption or specialized hardware like NVIDIA graphics cards.

Open the primary configuration file to apply the necessary changes:

```sh
nano /etc/mkinitcpio.conf
```

!!! info

    For more information, see the [Installation guide: Initramfs](https://wiki.archlinux.org/title/Installation_guide#Initramfs) and [Mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio), including the section on [dm-crypt hooks](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Configuring_mkinitcpio).

#### Configure LUKS encryption

If you use LUKS, integrate the `encrypt` hook into the `HOOKS` array. This hook enables the decryption prompt early in the boot sequence.

Locate the `HOOKS=` line and manually insert `encrypt` after the `block` hook and before the `filesystems` hook.

```
HOOKS=(... block encrypt filesystems ...)
```

#### Configure the NVIDIA driver

To properly initialize the proprietary NVIDIA driver, adjust both the `HOOKS` and `MODULES` arrays.

**1. Remove the default `kms` hook (if present) from `HOOKS` array** to prevent conflicts with the proprietary driver's kernel mode setting logic.

```
HOOKS=(... [kms should not be in this list] ...)
```

**2. Add the required driver components to the `MODULES` array**. This ensures the graphics driver loads during the early boot stage.

Include `i915` **only** if your system features a hybrid setup with an Intel iGPU.

```
MODULES=(... i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm ...)
```

Include the `nvidia` modules for all proprietary driver installations.

```
MODULES=(... nvidia nvidia_modeset nvidia_uvm nvidia_drm ...)
```

!!! info

    See [NVIDIA: Early loading](https://wiki.archlinux.org/title/NVIDIA#Early_loading) for more details.

**Regenerate initramfs**

Apply the configuration changes and regenerate all initramfs images.

```sh
mkinitcpio -P
```

### Boot loader finalization

Re-run the boot installation command *inside* the chroot to ensure the bootloader files on the ESP match the system's installed version.

```sh
bootctl install
```

Enable the automatic update service for `systemd-boot` to ensure the bootloader files are updated whenever the `systemd` package is upgraded.

!!! info

    See [systemd-boot: Updating the UEFI boot manager](https://wiki.archlinux.org/title/Systemd-boot#Updating_the_UEFI_boot_manager) for more details.

```sh
systemctl enable systemd-boot-update.service
```

### Exit chroot and reboot

Exit the chroot environment and reboot the system into your new Arch Linux installation. Remove the installation USB drive.

```sh
exit
reboot
```

## Post-installation

Congratulations! Your Arch Linux system should now boot.

For further steps refer to [General recommendations](https://wiki.archlinux.org/title/General_recommendations) and [List of applications](https://wiki.archlinux.org/title/List_of_applications).

### Install `yay` AUR helper (optional)

Install `yay`, a popular tool for installing and managing packages from the Arch User Repository (AUR). Run these commands as your regular user, not as root.

```sh
sudo pacman -S --needed git base-devel
yay_temp="$(mktemp --directory)"
git clone https://aur.archlinux.org/yay-bin.git "${yay_temp:?}"
(cd "${yay_temp:?}" && makepkg -si)
rm -rf "${yay_temp:?}"
```

After installing, follow the initial setup steps in the project’s documentation under [First Use: Development packages upgrade](https://github.com/Jguer/yay?tab=readme-ov-file#first-use).

!!! info

    See [AUR helpers](https://wiki.archlinux.org/title/AUR_helpers) and [yay](https://github.com/Jguer/yay) for more information.
