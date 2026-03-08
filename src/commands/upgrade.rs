use clap::crate_version;

/// Upgrades to the latest version.
pub async fn upgrade_command(user_agent: Option<String>) -> Result<(), Box<dyn std::error::Error>> {
    let user_agent = user_agent.unwrap_or(
        "Mozilla/5.0 (X11; \
            Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) \
            Chrome/51.0.2704.103 Safari/537.36"
            .to_string(),
    );
    let latest_tag = reqwest::Client::new()
        .get("https://api.github.com/repos/ArkForgeLabs/Astra/tags")
        .header(reqwest::header::USER_AGENT, user_agent)
        .send()
        .await?
        .json::<serde_json::Value>()
        .await?;

    // Get the latest tag.
    #[allow(clippy::expect_used)]
    let latest_tag = latest_tag
        .as_array()
        .expect("Could not obtain a list of releases")
        .first()
        .expect("Could not get the first available release")
        .as_object()
        .expect("Could not get the release details")
        .get("name")
        .expect("Could not get the tag")
        .as_str()
        .expect("Tag content is not in correct format");

    // Compare the latest tag with the current version.
    if version_compare::compare_to(latest_tag, crate_version!(), version_compare::Cmp::Gt)
        .is_ok_and(|compared| compared)
    {
        println!("Updating from {} to {latest_tag}...", crate_version!());

        let runtime = if cfg!(feature = "lua54") {
            "lua54"
        } else if cfg!(feature = "luajit52") {
            "luajit52"
        } else if cfg!(feature = "luau") {
            "luau"
        } else if cfg!(feature = "lua51") {
            "lua51"
        } else if cfg!(feature = "lua52") {
            "lua52"
        } else if cfg!(feature = "lua53") {
            "lua53"
        } else {
            "luajit"
        };

        let architecture = if cfg!(windows) {
            if cfg!(target_arch = "aarch64") {
                "windows-arm64.exe"
            } else {
                "windows-amd64.exe"
            }
        } else if cfg!(target_os = "linux") {
            if cfg!(target_arch = "aarch64") {
                "linux-arm64"
            } else {
                "linux-amd64"
            }
        } else if cfg!(target_os = "macos") {
            "macos-arm64"
        } else if cfg!(target_arch = "riscv64") {
            "riscv-amd64"
        } else {
            "linux-amd64"
        };

        let file_name = format!("astra-{runtime}-{architecture}");
        let url =
            format!("https://github.com/ArkForgeLabs/Astra/releases/latest/download/{file_name}");

        // Download the latest release.
        let content = reqwest::get(url).await?.bytes().await?;
        let current_file_name = std::env::current_exe()?.to_string_lossy().to_string();

        std::fs::write(format!("{file_name}-{latest_tag}"), content)?;
        std::fs::rename(
            current_file_name.clone(),
            format!("{current_file_name}_old"),
        )?;
        std::fs::rename(
            format!("{file_name}-{latest_tag}"),
            current_file_name.clone(),
        )?;

        #[cfg(target_os = "linux")]
        {
            let _ = std::process::Command::new("chmod")
                .arg("+x")
                .arg(current_file_name)
                .spawn();
        }

        println!(
            r#"🚀 Update complete!

Some of the next steps could be updating the exported type definitions:

astra export"#
        );
    } else {
        println!("Already up to date!")
    }

    Ok(())
}

pub fn remove_old_runtime() -> Result<(), Box<dyn std::error::Error>> {
    let current_file_name = std::env::current_exe()?.to_string_lossy().to_string();
    if std::fs::exists(format!("{current_file_name}_old"))? {
        std::fs::remove_file(format!("{current_file_name}_old"))?;
    }

    Ok(())
}
