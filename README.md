# ifind

> Find projects by what they do, not what they're named.

`ifind` searches inside your project files (README, package.json, pyproject.toml, CLAUDE.md, etc.) to find directories by keyword. It combines [ripgrep](https://github.com/BurntSushi/ripgrep) for fast content search with [fzf](https://github.com/junegunn/fzf) for interactive fuzzy selection and preview.

<!-- ![demo](docs/demo.gif) -->

## Installation

### macOS

```sh
brew install fzf ripgrep fd
curl -fsSL https://raw.githubusercontent.com/marsha5813/ifind/main/install.sh | bash
```

### Linux (Debian/Ubuntu)

```sh
sudo apt-get install fzf ripgrep fd-find
curl -fsSL https://raw.githubusercontent.com/marsha5813/ifind/main/install.sh | bash
```

### Linux (Arch)

```sh
sudo pacman -S fzf ripgrep fd
curl -fsSL https://raw.githubusercontent.com/marsha5813/ifind/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
scoop install fzf ripgrep fd
irm https://raw.githubusercontent.com/marsha5813/ifind/main/install.ps1 | iex
```

### Windows (WSL)

Follow the Linux instructions above.

### From source

```sh
git clone https://github.com/marsha5813/ifind.git
cd ifind
./install.sh
```

Then restart your shell or `source ~/.zshrc`.

## Usage

```sh
ifind web scraping      # find projects related to web scraping
ifind api               # find API projects
ifind pipeline          # find data pipeline projects
ifind                   # browse all projects interactively
```

### How it works

When you run `ifind <query>`:

1. **Directory name matching** — matches your query against folder names (case-insensitive)
2. **File content search** — searches inside config/doc files using ripgrep
3. **Deduplication** — merges results from both sources
4. **Interactive picker** — presents matches in fzf with a README preview panel
5. **Jump** — `cd`s you into the selected project

## Configuration

Set these environment variables in your shell rc file:

| Variable | Default | Description |
|----------|---------|-------------|
| `IFIND_ROOT` | current directory | Root directory to search |
| `IFIND_DEPTH` | `1` | How many levels deep to look for project directories |
| `IFIND_FILES` | *(see below)* | Comma-separated list of filenames to search inside |

### Default files searched

CLAUDE.md, README.md, README.rst, README, README.txt, package.json, pyproject.toml, Cargo.toml, go.mod, Makefile, docker-compose.yml, docker-compose.yaml, .env.example, setup.py, setup.cfg, pom.xml, build.gradle, CMakeLists.txt

### Example configuration

```sh
# In your ~/.zshrc or ~/.bashrc
export IFIND_ROOT=~/projects
export IFIND_DEPTH=2           # search nested dirs like ~/projects/work/my-app
export IFIND_FILES="README.md,package.json,Cargo.toml"  # only search these files
```

## Dependencies

| Dependency | Required | Install |
|-----------|----------|---------|
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Yes | `brew install ripgrep` / `apt install ripgrep` |
| [fzf](https://github.com/junegunn/fzf) | Yes | `brew install fzf` / `apt install fzf` |
| [fd](https://github.com/sharkdp/fd) | No (falls back to `find`) | `brew install fd` / `apt install fd-find` |

## Platform Support

| Platform | Shell | Status |
|----------|-------|--------|
| macOS | zsh, bash | Fully supported |
| Linux | zsh, bash | Fully supported |
| Windows | PowerShell | Supported (see `bin/ifind.ps1`) |
| Windows (WSL) | zsh, bash | Fully supported |

## Uninstall

```sh
# macOS/Linux (from the repo)
./uninstall.sh
```

```powershell
# Windows - remove the dot-source line from $PROFILE and delete:
Remove-Item -Recurse "$HOME\.local\share\ifind"
```

## License

[MIT](LICENSE)
