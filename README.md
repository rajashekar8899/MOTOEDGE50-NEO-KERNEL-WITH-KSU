# Moto Edge 50 Neo Kernel with WildKSU + SUSFS

This repository automates the process of patching the stock Moto Edge 50 Neo `boot.img` with [WildKSU](https://github.com/WildKernels/GKI_KernelSU_SUSFS) (GKI 6.1.141) and SUSFS integration.

## How to Build the Patched boot.img

1. Go to the **Actions** tab in this repository.
2. Select the **Patch Kernel with WildKSU** workflow.
3. Click **Run workflow**.
4. You can specify the firmware directory (default: `firmware_V1UIS35H`) and kernel version if needed.
5. Once the workflow finishes, download the `patched-boot-6.1.141` artifact.

## How to Install

> [!WARNING]
> Rooting and flashing kernels carry risks. Ensure you have a backup of your data.
>
> **CRITICAL**: ONLY flash a `patched_boot.img` that exactly matches your device's **Build Number**. Flashing a kernel from a newer or older version than your current OS will result in a **BOOTLOOP** or **BRICK**.
>
> Check your build number in: `Settings > About phone > Build number`.

### Step 1: Flash Patched boot.img

1. Reboot your phone to fastboot mode:

   ```bash
   adb reboot bootloader
   ```

2. Flash the patched boot image:

   ```bash
   fastboot flash boot patched_boot.img
   ```

### Step 2: Patch init_boot.img

1. Download and install the [WildKSU Manager](https://github.com/WildKernels/Wild_KSU/releases/tag/latest). *It is highly recommended to use the spoofed version to hide the app from aggressive detection.*
2. Since the ramdisk is located in `init_boot.img` on this device:
   - Use the WildKSU app.
   - Choose "Direct Install" or "Patch File" (using the `init_boot.img` from the `firmware_V1UIS35H` folder).
   - Follow the app's instructions to complete the root process.

## Recommended Modules for Root Hiding

For best results in bypassing integrity checks and hiding root from aggressive apps, install the following modules in order:

1. **[ZygiskNext](https://github.com/Dr-TSNG/ZygiskNext/releases/tag/latest)**: Enables Zygisk for Magisk-style modules.
2. **[meta-overlayfs](https://github.com/KernelSU-Modules-Repo/meta-overlayfs/releases/tag/latest)**: The official reference mounting method for KernelSU (Recommended). It provides standard overlayfs support, ensuring high compatibility and proper unmounting.
3. **[SUSFS Module](https://github.com/sidex15/susfs4ksu-module/releases/tag/latest)**: Manages kernel-level SUSFS features.

## Repository Structure

- `firmware_V1UIS35H/`: Contains stock ROM files for version V1UIS35H.11-39-28-5.
- `.github/workflows/`: Contains the build automation script.

## Maintenance

When a new firmware update is available:

1. Create a new subdirectory (e.g., `firmware_NEWVERSION`).
2. Upload the new stock ROM files to it.
3. Run the GitHub Action selecting the new directory.

## Credits

- [WildKernels](https://github.com/WildKernels) for the GKI KernelSU + SUSFS builds.
- [topjohnwu](https://github.com/topjohnwu) for Magisk and `magiskboot`.
- [magojohnji](https://github.com/magojohnji/magiskboot-linux) for the Linux `magiskboot` binary.
