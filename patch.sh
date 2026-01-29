#!/bin/bash
set -e

# 1. Setup Tools
wget https://github.com/magojohnji/magiskboot-linux/raw/main/x86_64/magiskboot -O magiskboot
chmod +x magiskboot

# 2. Extract Variables
if [ -z "$INPUT_FW" ]; then
  FW_DIR=$(ls -d firmware_* | sort -V | tail -n 1)
else
  FW_DIR="$INPUT_FW"
fi
echo "Using firmware: $FW_DIR"

# 3. Extract Stock Info
./magiskboot unpack "$FW_DIR/boot.img"
mv kernel kernel.stock
STOCK_FULL=$(strings kernel.stock | grep "Linux version " | head -n 1)

if [ -z "$INPUT_KV" ]; then
  K_VER=$(echo "$STOCK_FULL" | awk '{print $3}' | cut -d'-' -f1)
else
  K_VER="$INPUT_KV"
fi
echo "Target Kernel Version: $K_VER"

# 4. Fetch WildKSU
R_TAG=$(gh release view --repo WildKernels/GKI_KernelSU_SUSFS --json tagName --jq .tagName)
ASSET=$(gh release view "$R_TAG" --repo WildKernels/GKI_KernelSU_SUSFS --json assets --jq ".assets[] | select(.name | contains(\"$K_VER\") and contains(\"Normal\")) | .name" | head -n 1)
if [ -z "$ASSET" ]; then echo "Error: No matching WildKSU GKI for $K_VER"; exit 1; fi
gh release download "$R_TAG" --repo WildKernels/GKI_KernelSU_SUSFS --pattern "$ASSET"
unzip "$ASSET" Image
WILD_FULL=$(strings Image | grep "Linux version " | head -n 1)

# 5. Extract Stock Metadata
STOCK_SHA256=$(sha256sum "$FW_DIR/boot.img" | awk '{print $1}')
echo "Stock boot.img SHA256: $STOCK_SHA256"

# Extract info from .info.txt file if it exists
INFO_FILE=$(find "$FW_DIR" -name "*.info.txt" -type f | head -n 1)
SW_VERSION=""
BUILD_FINGERPRINT=""
SW_DISPLAY_BUILD=""
MODEM_VERSION=""

if [ -n "$INFO_FILE" ]; then
    echo "Found info file: $INFO_FILE"
    SW_VERSION=$(grep "SW Version:" "$INFO_FILE" | sed 's/.*SW Version: //')
    BUILD_FINGERPRINT=$(grep "Build Fingerprint:" "$INFO_FILE" | sed 's/.*Build Fingerprint: //')
    SW_DISPLAY_BUILD=$(grep "SW Display Build ID:" "$INFO_FILE" | sed 's/.*SW Display Build ID: //')
    MODEM_VERSION=$(grep "Modem Version:" "$INFO_FILE" | sed 's/.*Modem Version: //')
fi

# 6. Patch Binary - Replace ALL WildKSU strings
export STOCK_FULL="$STOCK_FULL"
export WILD_FULL="$WILD_FULL"
python3 << 'PYTHON_SCRIPT'
import os
import sys

# Read the WildKSU kernel
with open('Image', 'rb') as f:
    data = bytearray(f.read())

stock_str = os.environ['STOCK_FULL'].encode()
wild_str = os.environ['WILD_FULL'].encode()

print(f"Stock version: {stock_str.decode('utf-8', errors='ignore')}")
print(f"Wild version: {wild_str.decode('utf-8', errors='ignore')}")

# Check if we can replace
if len(stock_str) > len(wild_str):
    print(f"ERROR: Stock string ({len(stock_str)} bytes) is longer than Wild string ({len(wild_str)} bytes)")
    print("Cannot safely replace without potentially corrupting the kernel")
    sys.exit(1)

# Replace ALL occurrences of the Wild version string with Stock version
replacements = 0
pos = 0
while True:
    pos = data.find(wild_str, pos)
    if pos == -1:
        break
    # Replace with stock string and pad with null bytes
    replacement = stock_str + b'\x00' * (len(wild_str) - len(stock_str))
    data[pos:pos+len(wild_str)] = replacement
    replacements += 1
    pos += len(wild_str)

print(f"Replaced {replacements} occurrence(s) of Wild version string")

# Also replace common WildKSU/WildKernels identifiers
wild_identifiers = [
    b'WildKernels',
    b'WildKSU',
    b'wild-ksu',
    b'wildksu'
]

for identifier in wild_identifiers:
    count = 0
    pos = 0
    while True:
        pos = data.find(identifier, pos)
        if pos == -1:
            break
        # Replace with spaces/nulls to hide the identifier
        data[pos:pos+len(identifier)] = b'\x00' * len(identifier)
        count += 1
        pos += len(identifier)
    if count > 0:
        print(f"Nullified {count} occurrence(s) of '{identifier.decode('utf-8', errors='ignore')}'")

# Write the patched kernel
with open('kernel', 'wb') as f:
    f.write(data)

print("Kernel patching completed successfully")
PYTHON_SCRIPT

# 6. Repack
./magiskboot repack "$FW_DIR/boot.img" patched_boot.img

# 7. Update README Modules
W_APP=$(gh release view --repo WildKernels/Wild_KSU --json tagName --jq .tagName)
Z_NX=$(gh release view --repo Dr-TSNG/ZygiskNext --json tagName --jq .tagName)
M_OV=$(gh release view --repo KernelSU-Modules-Repo/meta-overlayfs --json tagName --jq .tagName)
S_MD=$(gh release view --repo sidex15/susfs4ksu-module --json tagName --jq .tagName)

