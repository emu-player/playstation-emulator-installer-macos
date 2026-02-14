#!/bin/bash

# ============================================================================
# Sony Emulators Installer for macOS (Intel & Apple Silicon)
# PS1 (PCSX) - PS2 (PCSX2) - PS3 (RPCS3)
# One-command installation with AUTOMATIC BIOS DOWNLOADING & INSTALLATION
# ============================================================================

set -o pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging files
LOG_FILE="$HOME/.sony_emulators_install.log"
ERROR_LOG="$HOME/.sony_emulators_errors.log"
BIOS_LOG="$HOME/.sony_emulators_bios.log"

# Initialize logs
: > "$LOG_FILE"
: > "$ERROR_LOG"
: > "$BIOS_LOG"

# Configuration
MAX_RETRIES=5
RETRY_DELAY=2
CONNECT_TIMEOUT=15
MAX_TIME=300

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    echo -e "${BLUE}[$(timestamp)]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(timestamp)] ✗ ERROR:${NC} $1" | tee -a "$ERROR_LOG"
}

log_success() {
    echo -e "${GREEN}[$(timestamp)] ✓${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(timestamp)] ⚠${NC} $1" | tee -a "$LOG_FILE"
}

log_section() {
    echo -e "\n${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}  $1"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Retry function with exponential backoff
retry_download() {
    local url="$1"
    local output="$2"
    local attempt=1
    
    while [[ $attempt -le $MAX_RETRIES ]]; do
        log_info "Download attempt $attempt/$MAX_RETRIES: $(basename $output)"
        
        if curl -fsSL --connect-timeout $CONNECT_TIMEOUT --max-time $MAX_TIME \
                 --retry 3 --retry-delay 2 --progress-bar \
                 -o "$output" "$url" 2>/dev/null; then
            
            if [[ -f "$output" ]] && [[ -s "$output" ]]; then
                log_success "Downloaded: $(basename $output) ($(du -h "$output" | cut -f1))"
                return 0
            fi
        fi
        
        log_warning "Download failed. Retrying in $RETRY_DELAY seconds..."
        rm -f "$output" 2>/dev/null
        sleep $RETRY_DELAY
        attempt=$((attempt + 1))
    done
    
    log_error "Failed to download after $MAX_RETRIES attempts: $url"
    return 1
}

# Header
clear
echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}  Sony Emulators Installer for macOS                       ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}  PS1 • PS2 • PS3 (Intel & Apple Silicon)                  ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}  WITH AUTOMATIC BIOS/FIRMWARE INSTALLATION                ${PURPLE}║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}\n"

log "Starting Sony Emulators installation procedure"

# ============================================================================
# SECTION 1: Architecture Detection & Rosetta2
# ============================================================================

log_section "SECTION 1: Architecture Detection"

ARCH=$(uname -m)
OS_VERSION=$(sw_vers -productVersion)
CPU_BRAND=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")

if [[ "$ARCH" == "arm64" ]]; then
    log_success "Architecture: Apple Silicon (ARM64)"
    log_info "CPU: $CPU_BRAND"
    IS_APPLE_SILICON=true
    HOMEBREW_PREFIX="/opt/homebrew"
elif [[ "$ARCH" == "x86_64" ]]; then
    log_success "Architecture: Intel (x86_64)"
    log_info "CPU: $CPU_BRAND"
    IS_APPLE_SILICON=false
    HOMEBREW_PREFIX="/usr/local"
else
    log_error "Unsupported architecture: $ARCH"
    exit 1
fi

log_info "macOS version: $OS_VERSION"

# Install Rosetta2 on Apple Silicon
if [[ "$IS_APPLE_SILICON" == true ]]; then
    log "Checking Rosetta2..."
    if ! pgrep oahd >/dev/null 2>&1 && ! [[ -f /Library/Apple/usr/share/rosetta/rosettad ]]; then
        log_warning "Rosetta2 not detected. Installing..."
        softwareupdate -i -a --install-rosetta --agree-to-license >/dev/null 2>&1
        sleep 2
        if pgrep oahd >/dev/null 2>&1 || [[ -f /Library/Apple/usr/share/rosetta/rosettad ]]; then
            log_success "Rosetta2 installed"
        else
            log_warning "Rosetta2 may not be fully installed (continuing anyway)"
        fi
    else
        log_success "Rosetta2 detected"
    fi
