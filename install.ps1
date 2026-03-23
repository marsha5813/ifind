# ifind installer for Windows (PowerShell)

$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $HOME ".local\share\ifind"
$SourceMarker = "# ifind - intelligent project finder"

function Write-Info { param([string]$Message) Write-Host "[ifind] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[ifind] $Message" -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host "[ifind] $Message" -ForegroundColor Red }

# Find source file
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceFile = Join-Path $ScriptDir "bin\ifind.ps1"

if (-not (Test-Path $SourceFile)) {
    Write-Err "Cannot find bin\ifind.ps1 relative to install script."
    exit 1
}

# Check dependencies
Write-Info "Checking dependencies..."

$missing = @()
foreach ($cmd in @("rg", "fzf")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        $missing += $cmd
    }
}

if ($missing.Count -gt 0) {
    Write-Err "Required dependencies not found: $($missing -join ', ')"
    Write-Host "  Install with: scoop install $($missing -join ' ')"
    Write-Host "  Or:           winget install $($missing -join ' ')"
    exit 1
}

if (-not (Get-Command fd -ErrorAction SilentlyContinue)) {
    Write-Warn "Optional dependency 'fd' not found (will fall back to Get-ChildItem)"
}

# Install
Write-Info "Installing to $InstallDir..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item $SourceFile -Destination (Join-Path $InstallDir "ifind.ps1") -Force

# Add to PowerShell profile
$ProfilePath = $PROFILE
$SourceLine = @"

$SourceMarker
if (Test-Path "$InstallDir\ifind.ps1") { . "$InstallDir\ifind.ps1" }
"@

if (Test-Path $ProfilePath) {
    $content = Get-Content $ProfilePath -Raw
    if ($content -match [regex]::Escape($SourceMarker)) {
        Write-Info "Already configured in profile, skipping."
    } else {
        Add-Content -Path $ProfilePath -Value $SourceLine
        Write-Info "Added to PowerShell profile"
    }
} else {
    New-Item -ItemType File -Force -Path $ProfilePath | Out-Null
    Set-Content -Path $ProfilePath -Value $SourceLine
    Write-Info "Created PowerShell profile and added ifind"
}

Write-Info "Installation complete!"
Write-Host ""
Write-Host "  Restart your shell or run:"
Write-Host "    . $InstallDir\ifind.ps1"
Write-Host ""
Write-Host "  Then try:"
Write-Host "    ifind                # browse all projects"
Write-Host "    ifind web scraping   # find projects by keyword"
