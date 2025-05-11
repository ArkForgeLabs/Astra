use mlua::UserData;

#[derive(Debug, Clone, Default, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct RouteConfiguration {
    pub body_limit: Option<usize>,
}
impl UserData for RouteConfiguration {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("set_body_limit", |_, this, body_limit: usize| {
            this.body_limit = Some(body_limit);

            Ok(())
        });
    }
}