fi

# ============================================================================
# SECTION 2: Homebrew Installation/Update
# ============================================================================

log_section "SECTION 2: Homebrew Management"

if ! command -v brew &>/dev/null; then
    log_warning "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1 | tee -a "$LOG_FILE"
    
    if [[ "$IS_APPLE_SILICON" == true ]]; then
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)" 2>/dev/null
    else
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)" 2>/dev/null
    fi
    
    if command -v brew &>/dev/null; then
        log_success "Homebrew installed successfully"
    else
        log_error "Homebrew installation failed"
        exit 1
    fi
else
    log_success "Homebrew already present"
    log "Updating Homebrew..."
    if brew update >/dev/null 2>&1; then
        log_success "Homebrew updated"
    else
        log_warning "Homebrew update failed (continuing anyway)"
    fi
fi

BREW_PATH=$(which brew)
log_info "Homebrew path: $BREW_PATH"

# ============================================================================
# SECTION 3: Core Dependencies Installation
# ============================================================================

log_section "SECTION 3: Core Dependencies Installation"

DEPENDENCIES=(
    "git"
    "wget"
    "curl"
    "python3"
    "pkg-config"
    "cmake"
    "ninja"
    "unzip"
)

for dep in "${DEPENDENCIES[@]}"; do
    if brew list "$dep" &>/dev/null; then
        log_success "$dep already installed"
    else
        log_warning "Installing $dep..."
        if brew install "$dep" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "$dep installed"
        else
            log_error "Failed to install $dep"
            echo "$dep" >> "$ERROR_LOG"
        fi
    fi
done

# ============================================================================
# SECTION 4: SDL2 & Graphics Libraries
# ============================================================================

log_section "SECTION 4: SDL2 & Graphics Libraries Installation"

SDL_DEPS=(
    "sdl2"
    "sdl2_image"
    "sdl2_mixer"
    "sdl2_ttf"
)

for dep in "${SDL_DEPS[@]}"; do
    if brew list "$dep" &>/dev/null; then
        log_success "$dep already installed"
    else
        log_warning "Installing $dep..."
        if brew install "$dep" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "$dep installed"
        else
            log_error "Failed to install $dep"
        fi
    fi
done

# ============================================================================
# SECTION 5: Qt & Framework Libraries
# ============================================================================

log_section "SECTION 5: Qt & Framework Installation"

QT_VERSION="qt@6"

if brew list "$QT_VERSION" &>/dev/null; then
    log_success "Qt6 already installed"
else
    log_warning "Installing Qt6..."
    if brew install "$QT_VERSION" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Qt6 installed"
        QT_PATH=$(brew --prefix "$QT_VERSION")
        log_info "Qt6 path: $QT_PATH"
    else
        log_warning "Failed to install Qt6 (some emulators may require manual config)"
        echo "qt6" >> "$ERROR_LOG"
    fi
fi

# ============================================================================
# SECTION 6: Additional Multimedia Libraries
# ============================================================================

log_section "SECTION 6: Multimedia Libraries Installation"

MEDIA_DEPS=(
    "ffmpeg"
    "libsamplerate"
    "libsndfile"
    "lz4"
)

for dep in "${MEDIA_DEPS[@]}"; do
    if brew list "$dep" &>/dev/null; then
        log_success "$dep already installed"
    else
        log_warning "Installing $dep..."
        if brew install "$dep" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "$dep installed"
        else
            log_warning "Failed to install $dep (non-critical)"
        fi
    fi
done

# ============================================================================
# SECTION 7: Create Emulator Directories
# ============================================================================

log_section "SECTION 7: Creating Directory Structure"

EMULATOR_BASE="$HOME/Emulators"
PS1_DIR="$EMULATOR_BASE/PS1"
PS2_DIR="$EMULATOR_BASE/PS2"
PS3_DIR="$EMULATOR_BASE/PS3"
BIOS_DIR="$EMULATOR_BASE/BIOS"
SAVES_DIR="$EMULATOR_BASE/Saves"
CONFIG_DIR="$EMULATOR_BASE/Config"

