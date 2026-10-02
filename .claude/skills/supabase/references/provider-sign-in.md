# Google and Apple sign-in (native ID tokens)

The app signs in with Google (iOS, Android) and Apple (iOS only) by handing
the platform's ID token to `signInWithIdToken`; there is no browser
redirect, no callback URL and **no provider secret** anywhere (the ID-token
grant never reads one, and the CLI exempts both providers from requiring
it). `[auth.external.google]` and `[auth.external.apple]` in `config.toml`
carry only public client ids, so they apply locally and on the hosted
project alike.

- **Google** clients live in the Google Cloud project `emotely-sign-in`
  (Google Auth Platform, owned by the maintainer's personal Google account,
  publishing status *In production*, basic scopes only so no verification).
  `client_id` lists the web client first (Android's Credential Manager
  issues tokens for it; the app passes it as `serverClientId`), then the iOS
  client (the audience of iOS tokens). The two Android clients (Play App Signing SHA-1, and the
  maintainer's local debug key) are not audiences; they only let Google
  recognize the calling app. A new signing key (Play key upgrade, a CI debug
  keystore) needs its own Android client there, or Google sign-in fails on
  that build with a `canceled` error the plugin cannot tell apart from the
  user dismissing the sheet.
- **Apple** needs only the bundle id `de.emotely.emotely` as `client_id`.
  The App ID has the Sign in with Apple capability and the match profile
  carries `com.apple.developer.applesignin`; no Services ID, no key.
- **Nonce**: the app sends SHA-256(nonce) to the provider and the raw nonce
  to Auth, so `skip_nonce_check` stays `false`.
- **Identity linking** is automatic: a Google or Apple sign-in whose
  verified email matches an existing account lands in that same
  `auth.users` row. Apple's private relay addresses never match, so such a
  user gets a separate account.
- **Deploys** push these blocks like any other auth setting, and the
  deploy's second push (`Config converged`) proves the comma-separated
  `client_id` list round-trips through the Management API.
