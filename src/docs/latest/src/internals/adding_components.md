# Extending Astra

## Through Components

Your point of interest will be the `src` directory. If your aim is to extend the engine, you may look into the `components` folder upon which you can add a new file of your choice.

For extensions, you need a struct that implements `LuaComponents` trait implemented which gives an async `lua` runtime context. Within it you can create a new lua function that adds your function to the global context at runtime.

```rust
pub struct MyNewExtension {
    pub field: String,
}
impl crate::components::LuaComponents for MyNewExtension {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let function = lua.create_async_function(|lua, param: mlua::Value| async move {
            /* Content */

            Ok(Self { field: "Hello!".to_string() })
        })?;

        lua.globals().set("my_extension", function)
    }
}
```

After this, open `mod.rs` folder, include your new extention's file, and within `register_components` call your extension's `register_to_lua` method.

```rust
    my_extension::MyNewExtension::register_to_lua(lua).await?;
```

If you wish to return a table with methods that your lua code can call, then you need to implement mlua's `UserData` trait:

```rust
impl UserData for MyNewExtension {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        // Add your custom method that you can call within Lua
        methods.add_method(
            "sync_method",
            |lua, this, param: mlua::Value| {
                // Your code
                println!("{:param#?}");

                Ok(())
            },
        );

        // It can also be async
        methods.add_async_method(
            "async_method",
            |lua, this, param: mlua::Value| async move {
                // Your code
                println!("{:param#?}");

                Ok(())
            },
        );

        // As well as mutability
        methods.add_mut_method(
            "sync_method",
            |lua, this, param: String| {
                // Your code
                this.field = param.clone();
                println!("{:param#?}");

                Ok(())
            },
        );
    }
}
```