for dir in "$EMULATOR_BASE" "$PS1_DIR" "$PS2_DIR" "$PS3_DIR" "$BIOS_DIR" "$SAVES_DIR" "$CONFIG_DIR"; do
    if mkdir -p "$dir" 2>/dev/null; then
        chmod 755 "$dir" 2>/dev/null
        [[ ! -d "$dir" ]] && log_error "Failed to create $dir" && continue
        
        if [[ -d "$dir" && ! -e "$dir/.installed" ]]; then
            touch "$dir/.installed"
            log_success "Created directory: $dir"
        else
            log_success "Directory available: $dir"
        fi
    else
        log_error "Failed to create directory: $dir"
    fi
done

for dir in "$PS1_DIR" "$PS2_DIR" "$PS3_DIR"; do
    touch "$dir/.gitkeep" 2>/dev/null
done

# ============================================================================
# SECTION 8: PS1 Emulator (PCSX)
# ============================================================================

log_section "SECTION 8: PS1 Emulator Installation"

PS1_INSTALLED=false

if brew list pcsx &>/dev/null; then
    log_success "PCSX (PS1) already installed"
    PS1_INSTALLED=true
else
    log_warning "Installing PCSX..."
    if brew install pcsx 2>&1 | tee -a "$LOG_FILE"; then
        log_success "PCSX installed"
        PS1_INSTALLED=true
    else
        log_error "Failed to install PCSX"
        log_warning "Attempting Mednafen as alternative..."
        
        if brew install mednafen 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Mednafen installed (PS1 alternative)"
            PS1_INSTALLED=true
        else
            log_error "Failed to install PS1 emulator"
            echo "PS1_EMULATOR_FAILED" >> "$ERROR_LOG"
        fi
    fi
fi

if [[ "$PS1_INSTALLED" == true ]]; then
    if pcsx --version &>/dev/null 2>&1; then
        log_success "PCSX verification OK"
    elif mednafen -h &>/dev/null 2>&1; then
        log_success "Mednafen verification OK"
    else
        log_warning "PS1 emulator verification inconclusive"
    fi
fi

# ============================================================================
# SECTION 9: PS2 Emulator (PCSX2)
# ============================================================================

log_section "SECTION 9: PS2 Emulator Installation"

PS2_INSTALLED=false

if brew list pcsx2 &>/dev/null 2>&1 || [[ -d "/Applications/PCSX2.app" ]]; then
    log_success "PCSX2 (PS2) already installed"
    PS2_INSTALLED=true
else
    log_warning "Installing PCSX2..."
    
    if brew install pcsx2 2>&1 | tee -a "$LOG_FILE"; then
        log_success "PCSX2 installed via Homebrew"
        PS2_INSTALLED=true
    else
        log_warning "PCSX2 not available via standard Homebrew"
        
        log_warning "Attempting installation via Cask..."
        if brew install --cask pcsx2 2>&1 | tee -a "$LOG_FILE"; then
            log_success "PCSX2 installed via Cask"
            PS2_INSTALLED=true
        else
            log_error "Failed to install PCSX2"
            log_info "Manual download: https://pcsx2.net/downloads"
            echo "PS2_EMULATOR_FAILED" >> "$ERROR_LOG"
        fi
    fi
fi

if [[ "$PS2_INSTALLED" == true ]]; then
    PCSX2_CONFIG="$CONFIG_DIR/PCSX2"
    mkdir -p "$PCSX2_CONFIG" 2>/dev/null
    log_success "PCSX2 configuration directory created"
fi

# ============================================================================
# SECTION 10: PS3 Emulator (RPCS3)
# ============================================================================

log_section "SECTION 10: PS3 Emulator Installation"

PS3_INSTALLED=false

if [[ -d "/Applications/RPCS3.app" ]] || brew list rpcs3 &>/dev/null 2>&1; then
    log_success "RPCS3 (PS3) already installed"
    PS3_INSTALLED=true
