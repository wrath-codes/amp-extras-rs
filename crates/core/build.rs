use std::{env, fs, path::PathBuf, process::Command};

fn main() {
    let profile = env::var("PROFILE").unwrap_or_else(|_| "debug".to_string());

    println!("cargo:warning=Building in {} mode", profile);

    // Determine the shared library extension based on platform
    let lib_extension = if cfg!(target_os = "macos") {
        "dylib"
    } else if cfg!(target_os = "windows") {
        "dll"
    } else {
        "so"
    };

    let lib_name = format!("libamp_extras_core.{}", lib_extension);

    // Find workspace root
    let workspace_root = env::var("CARGO_MANIFEST_DIR")
        .map(PathBuf::from)
        .unwrap()
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .to_path_buf();

    let lua_dir = workspace_root.join("lua").join("amp_extras");

    // Create lua directory if it doesn't exist
    fs::create_dir_all(&lua_dir).ok();

    // Track version for release builds
    if profile == "release" {
        // Delete existing version file (may have been created by downloader)
        let version_file = lua_dir.join("version");
        let _ = fs::remove_file(&version_file);

        // Try to get git tag first (for tagged releases)
        let version = get_git_tag().or_else(get_git_sha);

        if let Some(v) = version {
            let _ = fs::write(&version_file, v.trim());
            println!("cargo:warning=Version: {}", v.trim());
        }
    }

    // Get target directory
    let out_dir = env::var("OUT_DIR").unwrap();
    let target_dir = PathBuf::from(&out_dir)
        .ancestors()
        .nth(3)
        .unwrap()
        .to_path_buf();

    let lib_src = target_dir.join(&lib_name);
    let lib_dest = lua_dir.join("amp_extras_core.so");

    println!(
        "cargo:warning=Will copy {} to {}",
        lib_src.display(),
        lib_dest.display()
    );
    println!("cargo:rerun-if-changed=src/");
}

fn get_git_tag() -> Option<String> {
    Command::new("git")
        .args(["describe", "--tags", "--exact-match"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
}

fn get_git_sha() -> Option<String> {
    Command::new("git")
        .args(["rev-parse", "HEAD"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
}
