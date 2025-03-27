# Contributing to LLMAgent

Thank you for your interest in contributing to LLMAgent! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). We expect all contributors to adhere to these guidelines to ensure a welcoming and productive environment.

## Getting Started

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/llm_agent.git
   cd llm_agent
   ```
3. **Install dependencies**:
   ```bash
   mix deps.get
   ```
4. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Code Style & Standards

LLMAgent follows the standard Elixir style guidelines:

1. Use `mix format` to format your code before submitting
2. Follow the naming conventions:
   - **Modules**: CamelCase, descriptive of purpose
   - **Functions**: snake_case, verb-based, descriptive
   - **Variables**: snake_case, clear purpose
   - **Signals**: Atom types, descriptive of state
   - **Constants**: ALL_CAPS for true constants, CamelCase for configuration

3. Write clear and expressive code, preferring readability over cleverness

### Documentation

All code contributions should be properly documented:

1. **Module Documentation**:
   - Every module must have a `@moduledoc`
   - Explain the module's purpose and responsibilities
   - Document how it fits in the overall architecture

2. **Function Documentation**:
   - All public functions must have a `@doc` comment
   - Include `@spec` type specifications
   - Document parameters and return values
   - Provide examples for non-trivial functions

### Testing

1. All new features or bug fixes should include tests:
   ```bash
   mix test
   ```

2. Ensure your changes don't break existing functionality.

3. Test coverage should be maintained or improved:
   ```bash
   mix test --cover
   ```

4. For LLM-related components, include appropriate mocks to avoid API calls during tests.

### Linting & Static Analysis

Before submitting changes, run:

```bash
mix lint  # Alias for format and credo
```

This checks code formatting and runs Credo for static analysis.

## Submitting Changes

1. **Commit your changes** with clear, descriptive commit messages:
   ```bash
   git commit -m "Add feature X that solves problem Y"
   ```

2. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request** against the `develop` branch of the original repository.

4. **Describe your changes** in the PR description, including:
   - What problem your PR solves
   - How your implementation works
   - Any potential side effects or considerations
   - Links to related issues

5. **Wait for review**. Maintainers will review your PR and might request changes.

## Types of Contributions

### Bug Fixes

If you're fixing a bug:

1. Ensure the bug is documented in an issue
2. Reference the issue in your PR
3. Add a test that reproduces the bug
4. Explain your approach to fixing it

### Features

For new features:

1. Open an issue discussing the feature before implementing
2. Explain how the feature aligns with project goals
3. Consider edge cases and performance implications
4. Include comprehensive tests and documentation

### Documentation

Documentation improvements are always welcome:

1. Correct inaccuracies in existing docs
2. Expand explanations for clarity
3. Add examples where useful
4. Ensure formatting is consistent

## Architectural Guidelines

When contributing to LLMAgent, follow these architectural principles:

1. **Signal-Driven Architecture**: Maintain the separation between signals, handlers, and state.
2. **Immutability**: State should be immutable and transformations explicit.
3. **Composability**: Components should be composable and reusable.
4. **Separation of Concerns**: Clearly delineate responsibilities between modules.
5. **Testability**: Design for testability, avoid hidden dependencies.

## Release Process

Only maintainers can release new versions. The process involves:

1. Updating the CHANGELOG.md
2. Bumping version in mix.exs
3. Tagging the release
4. Publishing to Hex.pm

## Getting Help

If you need help with the contribution process:

1. Check existing documentation
2. Open a discussion on GitHub
3. Reach out to maintainers

Thank you for contributing to LLMAgent!
