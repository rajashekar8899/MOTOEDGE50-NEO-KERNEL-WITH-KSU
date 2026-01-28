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

1. Download and install the [WildKSU Manager](https://github.com/WildKernels/Wild_KSU).
2. Since the ramdisk is located in `init_boot.img` on this device:
   - Use the WildKSU app.
   - Choose "Direct Install" or "Patch File" (using the `init_boot.img` from the `firmware_V1UIS35H` folder).
   - Follow the app's instructions to complete the root process.

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
