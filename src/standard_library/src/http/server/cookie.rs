use axum_extra::extract::cookie::Cookie;
use mlua::{FromLua, UserData};

#[derive(Debug, Clone, FromLua)]
pub struct AstraHTTPCookie<'a>(pub Cookie<'a>);
impl UserData for AstraHTTPCookie<'_> {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("set_name", |_, this, name: String| {
            this.0.set_name(name);
            Ok(())
        });
        methods.add_method_mut("set_value", |_, this, value: String| {
            this.0.set_value(value);
            Ok(())
        });
        methods.add_method_mut("set_domain", |_, this, domain: String| {
            this.0.set_domain(domain);
            Ok(())
        });
        methods.add_method_mut("set_path", |_, this, path: String| {
            this.0.set_path(path);
            Ok(())
        });
        methods.add_method_mut("set_expiration", |_, this, expiration: i64| {
            this.0
                .set_expires(time::OffsetDateTime::now_utc() + time::Duration::seconds(expiration));
            Ok(())
        });
        methods.add_method_mut("set_http_only", |_, this, http_only: bool| {
            this.0.set_http_only(http_only);
            Ok(())
        });
        methods.add_method_mut("set_max_age", |_, this, max_age: i64| {
            this.0.set_max_age(time::Duration::seconds(max_age));
            Ok(())
        });
        methods.add_method_mut("set_permanent", |_, this, _: ()| {
            this.0.make_permanent();
            Ok(())
        });

        methods.add_method("get_name", |_, this, _: ()| Ok(this.0.name().to_string()));
        methods.add_method("get_value", |_, this, _: ()| Ok(this.0.value().to_string()));
        methods.add_method("get_domain", |_, this, _: ()| {
            Ok(this.0.domain().map(|domain| Some(domain.to_string())))
        });
        methods.add_method("get_path", |_, this, _: ()| {
            Ok(this.0.path().map(|path| Some(path.to_string())))
        });
        methods.add_method("get_expiration", |_, this, _: ()| {
            Ok(this
                .0
                .expires_datetime()
                .map(|expire| expire.offset().whole_seconds()))
        });
        methods.add_method("is_http_only", |_, this, _: ()| Ok(this.0.http_only()));
        methods.add_method("get_max_age", |_, this, _: ()| {
            Ok(this.0.max_age().map(|age| age.whole_seconds()))
        });
    }
}
