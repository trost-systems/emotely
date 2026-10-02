/// The accounts the app stores' reviewers sign in with. Store review and
/// Google's pre-launch crawler cannot read a mailbox, so these two sign in
/// with a password instead of an emailed code (and never cost an email).
/// They exist only on the server, created by the release skill's
/// `reviewer-accounts.sh`; nothing in the app can create one.
const reviewAccounts = {
  'google-play-review@getemotely.com',
  'app-store-review@getemotely.com',
};

/// Whether [email] names a review account, however it was typed: surrounding
/// whitespace and letter case do not count, so the check cannot be sidestepped
/// into the code flow (which would cost an email) by a stray capital.
bool isReviewAccount(String email) =>
    reviewAccounts.contains(email.trim().toLowerCase());

/// The domain every internal address sits on.
const internalDomain = '@getemotely.com';

/// Whether [email] is one of the founder's own accounts, normalized the same
/// way as [isReviewAccount].
///
/// The rule is the domain, not a list: `getemotely.com` is a Google Workspace
/// alias domain only the founder controls, so every address on it is his —
/// his test alias, the two [reviewAccounts] (a subset of this, along with the
/// crawler that signs in as one of them), and any alias he adds later without
/// touching this code. Anyone who signs up with an address anywhere else is a
/// real user.
///
/// Ends-with, never contains: `x@getemotely.com.evil.org` is a different
/// domain and an ordinary user.
bool isInternalAccount(String email) =>
    email.trim().toLowerCase().endsWith(internalDomain);
