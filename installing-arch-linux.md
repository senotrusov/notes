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

# Installing <span class="nobr">Arch Linux</span>

## Preface

[Arch Linux](https://archlinux.org/) uses a hands-on installation approach in which you build the system step by step using explicit commands. This design emphasizes clarity and user control. There is no guided installer or hidden automation. Every part of the setup is open, deliberate, and visible, making each decision easier to understand.

To learn which commands to run and, more importantly, to understand the system components involved and how they fit together, the primary resource is the [Arch Wiki](https://wiki.archlinux.org/). It is well maintained and offers an extensive collection of up-to-date information. In particular, the [Installation guide](https://wiki.archlinux.org/title/Installation_guide) provides the foundation for installing a working system.

The reason this guide exists is that the Arch installation process encourages you to make your own choices. Doing so often requires substantial research, both on the Arch Wiki and elsewhere. The outcome of that research is a personal path: a specific sequence of commands paired with the reasoning behind them.

This guide serves as a set of lab notes that records both the steps taken and the rationale for each decision, allowing the installation process to remain reproducible without losing context. I originally created it for my own use, primarily for a personal laptop or workstation. Over time, it became clear that the result was fairly generic: a minimal, reasonably secure system that could be useful on many machines.

For that reason, I decided to share it with a broader audience. Common decisions are consolidated into ready-to-run command sequences, while still leaving you free to follow them exactly, diverge where necessary, or rework the process entirely.

At several points, the guide presents prepared alternatives. These cover choices such as full-disk encryption, `ext4` versus `Btrfs`, NVIDIA driver installation, and package selection. Each option is self-contained and includes a complete set of commands that can be used as-is.

Beyond the basic installation, the guide also addresses practical configuration details. It demonstrates how to align an NVMe drive to 4K sectors, enable TRIM in an encrypted setup, and create a clean partition layout using `parted`. It walks through configuring swap as a file, setting up `systemd-boot`, installing an [AUR](https://aur.archlinux.org/) helper, and enabling SSH during installation so you can work from another machine and copy commands easily.

The guide is distributed under the permissive [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0). I encourage you to submit a pull request if you want to add material in the same spirit, correct mistakes, or update the guide to reflect recent changes. You are also welcome to fork it and maintain your own version if your use case differs significantly.

This document does not replace the official [Installation Guide](https://wiki.archlinux.org/title/Installation_guide), which remains the definitive reference.

!!! danger "Data loss warning"

    This guide includes steps that will erase all data on your disk. Modify the disk preparation, partitioning, and formatting steps if you intend to preserve existing data.

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

    This method relies on the Arch Linux [download page](https://archlinux.org/download/#checksums) to securely provide the correct checksum.

    ```sh
    curl --silent --show-error "https://archlinux.org/download/" |
      grep -E --only-matching "SHA256.*[a-f0-9]{64}" |
      awk 'NR==1' |
      sed -E 's/SHA256.*([a-f0-9]{64})/\1  archlinux-x86_64.iso/' |
      sha256sum --check -
    ```

    If the output is `archlinux-x86_64.iso: OK`, the file is valid.

    !!! warning "One-liner limitations"

        Although this one-liner is convenient, changes to the download page formatting may prevent it from retrieving the correct checksum. If you encounter issues, use the manual method.

=== "Manually obtaining the checksum"

    Visit the Arch Linux [download page](https://archlinux.org/download/#checksums) and copy the SHA256 hash for the ISO.

    Replace `SIGNATURE` with the copied hash, then verify the file.

    ```sh
    sha256sum --check <(echo SIGNATURE archlinux-x86_64.iso)
    ```

    If the output is `archlinux-x86_64.iso: OK`, the file is valid.

### Write the ISO to a USB drive

Begin by identifying the USB device you plan to use. After verifying the correct device, store its path in a variable so you can safely proceed with creating the bootable drive.

You can locate the device with either `lsblk` or `fdisk`. The `lsblk` command provides detailed information, while `fdisk` offers a shorter summary.

=== "Using `lsblk`"

    Display the connected physical devices.

    ```sh
    lsblk -dpo NAME,SIZE,TRAN,MODEL,REV,SERIAL
    ```

    Then view the same devices again with expanded partition and filesystem details.

    ```sh
    lsblk -po NAME,SIZE,TYPE,MOUNTPOINTS,FSTYPE,LABEL,UUID,PARTTYPENAME,PARTLABEL
    ```

=== "Using `fdisk`"

    List the available disks and partitions.

    ```sh
    sudo fdisk -l
    ```

!!! danger "All data on the selected device will be lost"

    The device you choose will be completely erased in the following steps. Double check your selection to avoid unintended data loss.

Once you have confirmed the correct device, assign its path to a variable. Replace `sdX` with the actual device name of your USB drive.

```sh
flash="/dev/sdX"
```

Finally, use `dd` to write the ISO image to the device.

```sh
sudo dd if=archlinux-x86_64.iso of="${flash:?}" bs=4M status=progress oflag=sync
```

???+ example "Verify the USB copy (optional)"

    To ensure the data was written correctly, compare the written data byte-by-byte with the original ISO file.

    ```sh
    sudo dd if="${flash:?}" iflag=direct,count_bytes count="$(stat -c %s archlinux-x86_64.iso)" bs=4M status=progress | cmp - archlinux-x86_64.iso && echo VERIFIED || echo ERROR
    ```

## Boot from USB flash drive

Access your system’s firmware (BIOS/UEFI) settings to select the USB drive as the boot device.

The USB drive can be safely removed once the live environment loads to a shell prompt.

!!! warning "Secure Boot is not supported"

    The official Arch Linux installation images do not support Secure Boot, so it must be disabled to boot the installer. Enabling Secure Boot on the installed system is an advanced topic and is not covered in this guide. If required, consult the [Secure Boot](https://wiki.archlinux.org/title/Secure_Boot) page.

## Improve console readability

Change the console font for better legibility, especially on high-resolution displays. This sets the Terminus font with a Western European codepage and bold weight. Choose the font size that suits your needs.

```sh
setfont ter-124b  # 24-pixel height
setfont ter-128b  # 28-pixel height
setfont ter-132b  # 32-pixel height
```

!!! info

    For more details, see [Installation guide: Set the console keyboard layout and font](https://wiki.archlinux.org/title/Installation_guide#Set_the_console_keyboard_layout_and_font) and [Linux console: Fonts](https://wiki.archlinux.org/title/Linux_console#Fonts).

## Network checks and optional SSH connection

A stable network connection is mandatory for the installation. Test connectivity to ensure the live environment can reach the internet.

```sh
ping -c 3 archlinux.org
```

Wired connections typically work automatically.

!!! tip "Wireless Network"

    For wireless setup or troubleshooting, see the [Installation guide: Connect to the internet](https://wiki.archlinux.org/title/Installation_guide#Connect_to_the_internet) and the [Network configuration](https://wiki.archlinux.org/title/Network_configuration) guide.

???+ example "Connect to the live environment by SSH (optional)"

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

        Use the assigned IP address to connect from your client machine, replacing `IP_ADDRESS`.

        ```sh
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l root IP_ADDRESS
        ```

    !!! info

        Refer to the [Install Arch Linux via SSH](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH) guide for more information.

## Perform basic system checks

### Confirm UEFI boot mode

Confirm the system booted in UEFI mode, which is required for `systemd-boot`.

```sh
cat /sys/firmware/efi/fw_platform_size
```

If the file exists and contains `64`, the system is in 64-bit UEFI mode. If the file is absent, reboot the system and switch to UEFI mode in the firmware settings.

### Check system time

Verify the current time and that NTP synchronization is active.

```sh
timedatectl
```

The time zone set here only affects the live environment and will be configured for the installed system later.

!!! info

    For more details, see [Installation guide: Update the system clock](https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock).

## Assign variables for disk identification

Identify the target disk by listing available block devices and assign the device path and partition names to shell variables.

You can locate the device with either `lsblk` or `fdisk`. The `lsblk` command provides detailed information, while `fdisk` offers a shorter summary.

=== "Using `lsblk`"

    Display the connected physical devices.

    ```sh
    lsblk -dpo NAME,SIZE,TRAN,MODEL,REV,SERIAL
    ```

    Then view the same devices again with expanded partition and filesystem details.

    ```sh
    lsblk -po NAME,SIZE,TYPE,MOUNTPOINTS,FSTYPE,LABEL,UUID,PARTTYPENAME,PARTLABEL
    ```

=== "Using `fdisk`"

    List the available disks and partitions.

    ```sh
    fdisk -l
    ```

!!! danger "All data on the selected disk will be lost"

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

    Replace `/dev/sda` with the SATA device you want to use, and assign the partition names to variables.

    ```sh
    target=/dev/sda
    efi="${target:?}1"
    root_physical="${target:?}2"
    root_actual="${root_physical:?}"
    ```

The `root_actual` variable is initially set to the physical root partition and will be updated later if LUKS encryption is applied.

## Check disk settings

### Ensure 4K block size on NVMe drives

Aligning your NVMe drive to a 4K (4096 bytes) logical sector size, if supported, improves performance and durability.

!!! danger "Destructive operation with potential hardware risk"

    This operation is **destructive and will erase all data on the drive**. It has also been observed that some NVMe drives become unresponsive after formatting and require a system reboot before they operate again (although the new format will be applied afterward). It is also reasonable to assume that **some drives may become unusable due to firmware bugs**, as very few users ever change the factory default format. You likely do not want to be the first to discover such an issue, so proceed with caution and carefully **consider whether reformatting is worth the risk**. It is perfectly fine to stay with the manufacturer’s default format, even if it offers slightly lower performance, in exchange for peace of mind.

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

If a 4K format is supported but not active, reformat the drive to the optimal LBA Format ID.

```sh
nvme format --lbaf=FORMAT_ID "${target:?}"
```

!!! info

    See [Advanced Format: NVMe solid state drives](https://wiki.archlinux.org/title/Advanced_Format#NVMe_solid_state_drives) for more details.

### Verify TRIM support

Verify TRIM support, which allows the OS to communicate unused data blocks to a Solid State Drive (SSD) to maintain performance and lifespan. Non-zero values for `DISC-GRAN` and `DISC-MAX` confirm that TRIM support is present.

```sh
lsblk --discard "${target:?}"
```

!!! info

    See [Solid state drive: TRIM](https://wiki.archlinux.org/title/Solid_state_drive#TRIM) for more details.

## Create partitions

The plan is to create a ~1 GiB EFI system partition for boot files and use the remaining space for the root partition. Swap will later be added as a regular file within the root filesystem to keep the layout flexible.

!!! tip "Explore more partitioning options"

    For more ways to set up your partitions, see the [Installation guide: Partition the disks](https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks) and the [Parted](https://wiki.archlinux.org/title/Parted) guide on the Arch Wiki.

Launch `parted` for interactive partitioning.

```sh
parted "${target:?}"
```

### Create a GPT partition table

Create a GPT (GUID Partition Table), the modern standard required for UEFI.

```parted
mklabel gpt
```

### Set the unit to MiB for optimal alignment

Set the unit to mebibytes (`MiB`) so that any values passed to `mkpart` are interpreted in this unit. Doing this first ensures partitions land on precise mebibyte boundaries, which avoids alignment problems and improves performance. Because the default `parted` unit is less exact, explicitly selecting `MiB` helps prevent unintended offsets.

```parted
unit MiB
```

!!! info

    See [Advanced Format: Partition alignment](https://wiki.archlinux.org/title/Advanced_Format#Partition_alignment) for more details.

### Create the EFI system partition (ESP)

Create a FAT32 partition that occupies the space from 1 MiB up to the chosen alignment point, which comes out to roughly 1.10 GiB.

=== "Use LUKS encryption"

    ```parted
    mkpart efi fat32 1 1136
    ```

=== "Do not use LUKS encryption"

    ```parted
    mkpart efi fat32 1 1152
    ```

???+ tip "Rationale for the 1152 MiB alignment point"

    Modern high-density TLC and QLC flash devices that use 3-bit cells and multi-plane layouts often have erase block sizes divisible by three, such as 24 MiB, 48 MiB, or 96 MiB.

    Given that a boot partition typically needs about 1 GiB, a natural question arises: where should the root partition begin?

    The 1152 MiB mark serves as a convenient common multiple that aligns cleanly with both traditional binary-oriented block sizes (such as 16 or 32 MiB) and newer ternary-based patterns. The following JavaScript snippet shows how evenly it divides into current and plausible future erase block sizes.

    ```js
    [4, 8, 16, 24, 32, 48, 96, 128, 192].map(i => 1152 / i)
    ```

    This assumes, of course, that filesystems arrange data in ways that respect the alignment constraints imposed by the hardware, which remains outside our control.

    If you are using an encrypted partition with LUKS2, keep in mind that it adds its own header, typically 16 MiB. Subtract this amount from the 1152 MiB alignment target.

    As a side note, the boot partition is fine with 1 MiB alignment since it is rarely written.

### Set the ESP flag

Mark the first partition as the EFI System Partition, which is necessary for UEFI bootloaders.

```parted
set 1 esp on
```

!!! info

    See the [EFI system partition](https://wiki.archlinux.org/title/EFI_system_partition) for more information.

### Create the root partition

Create the root partition using all remaining disk space, starting immediately after the ESP.

=== "Use LUKS encryption"

    ```parted
    mkpart root 1136 100%
    ```

=== "Do not use LUKS encryption"

    ```parted
    mkpart root 1152 100%
    ```

### Check partition alignment

Verify optimal alignment for partition 1.

```parted
align-check opt 1
```

Verify optimal alignment for partition 2.

```parted
align-check opt 2
```

### Review and exit

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

        If you choose to encrypt the root partition `$root_physical` with LUKS2, the decrypted device becomes `$root_actual`.

        ### Format the root partition with LUKS2

        Format the root partition (`$root_physical`) using LUKS2. The `--sector-size 4096` option aligns encryption with 4K physical sectors, which improves performance on modern drives.

        When prompted, choose a strong passphrase and store it safely. Losing the passphrase means losing access to all encrypted data.

        ```sh
        cryptsetup luksFormat --batch-mode --verify-passphrase --type luks2 --sector-size 4096 "${root_physical:?}"
        ```

        ### Open the LUKS container and set persistent options

        Open the encrypted partition and map it as `/dev/mapper/luks-root`. The performance and discard options enabled here apply automatically for future unlocks.

        ```sh
        cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --allow-discards --persistent open "${root_physical:?}" luks-root
        ```

        ### Set the `root_actual` variable

        Update the variable so that subsequent filesystem operations target the decrypted container.

        ```sh
        root_actual="/dev/mapper/luks-root"
        ```

        !!! info

            For details on discard support and performance tuning, see 
            [Discard and TRIM support](https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)) and 
            [Disabling the workqueue for SSD performance](https://wiki.archlinux.org/title/Dm-crypt/Specialties#Disable_workqueue_for_increased_solid_state_drive_(SSD)_performance).

    === "Do not use LUKS encryption"

        No action is required for this step when not using LUKS encryption. The `$root_actual` variable, which represents the device path for the root filesystem, retains its initial value of `$root_physical`.

## Format and mount file systems

Format the partitions with the chosen filesystems and mount them to the installation directory (`/mnt`).

### Root partition

Choose either the traditional `ext4` filesystem or `Btrfs`.
`Ext4` is a traditional, robust, and mature filesystem. `Btrfs` provides checksums and supports subvolumes and snapshotting for flexible organization.

=== "Ext4 filesystem"

    Create an ext4 filesystem on the partition.

    ```sh
    mkfs.ext4 "${root_actual:?}"
    ```

    Mount the root partition to `/mnt`.

    ```sh
    mount -o noatime,commit=30 "${root_actual:?}" /mnt
    ```

    The `noatime` option improves performance by disabling file access time updates, and the `commit=30` option sets the maximum time (in seconds) that data is held in memory before being written to disk, balancing data loss risk and I/O performance.

    !!! info

        See the [ext4](https://wiki.archlinux.org/title/ext4) guide for more information.

=== "Btrfs filesystem"

    Format the partition as Btrfs.

    ```sh
    mkfs.btrfs "${root_actual:?}"
    ```

    Temporarily mount the top-level filesystem to create a commonly adopted Btrfs subvolume layout (`@` for root, `@home`, and `@swap`).

    ```sh
    mount "${root_actual:?}" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@swap
    umount /mnt
    ```

    Mount the subvolumes at their final mount points.

    ```sh
    mount -o noatime,flushoncommit,subvol=/@ "${root_actual:?}" /mnt
    mount --mkdir -o noatime,flushoncommit,subvol=/@home "${root_actual:?}" /mnt/home
    mount --mkdir -o noatime,flushoncommit,subvol=/@swap "${root_actual:?}" /mnt/swap
    ```

    The `noatime` option improves performance by disabling file access time updates, and `flushoncommit` prioritizes data integrity.

    !!! info

        See the [Btrfs](https://wiki.archlinux.org/title/Btrfs) guide for details on Btrfs usage and subvolume setup.

### EFI system partition

Format the ESP as FAT32, which is required for UEFI booting.

```sh
mkfs.fat -F 32 -S 4096 "${efi:?}"
```

Mount the ESP partition to `/mnt/boot` with secure permissions (`umask=0077`) to protect the boot files.

```sh
mount --mkdir -o noatime,umask=0077 "${efi:?}" /mnt/boot
```

Verify that all partitions, including subvolumes, are correctly mounted under `/mnt`.

```sh
mount | grep /mnt
```

!!! info

    See [Installation guide: Format the partitions](https://wiki.archlinux.org/title/Installation_guide#Format_the_partitions), [Installation guide: Mount the file systems](https://wiki.archlinux.org/title/Installation_guide#Mount_the_file_systems), and [File systems](https://wiki.archlinux.org/title/File_systems) for more details.

## Install essential packages

Select your CPU architecture below and run the corresponding code block in your shell to initialize the `packages` array. This array includes the kernel, firmware, boot manager tools, essential utilities, and the correct CPU microcode package.

### Define the base system

=== "Universal (Intel and AMD)"

    ```sh
    packages=(
      amd-ucode         # CPU microcode updates for AMD processors
      base              # Minimal base system required for a functional Arch installation
      efibootmgr        # Tool for managing UEFI boot entries
      intel-ucode       # CPU microcode updates for Intel processors
      linux             # The Linux kernel
      linux-firmware    # Firmware files required by many hardware devices
      man-db            # Backend for the manual page system
      man-pages         # Official Linux manual pages
      nano              # Simple terminal-based text editor
      sudo              # Privileged command execution for non-root users
      terminus-font     # Readable monospaced console font
      )
    ```

=== "Intel only"

    ```sh
    packages=(
      base              # Minimal base system required for a functional Arch installation
      efibootmgr        # Tool for managing UEFI boot entries
      intel-ucode       # CPU microcode updates for Intel processors
      linux             # The Linux kernel
      linux-firmware    # Firmware files required by many hardware devices
      man-db            # Backend for the manual page system
      man-pages         # Official Linux manual pages
      nano              # Simple terminal-based text editor
      sudo              # Privileged command execution for non-root users
      terminus-font     # Readable monospaced console font
      )
    ```

=== "AMD only"

    ```sh
    packages=(
      amd-ucode         # CPU microcode updates for AMD processors
      base              # Minimal base system required for a functional Arch installation
      efibootmgr        # Tool for managing UEFI boot entries
      linux             # The Linux kernel
      linux-firmware    # Firmware files required by many hardware devices
      man-db            # Backend for the manual page system
      man-pages         # Official Linux manual pages
      nano              # Simple terminal-based text editor
      sudo              # Privileged command execution for non-root users
      terminus-font     # Readable monospaced console font
      )
    ```

### Add optional packages

Append optional packages such as desktop environments, drivers, and file system utilities to the `packages` array as needed for your system.

???+ example "GNOME desktop environment"

    Install these packages to set up a modern graphical desktop with built in networking support.

    ```sh
    packages+=(
      gnome              # Full GNOME desktop environment
      networkmanager     # Network connection management service
    )
    ```

???+ example "Web browser and essential desktop fonts"

    Recommended for most desktop systems. A web browser is required for everyday use, and the Noto font family provides broad language and emoji coverage with consistent rendering.

    ```sh
    packages+=(
      firefox            # Graphical web browser
      noto-fonts         # Primary Unicode font family
      noto-fonts-cjk     # Chinese, Japanese, and Korean font support
      noto-fonts-emoji   # Emoji font for full emoji rendering
    )
    ```

???+ example "NVIDIA open kernel driver"

    Install this package if your system uses a supported NVIDIA GPU and you want hardware-accelerated graphics. It targets newer GPUs and integrates directly with the Linux kernel.

    ```sh
    packages+=(
      nvidia-open        # Open-source NVIDIA kernel driver
    )
    ```

???+ example "Btrfs file system utilities"

    Install these packages if you plan to use Btrfs on the root filesystem or on additional drives.

    ```sh
    packages+=(
      btrfs-progs        # Btrfs user-space management tools
      compsize           # Reports compression and disk usage on Btrfs
    )
    ```

???+ example "AUR and development tools"

    Install these packages if you intend to use the Arch User Repository (AUR). AUR helper installation is covered later in this guide.    

    ```sh
    packages+=(
      git                # Distributed version control system
      base-devel         # Basic tools to build Arch Linux packages
    )
    ```

???+ example "`systemd-resolved` system DNS resolver"

    Install this package only if you plan to use systemd-resolved and need compatibility with software that expects the traditional resolvconf interface. Do not include it unless systemd-resolved will be enabled later in this guide.

    ```sh
    packages+=(
      systemd-resolvconf # resolvconf compatibility for systemd-resolved
    )
    ```

!!! tip "More package ideas"

    See the [Installation guide: Install essential packages](https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages) for a complete list of recommended packages.

### Run package installation

After defining the base system and appending optional packages, run the following command to install all selected packages onto the mounted system.

```sh
pacstrap -K /mnt "${packages[@]:?}"
```

The `-K` flag ensures a proper `pacman` keyring setup in the new system.

## Patch the system in `/mnt` before chroot

### Fstab (file system table)

Generate the `fstab` file, which the system uses at boot to determine which filesystems to mount. The `-U` option ensures partitions are identified by their UUIDs for reliable mounting.

```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

Check the generated file to confirm the filesystem entries.

```sh
cat /mnt/etc/fstab
```

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

!!! info

    For details on configuring this file, see the [Installation guide: Fstab](https://wiki.archlinux.org/title/Installation_guide#Fstab).

### Configure systemd-boot

Install the `systemd-boot` boot manager. This command populates the EFI System Partition (ESP) with the necessary binaries and creates the default configuration directory structure.

```sh
bootctl --esp-path=/mnt/boot install
```

???+ tip "Why `bootctl install` must be repeated later"

    Note that this `bootctl install` step must be repeated later inside the chroot environment. The versions of packages on the live installation medium may be older than those installed on the target system, which can lead to mismatches.

    The initial invocation must be performed from outside the chroot, because a chroot environment cannot query EFI variables to register the bootloader (see [systemd issue #36174](https://github.com/systemd/systemd/issues/36174)).

???+ example "Verifying and managing EFI boot entries"

    Unlike legacy BIOS bootloaders, which reside physically on the disk’s Master Boot Record (MBR), UEFI boot entries are stored in the motherboard’s NVRAM (Non-Volatile RAM). Because of this, boot entries often persist even after a disk has been formatted or replaced.

    !!! danger "Risk of an unbootable system"

        Deleting or reordering the wrong boot entry can prevent the system from booting. Verify that you are not modifying the entry for your current installation, any other operating systems in a multiboot setup, or the firmware interface.

    ???+ tip "About the Unicode Switch"

        Although the UEFI specification mandates UCS-2 (Unicode) encoding for boot entry descriptions and arguments, `efibootmgr` defaults to ASCII to maintain compatibility with older or non-standard firmware. 
        
        Most modern systems follow the standard and require the <span class="nobr">`--unicode`</span> switch. However, some firmware implementations are non-compliant and may expect ASCII. If your boot entries appear as unreadable garbage text or fail to pass arguments to the kernel, try toggling this switch to match your firmware's behavior.

    === "With unicode switch"

        <h4>View boot order and entries</h4>

        You can list the current boot configuration, which includes the active `BootOrder` and a list of all available boot options.

        ```sh
        efibootmgr --unicode
        ```

        <h4>Identify your new entry</h4>
        
        The full list of boot entries can be confusing, often containing leftovers from previous installations or firmware defaults. To easily locate the entry for your new installation, filter the list using your EFI partition’s UUID.

        ```sh
        efibootmgr --unicode | grep -F "$(lsblk --nodeps --noheadings --output "PARTUUID" "${efi:?}")"
        ```

        <h4>Modify boot order</h4>
        
        If your new entry is not at the top of the list, you can manually update the boot order. Replace `XXXX` with the hexadecimal boot numbers (for example, `0001,0003`) found in the output above.

        ```sh
        efibootmgr --unicode --bootorder XXXX,XXXX 
        ```

        <h4>Remove stale entries</h4>
        
        You may find leftover entries from previous installations or experiments. To keep your boot menu clean, you can delete these stale entries.
        
        ```sh
        efibootmgr --unicode --delete-bootnum --bootnum XXXX
        ```

    === "Without unicode switch"

        <h4>View boot order and entries</h4>

        You can list the current boot configuration, which includes the active `BootOrder` and a list of all available boot options.

        ```sh
        efibootmgr
        ```

        <h4>Identify your new entry</h4>
        
        The full list of boot entries can be confusing, often containing leftovers from previous installations or firmware defaults. To easily locate the entry for your new installation, filter the list using your EFI partition’s UUID.

        ```sh
        efibootmgr | grep -F "$(lsblk --nodeps --noheadings --output "PARTUUID" "${efi:?}")"
        ```

        <h4>Modify boot order</h4>
        
        If your new entry is not at the top of the list, you can manually update the boot order. Replace `XXXX` with the hexadecimal boot numbers (for example, `0001,0003`) found in the output above.

        ```sh
        efibootmgr --bootorder XXXX,XXXX 
        ```

        <h4>Remove stale entries</h4>
        
        You may find leftover entries from previous installations or experiments. To keep your boot menu clean, you can delete these stale entries.
        
        ```sh
        efibootmgr --delete-bootnum --bootnum XXXX
        ```

#### Configure `loader.conf`

Set `arch.conf` as the default boot entry in the global bootloader configuration file.

```sh
echo "default arch.conf" >> /mnt/boot/loader/loader.conf
```

#### Create `arch.conf` boot entry

Define the boot process for the Arch Linux kernel.

##### Get UUID

First, retrieve the UUID of the physical root partition.

```sh
root_device_uuid="$(lsblk --nodeps --noheadings --output "UUID" "${root_physical:?}")"
```

##### Define kernel arguments

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

##### Create the configuration file

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

!!! info

    Consult the [systemd-boot](https://wiki.archlinux.org/title/Systemd-boot) wiki page, read more about [Microcode and systemd-boot](https://wiki.archlinux.org/title/Microcode#systemd-boot) to ensure proper loading, and see [UEFI: efibootmgr](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface#efibootmgr) for managing boot entries.

### Configure `systemd-resolved`

The `/etc/resolv.conf` file is bind-mounted from the host system when using `arch-chroot`, so it cannot be replaced from inside the chroot. To ensure DNS resolution works correctly on the installed system, you must create the symlink before entering the chroot environment.

Run the following command from outside the chroot.

```sh
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
```

!!! info

    For more details about DNS handling and alternative setups, see the [systemd-resolved](https://wiki.archlinux.org/title/Systemd-resolved) wiki page.

## Chroot into the installed system for final configuration

Change the root directory to the newly installed system to complete the final configuration steps.

In an Arch Linux installation, `chroot` (change root) places you inside the installed system environment. Until now, you have been working from the live installation environment, which is outside the installed system. After chrooting, all commands will run as if the system were already booted.

```sh
arch-chroot /mnt
```

!!! info

    See the [Installation guide: Chroot](https://wiki.archlinux.org/title/Installation_guide#Chroot) for more information on this process.

### Time configuration

Configure the system clock to use the correct time zone and keep it synchronized automatically.

First, list all supported time zones and identify the one that matches your region or intended system role, such as `UTC` for servers.

```sh
timedatectl list-timezones
```

Then, set the system time zone by linking `/etc/localtime` to the appropriate zoneinfo file. Replace `Etc/UTC` with the time zone you want.

```sh
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
```

Next, synchronize the hardware clock with the current system time and generate `/etc/adjtime`.

```sh
hwclock --systohc
```

Finally, enable automatic network time synchronization to keep the clock accurate.

```sh
systemctl enable systemd-timesyncd.service
```

!!! info

    For more information, see the [Installation guide: Time](https://wiki.archlinux.org/title/Installation_guide#Time) and the [System time](https://wiki.archlinux.org/title/System_time) documentation.

### Localization

This section configures the system language, regional formatting, and console behavior.

#### Configure `/etc/locale.gen`

Locales must be generated before they can be used. The file `/etc/locale.gen` determines which locales will be built by `locale-gen`.

You can either edit the file and uncomment the locales you need, or overwrite it with only the required entries. Both methods are valid.

=== "Overwrite `/etc/locale.gen`"

    Begin by creating a backup of the file for future reference.

    ```sh
    cp /etc/locale.gen /etc/locale.gen-dist
    ```

    Next, list the available locales. The example below filters for English locales, but you can adjust the search pattern.

    ```sh
    grep -i en /usr/share/i18n/SUPPORTED
    ```

    Finally, write your selected locales to `/etc/locale.gen`. The example demonstrates a mixed European style that will be described later.

    ```sh
    cat <<EOF > /etc/locale.gen
    en_DK.UTF-8 UTF-8
    en_IE.UTF-8 UTF-8
    en_US.UTF-8 UTF-8
    EOF
    ```

=== "Uncomment existing entries"

    Open `/etc/locale.gen` and remove the leading `#` from the locales you want to enable.

    ```sh
    nano /etc/locale.gen
    ```

After updating the file, generate the locales:

```sh
locale-gen
```

#### Create `/etc/locale.conf`

Create `/etc/locale.conf` to define system-wide locale environment variables.

The example below uses English (United States) for system messages, which is the least surprising option for most Linux software, while applying ISO date and time formatting, metric units for measurements, the euro for currency, and ISO 216 A4 as the default paper size.

```sh
cat <<EOF > /etc/locale.conf
LANG=en_US.UTF-8
LC_MEASUREMENT=en_IE.UTF-8
LC_MONETARY=en_IE.UTF-8
LC_PAPER=en_IE.UTF-8
LC_TIME=en_DK.UTF-8
EOF
```

Key points:

* `LANG` defines the default locale and message language.
* `LC_MEASUREMENT` enables metric units.
* `LC_MONETARY` uses the euro.
* `LC_PAPER` sets A4 as the default paper size.
* `LC_TIME` applies ISO style date and time formatting.

#### Configure the virtual console

The virtual console settings control the keyboard layout and font used in TTYs and during early boot.

Edit `/etc/vconsole.conf` to set `KEYMAP` and `FONT`.

Example configuration for a US keyboard layout with the Terminus font (Western European codepage, 28 pixel height, bold):

```sh
cat <<EOF > /etc/vconsole.conf
KEYMAP=us
FONT=ter-124b
EOF
```

!!! warning "Ensure correct keymap for disk unlock"

    When using LUKS full disk encryption, the `KEYMAP` defined in `/etc/vconsole.conf` is the only keyboard layout available during boot when entering the unlock password. This layout must match your physical keyboard exactly, or you may not be able to type the correct password.

!!! info

    For additional details, see the [Arch Linux Installation Guide – Localization](https://wiki.archlinux.org/title/Installation_guide#Localization).

### Network configuration

Set a unique hostname for your system.

```sh
echo myhostname > /etc/hostname
```

#### Configure systemd-resolved to use DNS over TLS

Enable the `systemd-resolved` service.

```sh
systemctl enable systemd-resolved.service
```

Create the configuration drop-in directory.

```sh
mkdir -p /etc/systemd/resolved.conf.d
```

Create a drop-in configuration file for your preferred DNS provider. Use one of the examples below or provide your own configuration. These examples enforce encrypted DNS resolution for all domains.

=== "Cloudflare"

    ```sh
    cat <<EOF > /etc/systemd/resolved.conf.d/dns_over_tls.conf
    [Resolve]
    DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com 2606:4700:4700::1001#cloudflare-dns.com
    DNSOverTLS=yes
    Domains=~.
    EOF
    ```

=== "Google"

    ```sh
    cat <<EOF > /etc/systemd/resolved.conf.d/dns_over_tls.conf
    [Resolve]
    DNS=8.8.8.8#dns.google 8.8.4.4#dns.google 2001:4860:4860::8888#dns.google 2001:4860:4860::8844#dns.google
    DNSOverTLS=yes
    Domains=~.
    EOF
    ```

=== "Both Cloudflare and Google"

    ```sh
    cat <<EOF > /etc/systemd/resolved.conf.d/dns_over_tls.conf
    [Resolve]
    DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com 2606:4700:4700::1001#cloudflare-dns.com 8.8.8.8#dns.google 8.8.4.4#dns.google 2001:4860:4860::8888#dns.google 2001:4860:4860::8844#dns.google
    DNSOverTLS=yes
    Domains=~.
    EOF
    ```

#### Network management

If you installed GNOME together with NetworkManager, networking will be managed automatically. NetworkManager will be enabled in a later section. 

If you did not install GNOME and NetworkManager, you must configure networking manually. The example below uses [`systemd-networkd`](https://wiki.archlinux.org/title/Systemd-networkd) and should work out of the box for a wired Ethernet connection using DHCP.

???+ abstract "Configure networking with systemd-networkd"

    Enable the `systemd-networkd` service so it can manage network interfaces at boot.

    ```sh
    systemctl enable systemd-networkd.service
    ```

    Create a basic DHCP profile for wired Ethernet interfaces.

    ```sh
    cat <<EOF > /etc/systemd/network/10-wired.network
    [Match]
    Name=en*
    Name=eth*

    [Link]
    RequiredForOnline=routable

    [Network]
    DHCP=yes

    [DHCPv4]
    RouteMetric=100

    [IPv6AcceptRA]
    RouteMetric=100
    EOF
    ```

    If you use Wi-Fi, you will also need a wireless network profile. Note that `systemd-networkd` does not handle Wi-Fi authentication, so you must connect and authenticate using [`wpa_supplicant`](https://wiki.archlinux.org/title/Wpa_supplicant) or the newer [`iwd`](https://wiki.archlinux.org/title/Iwd).

    ```sh
    cat <<EOF > /etc/systemd/network/60-wireless.network
    [Match]
    Name=wl*

    [Link]
    RequiredForOnline=routable

    [Network]
    DHCP=yes

    [DHCPv4]
    RouteMetric=600

    [IPv6AcceptRA]
    RouteMetric=600
    EOF
    ```

!!! tip "Further network setup guidance"

    See [Network configuration: Set the hostname](https://wiki.archlinux.org/title/Network_configuration#Set_the_hostname) for hostname configuration, [systemd-resolved](https://wiki.archlinux.org/title/Systemd-resolved) for DNS management, and the [Network configuration](https://wiki.archlinux.org/title/Network_configuration) page for additional networking guidance.

### Enable services that you may have optionally installed

???+ example "GNOME desktop environment"

    #### Enable the GNOME display manager (GDM)

    If you installed the GNOME desktop environment, enable its display manager so the graphical login screen starts automatically at boot.

    ```sh
    systemctl enable gdm.service
    ```

    #### Enable NetworkManager

    If NetworkManager is installed, enable it so network connections are managed automatically.

    ```sh
    systemctl enable NetworkManager.service
    ```

    #### Enable the Bluetooth service

    If Bluetooth packages are installed, enable the Bluetooth service to manage devices.

    ```sh
    systemctl enable bluetooth.service
    ```

    !!! info

        See the [GDM](https://wiki.archlinux.org/title/GDM) guide for details on the GNOME display manager, the [NetworkManager](https://wiki.archlinux.org/title/NetworkManager) guide for configuring networking, and the [Bluetooth](https://wiki.archlinux.org/title/Bluetooth) page for setting up Bluetooth support.

### Set root password and create a user

Set a strong password for the root account. Even if you normally use `sudo` for administrative tasks, the root password is required for system recovery tasks such as entering the `systemd` emergency shell.

```sh
passwd
```

Choose a username for your regular account (example: `foo`).

```sh
username=foo
```

Create the user, including a home directory, and add them to the `wheel` group to allow administrative access via `sudo`.

```sh
useradd --create-home --groups wheel "${username:?}"
```

Set a secure password for the new user.

```sh
passwd "${username:?}"
```

Enable `sudo` access for members of the `wheel` group.

```sh
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/allow-wheel
```

!!! info

    See the [Installation guide: Root password](https://wiki.archlinux.org/title/Installation_guide#Root_password) for more context, and the [Users and groups](https://wiki.archlinux.org/title/Users_and_groups) guide for additional details on account management.

### Swap space setup

Even on systems with plenty of RAM, swap plays an important role. It provides backing storage for inactive memory pages, helping the kernel manage physical RAM more efficiently.

Choose the method that matches your filesystem to create and enable a swap file. The examples below use an 8 GiB swap file, but the same steps apply to other sizes.

=== "Ext4 filesystem"

    Create a swap file on an Ext4 root filesystem and ensure it is activated at boot.

    Start by creating a directory to hold the swap file.

    ```sh
    mkdir -p /swap
    ```

    Create the swap file with a fixed UUID and the desired size.

    ```sh
    mkswap --uuid clear --size 8G --file /swap/swapfile
    ```

    Add the swap file to `fstab` so it is enabled automatically during boot.

    ```sh
    echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
    ```

    !!! info

        For more background and tuning options, see the [Swap](https://wiki.archlinux.org/title/Swap) documentation.

=== "Btrfs filesystem"

    Create a swap file using Btrfs-specific tooling and enable it at boot. In this example, `/swap` refers to a directory where a dedicated `@swap` subvolume is already mounted.

    Use the Btrfs helper command to create the swap file.

    ```sh
    btrfs filesystem mkswapfile --size 8g --uuid clear /swap/swapfile
    ```

    Register the swap file in `fstab` so it is activated automatically.

    ```sh
    echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
    ```

    !!! info

        Additional details are covered in the [Btrfs: Swap file](https://wiki.archlinux.org/title/Btrfs#Swap_file) and [Swap](https://wiki.archlinux.org/title/Swap) documentation.

### Enable periodic TRIM

=== "Ext4 filesystem"

    If your root filesystem is `ext4` on an SSD, enable the `fstrim` timer so the system periodically issues TRIM to free unused blocks. This helps maintain SSD write performance over time.

    ```sh
    systemctl enable fstrim.timer
    ```

=== "Btrfs filesystem"

    No action is needed, since Btrfs automatically enables the `discard=async` mount option on devices that support it.

### Configure Mkinitcpio

The initial ramdisk environment (`initramfs`) must be configured correctly to ensure successful system booting, particularly when using LUKS encryption or proprietary NVIDIA drivers.

You can add drop-in configuration files or make the changes manually. If you choose manual configuration, open the primary configuration file and follow the instructions below.

```sh
nano /etc/mkinitcpio.conf
```

#### Configure boot-time initramfs settings

???+ abstract "Configure disk encryption"

    === "Use LUKS encryption"

        Integrate the `sd-encrypt` hook into the `HOOKS` array. This hook enables the system to prompt for decryption during the early boot stage.

        === "Add drop-in configuration file"

            Create the following drop-in configuration file to automatically insert `sd-encrypt` immediately after the `block` hook in the `HOOKS=` array.

            ```sh
            cat <<'EOF' > /etc/mkinitcpio.conf.d/10-add-luks-encryption-hook.conf
            mapfile -t HOOKS < <(
              for element in "${HOOKS[@]}"; do
                echo "$element"
                if [ "$element" = "block" ]; then
                  echo "sd-encrypt"
                fi
              done
            )
            EOF
            ```

        === "Edit the file directly"

            Locate the `HOOKS=` line and manually insert `sd-encrypt` after the `block` hook and before the `filesystems` hook.

            ```
            HOOKS=(... block sd-encrypt filesystems ...)
            ```

        !!! info

            See the [Encrypting an entire system: Configuring mkinitcpio](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Configuring_mkinitcpio) for more details.

    === "Do not use LUKS encryption"

        No changes are required.

???+ abstract "Configure the NVIDIA driver"

    To ensure the proprietary NVIDIA driver initializes correctly during the early boot stage, update both the `HOOKS` and `MODULES` arrays.

    <h5>Remove the `kms` hook from `HOOKS`</h5>

    Removing `kms` from the `HOOKS` array prevents the inclusion of the `nouveau` module in the initramfs, ensuring the kernel cannot load the open-source driver early in the boot process and avoiding conflicts with the proprietary NVIDIA driver.

    === "Add drop-in configuration file"

        Add this drop-in configuration file that will remove `kms` from `HOOKS` array

        ```sh
        cat <<'EOF' > /etc/mkinitcpio.conf.d/20-remove-kms-hook.conf
        mapfile -t HOOKS < <(
          for element in "${HOOKS[@]}"; do
            if [ "$element" != "kms" ]; then
              echo "$element"
            fi
          done
        )
        EOF
        ```

    === "Edit the file directly"

        If `kms` appears in your `HOOKS` array, remove it.

        ```
        HOOKS=(...) # Make sure "kms" is not included!
        ```

    <h5>Add the required NVIDIA modules to `MODULES`</h5>

    These kernel modules ensure the NVIDIA driver stack is available early in the boot process.

    Choose the configuration that matches your system.

    === "NVIDIA-only system"

        This configuration is for systems that use only an NVIDIA GPU.

        The proprietary NVIDIA driver requires the following kernel modules to be loaded during early boot.

        === "Add drop-in configuration file"

            Create a drop-in configuration file that appends the required NVIDIA kernel modules to the mkinitcpio `MODULES` array.

            ```sh
            cat <<EOF > /etc/mkinitcpio.conf.d/30-add-nvidia-modules.conf
            MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
            EOF
            ```

        === "Edit the file directly"

            Add the following NVIDIA kernel modules to the `MODULES` array.

            ```
            MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
            ```

    === "Hybrid with Intel iGPU"

        This configuration is for systems with an NVIDIA GPU and an Intel integrated GPU (Optimus or hybrid graphics).

        Early boot requires both the Intel `i915` module and the NVIDIA driver modules.

        === "Add drop-in configuration file"

            Create a drop-in configuration file that appends the required Intel and NVIDIA kernel modules to the mkinitcpio `MODULES` array.

            ```sh
            cat <<EOF > /etc/mkinitcpio.conf.d/30-add-nvidia-modules.conf
            MODULES+=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
            EOF
            ```
            
        === "Edit the file directly"

            Add the following Intel and NVIDIA kernel modules to the `MODULES` array.

            ```
            MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
            ```

    !!! info

        See the [NVIDIA: Early loading](https://wiki.archlinux.org/title/NVIDIA#Early_loading) for more details.

#### Regenerate initramfs

Save your changes if you edited the configuration file manually, then regenerate all initramfs images.

```sh
mkinitcpio -P
```

!!! info

    For more information, see the [Installation guide: Initramfs](https://wiki.archlinux.org/title/Installation_guide#Initramfs) and the [Mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio) guide.

### Boot loader finalization

Re-run the boot installation command *inside* the chroot to ensure the bootloader files on the ESP match the system’s installed version.

```sh
bootctl install
```

Enable the automatic update service for `systemd-boot` to ensure the bootloader files are updated whenever the `systemd` package is upgraded.

```sh
systemctl enable systemd-boot-update.service
```

!!! info

    See the [systemd-boot: Updating the UEFI boot manager](https://wiki.archlinux.org/title/Systemd-boot#Updating_the_UEFI_boot_manager) for more details.

### Install AUR helper

Install [yay](https://github.com/Jguer/yay), a popular helper for installing and managing packages from the Arch User Repository (AUR).

???+ abstract "This is an optional step"

    Use the prebuilt **`yay-bin`** package from the AUR. This avoids compiling `yay` from source while still following the standard AUR workflow.

    Switch to the regular user account created earlier. You may see the error message `tty: ttyname error: No such device`. This happens because the chroot environment cannot resolve the terminal device path from the host. It is safe to ignore and does not affect the user session.

    ```sh
    runuser -l "${username:?}"
    ```

    Now, acting as your regular user, create a temporary directory and switch to it. This directory will be used to build the package.

    ```sh
    cd "$(mktemp -d)"
    ```

    Clone the `yay-bin` AUR repository into the current directory.

    ```sh
    git clone https://aur.archlinux.org/yay-bin.git .
    ```

    Build and install the package.

    ```sh
    makepkg -si
    ```

    Configure `yay` to always check for updates to development (`-git`) packages.

    ```sh
    yay --devel --save
    ```

    Exit the user shell to return to the root environment.

    ```sh
    exit
    ```

    !!! info

        See the [AUR helpers](https://wiki.archlinux.org/title/AUR_helpers) guide and the [yay](https://github.com/Jguer/yay) project for more information.

### Exit chroot and reboot

Exit the chroot environment to return to the live installation shell.

```sh
exit
```

Ensure the installation USB drive has been removed, then reboot the system into your new Arch Linux installation.

```sh
reboot
```

## Post-installation

Congratulations! Your Arch Linux system should now boot.

For further steps, see the [General recommendations](https://wiki.archlinux.org/title/General_recommendations) and the [List of applications](https://wiki.archlinux.org/title/List_of_applications) guides.
