use crate::traits::sync_traits::conflict_resolver::ConflictResolver;

pub struct DefaultResolver;

impl ConflictResolver for DefaultResolver {
    fn resolve(&self, local: &str, remote: &str) -> String {
        local.to_string()
    }
}
