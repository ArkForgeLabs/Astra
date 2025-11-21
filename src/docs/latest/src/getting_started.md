# Getting Started

## installation

You can install using an installer script:

### Linux

```bash
curl -fsSL https://astra.arkforge.net/install.sh | bash
```

### Windows

```powershell
powershell -c "irm https://astra.arkforge.net/install.ps1 | iex"
```

### Cargo

Alternatively you can also install through [cargo](https://doc.rust-lang.org/cargo/) tool, if you have it installed:

```bash
cargo install lua-astra
```

### Custom Installation

You can also obtain a prebuilt binary of the runtime from the [releases page](https://github.com/ArkForgeLabs/Astra/releases). Alternatively you can get it with `wget` as well. For example for the latest version with LuaJIT VM:

```bash
wget https://github.com/ArkForgeLabs/Astra/releases/latest/download/astra-luajit-linux-amd64
```

There are also windows binaries available if you are working on Windows, however we mostly assume your web server code will likely run linux, hence more support is geared towards it. Although the final code that runs should run well, agnostic of the platform it was written it (with the exception of OS specific additions).

After getting your binary on linux, you'll want to change permissions to make it executable:

```bash
chmod +x astra-luajit-linux-amd64
```

## Developer Experience

Each release likely contains updates to the packaged bundle lua code that contains definitions you might need during development which you can omit and ignore during production release. You can obtain them through:

```bash
./astra-luajit-linux-amd64 export
```

which will create a new folder called `.astra` along with a new file `.luarc.json`. They are used for intellisense and references for the available functions. There are some pure lua utilities for example table validation, ... which are also included in the bundle by default.

For development, we recommend [Emmylua Analyzer](https://github.com/EmmyLuaLs/emmylua-analyzer-rust?tab=readme-ov-file#-installation) for language server.

## Interal dev environment

If you want to extend or modify Astra, you will need [Rust](https://www.rust-lang.org/) and some form of C compiler such as [clang](https://clang.llvm.org/) or [gcc](https://gcc.gnu.org/) to be installed on the latest versio. You will also need to make sure a C linker, `Cargo`, `clippy` and `rust-analyzer` components are also installed. These components often are packaged alongside the basic installation. Your IDE may depend on whichever you are comfortable with as Rust have amazing support everywhere.

Then you'll need to clone the repository:

```bash
git clone https://github.com/ArkForgeLabs/Astra
```

And from there, in the `src` folder, you can begin your contribution and development.
