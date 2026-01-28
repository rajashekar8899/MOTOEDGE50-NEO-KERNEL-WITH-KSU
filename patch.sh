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

# 5. Patch Binary
export STOCK_FULL="$STOCK_FULL"
export WILD_FULL="$WILD_FULL"
python3 -c "
import os
with open('Image', 'rb') as f: data = f.read()
s = os.environ['STOCK_FULL'].encode()
w = os.environ['WILD_FULL'].encode()
if w in data and len(s) <= len(w):
    with open('kernel', 'wb') as f: f.write(data.replace(w, s + b'\x00' * (len(w) - len(s))))
else:
    with open('kernel', 'wb') as f: f.write(data)
"

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
        # Try finding the display ID property
        MOTO_ID=$(strings "$RD_FILE" | grep "ro.build.display.id=" | head -n 1 | cut -d'=' -f2)
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

gh release create "$TAG" patched_boot.img --title "Build: $FW_VER" --notes "**Firmware**: $FW_VER\n**Kernel**: $BUILD_ID\n**Patched with**: WildKSU ($W_APP)" --latest
