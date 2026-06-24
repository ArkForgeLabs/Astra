use std::{
    collections::HashMap,
    sync::{LazyLock, OnceLock},
};

#[derive(Debug, Clone)]
pub struct PackedFiles {
    entrypoint: String,
    imports: PackedFileType,
}

pub type PackedFileType = HashMap<String, String>;
pub static PACKED_FILES: OnceLock<PackedFileType> = OnceLock::new();
pub static REQUIRE_REGEX: LazyLock<regex::Regex> = LazyLock::new(|| {
    #[allow(clippy::expect_used)]
    regex::Regex::new(r#"require\s*\(\s*["']([^"']+)["']"#)
        .expect("Could not build the require regex. This is a bug!")
});
pub const START_INDICATOR: &[u8; 8] = b"_ASTBLD_";
pub const END_INDICATOR: &[u8; 8] = b"_ENDBLD_";

pub async fn is_packed_binary() -> std::io::Result<bool> {
    let current_binary = std::env::current_exe()?;
    let bytes = tokio::fs::read("meow2").await?;

    // let a = r#"return { test = function() print("HELLOOOO") end }"#;
    // let b = r#"require("bar").test()"#;

    // let mut c = PackedFileType::new();
    // c.insert("bar.lua".to_string(), a.to_string());
    // c.insert("main.lua".to_string(), b.to_string());
    // let content = serde_json::to_string(&c).unwrap();

    // println!("{content:?}");

    // bytes.append(&mut START_INDICATOR.to_vec());
    // bytes.append(&mut content.into_bytes());
    // bytes.append(&mut END_INDICATOR.to_vec());

    // tokio::fs::write("meow2", bytes.clone()).await;

    // check if the last bytes are END indicator
    if let _ = &bytes[bytes.len() - 8..bytes.len()] == END_INDICATOR
        && let Some(start) = bytes // find the start
            .windows(START_INDICATOR.len())
            .rposition(|w| w == START_INDICATOR)
        && let content = &bytes[start + 8..bytes.len() - 8]
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

pub async fn pack(path: String) -> std::io::Result<()> {
    let mut result = PackedFileType::new();
    dependency_resolution(&path, &mut result)?;

    println!("{:?}", result);

    Ok(())
}