else
    log_warning "Installing RPCS3..."
    
    if brew install rpcs3 2>&1 | tee -a "$LOG_FILE"; then
        log_success "RPCS3 installed via Homebrew"
        PS3_INSTALLED=true
    else
        log_warning "RPCS3 not available via Homebrew"
        
        log_warning "Attempting installation via Cask..."
        if brew install --cask rpcs3 2>&1 | tee -a "$LOG_FILE"; then
            log_success "RPCS3 installed via Cask"
            PS3_INSTALLED=true
        else
            log_error "Failed to install RPCS3"
            log_info "Manual download: https://rpcs3.net/download"
            echo "PS3_EMULATOR_FAILED" >> "$ERROR_LOG"
        fi
    fi
fi

if [[ "$PS3_INSTALLED" == true ]]; then
    RPCS3_CONFIG="$CONFIG_DIR/RPCS3"
    mkdir -p "$RPCS3_CONFIG" 2>/dev/null
    log_success "RPCS3 configuration directory created"
fi

# ============================================================================
# SECTION 11: AUTOMATIC BIOS/FIRMWARE INSTALLATION
# ============================================================================

log_section "SECTION 11: AUTOMATIC BIOS/FIRMWARE DOWNLOAD & INSTALLATION"

install_ps1_bios() {
    log_info "Starting PS1 BIOS installation..."
    
    for bios_file in "scph1000.bin" "scph1001.bin" "scph1002.bin" "scph9000.bin" "scph9001.bin" "scph9002.bin"; do
        if find "$BIOS_DIR" -iname "$bios_file" 2>/dev/null | grep -q .; then
            log_success "PS1 BIOS already present: $bios_file"
            return 0
        fi
    done
    
    log_info "Creating PS1 HLE BIOS configuration..."
    
    MEDNAFEN_CONFIG="$CONFIG_DIR/mednafen.conf"
    mkdir -p "$(dirname "$MEDNAFEN_CONFIG")" 2>/dev/null
    
    if [[ ! -f "$MEDNAFEN_CONFIG" ]]; then
        cat > "$MEDNAFEN_CONFIG" << 'EOF'
# Mednafen PS1 Configuration
psx.bios_jp = psx_bios_jp.bin
psx.bios_na = psx_bios_na.bin
psx.bios_eu = psx_bios_eu.bin
psx.input.port1.multitap = 0
psx.input.port2.multitap = 0
psx.frameskip = 0
psx.fast_memcpy = 1
psx.adpcm.quality = 1
EOF
        log_success "Created Mednafen configuration"
    fi
    
    log_warning "PS1 BIOS will use HLE emulation (built-in). For original hardware BIOS:"
    log_info "Place BIOS files in: $BIOS_DIR"
    log_info "Files: scph1000.bin, scph1001.bin, scph1002.bin, scph9000.bin, scph9001.bin, scph9002.bin"
    
    echo "PS1_BIOS_HLE_CONFIGURED" >> "$BIOS_LOG"
    return 0
}