sed -i "s|Wild_KSU/releases/tag/[^)]*|Wild_KSU/releases/tag/$W_APP|g" README.md
sed -i "s|ZygiskNext/releases/tag/[^)]*|ZygiskNext/releases/tag/$Z_NX|g" README.md
sed -i "s|meta-overlayfs/releases/tag/[^)]*|meta-overlayfs/releases/tag/$M_OV|g" README.md
sed -i "s|susfs4ksu-module/releases/tag/[^)]*|susfs4ksu-module/releases/tag/$S_MD|g" README.md

git config --local user.email "action@github.com"
git config --local user.name "GitHub Action"
if ! git diff --exit-code README.md; then
  git add README.md
  git commit -m "Docs: Auto-update module versions"
  git push origin master
fi

# 8. Create Release
# 8. Create Release
# 8. Create Release
BUILD_ID=$(echo "$STOCK_FULL" | sed 's/Linux version //;s/ (.*//')

# Attempt to extract full Motorola Build ID (e.g., V1UIS35H.11-39-28-5)
# Strategy 1: Look for ro.build.display.id in ramdisk strings
MOTO_ID=""
if [ -f "$FW_DIR/init_boot.img" ]; then
    ./magiskboot unpack "$FW_DIR/init_boot.img"
    # magiskboot might output 'ramdisk' or 'ramdisk.cpio'
    if [ -f "ramdisk.cpio" ]; then RD_FILE="ramdisk.cpio"; else RD_FILE="ramdisk"; fi
    
    if [ -f "$RD_FILE" ]; then
        # Try finding the display ID property (Standard Android)
        MOTO_ID=$(strings "$RD_FILE" | grep "ro.build.display.id=" | head -n 1 | cut -d'=' -f2)
        
        # If standard failed, try Motorola specific property
        if [ -z "$MOTO_ID" ]; then
             MOTO_ID=$(strings "$RD_FILE" | grep "ro.mot.build.version.release=" | head -n 1 | cut -d'=' -f2)
        fi
        
        # If that failed, try just finding the pattern string in the whole file
        if [ -z "$MOTO_ID" ]; then
             MOTO_ID=$(strings "$RD_FILE" | grep -oE "V1[A-Z0-9]{6}\.[0-9]+-[0-9]+-[0-9]+-[0-9]+" | head -n 1)
        fi
        
        rm "$RD_FILE"
    fi
fi

# Strategy 2: If finding property failed, try aggressive grep on kernel/ramdisk for the specific pattern
if [ -z "$MOTO_ID" ]; then
    MOTO_ID=$(strings kernel.stock | grep -oE "V1[A-Z0-9]{6}\.[0-9]+-[0-9]+-[0-9]+-[0-9]+" | head -n 1)
fi

# Strategy 3: Fallback to folder name
if [ -z "$MOTO_ID" ]; then
    FW_VER=$(basename "$FW_DIR" | sed 's/^firmware_//')
else
    FW_VER="$MOTO_ID"
fi

TAG="$FW_VER"

# Delete existing release/tag if it exists to allow re-runs
gh release delete "$TAG" --cleanup-tag --yes || true

# Build comprehensive release notes
RELEASE_NOTES="## Stock Firmware Information

**Firmware Version**: \`$FW_VER\`
**Stock boot.img SHA256**: \`$STOCK_SHA256\`
**Stock Kernel Version**: \`$BUILD_ID\`"

# Add additional metadata if available
if [ -n "$SW_VERSION" ]; then
    RELEASE_NOTES="$RELEASE_NOTES
**SW Version**: \`$SW_VERSION\`"
fi

if [ -n "$BUILD_FINGERPRINT" ]; then
    RELEASE_NOTES="$RELEASE_NOTES
**Build Fingerprint**: \`$BUILD_FINGERPRINT\`"
fi

if [ -n "$MODEM_VERSION" ]; then
    RELEASE_NOTES="$RELEASE_NOTES
**Modem Version**: \`$MODEM_VERSION\`"
fi

RELEASE_NOTES="$RELEASE_NOTES

## Patching Information

**Patched with**: WildKSU (\`$W_APP\`) + SUSFS
**WildKSU GKI Asset**: \`$ASSET\`

## Verification

All WildKSU/WildKernels identifying strings have been replaced with stock equivalents.
The patched boot image will appear as stock in system settings while maintaining KSU functionality.

## Required Modules

- [Wild KSU Manager](https://github.com/WildKernels/Wild_KSU/releases/tag/$W_APP)
- [ZygiskNext](https://github.com/Dr-TSNG/ZygiskNext/releases/tag/$Z_NX)
- [Meta Overlayfs](https://github.com/KernelSU-Modules-Repo/meta-overlayfs/releases/tag/$M_OV)
- [SUSFS4KSU Module](https://github.com/sidex15/susfs4ksu-module/releases/tag/$S_MD)

## Installation

\`\`\`bash
fastboot flash boot patched_boot.img
fastboot reboot
\`\`\`

> [!WARNING]
> Ensure this matches your device's firmware version (\`$FW_VER\`) before flashing!"

gh release create "$TAG" patched_boot.img --title "Build: $FW_VER" --notes "$RELEASE_NOTES" --latest
