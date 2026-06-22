use std::{
    collections::HashMap,
    sync::{LazyLock, OnceLock},
};

pub type PackedFileType = HashMap<String, String>;
pub static PACKED_FILES: OnceLock<PackedFileType> = OnceLock::new();
pub static REQUIRE_REGEX: LazyLock<regex::Regex> = LazyLock::new(|| {
    #[allow(clippy::expect_used)]
    regex::Regex::new(r#"require\s*\(\s*["']([^"']+)["']"#)
        .expect("Could not build the require regex. This is a bug!")
});
pub const START_INDICATOR: &[u8; 12] = b"=~`ASTBLD`~=";
pub const END_INDICATOR: &[u8; 12] = b"=~`ENDBLD`~=";

pub async fn is_packed_binary() -> std::io::Result<bool> {
    let current_binary = std::env::current_exe()?;
    let bytes = tokio::fs::read("meow").await?;

    let found_start = bytes
        .windows(START_INDICATOR.len())
        .rposition(|w| w == START_INDICATOR);
    let found_end = bytes
        .windows(END_INDICATOR.len())
        .rposition(|w| w == END_INDICATOR);

    if let Some(start) = found_start
        && let Some(end) = found_end
        && let content = &bytes[start + 12..end]
        && let Ok(result) = std::str::from_utf8(content)
        && let Ok(parsed) = serde_json::from_str::<PackedFileType>(result)
        && let Ok(_) = PACKED_FILES.set(parsed)
    {
        Ok(true)
    } else {
        Ok(false)
    }
}

pub fn dependency_resolution(file_path: &str, matches: &mut PackedFileType) -> std::io::Result<()> {
    if !matches.contains_key(file_path) {
        let file_content = std::fs::read_to_string(file_path)?;
        for (_, [import_path]) in REQUIRE_REGEX
            .captures_iter(&file_content)
            .map(|c| c.extract())
        {
            dependency_resolution(import_path, matches)?;
        }

        matches.insert(file_path.to_string(), file_content);
    }

    Ok(())
}
