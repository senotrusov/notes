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

# <small>Stanislav’s guide to</small> <span class="nobr">Arch Linux</span> installation

## Preface

[Arch Linux](https://archlinux.org/) offers a remarkably elegant installation model: you type a sequence of commands and shape the system into exactly what you want. Its charm lies in this freedom. Rather than pushing you through a predetermined installer, the process invites you to build the system step by step, with full visibility into how everything fits together.

After spending a fair amount of time reading the [Arch Wiki](https://wiki.archlinux.org/), I assembled a set of notes on how to create a system aligned with my preferences for minimalism and privacy. The document you’re reading grew out of those notes. It serves as a curated series of commands, each annotated with context and paired with links back to the Arch Wiki for deeper understanding.

These commands could easily be shaped into a full installation script, but I chose not to go that route. A script would freeze everything into a fixed program, hide the decision points, discourage experimentation, and make future adjustments harder for both you and me. That feels at odds with the spirit of Arch Linux.

Instead, the goal here is to keep each path open while providing a clear starting point. I make several decisions for you and consolidate them into ready-to-run commands, but you are free to follow them directly, watch closely, diverge at any moment, or reshape the entire process into something uniquely your own.

At a few key moments in the guide, you can choose between different prepared configurations. These include decisions such as whether to use full-disk encryption, selecting between `ext4` and `Btrfs`, installing the NVIDIA driver, or choosing which packages you want included in your installation. Every option is presented with its own tab or expandable section that provides a complete, ready-to-use command set.

The guide also outlines practical methods and tool choices for configuring the system. It explains how to align an NVMe drive to a 4K logical sector size, enable TRIM within an encrypted setup so solid-state drives can manage unused blocks effectively, and create a clean partition scheme with `parted`. You will learn how to configure swap as a regular file, set up the `systemd-boot` bootloader, and add a helper for working with packages from the [Arch User Repository](https://aur.archlinux.org/). Finally, the guide shows how to connect over SSH during installation so you can work comfortably from another machine, making it easier to copy commands and research solutions as you go.

This document is not meant to replace the official [Installation Guide](https://wiki.archlinux.org/title/Installation_guide), which remains the most complete and authoritative resource. Use them together to make informed decisions and adapt the process to your own sense of how things should come together.

This guide is provided under the terms of the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

!!! danger

    This guide includes steps that will erase all data on your disk. Adjust the disk preparation, partitioning, and formatting steps if this is not your intention.

## Recommended setup method

If you have access to a second computer, the most convenient way to install Arch is to boot the target machine from a flash drive and connect to it via SSH from the other computer. This approach allows you to keep this documentation open and copy commands easily between systems. Instructions for enabling SSH on the live environment are included below.

You can also complete the installation directly on the target machine if you prefer working locally.

## Safe use of shell variables

This guide uses parameter expansion syntax, such as `${target:?}`, to prevent unintended command operation if a variable is unset or empty. This safety check is particularly useful when copying commands over SSH or when several shell tabs are open, as it reduces the chance of running a command with incomplete parameters.

For manual input, you may simplify variable references to `$target`. However, ensure that every variable is correctly assigned and contains the expected value before running any command.

## Download the Arch ISO and write it to a USB drive

This section assumes you are using a Linux computer to create the bootable installation medium. If you are on Windows, macOS, or Android, refer to the [USB flash installation medium](https://wiki.archlinux.org/title/USB_flash_installation_medium) article. The Arch ISO file and additional download options are available on the [Arch Linux Downloads](https://archlinux.org/download/).

### Download the ISO

Use `curl` to fetch the latest installation image from a reliable mirror. Arch Linux releases a new ISO every month.

```sh
curl -O https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
```

### Verify the SHA256 checksum

Verify the SHA256 hash to ensure the downloaded file matches the official signature and has not been tampered with.

=== "Using the one-liner"

    !!! warning inline end

        Although this one-liner is convenient, it may break if the download page changes its formatting. If you encounter issues, use the manual method.

    This method relies on the [archlinux.org](https://archlinux.org/) website to securely provide the correct checksum.

    ```sh
    curl -s https://archlinux.org/download/ |
      grep -m1 "SHA256" |
      grep -oE "[a-f0-9]{64}" |
      sed "s/$/  archlinux-x86_64.iso/" |
      sha256sum --check -
    ```

    If the output is `archlinux-x86_64.iso: OK`, the file is valid.

=== "Manually obtaining the checksum"

    Visit the [Arch Linux download](https://archlinux.org/download/#checksums) and copy the SHA256 hash for the ISO.

    Replace `SIGNATURE` with the copied hash, then verify the file:

    ```sh
    sha256sum --check <(echo SIGNATURE archlinux-x86_64.iso)
    ```

    If the output is `archlinux-x86_64.iso: OK`, the file is valid.

### Write the ISO to a USB drive

Identify the target USB device using `fdisk -l`, then set the device path variable to prepare the bootable medium.

```sh
sudo fdisk -l
```

!!! danger

    The device you select will be completely erased in the following steps. Choose carefully to avoid data loss.

Set the device path variable, replacing `sdX` with your USB drive’s actual device name (e.g., `sdb` or `mmcblk0`).

```sh
flash="/dev/sdX"
```

Use `dd` to write the ISO to the USB device.

```sh
sudo dd if=archlinux-x86_64.iso of="${flash:?}" bs=4M status=progress oflag=sync
```

???+ example "Verify the USB copy (optional)"

    To ensure the data was written correctly, compare the written data byte-by-byte with the original ISO file. Remove and reinsert the USB drive first to clear any potential cache.

    ```sh
    sudo cmp -n "$(stat -c %s archlinux-x86_64.iso)" archlinux-x86_64.iso "${flash:?}" && echo OK || echo ERROR
    ```

## Boot from USB flash drive

Access your system’s firmware (BIOS/UEFI) settings to select the USB drive as the boot device.

The USB drive can be safely removed once the live environment loads to a shell prompt.

!!! warning

    **Disable Secure Boot** in your firmware settings. The official Arch Linux installation images do not support Secure Boot. Secure Boot configuration for the installed system is an advanced topic; consult the [Secure Boot](https://wiki.archlinux.org/title/Secure_Boot) guide if required.

## Improve console readability

!!! info inline end ""

    For more details, see [Installation guide: Set the console keyboard layout and font](https://wiki.archlinux.org/title/Installation_guide#Set_the_console_keyboard_layout_and_font) and [Linux console: Fonts](https://wiki.archlinux.org/title/Linux_console#Fonts).

Change the console font for better legibility, which is especially useful on high-resolution displays.

```sh
setfont ter-124b  # Western European codepage, 24-pixel height, bold
setfont ter-128b  # Western European codepage, 28-pixel height, bold
setfont ter-132b  # Western European codepage, 32-pixel height, bold
```

## Network checks and optional SSH connection

A stable network connection is mandatory for the installation. Test connectivity to ensure the live environment can reach the internet.

```sh
ping -c 3 archlinux.org
```

Wired connections typically work automatically.

!!! tip "Wireless Network"

    For wireless setup or troubleshooting, see the [Installation guide: Connect to the internet](https://wiki.archlinux.org/title/Installation_guide#Connect_to_the_internet) and the [Network configuration](https://wiki.archlinux.org/title/Network_configuration) guide.

???+ example "Connect to the live environment by SSH (optional)"

    !!! info inline end ""

        Refer to the [Install Arch Linux via SSH](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH) guide for more information.

    Using SSH from another machine can simplify the process by allowing for easy command copy-pasting and simultaneous research.

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

        If mDNS fails, find the live environment’s IP address on the network.

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

!!! info inline end ""

    For more details, see [Installation guide: Update the system clock](https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock).

Verify the current time and that NTP synchronization is active (handled automatically by `systemd-timesyncd` in the live environment).

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

*Note: The `root_actual` variable is initially set to the physical root partition and will be updated later if LUKS encryption is applied.*

## Check disk settings

### Ensure 4K block size on NVMe drives

!!! info inline end ""

    See [Advanced Format: NVMe solid state drives](https://wiki.archlinux.org/title/Advanced_Format#NVMe_solid_state_drives) for more details.

Aligning your NVMe drive to a 4K (4096 bytes) logical sector size, if supported, improves performance and durability.

First, check the current logical sector size.

```sh
fdisk -l "${target:?}"
```

Next, verify the supported LBA formats to determine the optimal `FORMAT_ID`.

=== "With `smartctl`"

    Examine the `Supported LBA Sizes` list at the end of the output.

    ```sh
    smartctl --capabilities "${target:?}"
    ```

=== "With `nvme`"

    Check the `LBA Format` list at the end of the output.

    ```sh
    nvme id-ns --human-readable "${target:?}"
    ```

!!! danger

    This operation is **destructive and will erase all data on the drive**. It has also been observed that some NVMe drives become unresponsive after formatting and require a system reboot before they operate again (although the new format will be applied afterward). It is also reasonable to assume that **some drives may become unusable due to firmware bugs**, as very few users ever change the factory default format. You likely do not want to be the first to discover such an issue, so proceed with caution and carefully **consider whether reformatting is worth the risk**. It is perfectly fine to stay with the manufacturer’s default format, even if it offers slightly lower performance, in exchange for peace of mind.

If a 4K format is supported but not active, reformat the drive to the optimal LBA Format ID.

```sh
nvme format --lbaf=FORMAT_ID "${target:?}"
```

### Verify TRIM support

!!! info inline end ""

    See [Solid state drive: TRIM](https://wiki.archlinux.org/title/Solid_state_drive#TRIM) for more details.

Verify TRIM support, which allows the OS to communicate unused data blocks to a Solid State Drive (SSD) to maintain performance and lifespan. Non-zero values for `DISC-GRAN` and `DISC-MAX` confirm that TRIM support is present.

```sh
lsblk --discard "${target:?}"
```

## Create partitions

!!! tip inline end "Explore more partitioning options"

    For more ways to set up your partitions, see the [Installation guide: Partition the disks](https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks) and the [Parted](https://wiki.archlinux.org/title/Parted) guide on the Arch Wiki.

The plan is to create a ~1 GiB EFI system partition for boot files and use the remaining space for the root partition. Swap will later be added as a regular file within the root filesystem to keep the layout flexible.

Launch `parted` for interactive partitioning.

```sh
parted "${target:?}"
```

**Create a GPT partition table**

Create a GPT (GUID Partition Table), the modern standard required for UEFI.

```parted
mklabel gpt
```

**Set the unit to MiB for optimal alignment**

!!! info inline end ""

    See [Advanced Format: Partition alignment](https://wiki.archlinux.org/title/Advanced_Format#Partition_alignment) for more details.

Set the unit to mebibytes (`MiB`) so that any values passed to `mkpart` are interpreted in this unit. Doing this first ensures partitions land on precise mebibyte boundaries, which avoids alignment problems and improves performance. Because the default `parted` unit is less exact, explicitly selecting `MiB` helps prevent unintended offsets.

```parted
unit MiB
```

**Create the EFI system partition (ESP)**

Create a FAT32 partition that occupies the space from 1 MiB up to the chosen alignment point, which comes out to roughly 1.10 GiB.

???+ info "Rationale for the 1152 MiB alignment point"

    Modern high-density TLC and QLC flash devices that use 3-bit cells and multi-plane layouts often have erase block sizes divisible by three, such as 24 MiB, 48 MiB, or 96 MiB.

    Given that a boot partition typically needs about 1 GiB, a natural question arises: where should the root partition begin?

    The 1152 MiB mark serves as a convenient common multiple that aligns cleanly with both traditional binary-oriented block sizes (such as 16 or 32 MiB) and newer ternary-based patterns. The following JavaScript snippet shows how evenly it divides into current and plausible future erase block sizes:

    ```js
    [4, 8, 16, 24, 32, 48, 96, 128, 192].map(i => 1152 / i)
    ```

    This assumes, of course, that filesystems arrange data in ways that respect the alignment constraints imposed by the hardware, which remains outside our control.

    If you are using an encrypted partition with LUKS2, keep in mind that it adds its own header, typically 16 MiB. Subtract this amount from the 1152 MiB alignment target.

    As a side note, the boot partition is fine with 1 MiB alignment since it is rarely written.

=== "Use LUKS encryption"

    ```parted
    mkpart efi fat32 1 1136
    ```

=== "Do not use LUKS encryption"

    ```parted
    mkpart efi fat32 1 1152
    ```

**Set the ESP flag**

!!! info inline end ""

    See the [EFI system partition](https://wiki.archlinux.org/title/EFI_system_partition) for more information.

Mark the first partition as the EFI System Partition, which is necessary for UEFI bootloaders.

```parted
set 1 esp on
```

**Create the root partition**

Create the root partition using all remaining disk space, starting immediately after the ESP.

=== "Use LUKS encryption"

    ```parted
    mkpart root 1136 100%
    ```

=== "Do not use LUKS encryption"

    ```parted
    mkpart root 1152 100%
    ```

**Check partition alignment**

Verify optimal alignment for partition 1.

```parted
align-check opt 1
```

Verify optimal alignment for partition 2.

```parted
align-check opt 2
```

**Review and exit**

Display the partition table to verify the final layout.

```parted
print
```

Exit `parted`.

```parted
quit
```

## Configure disk encryption

Choose whether to encrypt the root partition with LUKS or proceed without encryption.

!!! tip "Understanding disk encryption"

    Disk encryption is a broad topic with many configuration options and security trade-offs. While this guide covers one possible approach, you can always dive deeper into the various methods and implementation details using the extensive [dm-crypt](https://wiki.archlinux.org/title/Dm-crypt) page on the Arch Wiki.

!!! abstract "Configure disk encryption"

    === "Use LUKS encryption"

        If you choose to encrypt the root partition (`$root_physical`) with LUKS2, the decrypted device becomes `$root_actual`.

        ### Format the root partition with LUKS2

        Format the root partition (`$root_physical`) using LUKS2. The `--sector-size 4096` option aligns encryption with 4K physical sectors, which improves performance on modern drives.

        When prompted, choose a strong passphrase and store it safely. Losing the passphrase means losing access to all encrypted data.

        ```sh
        cryptsetup luksFormat --batch-mode --verify-passphrase --type luks2 --sector-size 4096 "${root_physical:?}"
        ```

        ### Open the LUKS container and set persistent options

        !!! info inline end ""

            For details on discard support and performance tuning, see  
            [Discard and TRIM support](https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)) and  
            [Disabling the workqueue for SSD performance](https://wiki.archlinux.org/title/Dm-crypt/Specialties#Disable_workqueue_for_increased_solid_state_drive_(SSD)_performance).

        Open the encrypted partition and map it as `/dev/mapper/luks-root`. The performance and discard options enabled here apply automatically for future unlocks.

        ```sh
        cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --allow-discards --persistent open "${root_physical:?}" luks-root
        ```

        ### Set the `root_actual` variable

        Update the variable so that subsequent filesystem operations target the decrypted container.

        ```sh
        root_actual="/dev/mapper/luks-root"
        ```

    === "Do not use LUKS encryption"

        No action is required for this step when not using LUKS encryption. The `$root_actual` variable, which represents the device path for the root filesystem, retains its initial value of `$root_physical`.

## Format and mount file systems

!!! info inline end ""

    See [Installation guide: Format the partitions](https://wiki.archlinux.org/title/Installation_guide#Format_the_partitions), [Installation guide: Mount the file systems](https://wiki.archlinux.org/title/Installation_guide#Mount_the_file_systems), and [File systems](https://wiki.archlinux.org/title/File_systems) for more details.

Format the partitions with the chosen filesystems and mount them to the installation directory (`/mnt`).

### Root partition

Choose either the traditional `ext4` filesystem or `Btrfs` with subvolumes.

=== "Ext4 filesystem"

    !!! info inline end ""

        See the [ext4](https://wiki.archlinux.org/title/ext4) guide for more information.

    Ext4 is a traditional, robust, and mature filesystem.

    **Format and mount:**

    ```sh
    mkfs.ext4 "${root_actual:?}"
    mount -o noatime,commit=30 "${root_actual:?}" /mnt
    ```

    The `noatime` option improves performance by disabling file access time updates, and the `commit=30` option sets the maximum time (in seconds) that data is held in memory before being written to disk, balancing data loss risk and I/O performance.

=== "Btrfs filesystem"

    !!! info inline end ""

        See the [Btrfs](https://wiki.archlinux.org/title/Btrfs) guide for details on Btrfs usage and subvolume setup.

    Format the partition for Btrfs. Btrfs subvolumes enable flexible organization and snapshotting.

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
    mount --mkdir -o noatime,flushoncommit,subvol=/@home "${root_actual:?}" /mnt/home
    mount --mkdir -o noatime,flushoncommit,subvol=/@swap "${root_actual:?}" /mnt/swap
    ```

### EFI system partition

Format the ESP as FAT32, which is required for UEFI booting.

**Format the EFI partition as FAT32:**

```sh
mkfs.fat -F 32 -S 4096 "${efi:?}"
```

**Mount the EFI partition to `/mnt/boot`:**

Mount the ESP with secure permissions (`umask=0077`) to protect the boot files.

```sh
mount --mkdir -o noatime,umask=0077 "${efi:?}" /mnt/boot
```

### Double-check mounts

Verify that all partitions, including subvolumes, are correctly mounted under `/mnt`.

```sh
mount | grep /mnt
```

## Install essential packages

!!! tip inline end "More package ideas"

    See the [Installation guide: Install essential packages](https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages) for a complete list of recommended packages.

Select your CPU architecture below and run the corresponding code block in your shell to initialize the `packages` array. This array includes the kernel, firmware, boot manager tools, essential utilities, and the correct CPU microcode package.

### Define the base system

=== "Universal (Intel and AMD)"

    ```sh
    packages=(
      amd-ucode
      base
      efibootmgr
      intel-ucode
      linux
      linux-firmware
      man-db
      man-pages
      nano
      sudo
      terminus-font
      )
    ```

=== "Intel only"

    ```sh
    packages=(
      base
      efibootmgr
      intel-ucode
      linux
      linux-firmware
      man-db
      man-pages
      nano
      sudo
      terminus-font
      )
    ```

=== "AMD only"

    ```sh
    packages=(
      amd-ucode
      base
      efibootmgr
      linux
      linux-firmware
      man-db
      man-pages
      nano
      sudo
      terminus-font
      )
    ```

### Add optional packages

Append optional packages, such as file system utilities, desktop environment components, or drivers, to the `packages` array.

???+ example "Btrfs file system utilities"

    ```sh
    packages+=(
      btrfs-progs
      compsize
    )
    ```

???+ example "NVIDIA open kernel driver"

    ```sh
    packages+=(
      nvidia-open
    )
    ```

???+ example "GNOME desktop environment and NetworkManager"

    ```sh
    packages+=(
      gnome
      gnome-terminal
      networkmanager
    )
    ```

    NetworkManager provides a unified way to manage network connections and integrates well with the GNOME desktop environment.

???+ example "Web browser and essential desktop fonts"

    ```sh
    packages+=(
      firefox
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
    )
    ```
  
### Run package installation

After defining the base system and appending optional packages, run the following command to install all selected packages onto the mounted system.

```sh
pacstrap -K /mnt "${packages[@]:?}"
```

The `-K` flag ensures a proper `pacman` keyring setup in the new system.

## Patch the system in `/mnt` before chroot

### Fstab (file system table)

!!! info inline end ""

    For details on configuring this file, see the [Installation guide: Fstab](https://wiki.archlinux.org/title/Installation_guide#Fstab).

Generate the `fstab` file, which the system uses at boot to determine which filesystems to mount. The `-U` option ensures partitions are identified by their UUIDs for reliable mounting.

```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

**Review `fstab`**

Check the generated file to confirm the filesystem entries.

```sh
cat /mnt/etc/fstab
```

**Edit `fstab` (only if necessary)**

Make any required adjustments to the file based on your setup.

=== "Ext4 filesystem"

    Ext4 generally does not require manual editing. Since `genfstab` detects active mount options, the flags you used earlier (`noatime` and `commit=30`) should already be present.

    ```sh
    nano /mnt/etc/fstab
    ```

=== "Btrfs filesystem"

    Consider removing any `subvolid=` entries to rely solely on path-based `subvol=` mounts. This ensures that your system mounts the correct subvolumes even if their IDs change during a snapshot rollback.
    
    Since `genfstab` detects active mount options, the flags you used earlier (`noatime`, `flushoncommit`, and `subvol=`) should already be present.

    ```sh
    nano /mnt/etc/fstab
    ```

### Configure systemd-boot

!!! info inline end ""

    For detailed documentation, consult the guides on [systemd-boot](https://wiki.archlinux.org/title/Systemd-boot) and [UEFI: efibootmgr](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface#efibootmgr).

Install the `systemd-boot` boot manager. This command populates the EFI System Partition (ESP) with the necessary binaries and creates the default configuration directory structure.

```sh
bootctl --esp-path=/mnt/boot install
```

!!! info "Why run this twice?"

    You will need to re-run this command later inside the chroot environment. The versions of packages on the live installation medium may be older than the versions installed on the target system, which can result in mismatches.
    
    However, the initial setup must be performed from *outside* the chroot because the chroot environment usually cannot query EFI variables to register the bootloader (see [systemd issue #36174](https://github.com/systemd/systemd/issues/36174)).

???+ example "Verifying and managing EFI boot entries"

    Unlike legacy BIOS bootloaders, which reside physically on the disk’s Master Boot Record (MBR), UEFI boot entries are stored in the motherboard’s NVRAM (Non-Volatile RAM). Because of this, boot entries often persist even after a disk has been formatted or replaced.

    !!! tip inline end "About the Unicode Switch"

        Although the UEFI specification mandates **UCS-2 (Unicode)** encoding for boot entry descriptions and arguments, `efibootmgr` defaults to **ASCII** to maintain compatibility with older or non-standard firmware. 
        
        Most modern systems follow the standard and require the <span class="nobr">`--unicode`</span> switch. However, some firmware implementations are non-compliant and may expect ASCII. If your boot entries appear as unreadable garbage text or fail to pass arguments to the kernel, try toggling this switch to match your firmware's behavior.

    **View boot order and entries**

    You can list the current boot configuration, which includes the active `BootOrder` and a list of all available boot options:

    === "With unicode switch"

        ```sh
        efibootmgr --unicode
        ```

    === "Without unicode switch"

        ```sh
        efibootmgr
        ```

    **Identify your new entry**
    
    The full list of boot entries can be confusing, often containing leftovers from previous installations or firmware defaults. To easily locate the entry for your new installation, filter the list using your EFI partition’s UUID:

    === "With unicode switch"

        ```sh
        efibootmgr --unicode | grep -F "$(lsblk --nodeps --noheadings --output "PARTUUID" "${efi:?}")"
        ```

    === "Without unicode switch"

        ```sh
        efibootmgr | grep -F "$(lsblk --nodeps --noheadings --output "PARTUUID" "${efi:?}")"
        ```

    **Modify boot order**
    
    If your new entry is not at the top of the list, you can manually update the boot order. Replace `XXXX` with the hexadecimal boot numbers (for example, `0001,0003`) found in the output above:

    === "With unicode switch"

        ```sh
        efibootmgr --unicode --bootorder XXXX,XXXX 
        ```

    === "Without unicode switch"

        ```sh
        efibootmgr --bootorder XXXX,XXXX 
        ```

    **Remove stale entries**
    
    You may find leftover entries from previous installations or experiments. To keep your boot menu clean, you can delete these stale entries.
    
    !!! danger

        Proceed with caution. Make sure you are not deleting the entry for your current installation, any other operating systems you use for multibooting, or the firmware interface.

    === "With unicode switch"

        ```sh
        efibootmgr --unicode --delete-bootnum --bootnum XXXX
        ```

    === "Without unicode switch"

        ```sh
        efibootmgr --delete-bootnum --bootnum XXXX
        ```

#### Configure `loader.conf`

!!! info inline end ""

    Consult the [systemd-boot: Loader configuration](https://wiki.archlinux.org/title/Systemd-boot#Loader_configuration) for additional configuration options.

Set `arch.conf` as the default boot entry in the global bootloader configuration file.

```sh
echo "default arch.conf" >> /mnt/boot/loader/loader.conf
```

#### Create `arch.conf` boot entry

Define the boot process for the Arch Linux kernel.

**1. Get UUID**

First, retrieve the UUID of the physical root partition.

```sh
root_device_uuid="$(lsblk --nodeps --noheadings --output "UUID" "${root_physical:?}")"
```

**2. Define kernel arguments**

Selecting the right kernel parameters ensures that your system can locate and mount the root filesystem during boot. The next step tailors these parameters to your encryption method.

=== "Use LUKS encryption"

    Include the decryption device (`rd.luks.name`) and set the root filesystem to the decrypted path (`/dev/mapper/luks-root`).

    ```sh
    kernel_args="rd.luks.name=${root_device_uuid}=luks-root root=/dev/mapper/luks-root"
    ```

=== "Do not use LUKS encryption"

    Set the root filesystem to the UUID of the physical root partition.

    ```sh
    kernel_args="root=UUID=${root_device_uuid}"
    ```

Before creating the final boot entry, make sure the kernel arguments also match your filesystem type. Some filesystems require extra flags so the kernel knows exactly where your root data is stored.

=== "Ext4 filesystem"

    No additional flags are required because Ext4 uses a straightforward layout that does not involve subvolumes or special mount instructions.

=== "Btrfs filesystem"

    If you used the Btrfs subvolume setup, append the flag specifying the root subvolume.

    ```sh
    kernel_args="${kernel_args:?} rootflags=subvol=/@"
    ```

**3. Create the configuration file**

!!! info inline end ""

    Read more about [Microcode and systemd-boot](https://wiki.archlinux.org/title/Microcode#systemd-boot) to ensure proper loading.

The microcode files (`intel-ucode.img` and `amd-ucode.img`) must appear before the main `initramfs-linux.img` in the configuration file to ensure they load first. The command below uses `tee` to create the `arch.conf` loader entry that references the appropriate microcode file or files, depending on the CPU architecture you select.

Make sure the required microcode files were copied to `/mnt/boot`. They are installed by `pacstrap` during the [Install essential packages](#install-essential-packages) step, where you select your CPU architecture from the corresponding tab.

In this step, you again choose one of the architecture tabs. Select the same architecture as before so that the correct microcode images installed earlier are used in your boot loader configuration.

=== "Universal (Intel and AMD)"

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

=== "Intel only"

    ```sh
    tee /mnt/boot/loader/entries/arch.conf <<EOF
    title   Arch Linux
    linux   /vmlinuz-linux
    initrd  /intel-ucode.img
    initrd  /initramfs-linux.img
    options ${kernel_args:?} rw
    EOF
    ```

=== "AMD only"

    ```sh
    tee /mnt/boot/loader/entries/arch.conf <<EOF
    title   Arch Linux
    linux   /vmlinuz-linux
    initrd  /amd-ucode.img
    initrd  /initramfs-linux.img
    options ${kernel_args:?} rw
    EOF
    ```

## Chroot into the installed system for final configuration

!!! info inline end ""

    See the [Installation guide: Chroot](https://wiki.archlinux.org/title/Installation_guide#Chroot) for more information on this process.

Change the root directory into the newly installed system to perform final, system-specific configurations.

```sh
arch-chroot /mnt
```

### Time configuration

!!! info inline end ""

    For further details, see the [Installation guide: Time](https://wiki.archlinux.org/title/Installation_guide#Time) and the [System time](https://wiki.archlinux.org/title/System_time) guide.

Set the system time zone and enable automatic synchronization.

List available time zones with.

```sh
timedatectl list-timezones
```

Configure the system time zone by linking to the appropriate zone info file. Replace `Etc/UTC` with the time zone you want to use.

```sh
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
```

Synchronize the hardware clock from the system time to generate `/etc/adjtime`, and enable NTP for ongoing time updates.

```sh
hwclock --systohc
systemctl enable systemd-timesyncd.service
```

### Localization

!!! tip inline end "Choosing your locale"

    If your primary locale is not US English, refer to the Arch Wiki’s [Installation guide: Localization](https://wiki.archlinux.org/title/Installation_guide#Localization) to select the correct value and plan your configuration.

Define a variable for your chosen locale. This variable will be used in the following steps.

```sh
locale="en_US.UTF-8"
```

#### 1. Configure `/etc/locale.gen`

Uncomment your chosen locale(s) in the `/etc/locale.gen` file.

=== "Apply changes automatically"

    Run the following command to automatically uncomment the line matching the `locale` variable.

    ```sh
    sed -ri "s/^#\s*(${locale//./[.]}(\s|\$))/\1/g" /etc/locale.gen
    ```

    Verify the uncommented (active) lines in `/etc/locale.gen`.

    ```sh
    grep -v "^#" /etc/locale.gen
    ```

=== "Edit the file directly"

    Open `/etc/locale.gen` and manually uncomment the appropriate line(s) (remove the `#` symbol).

    ```sh
    nano /etc/locale.gen
    ```

#### 2. Generate locales

Generate the configured locales.

```sh
locale-gen
```

#### 3. Create `/etc/locale.conf`

Create `/etc/locale.conf` to set the system-wide `LANG` environment variable.

```sh
echo "LANG=${locale:?}" > /etc/locale.conf
```

#### 4. Configure virtual console

Configure the virtual console by editing `/etc/vconsole.conf`. This sets the keyboard layout (`KEYMAP`) and console font (`FONT`) for the TTY/boot environment.

Example for US layout and Terminus font (Western European codepage, 28-pixel height, bold).

```sh
( echo "KEYMAP=us" && echo "FONT=ter-128b" ) > /etc/vconsole.conf
```

!!! warning "Ensure correct keymap for entering LUKS password"

    When using LUKS full disk encryption, the `KEYMAP` defined in `/etc/vconsole.conf` is the only layout active when prompted for the unlock password at boot. This keymap must match your physical keyboard layout to ensure you can correctly enter your password.

### Network configuration

Set a unique hostname for your system.

```sh
echo myhostname > /etc/hostname
```

!!! tip "Further Network Setup Guidance"

    For additional guidance on network setup, see the [Installation guide: Network configuration](https://wiki.archlinux.org/title/Installation_guide#Network_configuration), the [NetworkManager](https://wiki.archlinux.org/title/NetworkManager) guide, and [Network configuration: Set the hostname](https://wiki.archlinux.org/title/Network_configuration#Set_the_hostname).

### Enable services that you may have optionally installed

???+ example "GNOME desktop environment and NetworkManager"

    #### Enable the GNOME display manager (GDM)

    !!! info inline end ""

        See the [GDM](https://wiki.archlinux.org/title/GDM) guide for more details.

    If you installed the GNOME desktop environment, enable its display manager so the graphical session starts automatically at boot.

    ```sh
    systemctl enable gdm.service
    ```

    #### Enable NetworkManager

    If you installed NetworkManager, enable it so it can manage network connections on your system.

    ```sh
    systemctl enable NetworkManager.service
    ```

### Set root password and create a user

!!! info inline end ""

    See the [Installation guide: Root password](https://wiki.archlinux.org/title/Installation_guide#Root_password) for more context.

Set a secure password for the root account. Even if you normally use `sudo` for administrative tasks, the root password is still required for system recovery through the `systemd` emergency target.

```sh
passwd
```

!!! info inline end ""

    For more information on managing users, see the [Users and groups](https://wiki.archlinux.org/title/Users_and_groups) guide.

Create a regular user (example: `foo`) and add them to the `wheel` group so they can use `sudo`.

```sh
useradd --create-home --groups wheel foo
passwd foo
```

Enable `sudo` access for the `wheel` group.

```sh
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/allow-wheel
```

### Swap space setup

!!! info inline end ""

    See the [Swap](https://wiki.archlinux.org/title/Swap) guide for a detailed guide to configuring swap space.

Even with large amounts of RAM, swap is important because it provides a backing store for inactive program memory, allowing the kernel to better manage physical RAM and file caching.

Select the appropriate method based on your filesystem to create and enable an 8 GiB (example size) swap file:

=== "Ext4 filesystem"

    Create an 8 GiB swap file on an Ext4 root filesystem and add it to `fstab`.

    ```sh
    mkdir -p /swap
    mkswap --uuid clear --size 8G --file /swap/swapfile
    echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
    ```

=== "Btrfs filesystem"

    !!! info inline end ""

        A Btrfs swap file requires specific creation steps to avoid copy-on-write issues. See the [Btrfs: Swap file](https://wiki.archlinux.org/title/Btrfs#Swap_file) guide for more details.

    Use the Btrfs-specific command to create the 8 GiB swap file and add it to `fstab`. `/swap` is a directory where the dedicated `@swap` subvolume was mounted earlier.

    ```sh
    btrfs filesystem mkswapfile --size 8g --uuid clear /swap/swapfile
    echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
    ```

### Configure Mkinitcpio

!!! info inline end ""

    For more information, see the [Installation guide: Initramfs](https://wiki.archlinux.org/title/Installation_guide#Initramfs) and the [Mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio) guide.

The initial ramdisk environment (`initramfs`) must be configured correctly to ensure reliable system booting, especially when using LUKS encryption or proprietary NVIDIA drivers.

You may apply the changes automatically using the commands provided below or perform the edits manually. If you choose manual configuration, open the primary configuration file.

```sh
nano /etc/mkinitcpio.conf
```

#### Configure boot-time initramfs settings

!!! abstract "Configure disk encryption"

    === "Use LUKS encryption"

        !!! info inline end ""

            See the [Encrypting an entire system: Configuring mkinitcpio](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Configuring_mkinitcpio) for more details.

        Integrate the `sd-encrypt` hook into the `HOOKS` array. This hook enables the system to prompt for decryption during the early boot stage.

        === "Apply changes automatically"

            Run the command below and review its output. Confirm that `sd-encrypt` appears after the `block` hook and before the `filesystems` hook in the `HOOKS=` line.

            ```sh
            sed -ri '/^HOOKS=/ { /\bsd-encrypt\b/! s/\bblock\b/& sd-encrypt/; }' /etc/mkinitcpio.conf && grep "^HOOKS=" /etc/mkinitcpio.conf
            ```

        === "Edit the file directly"

            Locate the `HOOKS=` line and manually insert `sd-encrypt` after the `block` hook and before the `filesystems` hook.

            ```
            HOOKS=(... block sd-encrypt filesystems ...)
            ```

    === "Do not use LUKS encryption"

        No changes are required.

???+ example "Configure the NVIDIA driver"

    !!! info inline end ""

        See the [NVIDIA: Early loading](https://wiki.archlinux.org/title/NVIDIA#Early_loading) for more details.

    To ensure the proprietary NVIDIA driver initializes correctly during the early boot stage, update both the `HOOKS` and `MODULES` arrays.

    **1. Remove the `kms` hook from `HOOKS`**

    Removing `kms` from the `HOOKS` array prevents the inclusion of the `nouveau` module in the initramfs, ensuring the kernel cannot load the open-source driver early in the boot process and avoiding conflicts with the proprietary NVIDIA driver.

    === "Apply changes automatically"

        Run the command below and review its output. Confirm that `kms` no longer appears in the `HOOKS=` line.

        ```sh
        sed -ri '/^HOOKS=/ s/\bkms\b\s*//' /etc/mkinitcpio.conf && grep "^HOOKS=" /etc/mkinitcpio.conf
        ```

    === "Edit the file directly"

        If `kms` appears in your `HOOKS` array, remove it.

        ```
        HOOKS=(...) # Make sure "kms" is not included!
        ```

    **2. Add the required NVIDIA modules to `MODULES`**

    These kernel modules ensure that the NVIDIA driver stack is loaded early during boot.

    Select the configuration that matches your system:

    === "Standard NVIDIA"

        Systems using only an NVIDIA GPU must load the full proprietary module set.

        === "Apply changes automatically"

            Run the command below and review its output. Confirm that the `MODULES=` line includes the following modules: `nvidia nvidia_modeset nvidia_uvm nvidia_drm`

            ```sh
            sed -ri '/^MODULES=/ { /\bnvidia\b/! s/\(/& nvidia nvidia_modeset nvidia_uvm nvidia_drm /; }' /etc/mkinitcpio.conf && grep "^MODULES=" /etc/mkinitcpio.conf
            ```

        === "Edit the file directly"

            Add the following kernel modules to the `MODULES` array:

            ```
            MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
            ```

    === "Hybrid with Intel iGPU"

        Systems using an NVIDIA GPU alongside an Intel integrated GPU (hybrid/Optimus) must also include the Intel `i915` module.

        === "Apply changes automatically"

            Run the command below and review its output. Confirm that the `MODULES=` line includes the following modules: `i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm`

            ```sh
            sed -ri '/^MODULES=/ { /\bnvidia\b/! s/\(/& i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm /; }' /etc/mkinitcpio.conf && grep "^MODULES=" /etc/mkinitcpio.conf
            ```

        === "Edit the file directly"
            
            Add the following kernel modules to the `MODULES` array:

            ```
            MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
            ```

#### Regenerate initramfs

Save your changes if you edited the configuration file manually, then regenerate all initramfs images.

```sh
mkinitcpio -P
```

### Boot loader finalization

!!! info inline end ""

    See the [systemd-boot: Updating the UEFI boot manager](https://wiki.archlinux.org/title/Systemd-boot#Updating_the_UEFI_boot_manager) for more details.

Re-run the boot installation command *inside* the chroot to ensure the bootloader files on the ESP match the system’s installed version.

```sh
bootctl install
```

Enable the automatic update service for `systemd-boot` to ensure the bootloader files are updated whenever the `systemd` package is upgraded.

```sh
systemctl enable systemd-boot-update.service
```

### Exit chroot and reboot

Exit the chroot environment to return to the live installation shell.

```sh
exit
```

Remove the installation USB drive and reboot the system into your new Arch Linux installation.

```sh
reboot
```

## Post-installation

Congratulations! Your Arch Linux system should now boot.

For further steps, see the [General recommendations](https://wiki.archlinux.org/title/General_recommendations) and the [List of applications](https://wiki.archlinux.org/title/List_of_applications) guides.

### Install AUR helper (optional)

!!! info inline end ""

    See the [AUR helpers](https://wiki.archlinux.org/title/AUR_helpers) guide and the [yay](https://github.com/Jguer/yay) project for more information.

Install `yay`, a popular tool for installing and managing packages from the Arch User Repository (AUR). Run these commands as your regular user, not as root.

```sh
sudo pacman -S --needed git base-devel
yay_temp="$(mktemp --directory)"
git clone https://aur.archlinux.org/yay-bin.git "${yay_temp:?}"
(cd "${yay_temp:?}" && makepkg -si)
rm -rf "${yay_temp:?}"
```

After installing, refer to the [First Use](https://github.com/Jguer/yay?tab=readme-ov-file#first-use) section of yay’s documentation. Review the instructions to decide if you wish to configure `yay` to automatically check for updates to development (`-git`) packages.
