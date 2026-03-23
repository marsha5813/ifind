# ifind - Intelligent project finder (PowerShell)
# https://github.com/joey/ifind
#
# Dot-source this file in your $PROFILE to use the `ifind` function.
# Usage: ifind [query...]

$script:IFIND_DEFAULT_FILES = @(
    "CLAUDE.md", "README.md", "README.rst", "README", "README.txt",
    "package.json", "pyproject.toml", "Cargo.toml", "go.mod", "Makefile",
    "docker-compose.yml", "docker-compose.yaml", ".env.example",
    "setup.py", "setup.cfg", "pom.xml", "build.gradle", "CMakeLists.txt"
)

function ifind {
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$QueryParts
    )

    $query = ($QueryParts -join " ").Trim()
    $root = if ($env:IFIND_ROOT) { $env:IFIND_ROOT } else { Join-Path $HOME "dev" }
    $depth = if ($env:IFIND_DEPTH) { [int]$env:IFIND_DEPTH } else { 1 }
    $files = if ($env:IFIND_FILES) {
        $env:IFIND_FILES -split ","
    } else {
        $script:IFIND_DEFAULT_FILES
    }

    # Check required dependencies
    foreach ($cmd in @("rg", "fzf")) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            Write-Error "ifind: $cmd is required but not found. Install with: scoop install $cmd"
            return
        }
    }

    # Check root exists
    if (-not (Test-Path $root -PathType Container)) {
        Write-Error "ifind: root directory '$root' does not exist. Set IFIND_ROOT to your projects directory."
        return
    }

    # Discover project directories
    $dirs = @()
    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $dirs = fd --type d --min-depth 1 --max-depth $depth --no-hidden . $root 2>$null
    } else {
        $dirs = Get-ChildItem -Path $root -Directory -Depth ($depth - 1) |
            Where-Object { -not $_.Name.StartsWith(".") } |
            ForEach-Object { $_.FullName }
    }

    if (-not $dirs -or $dirs.Count -eq 0) {
        Write-Error "ifind: no directories found in '$root'"
        return
    }

    $matches = @()
    if ($query) {
        # Source 1: Match directory basenames
        $nameMatches = $dirs | Where-Object {
            (Split-Path $_ -Leaf) -match [regex]::Escape($query)
        }

        # Source 2: Match inside config files via ripgrep
        $globArgs = @()
        foreach ($f in $files) {
            $globArgs += "--glob"
            $globArgs += $f
        }

        $contentMatches = rg --ignore-case --files-with-matches `
            --no-messages `
            --max-depth ($depth + 1) `
            @globArgs `
            -- $query $root 2>$null |
            ForEach-Object { Split-Path $_ -Parent } |
            Sort-Object -Unique

        # Combine and deduplicate
        $matches = @($nameMatches) + @($contentMatches) |
            Where-Object { $_ } |
            Sort-Object -Unique
    } else {
        $matches = $dirs
    }

    if (-not $matches -or $matches.Count -eq 0) {
        Write-Error "ifind: no projects matched '$query'"
        return
    }

    # Build preview command
    $previewCmd = @"
`$dir = {}; `$found = `$false; foreach (`$f in @('CLAUDE.md','README.md','README.rst','README','README.txt')) { `$p = Join-Path `$dir `$f; if (Test-Path `$p) { Get-Content `$p -TotalCount 100; `$found = `$true; break } }; if (-not `$found) { Get-ChildItem `$dir }
"@

    # Interactive selection via fzf
    $selected = $matches | fzf `
        --header "ifind$(if ($query) { ": $query" })" `
        --preview "pwsh -NoProfile -Command `"$previewCmd`"" `
        --preview-window "right:60%:wrap" `
        --ansi `
        --select-1 `
        --exit-0

    if ($selected) {
        Set-Location $selected
        Write-Host "ifind: jumped to $(Split-Path $selected -Leaf)"
    }
}
