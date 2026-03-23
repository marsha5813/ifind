#!/usr/bin/env bash
# ifind installer for macOS/Linux
set -e

INSTALL_DIR="${HOME}/.local/share/ifind"
SOURCE_MARKER="# ifind - intelligent project finder"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[ifind]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ifind]${NC} $*"; }
error() { echo -e "${RED}[ifind]${NC} $*" >&2; }

GITHUB_RAW_URL="https://raw.githubusercontent.com/marsha5813/ifind/main"

# Find source file: local repo first, then download from GitHub
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
SOURCE_FILE="${SCRIPT_DIR:+$SCRIPT_DIR/bin/ifind.sh}"

if [[ -n "$SOURCE_FILE" && -f "$SOURCE_FILE" ]]; then
    info "Installing from local repo..."
else
    info "Downloading from GitHub..."
    SOURCE_FILE=$(mktemp)
    trap 'rm -f "$SOURCE_FILE"' EXIT
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/bin/ifind.sh" -o "$SOURCE_FILE"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$SOURCE_FILE" "${GITHUB_RAW_URL}/bin/ifind.sh"
    else
        error "curl or wget is required to download ifind."
        exit 1
    fi
fi

# Check dependencies
info "Checking dependencies..."

missing=()
if ! command -v rg >/dev/null 2>&1; then
    missing+=("ripgrep")
fi
if ! command -v fzf >/dev/null 2>&1; then
    missing+=("fzf")
fi

optional_missing=()
if ! command -v fd >/dev/null 2>&1; then
    optional_missing+=("fd")
fi

if [[ ${#missing[@]} -gt 0 ]]; then
    error "Required dependencies not found: ${missing[*]}"
    if command -v brew >/dev/null 2>&1; then
        echo "  Install with: brew install ${missing[*]}"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "  Install with: sudo apt-get install ${missing[*]}"
    elif command -v dnf >/dev/null 2>&1; then
        echo "  Install with: sudo dnf install ${missing[*]}"
    elif command -v pacman >/dev/null 2>&1; then
        echo "  Install with: sudo pacman -S ${missing[*]}"
    fi
    exit 1
fi

if [[ ${#optional_missing[@]} -gt 0 ]]; then
    warn "Optional dependencies not found: ${optional_missing[*]} (will fall back to find)"
fi

# Install
info "Installing to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp "$SOURCE_FILE" "$INSTALL_DIR/ifind.sh"

# Detect shell and add source line
SOURCE_LINE="${SOURCE_MARKER}
[ -f \"${INSTALL_DIR}/ifind.sh\" ] && source \"${INSTALL_DIR}/ifind.sh\""

add_to_rc() {
    local rc_file="$1"
    if [[ -f "$rc_file" ]] && grep -qF "$SOURCE_MARKER" "$rc_file"; then
        info "Already configured in $(basename "$rc_file"), skipping."
        return
    fi
    echo "" >> "$rc_file"
    echo "$SOURCE_LINE" >> "$rc_file"
    info "Added to $(basename "$rc_file")"
}

case "$(basename "$SHELL")" in
    zsh)
        add_to_rc "${HOME}/.zshrc"
        ;;
    bash)
        if [[ -f "${HOME}/.bashrc" ]]; then
            add_to_rc "${HOME}/.bashrc"
        elif [[ -f "${HOME}/.bash_profile" ]]; then
            add_to_rc "${HOME}/.bash_profile"
        fi
        ;;
    *)
        warn "Unknown shell '$(basename "$SHELL")'. Add this to your shell rc manually:"
        echo "  $SOURCE_LINE"
        ;;
esac

info "Installation complete!"
echo ""
echo "  Restart your shell or run:"
echo "    source ${INSTALL_DIR}/ifind.sh"
echo ""
echo "  Then try:"
echo "    ifind                # browse all projects"
echo "    ifind web scraping   # find projects by keyword"
echo ""
echo "  Configuration (optional, add to your shell rc):"
echo "    export IFIND_ROOT=~/projects   # default: ~/dev"
echo "    export IFIND_DEPTH=2           # default: 1"
