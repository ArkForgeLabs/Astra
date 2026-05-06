# Contributing to Astra

First off, thank you for considering contributing to Astra. It means a lot.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Contributor License Agreement](#contributor-license-agreement)

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

## Contributor License Agreement

### Summary

By contributing code to Astra, you agree to the terms below. This ensures that your contributions can be used under both the AGPL-3.0-only license (for open source users) and a proprietary commercial license (for paying customers of ArkForge LLC).

### The Agreement

**By submitting a pull request, committing code, or otherwise contributing to this repository, you agree to the following terms:**

**1. Definitions**

- "You" (or "Your") means the copyright owner or legal entity authorized by the copyright owner that is making this agreement.
- "Contribution" means any original work of authorship, including any modifications or additions to an existing work, that is intentionally submitted by You to ArkForge LLC for inclusion in Astra.
- "Submitted" means any form of electronic, verbal, or written communication sent to ArkForge LLC or its representatives, including but not limited to communication on GitHub (issues, pull requests, discussions), email, or mailing lists.

**2. Copyright License**

You grant to ArkForge LLC and to recipients of Astra a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright license to reproduce, prepare derivative works of, publicly display, publicly perform, sublicense, and distribute Your Contributions and such derivative works.

**3. Patent License**

You grant to ArkForge LLC and to recipients of Astra a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable (except as stated in this section) patent license to make, have made, use, offer to sell, sell, import, and otherwise transfer Astra, where such license applies only to those patent claims licensable by You that are necessarily infringed by Your Contribution(s) alone or by combination of Your Contribution(s) with Astra.

If You institute patent litigation against any entity (including a cross-claim or counterclaim in a lawsuit) alleging that Your Contribution or Astra constitutes direct or contributory patent infringement, then any patent licenses granted to You under this Agreement for that Contribution shall terminate as of the date such litigation is filed.

**4. License Versions**

You understand that Astra uses a **dual-license model**:

1. **GNU Affero General Public License v3.0 (AGPL-3.0-only)** — for open source use
2. **Commercial License** — for proprietary use (available from ArkForge LLC [contact@arkforge.net](mailto:contact@arkforge.net))

You agree that ArkForge LLC may license Your Contributions under any of these licenses, at its sole discretion.

**5. Representations**

- You represent that You are legally entitled to grant the above licenses.
- If Your employer(s) has rights to intellectual property that You create, You represent that You have received permission to make Contributions on behalf of that employer, or that Your employer has waived such rights for Your Contributions.
- You represent that each of Your Contributions is Your original creation.

**6. Support**

You are not expected to provide support for Your Contributions. You provide Your Contributions on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

**7. Notification**

You agree to notify ArkForge LLC of any facts or circumstances of which You become aware that would make these representations inaccurate in any respect.

---

*By contributing to Astra, you agree to the terms above. Thank you for helping make Astra better.*
