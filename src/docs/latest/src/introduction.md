# Introduction

## Versions

This documentation is on the [latest](https://astra.arkforge.net/docs/latest) version of Astra and will store a version for every major release. The other versions will be listed below here when available.

## About

ArkForge Astra is an easy-to-use, fault-tolerant, extendible, and high performant web server runtime targeting [Lua](https://lua.org) (5.1 upto 5.4), [LuaJIT](https://luajit.org/) (LuaJIT and LuaJIT 5.2), and [Luau](https://luau.org/), and built upon [Rust](https://www.rust-lang.org/). Astra takes advantages of the Rust's performance, correctness and memory safety offering, and with a rich standard library making full use of the [Tokio](https://tokio.rs/) async runtime, to write fault-tolerant and [no-build](https://x.com/dhh/status/1769903387527790975) servers with ease.

Currently Astra is used within the [ArkForge](https://arkforge.net) for some internal and external products. However being very young and early project, it lacks battle testing. Even so, it does not mean you cannot build software with it, as the base, Rust and Lua, is already mature and Astra is a thin wrapper over it.

## Philosophy

The goal is to have the cake and eat it too. Obtaining the low-level advantages of Rust while having the iteration, ease and development speed of Lua. This way you can both have a small runtime and iterate over your products and servers with a very simple CI setup that ships in seconds, or even direct SSH. This is also called no-build, as there is no building and packaging stage required.

In an ideal world, Astra will be able to handle majority of the common use cases, which are basic REST servers that uses a PostgreSQL or SQLite DB if needed, single server instance, and manage hundreds of thousands of users per second upon it.

Astra's development style is to be as minimalist and simple as we can afford. Simplicity means decreasing as many steps as possible between the core developers and someone completely new to the project being able to pick it up and start changing it to their needs. However we do add complexity when it is required as well. Keeping the minimalistic development style also means we use minimal number of tools, and if we do use a tool, it should not be too foreign from the source. The result of this is an output of a single binary, a single lua prelude that includes batteries along with it; still having all of the goodies that the Lua language provides.