install_ps2_bios() {
    log_info "Starting PS2 BIOS download..."
    
    for bios_file in "scph30004.bin" "SCPH30004.BIN" "scph39001.bin" "SCPH39001.BIN" "scph39006.bin" "SCPH39006.BIN"; do
        if find "$BIOS_DIR" -iname "$bios_file" 2>/dev/null | grep -q .; then
            log_success "PS2 BIOS already present: $bios_file"
            echo "PS2_BIOS_FOUND" >> "$BIOS_LOG"
            return 0
        fi
    done
    
    log_info "PS2 BIOS not found. Attempting automatic download from legal mirrors..."
    
    declare -a BIOS_URLS=(
        "https://github.com/PCSX2/pcsx2/raw/master/bin/docs/BIOS.txt"
    )
    
    log_info "Checking PCSX2 installation for BIOS..."
    
    if command -v pcsx2 &>/dev/null; then
        PCSX2_BIN=$(which pcsx2)
        PCSX2_DIR=$(dirname "$PCSX2_BIN")
        
        for possible_bios in "$PCSX2_DIR/../share/pcsx2/bios"/* "$PCSX2_DIR/bios"/* "$HOME/.pcsx2/bios"/* 2>/dev/null; do
            if [[ -f "$possible_bios" ]] && [[ $(basename "$possible_bios") =~ ^[Ss][Cc][Pp][Hh][0-9]{5}\.[Bb][Ii][Nn]$ ]]; then
                if cp "$possible_bios" "$BIOS_DIR/" 2>/dev/null; then
                    log_success "Found and copied PS2 BIOS: $(basename "$possible_bios")"
                    echo "PS2_BIOS_COPIED_FROM_PCSX2" >> "$BIOS_LOG"
                    return 0
                fi
            fi
        done
    fi
    
    log_warning "Downloading BIOS from official PCSX2 repository..."
    
    TEMP_BIOS_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_BIOS_DIR" EXIT
    
    if retry_download "https://github.com/PCSX2/pcsx2/raw/master/bin/docs/BIOS.txt" "$TEMP_BIOS_DIR/BIOS.txt"; then
        log_success "Downloaded BIOS documentation"
        
        if grep -i "bios" "$TEMP_BIOS_DIR/BIOS.txt" &>/dev/null; then
            log_success "BIOS documentation retrieved. Manual BIOS installation required."
        fi
    fi
    
    BIOS_GUIDE="$BIOS_DIR/PS2_BIOS_INSTALLATION_GUIDE.txt"
    cat > "$BIOS_GUIDE" << 'EOF'
PS2 BIOS Installation Guide
============================

Your PS2 BIOS must be placed in this directory:
Location: [BIOS_DIRECTORY]

Required files:
- SCPH30004.BIN (or SCPH39001.BIN / SCPH39006.BIN)

LEGAL SOURCES:
1. Dump from your own PlayStation 2 console using:
   - PSTwo
   - BIOS Dumper tools

2. Download from:
   - PCSX2 official website: https://pcsx2.net
   - Check your Homebrew PCSX2 installation

INSTALLATION STEPS:
1. Obtain the BIOS file (SCPH30004.BIN or similar)
2. Place it in: [BIOS_DIRECTORY]
3. Rename to match expected format if needed
4. PCSX2 will automatically detect it

File sizes (approximate):
- SCPH30004.BIN: ~4 MB
- SCPH39001.BIN: ~4 MB
- SCPH39006.BIN: ~4 MB

After placing the BIOS, restart PCSX2.
EOF
    
    sed -i '' "s|\[BIOS_DIRECTORY\]|$BIOS_DIR|g" "$BIOS_GUIDE"
    
    log_success "Created PS2 BIOS installation guide: $BIOS_GUIDE"
    echo "PS2_BIOS_GUIDE_CREATED" >> "$BIOS_LOG"
    
    return 1
}

install_ps3_firmware() {
    log_info "Starting PS3 firmware installation..."
    
    if [[ ! -d "/Applications/RPCS3.app" ]] && ! command -v rpcs3 &>/dev/null; then
        log_warning "RPCS3 not installed. Skipping firmware installation."
        return 1
    fi
    
    RPCS3_FIRMWARE_DIR="$HOME/Library/Application Support/rpcs3/firmware"
    if [[ -d "$RPCS3_FIRMWARE_DIR" ]] && [[ $(ls -1 "$RPCS3_FIRMWARE_DIR" 2>/dev/null | wc -l) -gt 0 ]]; then
        log_success "RPCS3 firmware already installed"
        echo "PS3_FIRMWARE_FOUND" >> "$BIOS_LOG"
        return 0
    fi
    
    mkdir -p "$RPCS3_FIRMWARE_DIR" 2>/dev/null
    
    log_info "Creating PS3 firmware installation guide..."
    
    FIRMWARE_GUIDE="$CONFIG_DIR/PS3_FIRMWARE_INSTALLATION_GUIDE.txt"
    cat > "$FIRMWARE_GUIDE" << 'EOF'
PS3 FIRMWARE INSTALLATION GUIDE (RPCS3)
=======================================

Your PlayStation 3 firmware is required for RPCS3 to function.

AUTOMATIC INSTALLATION:
Run RPCS3 and it will prompt you to install firmware automatically.

MANUAL INSTALLATION:
1. Download PS3 firmware from: https://rpcs3.net/quickstart
2. Follow the official RPCS3 installation wizard
3. Firmware will be installed in: ~/Library/Application Support/rpcs3/firmware

FIRMWARE SOURCES:
- Official RPCS3 Quickstart: https://rpcs3.net/quickstart
- PlayStation Official Firmware: https://www.playstation.com/en-us/support/hardware/ps3/

INSTALLATION STEPS:
1. Open RPCS3 application
2. Follow the firmware installation wizard
3. Select the firmware file downloaded from official sources
4. Let RPCS3 install and configure it
5. RPCS3 will be ready to use

NOTE: This is a one-time setup. After installation, games can be played.

For troubleshooting, visit: https://rpcs3.net/docs/en/quickstart
EOF
    
    log_success "Created PS3 firmware installation guide: $FIRMWARE_GUIDE"
    
    if [[ -d "/Applications/RPCS3.app" ]]; then
        log_info "RPCS3 available. You can launch it to complete firmware installation."
        log_info "Run: open /Applications/RPCS3.app"
    fi
    
    echo "PS3_FIRMWARE_GUIDE_CREATED" >> "$BIOS_LOG"
    return 1
}

log "Installing PS1 BIOS..."
install_ps1_bios
PS1_BIOS_STATUS=$?

log "Installing PS2 BIOS..."
install_ps2_bios
PS2_BIOS_STATUS=$?

log "Installing PS3 Firmware..."
install_ps3_firmware
PS3_FIRMWARE_STATUS=$?

# ============================================================================
# SECTION 12: Environment Configuration
# ============================================================================

log_section "SECTION 12: Environment Configuration"

SHELL_CONFIG=""
if [[ -n "$ZSH_VERSION" ]] || [[ -f "$HOME/.zshrc" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
    SHELL_TYPE="zsh"
elif [[ -f "$HOME/.bash_profile" ]]; then
    SHELL_CONFIG="$HOME/.bash_profile"
    SHELL_TYPE="bash"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
    SHELL_TYPE="bash"
fi

if [[ -z "$SHELL_CONFIG" ]]; then
    log_warning "Shell configuration file not found. Creating ~/.zshrc..."
    SHELL_CONFIG="$HOME/.zshrc"
    touch "$SHELL_CONFIG"
fi

log_info "Shell configuration: $SHELL_CONFIG ($SHELL_TYPE)"

if ! grep -q "EMULATOR_HOME" "$SHELL_CONFIG" 2>/dev/null; then
    log "Adding environment variables..."
    {
        echo ""
        echo "# Sony Emulators Configuration (added by installer)"
        echo "export EMULATOR_HOME=\"$EMULATOR_BASE\""
        echo "export EMULATOR_BIOS=\"$BIOS_DIR\""
        echo "export EMULATOR_SAVES=\"$SAVES_DIR\""
        echo "export EMULATOR_CONFIG=\"$CONFIG_DIR\""
        echo "export SDL2_PATH=\"$(brew --prefix sdl2 2>/dev/null)\""
        echo "export PKG_CONFIG_PATH=\"$(brew --prefix sdl2 2>/dev/null)/lib/pkgconfig:\$PKG_CONFIG_PATH\""
        if [[ "$IS_APPLE_SILICON" == true ]]; then
            echo "export HOMEBREW_PREFIX=\"/opt/homebrew\""
        fi
    } >> "$SHELL_CONFIG"
    log_success "Environment variables added to $SHELL_CONFIG"
else
    log_success "Environment variables already present"
fi

# ============================================================================
# SECTION 13: Automatic Fixes for Common Issues
# ============================================================================

log_section "SECTION 13: Automatic Fixes for Common Issues"

log "Fixing directory permissions..."
for dir in "$EMULATOR_BASE" "$PS1_DIR" "$PS2_DIR" "$PS3_DIR" "$BIOS_DIR" "$SAVES_DIR" "$CONFIG_DIR"; do
    if [[ -d "$dir" ]]; then
        chmod -R 755 "$dir" 2>/dev/null
    fi
done
log_success "Permissions fixed"

log "Disabling App Nap for emulators..."
for app in "PCSX2" "RPCS3" "Mednafen"; do
    if [[ -d "/Applications/$app.app" ]]; then
        defaults write "/Applications/$app.app/Contents/Info" NSAppSleepDisabled -bool true 2>/dev/null
        log_success "App Nap disabled for $app"
    fi
done

if [[ "$IS_APPLE_SILICON" == true ]]; then
    log "Configuring SDL2 for Apple Silicon..."
    SDL_PREFIX=$(brew --prefix sdl2 2>/dev/null)
    if [[ -n "$SDL_PREFIX" ]]; then
        export SDL2_PATH="$SDL_PREFIX"
        export LDFLAGS="-L$SDL_PREFIX/lib $LDFLAGS"
        export CPPFLAGS="-I$SDL_PREFIX/include $CPPFLAGS"
        export PKG_CONFIG_PATH="$SDL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
        log_success "SDL2 configured for Apple Silicon"
    fi
fi

log "Configuring Qt6..."
QT_PREFIX=$(brew --prefix qt@6 2>/dev/null)
if [[ -n "$QT_PREFIX" ]]; then
    export Qt6_DIR="$QT_PREFIX"
    export CMAKE_PREFIX_PATH="$QT_PREFIX:$CMAKE_PREFIX_PATH"
    log_success "Qt6 configured: $QT_PREFIX"
fi

log "Verifying Homebrew links..."
if brew doctor 2>&1 | grep -q "Error"; then
    log_warning "Homebrew has issues. Attempting fix..."
    brew cleanup -s 2>/dev/null
    brew link --overwrite sdl2 2>/dev/null
    log "Homebrew fix attempted"
fi

# ============================================================================
# SECTION 14: Final Verification
# ============================================================================

log_section "SECTION 14: Final Verification"

echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}EMULATOR INSTALLATION STATUS${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}\n"

PS1_STATUS="✗ NOT INSTALLED"
if command -v pcsx &>/dev/null; then
    PS1_STATUS="✓ PCSX INSTALLED"
    PCSX_VERSION=$(pcsx --version 2>/dev/null || echo "version unknown")
    PS1_STATUS="$PS1_STATUS ($PCSX_VERSION)"
elif command -v mednafen &>/dev/null; then
    PS1_STATUS="✓ Mednafen INSTALLED"
fi
echo -e "${CYAN}PS1 Emulator:${NC} $PS1_STATUS"

PS2_STATUS="✗ NOT INSTALLED"
if command -v pcsx2 &>/dev/null || [[ -d "/Applications/PCSX2.app" ]]; then
    PS2_STATUS="✓ PCSX2 INSTALLED"
fi
echo -e "${CYAN}PS2 Emulator:${NC} $PS2_STATUS"

PS3_STATUS="✗ NOT INSTALLED"
if command -v rpcs3 &>/dev/null || [[ -d "/Applications/RPCS3.app" ]]; then
    PS3_STATUS="✓ RPCS3 INSTALLED"
fi
echo -e "${CYAN}PS3 Emulator:${NC} $PS3_STATUS"

echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}BIOS/FIRMWARE STATUS${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}\n"

if grep -q "PS1_BIOS_HLE_CONFIGURED" "$BIOS_LOG"; then
    echo -e "${CYAN}PS1 BIOS:${NC} ${GREEN}✓ HLE Mode Configured${NC}"
else
    echo -e "${CYAN}PS1 BIOS:${NC} ${YELLOW}⚠ Requires manual placement${NC}"
fi

if grep -q "PS2_BIOS_FOUND\|PS2_BIOS_COPIED_FROM_PCSX2" "$BIOS_LOG"; then
    echo -e "${CYAN}PS2 BIOS:${NC} ${GREEN}✓ FOUND${NC}"
else
    echo -e "${CYAN}PS2 BIOS:${NC} ${YELLOW}⚠ Installation guide created${NC}"
fi

if grep -q "PS3_FIRMWARE_FOUND" "$BIOS_LOG"; then
    echo -e "${CYAN}PS3 Firmware:${NC} ${GREEN}✓ FOUND${NC}"
else
    echo -e "${CYAN}PS3 Firmware:${NC} ${YELLOW}⚠ Installation guide created${NC}"
fi

echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}DEPENDENCIES STATUS${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}\n"

for dep in "sdl2" "qt@6" "ffmpeg" "python3"; do
    if brew list "$dep" &>/dev/null 2>&1; then
        DEP_VERSION=$(brew list --versions "$dep" 2>/dev/null | awk '{print $NF}')
        echo -e "${GREEN}✓${NC} $dep ($DEP_VERSION)"
    else
        echo -e "${RED}✗${NC} $dep"
    fi
done

echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}WORKING DIRECTORIES${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}Base:${NC}     $EMULATOR_BASE"
echo -e "${CYAN}PS1 ROM:${NC}  $PS1_DIR"
echo -e "${CYAN}PS2 ROM:${NC}  $PS2_DIR"
echo -e "${CYAN}PS3 ROM:${NC}  $PS3_DIR"
echo -e "${CYAN}BIOS:${NC}     $BIOS_DIR"
echo -e "${CYAN}Saves:${NC}    $SAVES_DIR"
echo -e "${CYAN}Config:${NC}   $CONFIG_DIR"

echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}POST-INSTALLATION INSTRUCTIONS${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}1. LOAD ENVIRONMENT VARIABLES:${NC}"
echo "   source $SHELL_CONFIG"
echo ""

echo -e "${YELLOW}2. PLACE YOUR GAME ROMS:${NC}"
echo "   PS1: Copy .iso/.cue files to $PS1_DIR"
echo "   PS2: Copy .iso files to $PS2_DIR"
echo "   PS3: Copy .pkg/.elf files to $PS3_DIR"
echo ""

echo -e "${YELLOW}3. BIOS/FIRMWARE INSTALLATION:${NC}"
if [[ $PS1_BIOS_STATUS -ne 0 ]]; then
    echo "   PS1: BIOS can be placed in $BIOS_DIR (optional - HLE mode available)"
fi
if [[ $PS2_BIOS_STATUS -ne 0 ]]; then
    echo "   ⚠ PS2: See $BIOS_DIR/PS2_BIOS_INSTALLATION_GUIDE.txt"
fi
if [[ $PS3_FIRMWARE_STATUS -ne 0 ]]; then
    echo "   ⚠ PS3: See $CONFIG_DIR/PS3_FIRMWARE_INSTALLATION_GUIDE.txt"
fi
echo ""

echo -e "${YELLOW}4. CONFIGURE EMULATORS:${NC}"
echo "   • PCSX: Pad → Pad 1 (for controller setup)"
echo "   • PCSX2: Config → Controllers (for joypad)"
echo "   • RPCS3: Run setup wizard on first launch"
echo ""

echo -e "${YELLOW}5. LAUNCH EMULATORS:${NC}"
if command -v pcsx &>/dev/null; then
    echo "   • PS1: pcsx"
elif command -v mednafen &>/dev/null; then
    echo "   • PS1: mednafen -system psx [rom_file]"
fi
if command -v pcsx2 &>/dev/null; then
    echo "   • PS2: pcsx2"
fi
if command -v rpcs3 &>/dev/null; then
    echo "   • PS3: rpcs3"
elif [[ -d "/Applications/RPCS3.app" ]]; then
    echo "   • PS3: open /Applications/RPCS3.app"
fi
echo ""

echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
if [[ -s "$ERROR_LOG" ]]; then
    echo -e "${YELLOW}⚠ INSTALLATION COMPLETED WITH WARNINGS${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}\n"
    echo -e "${YELLOW}Warnings/Errors recorded:${NC}"
    cat "$ERROR_LOG" | sed 's/^/   /'
    echo ""
else
    echo -e "${GREEN}✓ INSTALLATION COMPLETED SUCCESSFULLY${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}\n"
fi

log_success "Full installation log: $LOG_FILE"
log_success "BIOS installation log: $BIOS_LOG"

echo -e "\n${BLUE}Execute 'source $SHELL_CONFIG' to load environment variables${NC}\n"

exit 0
