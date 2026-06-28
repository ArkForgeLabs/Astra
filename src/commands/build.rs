use std::{
    collections::HashMap,
    os::unix::fs::PermissionsExt,
    sync::{LazyLock, OnceLock},
};

use tokio::io::AsyncWriteExt;

#[derive(Debug, Default, Clone, serde::Serialize, serde::Deserialize)]
pub struct PackedFiles {
    pub start: String,
    pub entries: HashMap<String, String>,
}

pub static PACKED_FILES: OnceLock<PackedFiles> = OnceLock::new();
pub static REQUIRE_REGEX: LazyLock<regex::Regex> = LazyLock::new(|| {
    #[allow(clippy::expect_used)]
    regex::Regex::new(r#"require\s*\(\s*["']([^"']+)["']"#)
        .expect("Could not build the require regex. This is a bug!")
});
pub const START_INDICATOR: &[u8; 8] = b"_ASTBLD_";
pub const END_INDICATOR: &[u8; 8] = b"_ENDBLD_";

pub async fn is_packed_binary() -> std::io::Result<bool> {
    let current_binary = std::env::current_exe()?;
    let bytes = tokio::fs::read(current_binary).await?;

    // check if the last bytes are END indicator
    if let has_end = &bytes[bytes.len() - 8..bytes.len()] == END_INDICATOR
        && has_end
        && let Some(start) = bytes // find the start
            .windows(START_INDICATOR.len())
            .rposition(|w| w == START_INDICATOR)
        && let content = &bytes[start + 8..bytes.len() - 8]
        && let Ok(result) = std::str::from_utf8(content)
        && let Ok(packed_files) = serde_json::from_str::<PackedFiles>(result)
        && let Ok(_) = PACKED_FILES.set(packed_files)
    {
        Ok(true)
    } else {
        Ok(false)
    }
}

pub async fn dependency_resolution(
    file_path: &str,
    matches: &mut PackedFiles,
) -> std::io::Result<()> {
    Box::pin(async {
        if !matches.entries.contains_key(file_path)
            && let Some((_, file_content)) =
                crate::components::import::find_first_lua_match_with_content(
                    None, file_path, file_path,
                )
                .await
        {
            for (_, [import_path]) in REQUIRE_REGEX
                .captures_iter(&file_content)
                .map(|c| c.extract())
            {
                dependency_resolution(import_path, matches).await?;
            }

            matches
                .entries
                .insert(file_path.to_string() + ".lua", file_content);
        }

        Ok(())
    })
    .await
}

pub async fn pack(path: String, output: String) -> std::io::Result<()> {
    let mut result = PackedFiles::default();
    dependency_resolution(&path.replace(".luau", "").replace(".lua", ""), &mut result).await?;
    result.start = path;

    let current_binary = std::env::current_exe()?;
    let mut bytes = tokio::fs::read(current_binary).await?;

    bytes.append(&mut START_INDICATOR.to_vec());
    bytes.append(&mut serde_json::to_string(&result)?.into_bytes());
    bytes.append(&mut END_INDICATOR.to_vec());

    let mut file = tokio::fs::OpenOptions::new()
        .write(true)
        .truncate(true)
        .open(output)
        .await?;
    #[cfg(unix)]
    file.set_permissions(std::fs::Permissions::from_mode(0o755))
        .await?;
    file.write_all(&bytes).await?;

    Ok(())
}
