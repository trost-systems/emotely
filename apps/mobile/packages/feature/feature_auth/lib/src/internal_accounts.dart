/// The domain every internal address sits on.
const internalDomain = '@getemotely.com';

/// Whether [email] is one of the founder's own accounts, however it was
/// typed: surrounding whitespace and letter case do not count.
///
/// The rule is the domain, not a list: `getemotely.com` is a Google Workspace
/// alias domain only the founder controls, so every address on it is his —
/// his test alias, the stores' two review accounts (along with the crawler
/// that signs in as one of them), and any alias he adds later without
/// touching this code. Anyone who signs up with an address anywhere else is a
/// real user.
///
/// Ends-with, never contains: `x@getemotely.com.evil.org` is a different
/// domain and an ordinary user.
bool isInternalAccount(String email) =>
    email.trim().toLowerCase().endsWith(internalDomain);
