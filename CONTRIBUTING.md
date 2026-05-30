# Contributing to Astra

First off, thank you for considering contributing to Astra. It means a lot.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Developer Certificate of Origin](#developer-certificate-of-origin)

## Code of Conduct

This project is governed by the [Contributor Covenant](https://www.contributor-covenant.org/). By participating, you are expected to uphold this code. Please report unacceptable behavior to [contact@arkforge.net](mailto:contact@arkforge.net).

## How to Contribute

### Reporting Bugs

Open an issue with:
- A clear, descriptive title
- Steps to reproduce (include code snippets if applicable)
- Expected vs. actual behavior
- Your environment (OS, Astra version, Lua version)

### Suggesting Features

Open an issue tagged `enhancement` with:
- A clear description of the feature and the problem it solves
- Any relevant examples or use cases

## Development Setup

1. Clone the repo: `git clone https://github.com/ArkForgeLabs/Astra.git`
2. Build from source: `cargo build`
3. Run tests: `cargo test`

Prerequisites: Rust toolchain (stable), Lua 5.4+ (for test scripts).

## Code Style

- **Rust:** Follow `rustfmt` conventions. Run `cargo fmt` before committing.
- **Lua:** Follow `stylua` conventions (config at `.stylua.toml`). Run `stylua .` before committing.
- Keep functions focused and small.
- Prefer readability over cleverness.

## Testing

- All new features must include tests.
- Rust tests: `cargo test`
- Lua tests: `astra run tests/`
- Ensure existing tests pass before submitting a PR.

## Pull Request Process

1. Fork the repository and create a branch from `main`.
2. Make your changes, following the code style.
3. Add or update tests as needed.
4. Run the full test suite to confirm nothing is broken.
5. Submit a pull request with a clear title and description.
6. A maintainer will review your PR. Address any feedback.

## Developer Certificate of Origin

By contributing to Astra, you certify that your contribution is your own original work and you license it under the terms of the Apache License, Version 2.0.
