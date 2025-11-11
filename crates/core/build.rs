use std::{env, fs, path::PathBuf};

fn main() {
    // Get the output directory where the compiled .so/.dylib will be
    let out_dir = env::var("OUT_DIR").unwrap();
    let profile = env::var("PROFILE").unwrap();

    println!("cargo:warning=Building in {} mode", profile);
    println!("cargo:warning=Output directory: {}", out_dir);

    // Determine the shared library extension based on platform
    let lib_extension = if cfg!(target_os = "macos") {
        "dylib"
    } else if cfg!(target_os = "windows") {
        "dll"
    } else {
        "so"
    };

    // The library name will be libamp_extras_core.{extension}
    let lib_name = format!("libamp_extras_core.{}", lib_extension);

    // Find target directory (typically target/debug or target/release)
    let target_dir = PathBuf::from(&out_dir)
        .ancestors()
        .nth(3)
        .unwrap()
        .to_path_buf();

    let lib_src = target_dir.join(&lib_name);

    // Destination: lua/amp_extras/
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

    let lib_dest = lua_dir.join("amp_extras_core.so");

    println!(
        "cargo:warning=Will copy {} to {}",
        lib_src.display(),
        lib_dest.display()
    );
    println!("cargo:rerun-if-changed=src/");
}
