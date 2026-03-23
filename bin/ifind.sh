#!/usr/bin/env bash
# ifind - Intelligent project finder
# https://github.com/marsha5813/ifind
#
# Source this file in your shell rc to use the `ifind` function.
# Compatible with both bash and zsh.
# Usage: ifind [query...]

# Default config files to search inside projects
IFIND_DEFAULT_FILES="CLAUDE.md,README.md,README.rst,README,README.txt,package.json,pyproject.toml,Cargo.toml,go.mod,Makefile,docker-compose.yml,docker-compose.yaml,.env.example,setup.py,setup.cfg,pom.xml,build.gradle,CMakeLists.txt"

# Internal helper: filter directories by query words.
# Args: root depth files word1 [word2 ...]
# Outputs matching directory paths to stdout.
_ifind_search() {
    local root="$1" depth="$2" files="$3"
    shift 3

    # Discover project directories
    local dirs
    if command -v fd >/dev/null 2>&1; then
        dirs=$(fd --type d --min-depth 1 --max-depth "$depth" --no-hidden . "$root" 2>/dev/null)
    else
        dirs=$(find "$root" -mindepth 1 -maxdepth "$depth" -type d ! -name '.*' 2>/dev/null)
    fi

    if [[ -z "$dirs" ]]; then
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        echo "$dirs"
        return 0
    fi

    # Source 1: Match directory basenames — grep chain, one grep per word
    local name_matches
    name_matches=$(echo "$dirs" | while IFS= read -r d; do
        d="${d%/}"
        printf '%s\t%s\n' "${d##*/}" "$d"
    done)
    while [[ $# -gt 0 && -n "$name_matches" ]]; do
        name_matches=$(echo "$name_matches" | grep -i -- "$1")
        shift
    done
    # Extract full paths (after the tab)
    if [[ -n "$name_matches" ]]; then
        name_matches=$(echo "$name_matches" | cut -f2)
    fi

    # Restore words — caller will pass them again via _ifind_content
    echo "$name_matches"
}

# Internal helper: search file contents for query words.
# Args: root depth files word1 [word2 ...]
# Outputs matching directory paths to stdout.
_ifind_content() {
    local root="$1" depth="$2" files="$3"
    shift 3

    [[ $# -eq 0 ]] && return 0

    # Build glob args from file list
    local glob_args=()
    local OLD_IFS="$IFS"
    IFS=','
    for f in $files; do
        glob_args+=(--glob "$f")
    done
    IFS="$OLD_IFS"

    # Start with files matching the first word
    local content_matches
    content_matches=$(rg --ignore-case --files-with-matches \
        --no-messages \
        --max-depth "$((depth + 1))" \
        "${glob_args[@]}" \
        -- "$1" "$root" 2>/dev/null)
    shift

    # Filter to keep only files containing ALL remaining words
    while [[ $# -gt 0 && -n "$content_matches" ]]; do
        content_matches=$(echo "$content_matches" | while IFS= read -r f; do
            if rg --ignore-case --quiet -- "$1" "$f" 2>/dev/null; then
                echo "$f"
            fi
        done)
        shift
    done

    # Extract parent directories
    if [[ -n "$content_matches" ]]; then
        echo "$content_matches" | while IFS= read -r filepath; do
            [[ -n "$filepath" ]] && dirname "$filepath"
        done
    fi
}

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

    local query="$*"
    local matches

    if [[ $# -gt 0 ]]; then
        # Search both directory names and file contents, deduplicate
        local name_matches content_matches
        name_matches=$(_ifind_search "$root" "$depth" "$files" "$@")
        content_matches=$(_ifind_content "$root" "$depth" "$files" "$@")
        matches=$(printf '%s\n%s' "$name_matches" "$content_matches" | sort -u | grep -v '^$')
    else
        # No query — list all directories
        if command -v fd >/dev/null 2>&1; then
            matches=$(fd --type d --min-depth 1 --max-depth "$depth" --no-hidden . "$root" 2>/dev/null)
        else
            matches=$(find "$root" -mindepth 1 -maxdepth "$depth" -type d ! -name '.*' 2>/dev/null)
        fi
    fi

    if [[ -z "$matches" ]]; then
        echo "ifind: no projects matched '$query'" >&2
        return 1
    fi

    # Build preview command (single quotes intentional — fzf substitutes {} at runtime)
    # shellcheck disable=SC2016
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
