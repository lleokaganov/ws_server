# ws_server

A minimal end-to-end-encrypted WebSocket relay. The server only routes opaque
encrypted frames between pairs of clients — it does not decrypt, validate, or
store messages. No database, no accounts, no email.

Derived from the `aguardia_server` codebase, with the auth / DB / email stack
removed: this is just the transport.

## Protocol summary

- **client_id**: first 8 bytes of `SHA-256(X25519_public)`. Deterministic, never
  sent on the wire — peers derive it from the public key.
- **Handshake** (single frame): `[X_client_pub:32] [nonce:24]
  [AEAD(ed_pub‖version)] [sig:64]`. The server decrypts the AEAD with
  `shared(X_server, X_client)`, recovers the client's Ed25519 public key, then
  verifies the signature.
- **Session keys** `K_c2s` / `K_s2c` are HKDF-SHA256 derived from the shared
  secret and used to XOR-obfuscate the routing header.
- **Routing frame**: `[8-byte XOR'd header] [nonce:24] [AEAD ciphertext for the
  peer] [sig:64]`. The server XOR-deobfuscates the header to find the
  recipient, replaces the header with `sender_id XOR keystream(K_s2c_recipient)`,
  and forwards the rest untouched.
- **Server-originated** frames carry an all-zero post-XOR header. They are
  signed with the server's Ed25519 key and encrypted with X25519.
- **Errors** use `cmd=0xFF` with codes `0x01=id_in_use`, `0x02=bad_version`,
  `0x03=recipient_offline`.

Full spec: [`doc/PROTOCOL.md`](doc/PROTOCOL.md).

## Stack

Rust, `actix-web` + `actix-ws`. Crypto via the dalek crates
(`x25519-dalek`, `ed25519-dalek`) plus `chacha20poly1305`, `chacha20`,
`hkdf` / `blake3`. See `Cargo.toml`.

## Build

```sh
cargo build --release
```

The release profile is size-optimised (`opt-level = "z"`, LTO, strip) for
small targets like a Raspberry Pi. Panic mode stays `unwind` so a bad frame
cannot take the whole relay down — actix isolates per-request panics.

## Generating server keys

The server has a long-term X25519 + Ed25519 keypair. Public halves are pinned
into every client, so **rotating these keys invalidates every installed
client** — generate once and keep them.

A placeholder is shipped at `src/server_keys.rs.example`. To get your own:

1. Generate fresh keys (any tool that produces 32-byte X25519 and Ed25519
   secrets — the placeholder file shows the constant shape the source expects).
2. Save the populated file as `src/server_keys.rs` (gitignored).
3. Embed the public halves (`X25519_PUBLIC`, `ED25519_PUBLIC`) into your
   clients so they can handshake against this deployment.

`src/server_keys.rs.example` is kept in git so a fresh checkout still builds
once you copy it to `server_keys.rs` and substitute real values.

## Run

```sh
ws_server         # listens on 0.0.0.0:8080 by default
```

The server logs to stderr with `tracing-subscriber`; set `RUST_LOG=info` (or
`debug`) to control verbosity.

## Reference client

A complete Rust client example lives in `examples/client.rs` — it demonstrates
the handshake, sending a message, and parsing server-routed frames.

```sh
cargo run --example client
```

## Status

In production on `ws://ws.lleo.me/` (a Raspberry Pi). Used by the
[`telefon`](https://github.com/lleokaganov/tele) chat app as its transport.
