pub mod client;
pub mod server;

pub fn type_definitions() -> String {
    let main = include_str!("http.lua").to_string();
    let server = include_str!("server/server.lua");
    let client = include_str!("client/client.lua");
    let middleware = include_str!("middleware.lua");

    main + "\n" + server + "\n" + client + "\n" + middleware
}
