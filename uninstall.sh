#!/usr/bin/env bash
# ifind uninstaller for macOS/Linux
set -e

INSTALL_DIR="${HOME}/.local/share/ifind"
SOURCE_MARKER="# ifind - intelligent project finder"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[ifind]${NC} $*"; }
error() { echo -e "${RED}[ifind]${NC} $*" >&2; }

# Remove installed files
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    info "Removed ${INSTALL_DIR}"
else
    info "Install directory not found, skipping."
fi

# Remove source lines from rc files
remove_from_rc() {
    local rc_file="$1"
    if [[ -f "$rc_file" ]] && grep -qF "$SOURCE_MARKER" "$rc_file"; then
        # Remove the marker line and the source line that follows it
        sed -i.bak "/${SOURCE_MARKER//\//\\/}/,+1d" "$rc_file"
        # Remove the backup file created by sed
        rm -f "${rc_file}.bak"
        # Clean up any trailing blank lines
        sed -i.bak -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$rc_file"
        rm -f "${rc_file}.bak"
        info "Removed from $(basename "$rc_file")"
    fi
}

remove_from_rc "${HOME}/.zshrc"
remove_from_rc "${HOME}/.bashrc"
remove_from_rc "${HOME}/.bash_profile"

info "Uninstall complete. Restart your shell to finish."
