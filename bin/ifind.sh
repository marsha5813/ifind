#!/usr/bin/env bash
# ifind - Intelligent project finder
# https://github.com/marsha5813/ifind
#
# Source this file in your shell rc to use the `ifind` function.
# Compatible with both bash and zsh.
# Usage: ifind [query...]

# Default config files to search inside projects
IFIND_DEFAULT_FILES="CLAUDE.md,README.md,README.rst,README,README.txt,package.json,pyproject.toml,Cargo.toml,go.mod,Makefile,docker-compose.yml,docker-compose.yaml,.env.example,setup.py,setup.cfg,pom.xml,build.gradle,CMakeLists.txt"

ifind() {
    local root="${IFIND_ROOT:-$HOME/dev}"
    local depth="${IFIND_DEPTH:-1}"
    local files="${IFIND_FILES:-$IFIND_DEFAULT_FILES}"

    # Check required dependencies
    if ! command -v rg >/dev/null 2>&1; then
        echo "ifind: ripgrep (rg) is required but not found. Install with: brew install ripgrep" >&2
        return 1
    fi
    if ! command -v fzf >/dev/null 2>&1; then
        echo "ifind: fzf is required but not found. Install with: brew install fzf" >&2
        return 1
    fi

    # Check that root directory exists
    if [[ ! -d "$root" ]]; then
        echo "ifind: root directory '$root' does not exist. Set IFIND_ROOT to your projects directory." >&2
        return 1
    fi

    # Discover project directories
    local dirs
    if command -v fd >/dev/null 2>&1; then
        dirs=$(fd --type d --min-depth 1 --max-depth "$depth" --no-hidden . "$root" 2>/dev/null)
    else
        dirs=$(find "$root" -mindepth 1 -maxdepth "$depth" -type d ! -name '.*' 2>/dev/null)
    fi

    if [[ -z "$dirs" ]]; then
        echo "ifind: no directories found in '$root'" >&2
        return 1
    fi

    local matches
    if [[ $# -gt 0 ]]; then
        # Use positional params directly as the word list (works in both bash and zsh)
        local query="$*"

        # Source 1: Match against directory basenames (case-insensitive)
        # All words must appear in the directory name
        local name_matches
        name_matches=$(echo "$dirs" | while IFS= read -r d; do
            d="${d%/}"
            local dir_name="${d##*/}"
            local all_match=true
            local w
            for w in "$@"; do
                if ! echo "$dir_name" | grep -qi -- "$w"; then
                    all_match=false
                    break
                fi
            done
            if $all_match; then
                echo "$d"
            fi
        done)

        # Source 2: Match inside config files via ripgrep
        # All words must appear somewhere in the file
        local glob_args=()
        local IFS=','
        for f in $files; do
            glob_args+=(--glob "$f")
        done
        unset IFS

        # Start with files matching the first word, then filter for remaining words
        local content_matches
        content_matches=$(rg --ignore-case --files-with-matches \
            --no-messages \
            --max-depth "$((depth + 1))" \
            "${glob_args[@]}" \
            -- "$1" "$root" 2>/dev/null)

        # Filter results to only keep files containing ALL remaining words
        shift
        local w
        for w in "$@"; do
            if [[ -z "$content_matches" ]]; then
                break
            fi
            content_matches=$(echo "$content_matches" | while IFS= read -r f; do
                if rg --ignore-case --quiet -- "$w" "$f" 2>/dev/null; then
                    echo "$f"
                fi
            done)
        done

        # Extract parent directories (skip empty lines)
        if [[ -n "$content_matches" ]]; then
            content_matches=$(echo "$content_matches" | while IFS= read -r filepath; do
                [[ -n "$filepath" ]] && dirname "$filepath"
            done)
        fi

        # Combine and deduplicate
        matches=$(printf '%s\n%s' "$name_matches" "$content_matches" | sort -u | grep -v '^$')
    else
        matches="$dirs"
    fi

    if [[ -z "$matches" ]]; then
        echo "ifind: no projects matched '$query'" >&2
        return 1
    fi

    # Build preview command (inline so it works in both bash and zsh)
    local preview_cmd='
        dir={}
        for f in "$dir"/CLAUDE.md "$dir"/README.md "$dir"/README.rst "$dir"/README "$dir"/README.txt; do
            if [[ -f "$f" ]]; then
                head -100 "$f"
                exit 0
            fi
        done
        ls -la "$dir"
    '

    # Interactive selection via fzf
    local selected
    selected=$(echo "$matches" | fzf \
        --header "ifind${query:+: $query}" \
        --preview "bash -c '$preview_cmd'" \
        --preview-window 'right:60%:wrap' \
        --ansi \
        --select-1 \
        --exit-0)

    if [[ -n "$selected" ]]; then
        cd "$selected" || return 1
        echo "ifind: jumped to $(basename "$selected")"
    fi
}
