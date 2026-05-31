# Introduction

## About

ArkForge Astra is an easy-to-use, fault-tolerant, extendible, and high performant web server runtime targeting [Lua](https://lua.org) (5.1 upto 5.5), [LuaJIT](https://luajit.org/) (LuaJIT and LuaJIT 5.2), and [Luau](https://luau.org/), and built upon [Rust](https://www.rust-lang.org/). Astra takes advantages of the Rust's performance, correctness and memory safety offering, and with a rich library and ecosystems, to privde a batteries included standard library (that is also customizable), write fault-tolerant code, in a concurrent and parallel environment.

Currently Astra is used within the [ArkForge](https://arkforge.net) for some internal and external products, automation scripts, and servers. We have also seen Astra, over the years, being used by some enterprise, universities, PhD students, and research labs as well. However being very young and early project, it may lack battle testing directly, however, it does not mean you cannot build software with it. Astra's foundations, Rust and Lua, is already mature and Astra is a thin wrapper over them. Even still, we urge you to remember that the API might change between updates, and we try our best to give deprecation notices.

## Why use Astra?

* `For fun`: It is refreshingly simple, small, easy to use, and to extend.
* `Rich STDLib`: We try to include all the libraries and functionalities you would need, at least for the majority of cases. This allows you to rarely, if ever, need a package manager or a library.
* `Resource efficiency`: You do not need to waste any resources you do not use. The runtime memory usage is small, and all of your available CPU and thread is used by default to finish the task sooner. However on idle it will remain small. The runtime itself is a tiny ~20MB file (~6MB gzipped), and with conditional compilation from source, we can bring it down to even ~1MB if needed.
* `Active development`: Exciting new additions and features coming all the time! We are buildiing a runtime that want to use, not one that we have to deal with!

## Why NOT use Astra

* `Long-term stability`: At least until version 1.0, there should be caution used since we are still figuring out the best way to provide the API. After the 1.0, the changes will be append-only and will be marked as deprecate until the next major version.
* `Great IDE support`: Lua and Luau is incredibly embeddable, which also means that it does not have a major standards and IDE supports that an enterprise level language would do. Do expect to patch things up yourself, if you ever need to in the first place.
* `Great tooling`: Lua and Luau, including Astra, have enough tooling for the average software and scripts written. However, incredible debuggers, optimizers, bundlers, and advanced anaylzers that other languages may have is missing here due to the same reason above.
* `Your manager said no`: It is understandable, organizations may have different requirements and standards, and Astra may not be included. If other tooling and languages are "good enough" for you and that is the amount you care, then that is alright as well.

## Philosophy

The goal is to have the cake and eat it too. Obtaining the low-level advantages of Rust while having the iteration, ease and development speed of Lua. This way you can both have a small runtime and iterate over your products and servers with a very simple CI setup that ships in seconds, or even direct SSH, or you could even live edit the files and work in production directly.

Astra's development style is to be as minimalist and simple as we can afford, while keeping the performance and customization as far as we can. Simplicity means decreasing as many steps as possible between the core developers and someone completely new to the project being able to pick it up and start changing it to their needs. However we do add complexity when it is required as well. Keeping the minimalistic development style also means we use minimal number of tools, and if we do use a tool, it should not be too foreign from the source.
