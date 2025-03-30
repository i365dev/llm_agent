# Changelog

All notable changes to LLMAgent will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-03-30

### Changed
- **BREAKING**: Refactored LLMAgent.Store to leverage AgentForge.Store's GenServer implementation
- Store interface now returns :ok instead of updated state maps
- Store now uses process names (atoms) instead of directly returning state maps
- Removed unused sequence_flows function and its helper functions from flows.ex

### Fixed
- Fixed warnings in the investment_portfolio.exs example
- Fixed unused function parameters
- Updated example code to use the correct Store interface

### Documentation
- Updated documentation to reflect Store interface changes
- Enhanced dynamic workflow documentation to better showcase complex scenarios

## [0.1.1] - 2025-03-29

### Added
- Enhanced documentation for dynamic workflow orchestration
- New guide for dynamic workflows with examples across domains
- Architecture documentation updates highlighting workflow emergence

## [0.1.0] - 2025-03-28

### Added
- Initial release of redesigned LLMAgent library
- Signal-based architecture built on AgentForge
- Tool integration system
- Handlers for various signal types
- Store for managing conversation state
- Flow compositions for different agent patterns
