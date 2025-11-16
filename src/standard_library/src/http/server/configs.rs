use mlua::{FromLua, UserData};

#[derive(Debug, Clone, Default, PartialEq, serde::Serialize, serde::Deserialize, FromLua)]
pub struct RouteConfiguration {
    pub body_limit: Option<usize>,
    pub compression: Option<bool>,
}
impl UserData for RouteConfiguration {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("set_body_limit", |_, this, body_limit: usize| {
            this.body_limit = Some(body_limit);

            Ok(())
        });

        methods.add_method_mut("set_compression", |_, this, compression: bool| {
            this.compression = Some(compression);

            Ok(())
        });
    }
}
