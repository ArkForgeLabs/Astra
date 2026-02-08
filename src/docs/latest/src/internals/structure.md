# Structure

Astra is written in Rust and is built on top of [Axum](https://docs.rs/axum). Axum internally uses [Tokio](https://docs.rs/tokio) for its async runtime and [Tower](https://docs.rs/tower). Astra also have other dependencies to assist with utilities and functionality of the runtime itself. One of them is [mlua](https://github.com/mlua-rs/mlua) which is the library used for the Lua runtime.

Astra's internal philosophy is to contain all routes in a single table array and use mlua `UserData` as much as possible for every other functionality. Since routes and server itself is the main point, utilities and functionality should be optional. Hence `main.rs`, `routes.rs` and `common.rs` are the main files that contain the essential details of the framework, while everything else is optional and extra. The utilities that require native system interopability must also be written in Rust. For example, the database drivers and the HTTP client.

> **Note:**
> If you wish to extend Astra with your own utilities written in Rust, check out [this guide](./extending_astra.md).

The source code structure is containing all of the sources in the `src` folder which divides between actual Rust code, `lua` folder which contains sources for the lua side and lua based utilities, and `docs` folder which contains sources for this documentation. The `docs` folder on the root only contains built doc files for usage with GitHub Pages.

There is also `astra_build.lua` which is a small script for automating different operations within Astra, such as automatic doc builds, lua packing, changelogs, ...
