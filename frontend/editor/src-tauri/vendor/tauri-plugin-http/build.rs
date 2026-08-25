// Copyright 2019-2023 Tauri Programme within The Commons Conservancy
// SPDX-License-Identifier: Apache-2.0
// SPDX-License-Identifier: MIT

#[path = "src/scope.rs"]
#[allow(dead_code)]
mod scope;

const COMMANDS: &[&str] = &[
    "fetch",
    "fetch_cancel",
    "fetch_send",
    "fetch_read_body",
    "fetch_cancel_body",
];

#[derive(schemars::JsonSchema)]
#[serde(untagged)]
#[allow(unused)]
enum HttpScopeEntry {
    Value(String),
    Object { url: String },
}

fn _f() {
    match scope::EntryRaw::Value(String::new()) {
        scope::EntryRaw::Value(url) => HttpScopeEntry::Value(url),
        scope::EntryRaw::Object { url } => HttpScopeEntry::Object { url },
    };
    match HttpScopeEntry::Value(String::new()) {
        HttpScopeEntry::Value(url) => scope::EntryRaw::Value(url),
        HttpScopeEntry::Object { url } => scope::EntryRaw::Object { url },
    };
}

fn main() {
    tauri_plugin::Builder::new(COMMANDS)
        .global_api_script_path("./api-iife.js")
        .global_scope_schema(schemars::schema_for!(HttpScopeEntry))
        .build();
}
