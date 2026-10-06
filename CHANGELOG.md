# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-10-06

### Added
- Ready-to-use download on the Releases page and a one-line installer (`install.sh`).
- **Quit** (like ⌘Q) next to **Force Quit**, so apps can close normally and ask to save.
- English and Portuguese, with a **Language** menu (English by default).
- Safari's and other apps' web page processes now count under the app that opened them, with its icon.
- Icons for command-line tools and system processes.
- Unit tests and GitHub Actions for builds, tests and releases.

### Fixed
- CPU, memory and disk numbers now follow the app's language (for example, `84,2%` in Portuguese).

### Changed
- The project is now a Swift package, organized into `App`, `Metrics`, `Processes` and `Support`.

## [1.0.0] - 2026-10-06

### Added
- CPU, RAM and disk usage in the menu bar, with alert colors at 75% and 90%.
- Top 8 apps by memory and top 5 by CPU, with force quit.
- Open at Login.

[1.1.0]: https://github.com/xfelipealves/SystemMonitor/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/xfelipealves/SystemMonitor/releases/tag/v1.0.0
