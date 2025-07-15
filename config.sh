#!/bin/bash

# LFS Auto-Builder Configuration for Arch Linux

# LFS version and target
LFS_VERSION="12.0"
LFS_TARGET="$(uname -m)-lfs-linux-gnu"

# Build directories
LFS="/mnt/lfs"
LFS_SOURCES="$LFS/sources"
LFS_TOOLS="$LFS/tools"
LFS_BUILD="$LFS/build"

# Parallel build jobs (adjust based on your CPU cores)
MAKE_JOBS="$(nproc)"

# Arch-specific package mappings
declare -A ARCH_PACKAGES=(
    ["bash"]="bash"
    ["binutils"]="binutils"
    ["bison"]="bison"
    ["coreutils"]="coreutils"
    ["diffutils"]="diffutils"
    ["findutils"]="findutils"
    ["gawk"]="gawk"
    ["gcc"]="gcc"
    ["grep"]="grep"
    ["gzip"]="gzip"
    ["m4"]="m4"
    ["make"]="make"
    ["patch"]="patch"
    ["perl"]="perl"
    ["python"]="python"
    ["sed"]="sed"
    ["tar"]="tar"
    ["texinfo"]="texinfo"
    ["xz"]="xz"
)

# Build options
CFLAGS="-O2 -pipe"
CXXFLAGS="$CFLAGS"
LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"

# Export variables
export LFS LFS_VERSION LFS_TARGET LFS_SOURCES LFS_TOOLS LFS_BUILD
export MAKE_JOBS CFLAGS CXXFLAGS LDFLAGS

# Function to check if we're on Arch Linux
check_arch_linux() {
    if [[ ! -f /etc/arch-release ]]; then
        echo "Error: This script is designed for Arch Linux"
        exit 1
    fi
}

# Function to get Arch package version
get_arch_version() {
    local package="$1"
    pacman -Q "$package" 2>/dev/null | awk '{print $2}'
}

# Function to check if package is installed
is_package_installed() {
    local package="$1"
    pacman -Qi "$package" &>/dev/null
}

# Arch-specific compiler flags
if [[ -f /etc/makepkg.conf ]]; then
    source /etc/makepkg.conf
    if [[ -n "$CFLAGS" ]]; then
        CFLAGS="$CFLAGS"
    fi
    if [[ -n "$CXXFLAGS" ]]; then
        CXXFLAGS="$CXXFLAGS"
    fi
fi
