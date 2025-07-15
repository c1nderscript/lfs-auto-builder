#!/bin/bash

# LFS Auto-Builder for Arch Linux
# This script automates the Linux From Scratch build process

set -e

# Source configuration
source "$(dirname "$0")/config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for safety reasons!"
    fi
}

# Check Arch Linux dependencies
check_arch_deps() {
    log "Checking Arch Linux dependencies..."
    
    local missing_deps=()
    local arch_deps=(
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
    )
    
    for dep in "${arch_deps[@]}"; do
        if ! pacman -Qi "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        warn "Missing dependencies: ${missing_deps[*]}"
        read -p "Install missing dependencies? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo pacman -S --needed "${missing_deps[@]}"
        else
            error "Please install missing dependencies before continuing"
        fi
    fi
    
    log "All dependencies satisfied"
}

# Setup build environment
setup_build_env() {
    log "Setting up build environment..."
    
    # Create LFS directory structure
    sudo mkdir -p $LFS/{etc,var,usr,tools,lib,bin,sbin}
    sudo mkdir -p $LFS/usr/{bin,lib,sbin}
    sudo mkdir -p $LFS/var/{log,lib,cache}
    
    # Create symbolic links for compatibility
    sudo ln -sf usr/bin $LFS/bin
    sudo ln -sf usr/lib $LFS/lib
    sudo ln -sf usr/sbin $LFS/sbin
    
    # Set up the lfs user
    if ! id "lfs" &>/dev/null; then
        sudo useradd -s /bin/bash -g users -m -k /dev/null lfs
        sudo passwd lfs
    fi
    
    # Set ownership
    sudo chown -R lfs:users $LFS/tools
    sudo chown -R lfs:users $LFS/usr
    sudo chown -R lfs:users $LFS/var
    
    log "Build environment setup complete"
}

# Download LFS sources
download_sources() {
    log "Downloading LFS sources..."
    
    mkdir -p $LFS/sources
    cd $LFS/sources
    
    # Download wget-list if not present
    if [[ ! -f wget-list ]]; then
        wget http://www.linuxfromscratch.org/lfs/downloads/stable/wget-list
    fi
    
    # Download sources
    wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
    
    # Download md5 checksums
    if [[ ! -f md5sums ]]; then
        wget http://www.linuxfromscratch.org/lfs/downloads/stable/md5sums
    fi
    
    # Verify checksums
    pushd $LFS/sources
    md5sum -c md5sums
    popd
    
    log "Source download and verification complete"
}

# Build temporary tools
build_temp_tools() {
    log "Building temporary tools..."
    
    # Switch to lfs user for building
    sudo -u lfs bash << 'EOF'
set -e

# Set up environment
cat > ~/.bash_profile << "EOL"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOL

cat > ~/.bashrc << "EOL"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOL

source ~/.bash_profile

# Build binutils pass 1
cd $LFS/sources
tar -xf binutils-*.tar.xz
cd binutils-*/
mkdir build
cd build
../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT \
             --disable-nls \
             --disable-werror
make
make install
cd $LFS/sources
rm -rf binutils-*/

# Build gcc pass 1
tar -xf gcc-*.tar.xz
cd gcc-*/

tar -xf ../mpfr-*.tar.xz
mv mpfr-* mpfr
tar -xf ../gmp-*.tar.xz
mv gmp-* gmp
tar -xf ../mpc-*.tar.xz
mv mpc-* mpc

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
esac

mkdir build
cd build
../configure \
    --target=$LFS_TGT \
    --prefix=$LFS/tools \
    --with-glibc-version=2.11 \
    --with-sysroot=$LFS \
    --with-newlib \
    --without-headers \
    --enable-initfini-array \
    --disable-nls \
    --disable-shared \
    --disable-multilib \
    --disable-decimal-float \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-libstdcxx \
    --enable-languages=c,c++

make
make install

cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
cd $LFS/sources
rm -rf gcc-*/

EOF

    log "Temporary tools build complete"
}

# Main execution
main() {
    log "Starting LFS Auto-Builder for Arch Linux"
    
    check_root
    check_arch_deps
    setup_build_env
    download_sources
    build_temp_tools
    
    log "LFS build process completed successfully!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
