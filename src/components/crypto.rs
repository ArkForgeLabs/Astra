// Cryptography util. Currently supporting only SHA2 and SHA3 (256 and 512 variants)

use base64::{
    Engine,
    prelude::{BASE64_STANDARD, BASE64_URL_SAFE},
};

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    let hash_function =
        lua.create_function(|_, (hash_type, input): (String, String)| Ok(hash(hash_type, input)))?;
    lua.globals().set("astra_internal__hash", hash_function)?;

    lua.globals().set(
        "astra_internal__base64_encode",
        lua.create_function(|_, input: String| Ok(base64_encode(input)))?,
    )?;

    lua.globals().set(
        "astra_internal__base64_encode_urlsafe",
        lua.create_function(|_, input: String| Ok(base64_encode_urlsafe(input)))?,
    )?;

    lua.globals().set(
        "astra_internal__base64_decode",
        lua.create_function(|_, input: String| base64_decode(input))?,
    )?;

    lua.globals().set(
        "astra_internal__base64_decode_urlsafe",
        lua.create_function(|_, input: String| base64_decode_urlsafe(input))?,
    )?;

    Ok(())
}

fn hash(hash_type: String, input: String) -> String {
    macro_rules! sha_impl {
        ($hash_function:ty) => {
            let mut sha = <$hash_function>::new();
            sha.update(input);
            return format!("{:x}", sha.finalize())
        };
    }
    if hash_type.starts_with("sha") {
        match hash_type.as_str() {
            "sha3_256" => {
                use sha3::Digest;
                sha_impl!(sha3::Sha3_256);
            }
            "sha3_512" => {
                use sha3::Digest;
                sha_impl!(sha3::Sha3_512);
            }
            "sha2_512" => {
                use sha3::Digest;
                sha_impl!(sha2::Sha512);
            }
            _ => {
                use sha2::Digest;
                sha_impl!(sha2::Sha256);
            }
        }
    } else {
        "".to_string()
    }
}

fn base64_encode(input: String) -> String {
    let mut output_buf = String::new();
    BASE64_STANDARD.encode_string(input, &mut output_buf);
    output_buf
}

fn base64_encode_urlsafe(input: String) -> String {
    let mut output_buf = String::new();
    BASE64_URL_SAFE.encode_string(input, &mut output_buf);
    output_buf
}

fn base64_decode(input: String) -> mlua::Result<String> {
    let mut output_buf = Vec::new();
    match BASE64_STANDARD.decode_vec(input.as_bytes(), &mut output_buf) {
        Ok(_) => Ok(String::from_utf8_lossy(output_buf.as_slice()).to_string()),
        Err(e) => Err(mlua::Error::runtime(format!(
            "Could not decode the base64 encoded input: {e:?}"
        ))),
    }
}

fn base64_decode_urlsafe(input: String) -> mlua::Result<String> {
    let mut output_buf = Vec::new();
    match BASE64_URL_SAFE.decode_vec(input.as_bytes(), &mut output_buf) {
        Ok(_) => Ok(String::from_utf8_lossy(output_buf.as_slice()).to_string()),
        Err(e) => Err(mlua::Error::runtime(format!(
            "Could not decode the base64 encoded input: {e:?}"
        ))),
    }
}
