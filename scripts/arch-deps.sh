#!/bin/bash

# Arch Linux Dependency Installer for LFS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[DEPS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running on Arch Linux
if [[ ! -f /etc/arch-release ]]; then
    error "This script is designed for Arch Linux only!"
fi

# Required packages for LFS build
REQUIRED_PACKAGES=(
    "base-devel"
    "git"
    "wget"
    "curl"
    "gawk"
    "m4"
    "texinfo"
    "bison"
    "flex"
    "bc"
    "cpio"
    "dosfstools"
    "parted"
    "qemu-system-x86_64"
    "arch-install-scripts"
    "rsync"
    "unzip"
    "which"
)

# Optional packages for enhanced experience
OPTIONAL_PACKAGES=(
    "ccache"
    "distcc"
    "ninja"
    "cmake"
    "meson"
    "python-pip"
    "python-setuptools"
    "python-wheel"
)

# Check and install required packages
install_required() {
    log "Checking required packages..."
    
    local missing_packages=()
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! pacman -Qi "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        warn "Missing required packages: ${missing_packages[*]}"
        
        if [[ $EUID -eq 0 ]]; then
            pacman -S --needed "${missing_packages[@]}"
        else
            sudo pacman -S --needed "${missing_packages[@]}"
        fi
    else
        log "All required packages are installed"
    fi
}

# Check and install optional packages
install_optional() {
    log "Checking optional packages..."
    
    local missing_optional=()
    
    for package in "${OPTIONAL_PACKAGES[@]}"; do
        if ! pacman -Qi "$package" &>/dev/null; then
            missing_optional+=("$package")
        fi
    done
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        warn "Missing optional packages: ${missing_optional[*]}"
        read -p "Install optional packages? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ $EUID -eq 0 ]]; then
                pacman -S --needed "${missing_optional[@]}"
            else
                sudo pacman -S --needed "${missing_optional[@]}"
            fi
        fi
    else
        log "All optional packages are installed"
    fi
}

# Version compatibility check
check_versions() {
    log "Checking package versions..."
    
    # Check bash version
    local bash_version=$(bash --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+')
    if [[ $(echo "$bash_version >= 3.2" | bc -l) -eq 0 ]]; then
        warn "Bash version $bash_version may be too old (need >= 3.2)"
    fi
    
    # Check gcc version
    local gcc_version=$(gcc --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+')
    if [[ $(echo "$gcc_version >= 5.1" | bc -l) -eq 0 ]]; then
        warn "GCC version $gcc_version may be too old (need >= 5.1)"
    fi
    
    # Check glibc version
    local glibc_version=$(ldd --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+')
    if [[ $(echo "$glibc_version >= 2.11" | bc -l) -eq 0 ]]; then
        warn "Glibc version $glibc_version may be too old (need >= 2.11)"
    fi
    
    log "Version checks complete"
}

# Setup build environment
setup_environment() {
    log "Setting up build environment..."
    
    # Create build directory
    if [[ ! -d /tmp/lfs-build ]]; then
        mkdir -p /tmp/lfs-build
    fi
    
    # Set up ccache if available
    if command -v ccache &> /dev/null; then
        log "Configuring ccache..."
        export PATH="/usr/lib/ccache/bin:$PATH"
        ccache --set-config=max_size=5G
        ccache --set-config=compression=true
    fi
    
    log "Environment setup complete"
}

# Main function
main() {
    log "Starting Arch Linux dependency setup for LFS"
    
    install_required
    install_optional
    check_versions
    setup_environment
    
    log "Dependency setup completed successfully!"
    log "You can now run the main LFS builder script"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
