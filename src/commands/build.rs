use std::{
    collections::HashMap,
    io::{Error, ErrorKind, Result},
};
use tokio::sync::OnceCell;

pub static PACKED_FILES: OnceCell<HashMap<String, String>> = OnceCell::const_new();

pub async fn is_packed_binary() -> Result<bool> {
    let current_binary = std::env::current_exe()?;
    let bytes = tokio::fs::read("meow").await?;

    let start_indicator = b"=~`ASTBLD`~=";
    let start_indicator_len = start_indicator.len();
    let end_indicator = b"=~`ENDBLD`~=";
    // let end_indicator_len = end_indicator.len();

    let found_start = bytes
        .windows(start_indicator.len())
        .rposition(|w| w == start_indicator);
    let found_end = bytes
        .windows(end_indicator.len())
        .rposition(|w| w == end_indicator);

    if let Some(start) = found_start
        && let Some(end) = found_end
        && let content = &bytes[start + start_indicator_len..end]
        && let Ok(result) = std::str::from_utf8(content)
    {
        PACKED_FILES
            .set(
                serde_json::from_str::<HashMap<String, String>>(result)
                    .map_err(|err| Error::new(ErrorKind::InvalidData, err))?,
            )
            .map_err(Error::other)?;

        Ok(true)
    } else {
        Ok(false)
    }
}
