# Changelog

All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

## [0.39.1](https://github.com/ArkForgeLabs/Astra/compare/v0.39.0..v0.39.1) - 2025-12-19

### Bug Fixes

- DB Pragma Query now returns proper lua nil when NULL value - ([86fa86e](https://github.com/ArkForgeLabs/Astra/commit/86fa86e1901c762b41bebf06cdcad54ba010ec3b))
- imports the .init files correctly now - ([36f33db](https://github.com/ArkForgeLabs/Astra/commit/36f33db641b1cdbc1e3fb17f4520cc15f5bc499a))

### Refactoring

- removed windows ARM builds as its not supported with vendoring yet - ([455a544](https://github.com/ArkForgeLabs/Astra/commit/455a544a093bcf31646449992f1e1c7e2a451c79))

## [0.39.0](https://github.com/ArkForgeLabs/Astra/compare/v0.38.0..v0.39.0) - 2025-12-18

### Features

- database pragma queries, fix: #132 - ([5112237](https://github.com/ArkForgeLabs/Astra/commit/511223789999e67576f88eb005956e933b237d1e))

## [0.38.0](https://github.com/ArkForgeLabs/Astra/compare/v0.37.1..v0.38.0) - 2025-12-14

### Bug Fixes

- linux minor updates to README - ([191e034](https://github.com/ArkForgeLabs/Astra/commit/191e03467222ba747e9ef180200dd29c3fe540af))
- potential HTTP client JSON serialization fix for requests - ([edc1550](https://github.com/ArkForgeLabs/Astra/commit/edc15502730542f20d063be8294dc9890579d1c5))
- #123 - now teal export is optional - ([24404ba](https://github.com/ArkForgeLabs/Astra/commit/24404badce0fe87903de279dc0c3e20405719012))
- fix CI for docs - ([19a9462](https://github.com/ArkForgeLabs/Astra/commit/19a9462bfdccf045ce1c633436f7adef4d93bcea))

### Documentation

- now automatically installs and builds the docs - ([c6c0924](https://github.com/ArkForgeLabs/Astra/commit/c6c092402629f796db1dc7567147a483abb4f66d))
- added cache to docs ci - ([48d107c](https://github.com/ArkForgeLabs/Astra/commit/48d107cb1c7ca1d74cfc9f0cc427656535c38d65))
- updated README to reflect the description better. fix: #121 - ([80bf314](https://github.com/ArkForgeLabs/Astra/commit/80bf314d072e864078ca34b15e735e652eb78f38))

### Features

- added fallback routes, fix #125 - ([044c6c9](https://github.com/ArkForgeLabs/Astra/commit/044c6c92f36f39dc6d937a3b31d1f5a0e6fe3f2d))
- add support for server redirects. fix #127 - ([5bb7d32](https://github.com/ArkForgeLabs/Astra/commit/5bb7d3289e4fa2dd155e78e070488c78240079dd))
- now init.lua or init.tl can be ran as default if no filename is provided. fix: #119 - ([e145040](https://github.com/ArkForgeLabs/Astra/commit/e145040091cc040f9107f06bfe85181b989e94f2))
- added MacOS, ARM, and RISC-V support for compilation. fix #116 - ([3af6f3d](https://github.com/ArkForgeLabs/Astra/commit/3af6f3d6418c6514a5eba8d8ed4c79ecdc2df540))
- now upgrade command can detect new architecture and OS - ([d0c6f01](https://github.com/ArkForgeLabs/Astra/commit/d0c6f011104d895ecdb321562ea41af6930f2aa0))

## [0.37.1](https://github.com/ArkForgeLabs/Astra/compare/v0.37.0..v0.37.1) - 2025-11-23

### Bug Fixes

- error messages displayed correctly - ([1bc37af](https://github.com/ArkForgeLabs/Astra/commit/1bc37af6ce8fce3bb2c6f1faaa08e76f1723348e))
- #108 - Luau now works - ([7a8ff02](https://github.com/ArkForgeLabs/Astra/commit/7a8ff0274b9798ce81a001fa2eb14a956b0df1e2))
- import paths interopability - ([2d41954](https://github.com/ArkForgeLabs/Astra/commit/2d419541e3611ff92a1897b900d47f7562625daf))

## [0.37.0](https://github.com/ArkForgeLabs/Astra/compare/v0.36.0..v0.37.0) - 2025-11-21

### Bug Fixes

- teal check with the new path system - ([75a5d79](https://github.com/ArkForgeLabs/Astra/commit/75a5d79e2200f510d7d595bf4b57ae7e0ffba82e))
- #118 - Teal running only when needed - ([27e3ddf](https://github.com/ArkForgeLabs/Astra/commit/27e3ddf0a7e2557da751d16f39c0fd96f08f91d2))

### Features

- added compression ability to each route - ([5d0062c](https://github.com/ArkForgeLabs/Astra/commit/5d0062c639077984794c6fac40f218a0286a9f55))
- added major serde targets - ([78b4928](https://github.com/ArkForgeLabs/Astra/commit/78b4928285dbc31c8587d43d5d8ac44cfc7ceaf8))
- added types for serde types - ([13a38d4](https://github.com/ArkForgeLabs/Astra/commit/13a38d4b93ec5b325ebfb031284605b3c9b72edb))
- added support for csv - ([5ee17e8](https://github.com/ArkForgeLabs/Astra/commit/5ee17e8b5de5bdf3cb5b6632e3f8f02ea02c2b47))
- added xml support - ([e1028de](https://github.com/ArkForgeLabs/Astra/commit/e1028def6837d754577c9ff9fcab6756bfb33ce9))

### Refactoring

- moved client.rs to its own directory - ([b3917e0](https://github.com/ArkForgeLabs/Astra/commit/b3917e0a464bacc2c0175c43f575f522f7f1e763))

## [0.36.0](https://github.com/ArkForgeLabs/Astra/compare/v0.35.0..v0.36.0) - 2025-11-11

### Features

- websocket client added - ([9774fe9](https://github.com/ArkForgeLabs/Astra/commit/9774fe9413e539cc2251493b3bdae4ab91c403bd))

### Refactoring

- updated dependencies - ([5225768](https://github.com/ArkForgeLabs/Astra/commit/5225768aa11f6a664a1da31a234b67872421f7cc))

## [0.35.0](https://github.com/ArkForgeLabs/Astra/compare/v0.34.0..v0.35.0) - 2025-11-08

### Features

- file_io now have methods for file read and write - ([9de9aa6](https://github.com/ArkForgeLabs/Astra/commit/9de9aa69abcd5f85f7f931a5bbfea6eaa1a2f48c))
- added Buffers and File opening for File IO - ([98743e1](https://github.com/ArkForgeLabs/Astra/commit/98743e185ced3b80da6667ca51478906f53c8f79))
- can omit the 'astra.lua.' prefix from standard library - ([27e09ff](https://github.com/ArkForgeLabs/Astra/commit/27e09ff288b9f9b3c38ac16468badfc56d4d2e42))
- filesystem buffer read and write added - ([e4c166d](https://github.com/ArkForgeLabs/Astra/commit/e4c166d4f97a62af79063bd184ed83262e1950d9))

### Refactoring

- renamed components with Lua prefix to Astra - ([0bfaeb3](https://github.com/ArkForgeLabs/Astra/commit/0bfaeb3fed2a1d4a0cecf1c505a664c19f64719c))
- added macros for file_io - ([61d8e62](https://github.com/ArkForgeLabs/Astra/commit/61d8e6294b1184d9d36077c6d160412657033686))
- renamed io.rs to file_io.rs to reflect the changes clearly - ([1e5ba81](https://github.com/ArkForgeLabs/Astra/commit/1e5ba818faaa76f92aa2447ee1b61667d06291c0))
- [**breaking**] renamed io.lua to fs.lua to better reflect its nature - ([a65781b](https://github.com/ArkForgeLabs/Astra/commit/a65781bf3d179dd0ebb98e33dc1b45ba68fe1e84))
- expanded the fs.rs into file_system.rs - ([bf67d0a](https://github.com/ArkForgeLabs/Astra/commit/bf67d0a6498c1a622d5e11bc4a57087111b30bd9))

## [0.34.0](https://github.com/ArkForgeLabs/Astra/compare/v0.33.1..v0.34.0) - 2025-11-02

### Documentation

- cleaned up and improved online documentation - ([7f7d09a](https://github.com/ArkForgeLabs/Astra/commit/7f7d09abbee096b9be13bfe4e5fa1ad4cc1a566f))

### Features

- IP Address access now available on servers - ([31b0177](https://github.com/ArkForgeLabs/Astra/commit/31b0177a6d032e664aa0bb2573c2878b1dd6f032))
- imported module caches can now be invalidated and caches are now faster and improved - ([88f4609](https://github.com/ArkForgeLabs/Astra/commit/88f4609d2901831b1323a386c7d2534a90d843ad))

### Refactoring

- renamed serializer to serde - ([2d49bb8](https://github.com/ArkForgeLabs/Astra/commit/2d49bb81a9db0ae2e4f4a26faad67a65d2556936))

## [0.33.1](https://github.com/ArkForgeLabs/Astra/compare/v0.33.0..v0.33.1) - 2025-10-31

### Bug Fixes

- fix for runtime selection from user, adding the function(Select-Runtime) call to handle the selection - ([46e7215](https://github.com/ArkForgeLabs/Astra/commit/46e7215690c41e77ee5c4054cbd74db3e0d8bf90))
- fix for windows: avoid colon variable parse error in PowerShell Write… (#110) - ([ef92a92](https://github.com/ArkForgeLabs/Astra/commit/ef92a928cd11e70fbd629ab6293afcd142ad57e9))
- windows updates being broken - ([4ac2e23](https://github.com/ArkForgeLabs/Astra/commit/4ac2e23203d5426e290a2dd742fa43a8c6917af9))
- don't use global variable `result` in middleware docs (#109) - ([094a308](https://github.com/ArkForgeLabs/Astra/commit/094a3088866384db4943692bafa7e2005388211b))

### Refactoring

- moved from luals to emmylua for language server. Added install scripts for different platforms - ([6878e0c](https://github.com/ArkForgeLabs/Astra/commit/6878e0cc7e81d0459f9dcc0e52b15e53e1ab004d))

## New Contributors

- @sweet-nes5 made their first contribution in https://github.com/ArkForgeLabs/Astra/pull/110

## [0.33.0](https://github.com/ArkForgeLabs/Astra/compare/v0.32.4..v0.33.0) - 2025-10-29

### Features

- added cache to workflows - ([79d3e84](https://github.com/ArkForgeLabs/Astra/commit/79d3e84de250014d69be64d2c0a48e7d2449c284))

### Refactoring

- Teal now do not check by default. Moved `--teal-compile-checks` to `--check-teal-code` - ([f595e8e](https://github.com/ArkForgeLabs/Astra/commit/f595e8e2f2a72356006e9bfc3abd929264dccc29))

## [0.32.4](https://github.com/ArkForgeLabs/Astra/compare/v0.32.3..0.32.4) - 2025-10-20

### Bug Fixes

- HTTP Multipart not saving binary zip archives correctly - ([026bb8c](https://github.com/ArkForgeLabs/Astra/commit/026bb8cde67120f57d60a51987322e9a5036f88f))

## [0.32.3](https://github.com/ArkForgeLabs/Astra/compare/v0.32.2..0.32.3) - 2025-10-19

### Bug Fixes

- Abort needing itself for task handler - ([8f99419](https://github.com/ArkForgeLabs/Astra/commit/8f9941955bd2288af6178bb263b5ee6c6ab01938))

## [0.32.2](https://github.com/ArkForgeLabs/Astra/compare/v0.32.1..v0.32.2) - 2025-10-18

### Bug Fixes

- obtaining the function for quit before the signal returning Nil for Teal slow loading - ([ee3afd9](https://github.com/ArkForgeLabs/Astra/commit/ee3afd9b68739e0620b742ff360d1ab022cad420))
- task keeps hanging the system on termination signal - ([1fef66a](https://github.com/ArkForgeLabs/Astra/commit/1fef66afb33a973d40d3764d7bf238d35ac7107a))

### Features

- Database connections now automatically closed on program closing - ([5b5b528](https://github.com/ArkForgeLabs/Astra/commit/5b5b5286373a4bc39471739cfd910c2e82893365))

## [0.32.1](https://github.com/ArkForgeLabs/Astra/compare/v0.32.0..v0.32.1) - 2025-10-17

### Bug Fixes

- windows fix for the sigterm - ([7979824](https://github.com/ArkForgeLabs/Astra/commit/79798247613806c721a36803ea64e51b9b4383aa))

## [0.32.0](https://github.com/ArkForgeLabs/Astra/compare/v0.31.0..v0.32.0) - 2025-10-17

### Bug Fixes

- bugs with HTTP not shutting down properly - ([5504a5f](https://github.com/ArkForgeLabs/Astra/commit/5504a5fb121273b504a095bdc092e0cf476e24df))

### Documentation

- added documentation for shutdown code - ([b84e540](https://github.com/ArkForgeLabs/Astra/commit/b84e54087dd4440aef942450756bee82ff3ac489))

### Features

- shutdown or termination code accessible from Lua for graceful shutdown - ([9d4876f](https://github.com/ArkForgeLabs/Astra/commit/9d4876f38a2d940fdca479f4a11dc85cb8e9ca54))

### Refactoring

- broken down the commands into smaller chunks - ([6a60282](https://github.com/ArkForgeLabs/Astra/commit/6a6028284c21f6a2c48077bab579ba63e727e719))

## [0.31.0](https://github.com/ArkForgeLabs/Astra/compare/v0.30.1..v0.31.0) - 2025-10-14

### Features

- HTTP Server multipart now have fields that can be read - ([23d58eb](https://github.com/ArkForgeLabs/Astra/commit/23d58eb561fe8e99ae1ac8c87c68503b780d2021))
- added some examples for the multipart - ([0791394](https://github.com/ArkForgeLabs/Astra/commit/079139445d2a8c3425c8af29d46267a43325e354))

## [0.30.1](https://github.com/ArkForgeLabs/Astra/compare/v0.30.0..v0.30.1) - 2025-10-14

### Bug Fixes

- typo change from abord to abort - ([18c631c](https://github.com/ArkForgeLabs/Astra/commit/18c631c4d935dabce3863501678786c61c560de2))
- astra path in config files being messed up - ([54a14ca](https://github.com/ArkForgeLabs/Astra/commit/54a14caceca5ab8bc7d310c6c64ffba77fc3abdf))

### Features

- added table validation to teal by @KhushMehta - ([5882db4](https://github.com/ArkForgeLabs/Astra/commit/5882db4910bbac0eddbac02fee8088224590f017))
- updated Teal source - ([c9f2ae3](https://github.com/ArkForgeLabs/Astra/commit/c9f2ae3f6474da99d3c6d63466ed8f79ce4bf40e))

### Refactoring

- removed nullability from some return types of HTTP in teal - ([f709d83](https://github.com/ArkForgeLabs/Astra/commit/f709d838891e423d6a13322c15f66afdf5d831c8))
- better errors for json - ([134829d](https://github.com/ArkForgeLabs/Astra/commit/134829dfe53c94cc91b372fd4ff67dd7bc82ef36))

## [0.30.0](https://github.com/ArkForgeLabs/Astra/compare/v0.29.3..v0.30.0) - 2025-10-04

### Bug Fixes

- teal code runs now fine with teal check disabled - ([2dbff33](https://github.com/ArkForgeLabs/Astra/commit/2dbff334fa394e0f23d1b0824dfda29651d25e97))

### Documentation

- updated http server and client docs - ([4d4eae8](https://github.com/ArkForgeLabs/Astra/commit/4d4eae896f65cfa44e92350a1b59dbbe64c5bbe8))

### Features

- http client now has streaming capabilities - ([28fec06](https://github.com/ArkForgeLabs/Astra/commit/28fec062ec17248bc3e317e03fb4995ec11ace15))
- http servers now got ability to be shut down - ([66e5b7e](https://github.com/ArkForgeLabs/Astra/commit/66e5b7e28ea9c118daf34ba9a825068438693af8))

### Refactoring

- clean up http client path - ([f4edf81](https://github.com/ArkForgeLabs/Astra/commit/f4edf814f4276bb1dbfffb85b1a9c19681321a64))
- revamped the HTTP Request module for better user experience - ([909953e](https://github.com/ArkForgeLabs/Astra/commit/909953efa4f1409f09ee823afb6a0c12d01dc9a3))

## [0.29.3](https://github.com/ArkForgeLabs/Astra/compare/v0.29.2..v0.29.3) - 2025-10-03

### Bug Fixes

- further fixes to Astra on windows having path issues - ([4d3e7cb](https://github.com/ArkForgeLabs/Astra/commit/4d3e7cb5c4de3aa649a435513c63d36416a96fc9))

## [0.29.2](https://github.com/ArkForgeLabs/Astra/compare/v0.29.1..v0.29.2) - 2025-09-29

### Bug Fixes

- teal import paths on windows - ([44a47fa](https://github.com/ArkForgeLabs/Astra/commit/44a47fa713a4f0382bac871a214b3ba0154a1b16))
- run tl check only on teal files - ([d90a509](https://github.com/ArkForgeLabs/Astra/commit/d90a50921c2c5995f44305a1745c922ea3a1e5f8))

## [0.29.1](https://github.com/ArkForgeLabs/Astra/compare/v0.29.0..v0.29.1) - 2025-09-22

### Bug Fixes

- exports now correctly to the appropriate folder - ([388ff2f](https://github.com/ArkForgeLabs/Astra/commit/388ff2f52a7d82fecb8d7f35af6a462d547bb808))
- teal loading stdlib modules on runtime checks - ([145242b](https://github.com/ArkForgeLabs/Astra/commit/145242bdced96e11912442eb42258ac6311cc7e4))

## [0.29.0](https://github.com/ArkForgeLabs/Astra/compare/v0.28.1..v0.29.0) - 2025-09-14

### Bug Fixes

- loading stdlib and globals without exported local folder - ([ec622d3](https://github.com/ArkForgeLabs/Astra/commit/ec622d335e03ae8caa56f9862526b2490622c197))

### Documentation

- updatd documentation for the new import api - ([87396b8](https://github.com/ArkForgeLabs/Astra/commit/87396b8992f613899a12e8628a4cf7fe409045cb))

### Features

- teal code can now be loaded and even mixed with normal lua code without additional steps - ([6bf04c4](https://github.com/ArkForgeLabs/Astra/commit/6bf04c427f947f6c345210c497ba430522577ccd))
- [**breaking**] removed import as require is now working safely - ([bf3feac](https://github.com/ArkForgeLabs/Astra/commit/bf3feac564460f38e97bc4536edc24364665c450))
- teal can now run directly, and script paths are now known during runtime, and debug and jit libraries are now available - ([a9edfba](https://github.com/ArkForgeLabs/Astra/commit/a9edfbaff666227178f10a4ac4677024fe560e5a))
- better file IO error delegation from Rust to Lua - ([c83c918](https://github.com/ArkForgeLabs/Astra/commit/c83c918b04ab6274b096c8dcb035281f4714b73c))
- now importing for teal and lua works wonderfully with the standard library folder as well - ([46f7043](https://github.com/ArkForgeLabs/Astra/commit/46f70439b098bcec189e8a6fb09961ff4fed6cdb))
- added Teal types - ([69bd843](https://github.com/ArkForgeLabs/Astra/commit/69bd8432449aed9230a8a5364899c0327f1428e0))
- runtime teal checks before runs - ([71e76ba](https://github.com/ArkForgeLabs/Astra/commit/71e76ba100049298399fe631d0b2d97fe471349c))
- added ability to turn off teal compile checks when running astra - ([e2573e3](https://github.com/ArkForgeLabs/Astra/commit/e2573e3ff8a0afd3460d37504db67efdf5752f88))
- added teal examples and fixed bugs - ([1b7b3fa](https://github.com/ArkForgeLabs/Astra/commit/1b7b3faa15467d08594d0af0ba7523a0e3312239))

### Refactoring

- moved all the type definition files to their own space - ([bfa7fa2](https://github.com/ArkForgeLabs/Astra/commit/bfa7fa2daaf8e72e0e2ad25968f949e65b0d7165))
- moved teal from global to behind Astra table - ([b49be8c](https://github.com/ArkForgeLabs/Astra/commit/b49be8c772b9fa8e2ec97e44bb0eb4f2d535f79e))
- added primitive global Astra function types - ([2db0d51](https://github.com/ArkForgeLabs/Astra/commit/2db0d515986d6b34b22763f050544c9c4836bb13))
- delegated error check of globals, and cleaned up code elsewhere - ([e4deeaf](https://github.com/ArkForgeLabs/Astra/commit/e4deeafa992923de6ab91f0fd8b682050e6dff6b))
- now exports teal libraries too and the export folder standardized - ([546d28f](https://github.com/ArkForgeLabs/Astra/commit/546d28feb75c37a3c0fc43f7fe28fb65bab1d47a))
- renamed `astra_stdlib` to `astra` - ([6b34330](https://github.com/ArkForgeLabs/Astra/commit/6b343303b3b1779662b99820ad6f35d58aaaf0a4))
- moved away from Astra global namespace in favor of importing needed functionality. - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.dotenv_load` moved to global `dotenv_load` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.regex` moved to global `regex` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.crypto` moved to lib `astra.lua.crypto` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.json` moved to lib `astra.lua.serializer` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.database_connect` moved to lib `astra.lua.database` and `database_connect` renamed to `connect` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.datetime` moved to lib `astra.lua.datetime` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.http` moved to lib `astra.lua.http` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.io` moved to lib `astra.lua.io` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.pubsub` and `Astra.observable` moved to lib `astra.lua.stores` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.new_templating_engine` moved to lib `astra.lua.jinja2` and `new_templating_engine` renamed to `new_engine` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- `Astra.validate_table` moved to lib `astra.lua.validate_table` - ([1c54ce2](https://github.com/ArkForgeLabs/Astra/commit/1c54ce23361849ffdb54d9ccadd7d33e976310d4))
- moved the examples to the new api - ([da95232](https://github.com/ArkForgeLabs/Astra/commit/da952325157811087a5ff715aa4184abcd1d6114))
- renamed `validate_table` to `validation` as there is plans for more validation options in the future - ([da95232](https://github.com/ArkForgeLabs/Astra/commit/da952325157811087a5ff715aa4184abcd1d6114))
- separated the teal type check from teal loader - ([f42a72a](https://github.com/ArkForgeLabs/Astra/commit/f42a72a3110b49448286308ac575643f44a26334))
- consistent api for jinja and database - ([fb3733f](https://github.com/ArkForgeLabs/Astra/commit/fb3733fae91a3d0225e42fae98d8c5abc6d983c4))

## [0.28.1](https://github.com/ArkForgeLabs/Astra/compare/v0.28.0..0.28.1) - 2025-09-03

### Bug Fixes

- return empty string when no reason provided for `send_close` - ([73271d1](https://github.com/ArkForgeLabs/Astra/commit/73271d1c28b5186585209863358f65ec41dee3b3))
- #13 - ([73271d1](https://github.com/ArkForgeLabs/Astra/commit/73271d1c28b5186585209863358f65ec41dee3b3))
- getenv not returning - ([58571c9](https://github.com/ArkForgeLabs/Astra/commit/58571c9f8fbcbf6d5909e440c03f00607dd08820))

### Documentation

- proper documentation for websockets - ([5a3fcf6](https://github.com/ArkForgeLabs/Astra/commit/5a3fcf68b0bdd01644ccfc1e1c55bdeed1c0a8b7))
- #13 - ([5a3fcf6](https://github.com/ArkForgeLabs/Astra/commit/5a3fcf68b0bdd01644ccfc1e1c55bdeed1c0a8b7))
- updated minor issue with websockets docs - ([8488733](https://github.com/ArkForgeLabs/Astra/commit/84887331e4a88465e2e12908630ee7a91cd0542e))

### Features

- send_code({1000})` - ([4091039](https://github.com/ArkForgeLabs/Astra/commit/40910393e90905a96bd6f318797eb790bc839532))
- can send a reasonless close frame without wrapping it in braces - ([4091039](https://github.com/ArkForgeLabs/Astra/commit/40910393e90905a96bd6f318797eb790bc839532))
- #13 - ([4091039](https://github.com/ArkForgeLabs/Astra/commit/40910393e90905a96bd6f318797eb790bc839532))

## [0.28.0](https://github.com/ArkForgeLabs/Astra/compare/v0.27.0..0.28.0) - 2025-09-02

### Bug Fixes

- link to middleware.lua in middleware.md (#87) - ([2a70d97](https://github.com/ArkForgeLabs/Astra/commit/2a70d9765f5277fbe30ce566007c5eaab111abb9))
- prelude registeration not loading the packed libs correctly - ([6145502](https://github.com/ArkForgeLabs/Astra/commit/614550209e0bf32bc3270a63132961293ccc05df))
- prelude error when the dependency for the module has not yet been loaded - ([a5df91f](https://github.com/ArkForgeLabs/Astra/commit/a5df91faaccd76b3b66bae1541b53cd594d59fbb))
- websocket route not being recognized - ([ebe4074](https://github.com/ArkForgeLabs/Astra/commit/ebe4074dc3bcba69f196f46f074d0715bf5861cf))
- barebones websocket lua api (needs more fixing) - ([3f28d3b](https://github.com/ArkForgeLabs/Astra/commit/3f28d3b67748c5e32bb3cff4f13d3546eefa8e45))
- #13, #98 - ([3f28d3b](https://github.com/ArkForgeLabs/Astra/commit/3f28d3b67748c5e32bb3cff4f13d3546eefa8e45))
- get rid of all unwrap and extracts - ([6519e66](https://github.com/ArkForgeLabs/Astra/commit/6519e660282adae1f3916d7c2462956bba8e2779))
- #13, #98 - ([6519e66](https://github.com/ArkForgeLabs/Astra/commit/6519e660282adae1f3916d7c2462956bba8e2779))
- issues fixed with bytes and normal send structure - ([5ac6273](https://github.com/ArkForgeLabs/Astra/commit/5ac627336a3f4b21e60ecb5d7764efca054f1e74))
- returns an empty string when reason not given - ([146b454](https://github.com/ArkForgeLabs/Astra/commit/146b454edbc5245e21bc4dde4da41e34a2af0d6a))
- #13, #98 - ([146b454](https://github.com/ArkForgeLabs/Astra/commit/146b454edbc5245e21bc4dde4da41e34a2af0d6a))

### Documentation

- updated middleware and sql driver - ([8cf1f5a](https://github.com/ArkForgeLabs/Astra/commit/8cf1f5a357b7a3ee2a21b8607205429ba210ae6e))

### Features

- Middleware system documentation - ([258b332](https://github.com/ArkForgeLabs/Astra/commit/258b3324550b00fa168c61ba4d07074c11f424cd))
- type detection and definition for HTTP Request params - ([4d9c6e8](https://github.com/ArkForgeLabs/Astra/commit/4d9c6e8a5694cff40010fbed01a90f0362e2ac8f))
- URL parameters parsing (#85) - ([04be222](https://github.com/ArkForgeLabs/Astra/commit/04be2229febd37b340877bbebb9539d9817c545c))
- datetime format function for custom formatting - ([b9d154e](https://github.com/ArkForgeLabs/Astra/commit/b9d154e454c45314fc41d3c5b874ecabf9e7bf06))
- websocket implementation (doesn't work) - ([f96893d](https://github.com/ArkForgeLabs/Astra/commit/f96893dadeebd5800b34883055b15b715e45edae))
- #13 - ([f96893d](https://github.com/ArkForgeLabs/Astra/commit/f96893dadeebd5800b34883055b15b715e45edae))
- broken websocket api - ([e04ca74](https://github.com/ArkForgeLabs/Astra/commit/e04ca745d5994b9ae5ce714a3ce752b8a276bfa8))
- #13 #98 - ([e04ca74](https://github.com/ArkForgeLabs/Astra/commit/e04ca745d5994b9ae5ce714a3ce752b8a276bfa8))
- the websocket recv now returns type and value - ([32280f2](https://github.com/ArkForgeLabs/Astra/commit/32280f2f327abca1c56322c1952ca90153ce3531))
- mlua functions for sending websocket messages - ([75fd957](https://github.com/ArkForgeLabs/Astra/commit/75fd95707e95b048ea887fbeccad56853fe25873))
- #13, 98 - ([75fd957](https://github.com/ArkForgeLabs/Astra/commit/75fd95707e95b048ea887fbeccad56853fe25873))

### Fix

- #88 - ([d4359fb](https://github.com/ArkForgeLabs/Astra/commit/d4359fb8944e3dee275244c32e727a5749ada71d))

### Refactoring

- minor cleanups done to the middleware example - ([1874c90](https://github.com/ArkForgeLabs/Astra/commit/1874c906de3ec585132374dbf3a280dd3e4310b3))
- less bloated version - ([d8a0d12](https://github.com/ArkForgeLabs/Astra/commit/d8a0d12e89d629b32948cc21e32f32a60e331f0c))
- clamped libs together and moved middleware to http - ([31dff80](https://github.com/ArkForgeLabs/Astra/commit/31dff8017671b6f90c7852a16e01bb93a29c54de))
- export now removes previously exported content - ([3b3a842](https://github.com/ArkForgeLabs/Astra/commit/3b3a84236c9572ca393f0a9882714c8874a9248e))
- update command now recommends reexporting the type definitions - ([f1a5327](https://github.com/ArkForgeLabs/Astra/commit/f1a53275f26924028efdbf8022ca4ba58e1bc80c))
- unnecessary error messages - ([e06bf1a](https://github.com/ArkForgeLabs/Astra/commit/e06bf1ad723553760d80fb14d6a7c77776eef17d))
- renamed binary to bytes - ([097e8ce](https://github.com/ArkForgeLabs/Astra/commit/097e8cea99245c4a16bf824218851d874ad559db))
- updated the datetime test and its formatting - ([4721d6e](https://github.com/ArkForgeLabs/Astra/commit/4721d6e588210152e425f9438f528991d8b3725e))

## [0.27.0](https://github.com/ArkForgeLabs/Astra/compare/v0.26.0..v0.27.0) - 2025-07-18

### Features

- [**breaking**] multiple of datetime creation methods was replaced by `Astra.datetime.new` - ([25e9c21](https://github.com/ArkForgeLabs/Astra/commit/25e9c21e86d5cdc8aa2bdfaa4e86aa7485b32a15))

## [0.26.0](https://github.com/ArkForgeLabs/Astra/compare/v0.25.1..v0.26.0) - 2025-07-17

### Bug Fixes

- delegate subcounter and enforce type preference - ([6b98b67](https://github.com/ArkForgeLabs/Astra/commit/6b98b678d4752378603ae309626102cfe39f2e82))

### Documentation

- data stores - ([a9f36c7](https://github.com/ArkForgeLabs/Astra/commit/a9f36c7286c9654aff1fcadbea1269bf0aa2b7c4))
- finished `data-stores` docs - ([d9c57a2](https://github.com/ArkForgeLabs/Astra/commit/d9c57a24906ce5a4e0f7246b7b81fc6017bb2a34))

### Features

- implement observer pattern - ([14141a4](https://github.com/ArkForgeLabs/Astra/commit/14141a485910c72f89682ba13f2cd63d45d5566e))

### Miscellaneous Chores

- prefer function type for publish - ([ad6e812](https://github.com/ArkForgeLabs/Astra/commit/ad6e8124076c62babbeffb4a7f74b4c9d89a75a2))

### Performance

- hashed tables for observee-subscriber sets #26 - ([3a7ae14](https://github.com/ArkForgeLabs/Astra/commit/3a7ae14fbfdbd80bd3edd86527fe80ddc50c06df))
- use a hash table to store subscribers - ([75f10be](https://github.com/ArkForgeLabs/Astra/commit/75f10be1db022c8df8db60ce07b4f30fae3d4a11))

### Refactoring

- add type hints - ([d165b53](https://github.com/ArkForgeLabs/Astra/commit/d165b53c0435b04a4ff223d0b5f01afc6b2b6657))
- moved observable under `Astra` - ([e7c86ff](https://github.com/ArkForgeLabs/Astra/commit/e7c86ff1063d3eb1ba808a211707df34a16b8220))

## [0.25.1](https://github.com/ArkForgeLabs/Astra/compare/v0.25.0..v0.25.1) - 2025-07-16

### Bug Fixes

- exported modules aren't interpreted - ([4c052d8](https://github.com/ArkForgeLabs/Astra/commit/4c052d8a8e56f2f4f8777688a68fe67c874d4aa1))

### Refactoring

- always checks for .astra folder first - ([756d768](https://github.com/ArkForgeLabs/Astra/commit/756d7681abcbe457476567b8ca67dd2b4a1a5a7f))

## [0.25.0](https://github.com/ArkForgeLabs/Astra/compare/v0.24.1..v0.24.2) - 2025-07-16

### Features

- implement pubsub stores #26 - ([ec958c9](https://github.com/ArkForgeLabs/Astra/commit/ec958c9fce8514e60b4c6fcb3f0980b1f7d78b0a))
- implement pubsub stores (#75) - ([cf1089b](https://github.com/ArkForgeLabs/Astra/commit/cf1089b827bad1c9f7a6bca5073ec5ffa8af1ba5))
- the runtime now prioritizes loading the locally exported modules instead of bundled modules - ([64b0869](https://github.com/ArkForgeLabs/Astra/commit/64b0869258933d95c1bca3d8f579dde09c6cda58))

### Miscellaneous Chores

- read the default folder or loaded folder from .luarc.json - ([6761d5b](https://github.com/ArkForgeLabs/Astra/commit/6761d5b26d9aa80b04b14b31c55ee414742ffe5a))

### Refactoring

- move pubsub under `Astra` - ([7901c39](https://github.com/ArkForgeLabs/Astra/commit/7901c39c120d647f52f3b9d739f164e8f79e38da))
- #26 - ([7901c39](https://github.com/ArkForgeLabs/Astra/commit/7901c39c120d647f52f3b9d739f164e8f79e38da))

## [0.24.1](https://github.com/ArkForgeLabs/Astra/compare/v0.24.0..0.24.1) - 2025-07-10

### Bug Fixes

- .luarc.json file incorrectly named - ([ca2b338](https://github.com/ArkForgeLabs/Astra/commit/ca2b338d1a99cdf54fa18c3e22a52f0a18ba031d))

## [0.24.0](https://github.com/ArkForgeLabs/Astra/compare/v0.23.1..0.24.0) - 2025-07-05

### Bug Fixes

- import using path as key instead of UUID - ([d7c099a](https://github.com/ArkForgeLabs/Astra/commit/d7c099a55448cf6255753deb441a557890c34691))
- imports fixed and update command now can take custom user_agent - ([ebdf3f6](https://github.com/ArkForgeLabs/Astra/commit/ebdf3f6de4187608f87b35b5c673dde2f59f6365))

### Documentation

- directory with Astra API definitions for Lua autocompletion - ([9956504](https://github.com/ArkForgeLabs/Astra/commit/9956504543468460695f3c036a05bd9350434b3d))
- Add .luarc.json to enable autocompletion - ([9d3511a](https://github.com/ArkForgeLabs/Astra/commit/9d3511a93452340d7256bd93849f2d42f1bad7d6))
- little clarification - ([d9cea09](https://github.com/ArkForgeLabs/Astra/commit/d9cea09c506afa26ca0226cedd55466cd73a90e1))
- definitions refactoring for better go-to experience - ([0a35c64](https://github.com/ArkForgeLabs/Astra/commit/0a35c6435ab207a821439748419d691a6fd99b8f))
- updated docs to reflect the new changes - ([419b0d3](https://github.com/ArkForgeLabs/Astra/commit/419b0d31740963af94200300719a653011a6d87a))

### Features

- astra now exports successfully - ([c9b8d36](https://github.com/ArkForgeLabs/Astra/commit/c9b8d3623ad13dd19d7124c98a5775bcef7d2544))
- server type definitions are correct now - ([e533936](https://github.com/ArkForgeLabs/Astra/commit/e5339363be567d3ebf4bdfca038de82786e113fe))
- completed type definition for the rest of the types - ([27db132](https://github.com/ArkForgeLabs/Astra/commit/27db13265d436871cf81ce98c67067601eb0c777))

### Refactoring

- cleaned up getters and setters - ([26e2569](https://github.com/ArkForgeLabs/Astra/commit/26e2569ea6864a20fdb15f4b0fc905ee600aed00))
- fused the normal and utc datetime constructors - ([4b7bba2](https://github.com/ArkForgeLabs/Astra/commit/4b7bba2b5f45c444a546f3e84e73ed83e81bec1f))
- the lua's type definitions for datetime - ([7001d9e](https://github.com/ArkForgeLabs/Astra/commit/7001d9e5df805069df0b5d4f3b3a2b0e8f143f05))
- moved the lib files back to the top level folder - ([f312335](https://github.com/ArkForgeLabs/Astra/commit/f312335edb41d501fe609000f197e8116e95a2aa))
- moved the type definitions on side of Rust code - ([1c3204c](https://github.com/ArkForgeLabs/Astra/commit/1c3204c70fdfbcf7772f2f38ae67699a95f22fb1))
- divided the http server into components - ([d5f1749](https://github.com/ArkForgeLabs/Astra/commit/d5f1749ce3eb4fa5a2e8bb23b846b4367219b540))

## [0.23.1](https://github.com/ArkForgeLabs/Astra/compare/v0.23.0..0.23.1) - 2025-06-25

### Bug Fixes

- more accurate iso8601 format - ([b30d1af](https://github.com/ArkForgeLabs/Astra/commit/b30d1af5ad0d29aebaf6c7c6db2e781086817054))

### Refactoring

- rename `chrono.rs` to `datetime.rs` - ([8242b82](https://github.com/ArkForgeLabs/Astra/commit/8242b821c887fe4dc6ea7ec4959e55f30a1cc793))

## [0.23.0](https://github.com/ArkForgeLabs/Astra/compare/v0.22.2..0.23.0) - 2025-06-22

### Bug Fixes

- #16 better error handling for chrono utility - ([7977da3](https://github.com/ArkForgeLabs/Astra/commit/7977da333e1d4f7e35705040caaf72eb80b1dc05))
- renamed methods and functions - ([4441886](https://github.com/ArkForgeLabs/Astra/commit/4441886aa153841161f0e9dd39500bc71baf9a9f))
- mend clipboard mishap - ([8962303](https://github.com/ArkForgeLabs/Astra/commit/8962303c911da92102402a58c1fd3e2a2b4d114b))
- directly set datetime constructors as globals - ([98e7ea9](https://github.com/ArkForgeLabs/Astra/commit/98e7ea9298ac71bf387166f1785d53a384a9c1cd))

### Features

- #16 added chrono utility - ([f952ecb](https://github.com/ArkForgeLabs/Astra/commit/f952ecb87808518f7c8b455ba2c3e92fd96f4a67))
- more flexible datetime construction - ([1e69842](https://github.com/ArkForgeLabs/Astra/commit/1e69842dfc71d197d4515f12d39778b894be3be7))
- added type definitions for struct LuaDateTime - ([09b307c](https://github.com/ArkForgeLabs/Astra/commit/09b307c1818aab8aeb2a26954ff6a2460bf93439))

## [0.22.2](https://github.com/ArkForgeLabs/Astra/compare/v0.22.1..0.22.2) - 2025-06-14

### Bug Fixes

- async code within functions are now possible - ([be6d0f6](https://github.com/ArkForgeLabs/Astra/commit/be6d0f6e1680b6c19008f84305a20c08fc603e41))

## [0.22.1](https://github.com/ArkForgeLabs/Astra/compare/v0.22.0..0.22.1) - 2025-06-14

### Bug Fixes

- the templating engine was not returning anything - ([6b8a02e](https://github.com/ArkForgeLabs/Astra/commit/6b8a02ea52a4406cd4f293133c4c5d1c759ddb7d))

## [0.22.0](https://github.com/ArkForgeLabs/Astra/compare/v0.21.2..0.22.0) - 2025-06-13

### Bug Fixes

- #65 added await for async tasks - ([4c39a6c](https://github.com/ArkForgeLabs/Astra/commit/4c39a6c8507dd888b88d2427343191637e5e6a7f))

### Documentation

- updated documentation from tera to jinja - ([c42af7c](https://github.com/ArkForgeLabs/Astra/commit/c42af7c2f7a86e44f9cfa59739a4ece25826a059))

### Features

- moved from tera to minijinja - ([33bbcab](https://github.com/ArkForgeLabs/Astra/commit/33bbcab58fee9332cb3676f5e1cb37b5555f19c3))
- minijinja functions are now working, added `remove_template` - ([ceef94b](https://github.com/ArkForgeLabs/Astra/commit/ceef94bbdc0aa1ce2364cc3a6e00177402fd9963))

### BREAKING

- `context_add`, `context_remove`, and `context_get` are removed. Instead you can add context while rendering or adding to the server

## [0.21.2](https://github.com/ArkForgeLabs/Astra/compare/v0.21.1..0.21.2) - 2025-06-02

### Refactoring

- [**breaking**] moved `server:templates` to `template_engine:add_to_server` and added `add_to_server_debug` as well - ([fbf70ba](https://github.com/ArkForgeLabs/Astra/commit/fbf70ba59eb7730c2314b68ec75ad12d7ecb0446))

## [0.21.1](https://github.com/ArkForgeLabs/Astra/compare/v0.21.0..0.21.1) - 2025-06-01

### Bug Fixes

- #39 - ([4879eaf](https://github.com/ArkForgeLabs/Astra/commit/4879eaf98cfb4bdaca0ae19226aadd385468faf2))

### Documentation

- added guide for regex - ([90dec9a](https://github.com/ArkForgeLabs/Astra/commit/90dec9a44124dcae812351d73394b7267f7d3b5d))

### Features

- Added regular expressions - ([4879eaf](https://github.com/ArkForgeLabs/Astra/commit/4879eaf98cfb4bdaca0ae19226aadd385468faf2))
- added a debugging mode for the template routes - ([cb4b079](https://github.com/ArkForgeLabs/Astra/commit/cb4b079be1f3dc6d002abade6773b90a9719b58c))

### Miscellaneous Chores

- updated the readme to include Astra Trails - ([5c0bf82](https://github.com/ArkForgeLabs/Astra/commit/5c0bf823b458bc0f04f7931836ef54b927c52496))

### Refactoring

- moved templating path logics to within the Lua's side - ([08acab2](https://github.com/ArkForgeLabs/Astra/commit/08acab23c77170e5a26898c91d95b79f224debe7))

## [0.21.0](https://github.com/ArkForgeLabs/Astra/compare/v0.20.0..0.21.0) - 2025-05-30

### Documentation

- added documentation for templating - ([3a6d097](https://github.com/ArkForgeLabs/Astra/commit/3a6d0976e33f1800d02fbfb5e984bfe99c3d55f0))

### Features

- initial tera templating added - ([952e863](https://github.com/ArkForgeLabs/Astra/commit/952e863b5371da2296264a88f67b2c4e602dbac5))
- added template routes and lua intellisense - ([e0365d1](https://github.com/ArkForgeLabs/Astra/commit/e0365d19658bf8557287266ba30efe74cbf49499))
- added exclusions and routes have been optimized - ([846783c](https://github.com/ArkForgeLabs/Astra/commit/846783c249d0d886aeb39284d409266643166ed7))
- now you can create an empty template engine - ([dcd2eed](https://github.com/ArkForgeLabs/Astra/commit/dcd2eed63e5c968efecb9e12c14cc64f9fd79851))
- added templating example - ([7a59a5c](https://github.com/ArkForgeLabs/Astra/commit/7a59a5c974556b53579629230a1a990921a11bfe))
- added template functions - ([6cd72fe](https://github.com/ArkForgeLabs/Astra/commit/6cd72fef783d24c033c005b4810a9f032ce7ca04))

## [0.19.3](https://github.com/ArkForgeLabs/Astra/compare/v0.19.2..v0.19.3) - 2025-05-24

### Features

- added database connection closing function - ([771d650](https://github.com/ArkForgeLabs/Astra/commit/771d650ccde93ce1ffd7e01cd1feb120db6acfeb))

### Miscellaneous Chores

- Improve Row Extraction to Key-Value Format for Lua (#55) - ([45c486f](https://github.com/ArkForgeLabs/Astra/commit/45c486f6e2dded1c34174d66b40c6807cf2dd584))
- cleaned up the `tryset_value` macro - ([995a991](https://github.com/ArkForgeLabs/Astra/commit/995a99195e99439f17d8b8a12d6255dfade4919f))
- [**breaking**] `validate_table` is now strict by default, and have better errors - ([f73dabf](https://github.com/ArkForgeLabs/Astra/commit/f73dabfe0aed482850a5e7fdae73c6a906e15ed7))

### Refactoring

- refactor: support KV table to extract row. e.g. row.name, row.id - ([dac9947](https://github.com/ArkForgeLabs/Astra/commit/dac99474735cd1b2bb097e0c125f55c7beadbdf8))

## [0.19.2] - 2025-05-22

### Bug Fixes

- #54 Now supports glibc 2.27 ([d1235d2](https://github.com/ArkForgeLabs/Astra/commit/d1235d268efced857b3b927b79c435c7c56d0562))

## [0.19.0] - 2025-05-01

### Bug Fixes

- Cookies not properly set ([952ddbd](https://github.com/ArkForgeLabs/Astra/commit/952ddbd731030c81f4031644e60b2740a6f45746))
- Config not added to the routes by default ([9845dd7](https://github.com/ArkForgeLabs/Astra/commit/9845dd72acd4e1b809f3a2af57a03c8b6abb02d5))

### Documentation

- Added wki on cookies ([2d74a04](https://github.com/ArkForgeLabs/Astra/commit/2d74a04ef2dde45a7c3902e29a07e8915a09e14a))
- Added intellisense type info for lua ([7529c13](https://github.com/ArkForgeLabs/Astra/commit/7529c132e949514340a0600a19ac79bc7e82401e))

### Features

- Cookies was added on the backend ([36ff2a0](https://github.com/ArkForgeLabs/Astra/commit/36ff2a08697361f54a76bbb001bf145c645a8ab9))
- Cookies UserData added ([3a29249](https://github.com/ArkForgeLabs/Astra/commit/3a29249fc96fdda972a6feafe1924053408f3d45))

## [0.18.2] - 2025-04-02

### Bug Fixes

- Image binaries multiparts was not able to be streamed due to default body limit malfunctioning ([48042d6](https://github.com/ArkForgeLabs/Astra/commit/48042d654fd3bf6c7d78eaf9dc7c5f543137d8b8))

### Documentation

- Updated docs to include crates.io install ([2e2a5de](https://github.com/ArkForgeLabs/Astra/commit/2e2a5deb5dfef25c387bd00344a1298927ab93d5))

### Features

- First attempts at adding cookie support ([0e74946](https://github.com/ArkForgeLabs/Astra/commit/0e749464e82a50389ef894bfde56c964cea59c51))

### Miscellaneous Tasks

- Fixed the binary name in the cli ([23666df](https://github.com/ArkForgeLabs/Astra/commit/23666df9a9141c566e30cbfcc32ed4a1faa3afd4))

## [0.18.1] - 2025-03-31

### Bug Fixes

- #27 ([1a4107a](https://github.com/ArkForgeLabs/Astra/commit/1a4107aa597204d274de6f72a8028bb288bb6a72))
- #10 ([dff002c](https://github.com/ArkForgeLabs/Astra/commit/dff002c6423c1c08fcd5b604f316fe6971925d29))
- #35 ([9841e48](https://github.com/ArkForgeLabs/Astra/commit/9841e4828e09fff509a9b3bc8973abf726779f87))
- #44 ([3abff8c](https://github.com/ArkForgeLabs/Astra/commit/3abff8c7bc39d95db8b4d3a29898a0b6ca8c740f))
- #43 ([593555d](https://github.com/ArkForgeLabs/Astra/commit/593555d0205a440189b08dad036a9ab8aaf058d4))
- #42 ([f25366f](https://github.com/ArkForgeLabs/Astra/commit/f25366fe1d2386d66aae4b21d4aab47c3f801f90))

### Miscellaneous Tasks

- Updated astra cargo binary name and README ([e6b6829](https://github.com/ArkForgeLabs/Astra/commit/e6b68293763b0c2f863392478756fa1f7b9bab22))
- Updated astra version and added categories and keywords ([68a65d1](https://github.com/ArkForgeLabs/Astra/commit/68a65d10b5e6ba26882f812bc7aa8732e0b3c0aa))
- Updated dependency versions ([894db27](https://github.com/ArkForgeLabs/Astra/commit/894db277ad1fc2be0af4a870e102a2e541091aaf))

## [0.17.3] - 2025-03-10

### Bug Fixes

- Functions being overridden upon registration ([01141eb](https://github.com/ArkForgeLabs/Astra/commit/01141eb1cfa43cb5d4871b77d398775c14970b05))

## [0.17.2] - 2025-03-09

### Bug Fixes

- #37 ([7ef97b9](https://github.com/ArkForgeLabs/Astra/commit/7ef97b973643c67632d5741a91a43490aaaecd51))

### Documentation

- Added documentation for the new import system ([b4d1d89](https://github.com/ArkForgeLabs/Astra/commit/b4d1d89c5ce61165a234d17279e9dfd9332c14c3))

## [0.17.1] - 2025-03-09

### Bug Fixes

- #38 better error messages ([717f4d7](https://github.com/ArkForgeLabs/Astra/commit/717f4d7f1c30dddd5ba0f0eea72369f27dd0dcd9))

### Miscellaneous Tasks

- Cleaned up the cli further ([67c37fa](https://github.com/ArkForgeLabs/Astra/commit/67c37fac4c74d97edbc2c796e2a7cc61e32716e1))
- Cleaned up the cli a bit ([5b2ec31](https://github.com/ArkForgeLabs/Astra/commit/5b2ec3114b554622af0907f22a1406ad09acdfb1))

## [0.17.0] - 2025-03-08

### Bug Fixes

- #34 ([b8e53e3](https://github.com/ArkForgeLabs/Astra/commit/b8e53e3a8a21ce63e5aa6581c70ab547936f20fb))

### Documentation

- Updated download config ([0dc904c](https://github.com/ArkForgeLabs/Astra/commit/0dc904c47ac61cc07d0cda58765c7d3c7b1806d1))
- Updated docs for the new reform ([8a535b4](https://github.com/ArkForgeLabs/Astra/commit/8a535b4b23b99a8d8d9286df36b90c8d1b3d8b4d))

### Features

- Added support for Lua 5.1, 5.2, 5.3 and 5.4 ([0a3d3d7](https://github.com/ArkForgeLabs/Astra/commit/0a3d3d7cf1d1cb6c81dfc6f0c20a696e596f01fa))

### Miscellaneous Tasks

- Moved away from workspace to a single crate ([5bb3adb](https://github.com/ArkForgeLabs/Astra/commit/5bb3adb43c91b02d48145bb8bb7c6324b61589d2))
- Moved utils into the main runtime ([b879098](https://github.com/ArkForgeLabs/Astra/commit/b879098dce03ad388959f6088e1ed6e766169b4e))
- Renamed the folder from `lua_bin` to `astra` ([beb9738](https://github.com/ArkForgeLabs/Astra/commit/beb9738635754024ce8c751f0725d0baa1ee8a70))

## [0.16.0] - 2025-03-08

### Bug Fixes

- #11 ([7fe2bb8](https://github.com/ArkForgeLabs/Astra/commit/7fe2bb8636ae55929ad259e55885259443cb8c13))

### Documentation

- Updated documentation about the SQL driver ([648f0a6](https://github.com/ArkForgeLabs/Astra/commit/648f0a67f5bc2d4c927e98ebae2965d4bdcb5de3))

### Features

- Added sqlite support ([f387584](https://github.com/ArkForgeLabs/Astra/commit/f38758425458ebe37ae492dfa63f9e8b4aa00934))

## [0.15.1] - 2025-03-06

### Bug Fixes

- #36 ([90ff3bb](https://github.com/ArkForgeLabs/Astra/commit/90ff3bb410092fd3e7bc73edda7c837053c4d94f))

### Features

- Added commandline arguments to lua ([374160c](https://github.com/ArkForgeLabs/Astra/commit/374160cd02cd04a370d1935af19de8db5e2e7c31))

## [0.15.0] - 2025-03-04

### Bug Fixes

- #31 ([b1b4d4d](https://github.com/ArkForgeLabs/Astra/commit/b1b4d4d8ec9deba359a5a6bc542b8aa205d3d174))
- Exporting bundled code errors ([34c0e00](https://github.com/ArkForgeLabs/Astra/commit/34c0e00e563592352db28ee543e223891621a3be))

## [0.14.1] - 2025-03-03

### Documentation

- Updated docs for the new syntax ([a2b2e1e](https://github.com/ArkForgeLabs/Astra/commit/a2b2e1e3e6f36d110ab2be2459b7cc47caa898f4))

### Miscellaneous Tasks

- Updated the syntax to be more clear ([0cf5339](https://github.com/ArkForgeLabs/Astra/commit/0cf5339c576ccde529fe5a9c5b9980789f582047))
- Moved the import and bundle ignore code to lua require override ([4ef1490](https://github.com/ArkForgeLabs/Astra/commit/4ef1490c1c471daa4b435c44c9a13bb511b5cca9))

## [0.14.0] - 2025-02-13

### Bug Fixes

- Annotations being wrong ([4ef8bf3](https://github.com/ArkForgeLabs/Astra/commit/4ef8bf3ab09099ca8496988d8ab961873b4b124c))

### Documentation

- Added documentation for the FileIO ([f871c43](https://github.com/ArkForgeLabs/Astra/commit/f871c43c1ecf3f7197ba2932fe10a2001b34a25d))

### Features

- Added chdir, exists, create_dir and create_dir_all ([479f9ab](https://github.com/ArkForgeLabs/Astra/commit/479f9ab2d8d6c6236645c691384f661b6e447639))
- Added remove, remove dir, and metadata functions ([7bb4152](https://github.com/ArkForgeLabs/Astra/commit/7bb41527b88c9681dc7f09e20f238adb415d22ab))
- Added annotations for read dir ([d4f7fee](https://github.com/ArkForgeLabs/Astra/commit/d4f7feefb633967a40def8fb32a5b6220b2549cf))
- Added import to the global context ([6ea4b64](https://github.com/ArkForgeLabs/Astra/commit/6ea4b6436edac57599e36226b95b4c7b2c3798b4))
- Added basic relative imports and filesystem functions ([142330c](https://github.com/ArkForgeLabs/Astra/commit/142330c407cb37659fb07e3d550b93f2d3134adf))

### Miscellaneous Tasks

- Updated version ([ae479cf](https://github.com/ArkForgeLabs/Astra/commit/ae479cfd58218cf463b10717599302d581269d16))

## [0.13.0] - 2025-02-01

### Features

- Self updating command added ([d2032da](https://github.com/ArkForgeLabs/Astra/commit/d2032da8543bf528820cbc9e4289ac14d4d926c4))
- Basic luau support ([72386df](https://github.com/ArkForgeLabs/Astra/commit/72386df547d66b39a56e1f82724ba5df6fc5b582))

## [0.12.2] - 2025-01-30

### Features

- Upload files with http client and save multipart files with uploaded filename ([3fbeced](https://github.com/ArkForgeLabs/Astra/commit/3fbeced38d099cbcbec50e30afadd89aaa8eb394))

## [0.12.0] - 2025-01-30

### Documentation

- Updated docs on the dotenv load order and global function ([b62794f](https://github.com/ArkForgeLabs/Astra/commit/b62794fb2878412f22e7566bb69d6d6dbefde98d))

### Features

- Moved dotenv to a native library ([55b0086](https://github.com/ArkForgeLabs/Astra/commit/55b0086ee83522be5197af0d5aa25705ae3b4d94))

## [0.11.1] - 2025-01-29

### Bug Fixes

- The startup function was not registered correctly ([05d2373](https://github.com/ArkForgeLabs/Astra/commit/05d2373106bd14718423218565534accb62bf5e6))

## [0.11.0] - 2025-01-29

### Documentation

- Added documentation for Crypto utility ([dfc0fc6](https://github.com/ArkForgeLabs/Astra/commit/dfc0fc606aac0ee4390a6365a9c36c18108f7b0d))

### Features

- Added function signatures on Lua as well ([c13087a](https://github.com/ArkForgeLabs/Astra/commit/c13087a77c698ce6239debbf6fb2eb313fe7d864))
- Added base64 support ([02f48c4](https://github.com/ArkForgeLabs/Astra/commit/02f48c4fc991f54ecafd1ff33bd3cfd46da1a79e))
- First edition of LuaCrypto ([20a55ae](https://github.com/ArkForgeLabs/Astra/commit/20a55aea168ea6fe4c9cac9259e0755e386c1e05))

## [0.10.2] - 2025-01-28

### Bug Fixes

- #22 export-bundle command did not execute ([5efd527](https://github.com/ArkForgeLabs/Astra/commit/5efd527e54e49f255cffee99cdd29e4efa8ecd5a))

## [0.10.1] - 2025-01-28

### Features

- Now build with core and full version of Astra ([c81bd67](https://github.com/ArkForgeLabs/Astra/commit/c81bd67f21db24a2eceb4043e123ecb84a24ced0))

### Miscellaneous Tasks

- Updated doc ([65a2a8e](https://github.com/ArkForgeLabs/Astra/commit/65a2a8e3e2b0f9472e36708cb9ae5a7bc1ae8cca))
- Moved everything into workspace structure ([04ff6e4](https://github.com/ArkForgeLabs/Astra/commit/04ff6e43506b2194a95ce704d1cfb77e71ec855a))
- Updated README.md with new syntax ([c346198](https://github.com/ArkForgeLabs/Astra/commit/c3461985a2279db20eb570fd813f122f9b2ffe76))

## [0.10.0] - 2025-01-27

### Fix

- #19 and introducing more types ([c95a4ac](https://github.com/ArkForgeLabs/Astra/commit/c95a4ac69b59a6526053a591221109a2dc846e44))

## [0.8.0] - 2025-01-23

### Documentation

- Updated documentation on the new HTTP client ([7d7b29a](https://github.com/ArkForgeLabs/Astra/commit/7d7b29a265ba85f849fd676d9a7972fbff5b467d))

### Features

- Updated lua bundle for the new http client ([c7ebb12](https://github.com/ArkForgeLabs/Astra/commit/c7ebb12bae8cd973bd61c321a3c27467e61f33c7))
- Revamped HTTP client is complete ([1f3e9ac](https://github.com/ArkForgeLabs/Astra/commit/1f3e9ace1800d8f7b615e6a0e3db889af743a235))
- Major redesign of the http client ([0997bb9](https://github.com/ArkForgeLabs/Astra/commit/0997bb9b083ad86c7e39a169f1d98efa2a553df0))

## [0.7.3] - 2025-01-22

### Miscellaneous Tasks

- Updated the lua bundle ([7e5a0d5](https://github.com/ArkForgeLabs/Astra/commit/7e5a0d5e8a3605adf46c5d74907f65acec3bd8d6))

## [0.7.2] - 2025-01-22

### Bug Fixes

- #9 ([bfcbfe6](https://github.com/ArkForgeLabs/Astra/commit/bfcbfe6180a932a18759de611a8ab82eeec166c4))
- #3, added extensive documentation on the website ([7fece9e](https://github.com/ArkForgeLabs/Astra/commit/7fece9e660af9f30400751feaaa4bb864248e539))
- #6 added refereces to other languages ([d9028bb](https://github.com/ArkForgeLabs/Astra/commit/d9028bbd85d3127aeefef63feb5698e2697d58b0))

### Documentation

- Utilities section has been documented ([8aeef7a](https://github.com/ArkForgeLabs/Astra/commit/8aeef7a5c1b516b50fcaf33e6ed355ca8059d428))
- Added schema validation docs and added single type arrays support ([f2b955b](https://github.com/ArkForgeLabs/Astra/commit/f2b955bca6a9904c91d2554f22b3147f88bc84e2))
- Finished the basic usage section ([ad85abf](https://github.com/ArkForgeLabs/Astra/commit/ad85abf5dd6ec4141d7c6c33cd6d6365b1a1aa93))

### Miscellaneous Tasks

- Added banner to the README ([873abdb](https://github.com/ArkForgeLabs/Astra/commit/873abdb78d40b81552a8b458b263574cd96ef447))
- Cleaned up unneeded context references ([41114e8](https://github.com/ArkForgeLabs/Astra/commit/41114e8316584d4f379f83ed43051660c895d2c4))
- Added banner ([a5ace95](https://github.com/ArkForgeLabs/Astra/commit/a5ace95eb8b8463184938c043ece5691e8021f02))

## [0.7.1] - 2025-01-13

### Bug Fixes

- #7 ([ef7317e](https://github.com/ArkForgeLabs/Astra/commit/ef7317ea924621eca214e5d5058b2c047cceb706))

## [0.7.0] - 2025-01-07

### Documentation

- Added basic documentation and guides ([f15be4d](https://github.com/ArkForgeLabs/Astra/commit/f15be4d9772aa0d46947f4b6225122581e040259))
- Updated the links in the page ([f572b38](https://github.com/ArkForgeLabs/Astra/commit/f572b3897548b656aab8641718bf3ad0d272301e))
- Updated to add versioning and a main page ([709b9d0](https://github.com/ArkForgeLabs/Astra/commit/709b9d06c71242147551c5a3725c1be143207004))
- Started writing documentation for the project ([caed6d5](https://github.com/ArkForgeLabs/Astra/commit/caed6d5543e61c6bba1543212f269c62d9ccaeff))

### Features

- Added multipart support ([7778e8a](https://github.com/ArkForgeLabs/Astra/commit/7778e8abe59957754cb14698d461929563da7bf6))
- Changed Makefile into a lua script for better automation ([eec31fa](https://github.com/ArkForgeLabs/Astra/commit/eec31fa8d587b492b386d5fe2ecc36309727d974))

### Miscellaneous Tasks

- Update version ([553a9c9](https://github.com/ArkForgeLabs/Astra/commit/553a9c91c6219d5254f3da07bf5bc397fb02ce60))

## [0.6.0] - 2025-01-05

### Features

- Added async tasks throughg tokio tasks ([97bcba8](https://github.com/ArkForgeLabs/Astra/commit/97bcba8f35d93a68e05b98a485ca3a793a6d0f16))

## [0.5.0] - 2025-01-01

### Features

- Added async task client http request support ([9ea6cfa](https://github.com/ArkForgeLabs/Astra/commit/9ea6cfa263f8a45d1f167fe8fc4e5a3dddac07da))

### Miscellaneous Tasks

- Updated dependencies and now Windows releases are supported ([577671c](https://github.com/ArkForgeLabs/Astra/commit/577671c93b4d28ac0baa7f9211b5760436d2555c))
- Removed caches from GH Actions ([3b0308c](https://github.com/ArkForgeLabs/Astra/commit/3b0308c825ce343ba3252a2bfa4381faf67264f0))

## [0.4.0] - 2024-12-29

### Features

- Added responses ([c94b9f7](https://github.com/ArkForgeLabs/Astra/commit/c94b9f7daae79d221d7246be9d6ffa7c01f53c0b))
- The body now can have text or json processed ([9041831](https://github.com/ArkForgeLabs/Astra/commit/9041831eacff5e016b7cabbfe86402c8c6e613d1))
- Fixed parse_query and added table schema validation ([2dc0ddf](https://github.com/ArkForgeLabs/Astra/commit/2dc0ddfa8b3b9af00c7162144369786408312565))

## [0.3.5] - 2024-12-27

### Bug Fixes

- #2 ([30ee5f5](https://github.com/ArkForgeLabs/Astra/commit/30ee5f5eaf36061c6cad8ac33f32ec4f67d8ff7e))

### Miscellaneous Tasks

- Updated the versions ([c556150](https://github.com/ArkForgeLabs/Astra/commit/c5561507ff9f2f9fb5d227badbedc39680843c54))

## [0.3.4] - 2024-12-27

### Miscellaneous Tasks

- Attempt at chmod during build ([56172b3](https://github.com/ArkForgeLabs/Astra/commit/56172b3ba2a9bb0e96d3abe349b9683557f8f1e4))

## [0.3.3] - 2024-12-26

### Features

- Dotenv and pretty print ([013a0d1](https://github.com/ArkForgeLabs/Astra/commit/013a0d199b6a02bde1630e78f85ddf530da41e39))

## [0.3.2] - 2024-12-26

### Features

- Compression layer is now included but optionally enabled through settings ([216eb9e](https://github.com/ArkForgeLabs/Astra/commit/216eb9ea3b3111c3e02513919df95acfc3e8fc9a))
- Added static_file serving support ([721510f](https://github.com/ArkForgeLabs/Astra/commit/721510f4b596227e667b732dc2d5a529190761e7))
- Optional compression and added new route methods ([ae7b01e](https://github.com/ArkForgeLabs/Astra/commit/ae7b01e81af3b3d9a23c5fee79b152cae710d8b3))

## [0.3.0] - 2024-12-24

### Features

- Added static routes and compression ([0bd553b](https://github.com/ArkForgeLabs/Astra/commit/0bd553b816b1bd9a73f266d3d4f9425b0fbcfdc4))

### Miscellaneous Tasks

- Updated versions ([a53971e](https://github.com/ArkForgeLabs/Astra/commit/a53971e76ed099edf8a535af3d734bcb5d88162b))

## [0.2.0] - 2024-12-24

### Features

- Postgresql support added ([5d4a941](https://github.com/ArkForgeLabs/Astra/commit/5d4a941ad522d696514c4424a6bef5ec19e92691))
- Added database and examples ([512dd38](https://github.com/ArkForgeLabs/Astra/commit/512dd3848b6fa5749d73a1161745c5a2ffef4589))

### Miscellaneous Tasks

- Updated version ([167d323](https://github.com/ArkForgeLabs/Astra/commit/167d3230088ec3598d043ce7ad9f5086886ba074))

## [0.1.0] - 2024-12-23

### Features

- Added bundle export option ([cccc13c](https://github.com/ArkForgeLabs/Astra/commit/cccc13c438eb0d5db78263d35442ac3a333092ee))
- Added version ([126361c](https://github.com/ArkForgeLabs/Astra/commit/126361cc166c1c8f7a87147ef013495b094acf29))
- Added workflow and cleaned up the source code ([161ba3b](https://github.com/ArkForgeLabs/Astra/commit/161ba3bb0a6fcda804403452f5d3a12adf0f8b55))
- Improved request methods ([c9b95d4](https://github.com/ArkForgeLabs/Astra/commit/c9b95d4e9985ed225829ca43afe3ac8f11bcb030))
- Added license and description ([82819f9](https://github.com/ArkForgeLabs/Astra/commit/82819f943b9dbf83c0b357bac00ee4045e1bb23f))
- Performance improved and added README ([3860a22](https://github.com/ArkForgeLabs/Astra/commit/3860a2263bfac5f3639f6791089be4838a31d404))
- Added requests information ([132a6d0](https://github.com/ArkForgeLabs/Astra/commit/132a6d02116f899e3226217f0d0ebb9e598c5c9d))
- Workable version with returns ([dce9274](https://github.com/ArkForgeLabs/Astra/commit/dce92748ff321e6e60f9445048e406266edb3314))
