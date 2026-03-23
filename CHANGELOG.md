# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-23

### Added
- Initial release
- Keyword search across project config files (CLAUDE.md, README, package.json, pyproject.toml, etc.)
- Directory basename matching (find projects by folder name)
- Interactive fuzzy picker with README preview via fzf
- Configurable search root, depth, and file list via environment variables
- Bash/Zsh shell function that cd's into selected project
- PowerShell equivalent for Windows
- Install and uninstall scripts for macOS/Linux and Windows
- fd-based directory discovery with find fallback
