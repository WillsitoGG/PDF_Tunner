use std::{
    path::{Path, PathBuf},
    sync::Arc,
};
use tauri::{Manager, Runtime};

pub use upstream_store::{Builder, Error, JsonValue, Result, Store, StoreBuilder};

fn portable_store_path(path: impl AsRef<Path>) -> PathBuf {
    let path = path.as_ref();
    if path.is_absolute() {
        return path.to_path_buf();
    }

    match std::env::var_os("PDF_TUNNER_PORTABLE_ROOT") {
        Some(root) => PathBuf::from(root)
            .join("data")
            .join("tauri")
            .join("store")
            .join(path),
        None => path.to_path_buf(),
    }
}

pub trait StoreExt<R: Runtime> {
    fn store(&self, path: impl AsRef<Path>) -> Result<Arc<Store<R>>>;
    fn store_builder(&self, path: impl AsRef<Path>) -> StoreBuilder<R>;
    fn get_store(&self, path: impl AsRef<Path>) -> Option<Arc<Store<R>>>;
}

impl<R: Runtime, T: Manager<R>> StoreExt<R> for T {
    fn store(&self, path: impl AsRef<Path>) -> Result<Arc<Store<R>>> {
        upstream_store::StoreExt::store(self, portable_store_path(path))
    }

    fn store_builder(&self, path: impl AsRef<Path>) -> StoreBuilder<R> {
        upstream_store::StoreExt::store_builder(self, portable_store_path(path))
    }

    fn get_store(&self, path: impl AsRef<Path>) -> Option<Arc<Store<R>>> {
        upstream_store::StoreExt::get_store(self, portable_store_path(path))
    }
}
