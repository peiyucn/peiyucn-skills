# Changelog

[简体中文](CHANGELOG.zh-CN.md) | English | [README](README.md)

All notable changes to the **note2md** plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow the plugin version in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json).

The retired `obscura-scrape` plugin is not listed here; its release history remains in git tags.

## [0.6.0] - 2026-09-07

### Added

- `agentsmd` command: `/note2md init` writes the `AGENTS.md` workspace manifest at the notes root; the manifest can also be created or refreshed independently.

## [0.5.3] - 2026-09-06

### Changed

- Returned to an independent version line per plugin. No user-perceivable behavior change.

## [0.5.1] - 2026-09-05

### Changed

- The generated `AGENTS.md` workspace manifest uses the standard section skeleton. No user-perceivable behavior change.

## [0.5.0] - 2026-08-10

### Changed

- OneNote conversion is script-driven.
- Template system redesigned.

## [0.4.1] - 2026-08-06

### Documentation

- Clarified the `_import` staging-area wording; non-Windows environments must export XML manually.

## [0.4.0] - 2026-08-06

### Changed

- OneNote import revamp: `_import` staging area, two import modes, XML formatting, and table/list rules.

## [0.3.0] - 2026-08-05

### Changed

- Removed the Python dependency; OneNote import now uses agent-native conversion with mandatory validation and works cross-platform.

## [0.2.1] - 2026-08-04

### Fixed

- `export-onenote.ps1` no longer fails on Chinese text under Windows PowerShell 5.1 due to encoding.

## [0.2.0] - 2026-08-04

### Added

- Recursive `SectionGroup` export and conversion.
- Loss matrix and known-limitations documentation.

### Fixed

- Plugin manifest and dead links.

## [0.1.0] - 2026-07-29

### Added

- Initial release: OneNote migration, slash commands, and the template system.
