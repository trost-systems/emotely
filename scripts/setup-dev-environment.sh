#!/usr/bin/env bash
# Set up a fresh Linux machine (a cloud agent container, a VM, a CI runner) so
# that every job in .github/workflows/ci.yml can be run locally: the agent
# (TypeScript), the app (Flutter), the web landing page (Dart/Jaspr) and the
# Supabase schema suite.
#
#   scripts/setup-dev-environment.sh [--verify] [--help]
#
# Runs as root on x86_64 Debian/Ubuntu and installs into a system prefix, which
# is what a container is. It is not a dotfiles-friendly installer for a personal
# laptop: under sudo it would leave root-owned build output in your checkout.
#
# Idempotent: re-running it is cheap, it re-downloads nothing that is already
# installed at the pinned version. Every step fails loudly — the script aborts
# on the first error and says which line died.
#
# Every version comes from the repository, never from this file:
#   Node          .nvmrc
#   pnpm          package.json  "packageManager"
#   Flutter       apps/mobile/app/.fvmrc
#   Dart          apps/web/scripts/vercel-install.sh  (checksum-pinned there)
#   Supabase CLI  .github/workflows/ci.yml  (supabase/setup-cli "version:")
#   jaspr_cli     .github/workflows/ci.yml, cross-checked against Vercel's
#   melos         .github/workflows/ci.yml  (the app job's activate line)
#   very_good_cli .github/workflows/ci.yml  (the app job's activate line)
# Bumping a pin means editing the file that owns it, and this script follows. A
# tool pinned in two files must agree in both, or the script refuses to run:
# Dart and jaspr_cli are each pinned twice, and a drift there would mean CI and
# production build the site with different SDKs.
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
# Everything this script installs lives under one prefix, so uninstalling is
# `rm -rf` of a single directory.
readonly PREFIX="${EMOTELY_TOOLCHAIN_PREFIX:-/opt/emotely-toolchain}"
readonly ENV_FILE="$PREFIX/env.sh"
# Sorted last on purpose: /etc/profile sources profile.d/*.sh in order, and the
# images this runs on ship nodejs.sh, nvm.sh and friends that prepend their own
# Node to PATH. Sorting before them means a login shell silently gets the wrong
# Node — the repo needs the one in .nvmrc.
readonly PROFILE_D="/etc/profile.d/99-emotely-toolchain.sh"
# pub's cache belongs to the toolchain, not to whichever account ran the script.
# In root's home, `jaspr` and `very_good` would be on PATH for root alone while
# $HOME/.pub-cache/bin in a system-wide profile.d resolves per user.
readonly PUB_CACHE_DIR="$PREFIX/pub-cache"
export PUB_CACHE="$PUB_CACHE_DIR"

VERIFY=0
SKIPPED=()

# --- output ------------------------------------------------------------------

if [ -t 1 ]; then
  readonly C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_OFF=$'\033[0m'
else
  readonly C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_OFF=''
fi

step() { printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_OFF"; }
info() { printf '    %s\n' "$*"; }
skip() { printf '    %s%s%s\n' "$C_DIM" "$*" "$C_OFF"; }
ok()   { printf '    %s✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
warn() { printf '    %s!%s %s\n' "$C_RED" "$C_OFF" "$*"; }

die() {
  printf '\n%s%sSETUP FAILED:%s %s\n' "$C_BOLD" "$C_RED" "$C_OFF" "$*" >&2
  printf '  The environment is NOT ready.\n' >&2
  exit 1
}

on_err() {
  local exit_code=$? line=$1 command=$2
  printf '\n%s%sSETUP FAILED%s at %s:%s (exit %s)\n' \
    "$C_BOLD" "$C_RED" "$C_OFF" "${BASH_SOURCE[0]}" "$line" "$exit_code" >&2
  printf '  command: %s\n' "$command" >&2
  printf '  The environment is NOT ready. Fix the error above and re-run.\n' >&2
  exit "$exit_code"
}
trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR

usage() {
  cat <<'USAGE'
Set up a fresh Linux machine so every job in .github/workflows/ci.yml can be
run locally: the agent (TypeScript), the app (Flutter), the web landing page
(Dart/Jaspr) and the Supabase schema suite.

  scripts/setup-dev-environment.sh [--verify] [--help]

Wants root on x86_64 Debian/Ubuntu, and Docker already installed (it starts the
daemon, it does not install Engine). Idempotent, and aborts on the first failed
step. Every version comes from the repository, never from the script:

  Node          .nvmrc
  pnpm          package.json  "packageManager"
  Flutter       apps/mobile/app/.fvmrc
  Dart          apps/web/scripts/vercel-install.sh  (checksum-pinned there)
  Supabase CLI  .github/workflows/ci.yml
  jaspr_cli     .github/workflows/ci.yml, cross-checked against Vercel's
  melos         .github/workflows/ci.yml
  very_good_cli .github/workflows/ci.yml

Options:
  --verify   After installing, run every CI job that needs no secret, and
             report which ones ran.
  --help     Show this message.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --verify) VERIFY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

# --- helpers -----------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

# Read a pin out of a repository file. Reads the file itself rather than taking
# it on stdin, so a missing file and an unparseable one are different messages
# and neither trips the ERR trap on the way (a process substitution that fails
# fires it too, and one cause printing three banners is worse than none).
pin() {
  local description=$1 file=$2 sed_expression=$3 value
  [ -r "$file" ] || die "$description is pinned in $file, which does not exist or cannot be read"
  value=$(sed -n "$sed_expression" "$file" | head -1)
  [ -n "$value" ] || die "could not read the $description pin from $file — has its format changed?"
  printf '%s' "$value"
}

# Pins are interpolated into URLs and compared against installed versions, so a
# value that is not a plain release number has to be rejected here rather than
# blamed on the network three lines later. `.nvmrc` and `.fvmrc` both accept
# channel names and `v`-prefixes that the tools they feed understand and this
# script does not.
require_release_number() {
  local description=$1 file=$2 value=$3
  case "$value" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) die "$description in $file is '$value'; this script needs an exact release number (e.g. 3.13.3), not a channel or a v-prefix" ;;
  esac
}

# Read a JSON value without interpolating anything into the JavaScript: the path
# and the key arrive as argv, so a checkout under a path containing a quote, or
# a pin containing one, is data rather than code.
json_value() {
  node -e '
    const [file, key] = process.argv.slice(1);
    const value = JSON.parse(require("fs").readFileSync(file, "utf8"))[key];
    process.stdout.write(value == null ? "" : String(value));
  ' "$1" "$2"
}

fetch() {
  local url=$1 destination=$2
  # --connect-timeout bounds only the handshake; without the speed guard a
  # proxy that accepts the connection and then stalls hangs the script forever.
  # --retry-all-errors because the proxy failure mode here is a 403/407, which
  # plain --retry does not consider retryable.
  curl --fail --silent --show-error --location \
    --retry 3 --retry-delay 2 --retry-all-errors \
    --connect-timeout 20 --max-time 1800 --speed-limit 1024 --speed-time 60 \
    --output "$destination" "$url" \
    || die "download failed: $url"
}

# Check against a sha256 the upstream project publishes, fetched at run time, so
# bumping a pin never means hand-copying a digest. Note what this is and is not:
# it catches a truncated or corrupted transfer and a mismatched pin. It is not
# provenance — the digest travels the same channel as the artifact. Only Dart's
# is genuinely independent, pinned in the repo by apps/web/scripts/vercel-install.sh.
fetch_verified() {
  local url=$1 destination=$2 expected_sha=$3
  fetch "$url" "$destination"
  printf '%s  %s\n' "$expected_sha" "$destination" | sha256sum --check --status \
    || die "checksum mismatch for $url — refusing to install it"
}

# tar run as root restores the uid/gid recorded in the archive. Upstream
# tarballs are built under ordinary accounts, so without this a system prefix
# ends up full of files owned by whatever uid happens to exist locally — and
# anyone holding it can rewrite a binary this script later runs as root.
extract() {
  local archive=$1 destination=$2
  shift 2
  tar --extract --file "$archive" --directory "$destination" \
    --no-same-owner --no-same-permissions "$@"
}

# `git config --add` appends every time; adding the same path on each run grows
# the global config without bound.
mark_git_safe() {
  local directory=$1
  git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$directory" \
    || git config --global --add safe.directory "$directory"
}

# A pub global shim records the SDK that resolved it ("created by pub vX.Y.Z").
# Presence alone is not enough: an activation made by the other Dart SDK on this
# machine loads a snapshot the running one may refuse.
activated_by() {
  local executable=$1
  [ -r "$PUB_CACHE_DIR/bin/$executable" ] || return 0
  # The line ends "pub v3.13.3." — the trailing period is not part of the version.
  sed -n 's/.*created by pub v\([0-9.]*[0-9]\).*/\1/p' "$PUB_CACHE_DIR/bin/$executable" | head -1
}

# --- 0. host packages --------------------------------------------------------

step "Host packages"

[ "$(uname -s)" = "Linux" ] || die "this script targets Linux; on macOS use Homebrew (see the skills in .claude/skills)"
# Every archive below is an x86_64 build, and Flutter publishes no Linux arm64
# release at all. Say so here rather than let a checksum pass and the binary
# fail later with "cannot execute binary file".
[ "$(uname -m)" = "x86_64" ] || die "only x86_64 is supported; this machine is $(uname -m)"
[ "$(id -u)" = "0" ] || die "run as root: the toolchain installs into $PREFIX"

missing=()
for command_name in curl git tar unzip xz sha256sum; do
  have "$command_name" || missing+=("$command_name")
done
if [ ${#missing[@]} -gt 0 ]; then
  have apt-get || die "missing ${missing[*]}, and no apt-get to install them; this script assumes Debian/Ubuntu"
  info "installing: ${missing[*]}"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq curl ca-certificates git tar unzip xz-utils coreutils
else
  skip "curl, git, tar, unzip, xz, sha256sum already present"
fi

mkdir -p "$PREFIX" "$PUB_CACHE_DIR"

# Flutter, its artifacts, Dart, Node and the Supabase images together want
# roughly 10 GB. Half an install is worse than none. The scratch directory lives
# under the prefix so this measures the filesystem the archives actually land
# on — a tmpfs /tmp would make a check against /opt meaningless.
available_kb=$(df -Pk "$PREFIX" | awk 'NR == 2 { print $4 }')
[ "${available_kb:-0}" -ge 10485760 ] \
  || die "need ~10 GB free on $PREFIX, have $((available_kb / 1024)) MB"

WORK_DIR="$(mktemp -d "$PREFIX/.setup-XXXXXX")"
readonly WORK_DIR
trap 'rm -rf "$WORK_DIR"' EXIT

# --- 1. Node -----------------------------------------------------------------

step "Node"

NODE_VERSION=$(pin "Node" "$REPO_ROOT/.nvmrc" 's/^[[:space:]]*v\{0,1\}\([^[:space:]]*\).*/\1/p')
readonly NODE_VERSION
require_release_number "the Node version" "$REPO_ROOT/.nvmrc" "$NODE_VERSION"
readonly NODE_DIR="$PREFIX/node"

if [ -x "$NODE_DIR/bin/node" ] && [ "$("$NODE_DIR/bin/node" --version)" = "v$NODE_VERSION" ]; then
  skip "Node v$NODE_VERSION already installed"
else
  info "installing Node v$NODE_VERSION (.nvmrc)"
  node_archive="node-v$NODE_VERSION-linux-x64.tar.xz"
  fetch "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt" "$WORK_DIR/node-shasums.txt"
  node_sha=$(awk -v file="$node_archive" '$2 == file { print $1 }' "$WORK_DIR/node-shasums.txt")
  [ -n "$node_sha" ] || die "Node v$NODE_VERSION has no linux-x64 build published"
  fetch_verified "https://nodejs.org/dist/v$NODE_VERSION/$node_archive" "$WORK_DIR/$node_archive" "$node_sha"
  rm -rf "$NODE_DIR"
  mkdir -p "$NODE_DIR"
  extract "$WORK_DIR/$node_archive" "$NODE_DIR" --xz --strip-components=1
fi
export PATH="$NODE_DIR/bin:$PATH"
# Assign before reporting: the exit status of a command substitution inside an
# argument list is discarded, so `ok "$(node --version)"` would print a cheerful
# tick for a binary that cannot run at all.
node_version_output=$(node --version)
ok "$node_version_output"

# --- 2. pnpm -----------------------------------------------------------------

step "pnpm"

PNPM_SPEC=$(json_value "$REPO_ROOT/package.json" packageManager)
[ -n "$PNPM_SPEC" ] || die "package.json has no packageManager field"
# corepack writes an integrity hash into the spec (pnpm@1.2.3+sha512.abc...);
# the installed version never carries one, so compare only the version part.
readonly PNPM_SPEC="${PNPM_SPEC%%+*}"

if have pnpm && [ "$(command -v pnpm)" = "$NODE_DIR/bin/pnpm" ] && [ "pnpm@$(pnpm --version)" = "$PNPM_SPEC" ]; then
  skip "$PNPM_SPEC already activated"
elif have corepack; then
  info "activating $PNPM_SPEC via corepack"
  corepack enable --install-directory "$NODE_DIR/bin"
  corepack prepare "$PNPM_SPEC" --activate
else
  # Node stopped shipping corepack in 25.0.0, so a future .nvmrc bump lands
  # here. CI would not notice — its agent job gets pnpm from pnpm/action-setup.
  info "no corepack in Node v$NODE_VERSION; installing $PNPM_SPEC with npm"
  npm install --global --silent "$PNPM_SPEC"
fi
pnpm_version_output=$(pnpm --version)
ok "pnpm $pnpm_version_output"

# --- 3. Dart -----------------------------------------------------------------
# The landing page builds on Vercel with a checksum-pinned SDK; that script is
# the pin, and CI must agree with it.

step "Dart SDK"

readonly VERCEL_INSTALL="$REPO_ROOT/apps/web/scripts/vercel-install.sh"
readonly CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

DART_VERSION=$(pin "Dart version" "$VERCEL_INSTALL" 's/^DART_VERSION="\([^"]*\)".*/\1/p')
DART_SHA256=$(pin "Dart checksum" "$VERCEL_INSTALL" 's/^DART_SHA256="\([^"]*\)".*/\1/p')
readonly DART_VERSION DART_SHA256
require_release_number "the Dart version" "$VERCEL_INSTALL" "$DART_VERSION"

ci_dart_version=$(pin "CI Dart version" "$CI_WORKFLOW" 's/^ *sdk: *"\{0,1\}\([0-9][0-9.]*\)"\{0,1\}.*/\1/p')
[ "$ci_dart_version" = "$DART_VERSION" ] \
  || die "the Dart pins disagree: $VERCEL_INSTALL says $DART_VERSION, $CI_WORKFLOW says $ci_dart_version"

readonly DART_DIR="$PREFIX/dart-sdk"
if [ -x "$DART_DIR/bin/dart" ] && "$DART_DIR/bin/dart" --version 2>&1 | grep -q "version: $DART_VERSION "; then
  skip "Dart $DART_VERSION already installed"
else
  info "installing Dart $DART_VERSION"
  dart_zip="dartsdk-linux-x64-release.zip"
  fetch_verified \
    "https://storage.googleapis.com/dart-archive/channels/stable/release/$DART_VERSION/sdk/$dart_zip" \
    "$WORK_DIR/$dart_zip" "$DART_SHA256"
  rm -rf "$DART_DIR" "$WORK_DIR/dart-unpack"
  unzip -q "$WORK_DIR/$dart_zip" -d "$WORK_DIR/dart-unpack"
  mv "$WORK_DIR/dart-unpack/dart-sdk" "$DART_DIR"
fi

# --- 4. Flutter --------------------------------------------------------------

step "Flutter SDK"

FLUTTER_VERSION=$(json_value "$REPO_ROOT/apps/mobile/app/.fvmrc" flutter)
readonly FLUTTER_VERSION
[ -n "$FLUTTER_VERSION" ] || die "apps/mobile/app/.fvmrc has no flutter version"
require_release_number "the Flutter version" "$REPO_ROOT/apps/mobile/app/.fvmrc" "$FLUTTER_VERSION"
readonly FLUTTER_DIR="$PREFIX/flutter"

# Flutter runs `git` against its own checkout — for `flutter --version`, and
# here to tell which release is unpacked. Git refuses on a tree it considers
# foreign unless it is marked safe, so do that before asking.
mark_git_safe "$FLUTTER_DIR"
# Same for the checkout itself: two --verify steps below are `git diff`, and as
# root over a checkout owned by someone else git refuses them with an exit code
# that is neither pass nor fail.
mark_git_safe "$REPO_ROOT"

if [ -x "$FLUTTER_DIR/bin/flutter" ] \
   && [ "$(git -C "$FLUTTER_DIR" describe --tags 2>/dev/null || true)" = "$FLUTTER_VERSION" ]; then
  skip "Flutter $FLUTTER_VERSION already installed"
else
  info "installing Flutter $FLUTTER_VERSION (apps/mobile/app/.fvmrc)"
  fetch "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json" \
    "$WORK_DIR/flutter-releases.json"
  # The release index carries the archive path and its sha256 per version.
  flutter_release=$(node -e '
    const [file, version] = process.argv.slice(1);
    const index = JSON.parse(require("fs").readFileSync(file, "utf8"));
    const release = index.releases.find(r => r.version === version && r.channel === "stable");
    process.stdout.write(release ? release.archive + " " + release.sha256 : "");
  ' "$WORK_DIR/flutter-releases.json" "$FLUTTER_VERSION")
  [ -n "$flutter_release" ] || die "Flutter $FLUTTER_VERSION is not in the Linux stable release index"
  fetch_verified \
    "https://storage.googleapis.com/flutter_infra_release/releases/${flutter_release%% *}" \
    "$WORK_DIR/flutter.tar.xz" "${flutter_release##* }"
  rm -rf "$FLUTTER_DIR"
  mkdir -p "$FLUTTER_DIR"
  extract "$WORK_DIR/flutter.tar.xz" "$FLUTTER_DIR" --xz --strip-components=1
fi

# Order matters and is asserted rather than assumed: Flutter's bin holds a
# `dart` of its own (its bundled SDK, a different patch release), so the
# standalone SDK goes on last and wins. apps/web is pinned to that one.
export PATH="$FLUTTER_DIR/bin:$PATH"
export PATH="$DART_DIR/bin:$PATH"
dart_version_output=$(dart --version 2>&1)
case "$dart_version_output" in
  *"version: $DART_VERSION"*) ;;
  *) die "'dart' on PATH is not the pinned standalone SDK: $dart_version_output" ;;
esac

# No telemetry from an agent container, and no animations in a log.
flutter --disable-analytics >/dev/null
flutter config --no-cli-animations >/dev/null
dart --disable-analytics >/dev/null

# First run unpacks the bundled Dart and the tool's own snapshot; do it now so
# the first `flutter test` is not a surprise download.
info "warming the Flutter tool (first run unpacks its artifacts)"
flutter precache --universal >/dev/null
ok "Flutter $FLUTTER_VERSION"
ok "Dart ${dart_version_output#Dart SDK version: }"

# `dart` on PATH is the standalone SDK, which cannot resolve `sdk: flutter`
# packages. Inside apps/mobile/app, use this wrapper wherever CI says `dart`.
install -d "$PREFIX/bin"
cat > "$PREFIX/bin/flutter-dart" <<WRAPPER
#!/usr/bin/env sh
# Flutter's bundled Dart — the one that can resolve \`sdk: flutter\` packages.
# Use it for apps/mobile/app (\`flutter-dart run build_runner build --only-check\`);
# plain \`dart\` is the standalone SDK the landing page is pinned to.
#
# It also puts Flutter's bin first on PATH for everything it starts, so a tool
# that shells out to \`dart\` (very_good_cli does, to run its hooks) stays on one
# SDK for the whole run. A kernel snapshot only loads into the SDK that compiled
# it; mixing the two mid-process gives "Invalid SDK hash".
PATH="$FLUTTER_DIR/bin:\$PATH"
export PATH
exec "$FLUTTER_DIR/bin/dart" "\$@"
WRAPPER
chmod +x "$PREFIX/bin/flutter-dart"
export PATH="$PREFIX/bin:$PATH"

# --- 5. Supabase CLI ---------------------------------------------------------

step "Supabase CLI"

# The workflow pins the CLI in more than one job. Take the pin only if every one
# of them is the same exact release: picking the first of several, or silently
# accepting a `version: latest` the regex cannot see, would be a choice this
# script has no business making.
supabase_pin_lines=$(grep -c 'supabase/setup-cli' "$CI_WORKFLOW" || true)
supabase_pins=$(sed -n '/supabase\/setup-cli/,/^$/ s/^ *version: *"\{0,1\}\([^"[:space:]]*\)"\{0,1\}.*/\1/p' "$CI_WORKFLOW" | sort -u)
supabase_pin_count=$(printf '%s' "$supabase_pins" | grep -c '^' || true)
[ "$supabase_pin_count" -eq 1 ] \
  || die "$CI_WORKFLOW has $supabase_pin_lines supabase/setup-cli steps but $supabase_pin_count distinct versions: $(printf '%s' "$supabase_pins" | tr '\n' ' ')"
readonly SUPABASE_VERSION="$supabase_pins"
require_release_number "the Supabase CLI version" "$CI_WORKFLOW" "$SUPABASE_VERSION"

if [ -x "$PREFIX/bin/supabase" ] && [ "$("$PREFIX/bin/supabase" --version 2>/dev/null)" = "$SUPABASE_VERSION" ]; then
  skip "Supabase CLI $SUPABASE_VERSION already installed"
else
  info "installing Supabase CLI $SUPABASE_VERSION (.github/workflows/ci.yml)"
  supabase_archive="supabase_${SUPABASE_VERSION}_linux_amd64.tar.gz"
  supabase_base="https://github.com/supabase/cli/releases/download/v$SUPABASE_VERSION"
  fetch "$supabase_base/checksums.txt" "$WORK_DIR/supabase-checksums.txt"
  supabase_sha=$(awk -v file="$supabase_archive" '$2 == file { print $1 }' "$WORK_DIR/supabase-checksums.txt")
  [ -n "$supabase_sha" ] || die "Supabase CLI $SUPABASE_VERSION publishes no linux_amd64 tarball"
  fetch_verified "$supabase_base/$supabase_archive" "$WORK_DIR/$supabase_archive" "$supabase_sha"
  extract "$WORK_DIR/$supabase_archive" "$PREFIX/bin" --gzip supabase
fi
supabase_version_output=$(supabase --version)
ok "Supabase CLI $supabase_version_output"

# Nothing under the prefix should be writable by a non-root account: these
# binaries run as root on the next `sudo` invocation of this script.
chown -R root:root "$PREFIX"

# --- 6. Chromium -------------------------------------------------------------
# `dart test -p chrome test/client` (apps/web) needs a browser. Agent
# containers usually ship the Playwright one; otherwise install Chromium.

step "Chromium"

chrome_binary=""
# `-x` alone is true for a directory, and the Playwright layout has a `chromium`
# directory in some images and a symlink to the binary in others — require a file.
for candidate in "${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}/chromium" \
                 "${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"/chromium-*/chrome-linux/chrome \
                 /usr/bin/chromium /usr/bin/chromium-browser /usr/bin/google-chrome; do
  if [ -f "$candidate" ] && [ -x "$candidate" ]; then chrome_binary="$candidate"; break; fi
done

if [ -z "$chrome_binary" ]; then
  have apt-get || die "no Chromium found and no apt-get to install one; apps/web's browser tests need a browser"
  info "no browser found; installing Chromium from apt"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq chromium || apt-get install -y -qq chromium-browser
  for candidate in /usr/bin/chromium /usr/bin/chromium-browser; do
    if [ -f "$candidate" ] && [ -x "$candidate" ]; then chrome_binary="$candidate"; break; fi
  done
  [ -n "$chrome_binary" ] || die "could not install a Chromium for the apps/web browser tests"
fi

# The test runner launches the browser as whoever runs it; as root Chromium
# refuses to start its sandbox, so point CHROME_EXECUTABLE at a wrapper that
# adds the flag rather than at the binary.
cat > "$PREFIX/bin/emotely-chrome" <<WRAPPER
#!/usr/bin/env sh
# Chromium for \`dart test -p chrome\`. --no-sandbox because these containers
# run as root, where Chromium's own sandbox cannot start.
exec "$chrome_binary" --no-sandbox --disable-dev-shm-usage "\$@"
WRAPPER
chmod +x "$PREFIX/bin/emotely-chrome"
export CHROME_EXECUTABLE="$PREFIX/bin/emotely-chrome"

# Being on disk is not the same as being able to start — a snap shim, or a
# Chromium missing a shared library, passes every check above and then fails
# inside `dart test -p chrome`, long after setup said it was fine.
"$PREFIX/bin/emotely-chrome" --headless=new --dump-dom about:blank >/dev/null 2>&1 \
  || die "$chrome_binary is installed but will not start; apps/web's browser tests need a working Chromium"
ok "$chrome_binary"

# --- 7. The shell environment ------------------------------------------------

step "Shell environment"

cat > "$ENV_FILE" <<ENV
# Written by scripts/setup-dev-environment.sh — do not edit by hand.
# The emotely toolchain: Node, pnpm, the standalone Dart SDK (the landing
# page's pin), Flutter, the Supabase CLI and a Chromium for the browser tests.
#
# Drop our entries before prepending them, so sourcing this twice does not stack
# PATH, and so it still wins when something sourced later (another profile.d
# entry, a version manager) has prepended its own Node in between.
emotely_path=\$(printf '%s' "\$PATH" | tr ':' '\n' | grep -vxF -e "$PREFIX/bin" -e "$NODE_DIR/bin" -e "$DART_DIR/bin" -e "$FLUTTER_DIR/bin" -e "$PUB_CACHE_DIR/bin" | paste -sd: -)
PATH="$PREFIX/bin:$NODE_DIR/bin:$DART_DIR/bin:$FLUTTER_DIR/bin:$PUB_CACHE_DIR/bin:\$emotely_path"
unset emotely_path
export PATH
export CHROME_EXECUTABLE="$PREFIX/bin/emotely-chrome"
export PUB_CACHE="$PUB_CACHE_DIR"
ENV

# An older run may have installed this under a name that sorts too early.
rm -f /etc/profile.d/emotely-toolchain.sh
ln -sf "$ENV_FILE" "$PROFILE_D"

# Login shells read profile.d; interactive non-login shells (what an agent
# usually gets) read .bashrc, so source it from there too, exactly once.
bashrc="$HOME/.bashrc"
marker="# emotely toolchain"
if ! grep -qF "$marker" "$bashrc" 2>/dev/null; then
  printf '\n%s\n. %s\n' "$marker" "$ENV_FILE" >> "$bashrc"
fi
# shellcheck source=/dev/null
. "$ENV_FILE"
ok "$ENV_FILE (sourced from $PROFILE_D and ~/.bashrc)"

# --- 8. Docker ---------------------------------------------------------------
# The Supabase stack (`supabase db start`, `supabase test db`) is containers.
# Everything else works without it, so nothing here is fatal: aborting would
# leave the machine less usable than if Docker were simply absent.

step "Docker"

docker_ready=0
if ! have docker; then
  warn "Docker is not installed — the Supabase schema suite cannot run."
  info "Install Docker Engine: https://docs.docker.com/engine/install/"
elif docker info >/dev/null 2>&1; then
  skip "daemon already running"
  docker_version_output=$(docker --version)
  ok "$docker_version_output"
  docker_ready=1
else
  info "starting dockerd"
  # The packaged init script sets ulimits the container may not allow, so run
  # the daemon directly and wait for the socket.
  mkdir -p /var/log
  (nohup dockerd >/var/log/dockerd.log 2>&1 &)
  for _ in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
  if docker info >/dev/null 2>&1; then
    docker_version_output=$(docker --version)
    ok "$docker_version_output"
    docker_ready=1
  else
    warn "dockerd did not come up (see /var/log/dockerd.log) — the Supabase suite cannot run."
    info "Rootless Docker, a stale DOCKER_HOST or a nested container all land here."
  fi
fi
[ "$docker_ready" -eq 1 ] || SKIPPED+=("supabase (no usable Docker)")

# --- 9. Workspace dependencies -----------------------------------------------

step "Workspace dependencies"

info "pnpm install (root tools incl. ast-grep, agent, contract)"
(cd "$REPO_ROOT" && pnpm install --frozen-lockfile)

# A pub workspace: one resolution for the app and every package in it.
info "apps/mobile: flutter pub get"
(cd "$REPO_ROOT/apps/mobile" && flutter pub get)

info "apps/web: dart pub get"
(cd "$REPO_ROOT/apps/web" && dart pub get)

# apps/agent/src/cli.ts and apps/agent/evals/harness.ts both read this file at
# startup. Leave a commented, value-free template so the names are discoverable;
# it is gitignored, and filling it in is a human's job.
readonly AGENT_ENV_FILE="$REPO_ROOT/apps/agent/.env.local"
if [ -e "$AGENT_ENV_FILE" ]; then
  skip "apps/agent/.env.local already exists — left untouched"
else
  info "writing an empty apps/agent/.env.local template"
  cat > "$AGENT_ENV_FILE" <<'AGENT_ENV'
# Read by `pnpm --filter @emotely/agent session` and by the evals. Gitignored.
# Values are secrets: fill them in yourself, never through an agent transcript.
AI_GATEWAY_API_KEY=
# Only for scripts/live-smoke.ts and the on-device acceptance session:
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
SMOKE_EMAIL=
SMOKE_PASSWORD=
AGENT_ENV
fi

# jaspr_cli is pinned twice: CI, and the Vercel install script that builds
# production. A drift there would have the site built with a different version
# than anything ever tested, so require both to agree.
JASPR_CLI_VERSION=$(pin "jaspr_cli" "$CI_WORKFLOW" 's/.*dart pub global activate jaspr_cli \([0-9][0-9.]*\).*/\1/p')
readonly JASPR_CLI_VERSION
vercel_jaspr_version=$(pin "Vercel jaspr_cli" "$VERCEL_INSTALL" 's/.*dart pub global activate jaspr_cli \([0-9][0-9.]*\).*/\1/p')
[ "$vercel_jaspr_version" = "$JASPR_CLI_VERSION" ] \
  || die "the jaspr_cli pins disagree: $CI_WORKFLOW says $JASPR_CLI_VERSION, $VERCEL_INSTALL says $vercel_jaspr_version"

# Both CLIs are re-activated whenever the SDK that resolved them is not the one
# that will run them: pub records the resolving SDK in the shim, and a snapshot
# only loads into the SDK that made it.
if [ "$(activated_by jaspr)" = "$DART_VERSION" ] \
   && dart pub global list 2>/dev/null | grep -q "^jaspr_cli $JASPR_CLI_VERSION\b"; then
  skip "jaspr_cli $JASPR_CLI_VERSION already activated"
else
  info "dart pub global activate jaspr_cli $JASPR_CLI_VERSION"
  dart pub global activate jaspr_cli "$JASPR_CLI_VERSION" >/dev/null
fi

# melos runs the workspace's gates and very_good_cli its coverage gate, both
# against apps/mobile, so they belong to Flutter's bundled SDK. CI pins both
# (the app job's activate lines); take the same pins.
flutter_dart_version=$(flutter-dart --version 2>&1 | sed -n 's/.*version: \([0-9][0-9.]*\).*/\1/p')
for tool in melos very_good_cli; do
  tool_version=$(pin "$tool" "$CI_WORKFLOW" "s/.*dart pub global activate $tool \([0-9][0-9.]*\).*/\1/p")
  require_release_number "the $tool version" "$CI_WORKFLOW" "$tool_version"
  # The shim is named after the executable, which for very_good_cli is very_good.
  executable=${tool%_cli}
  if [ "$(activated_by "$executable")" = "$flutter_dart_version" ] \
     && flutter-dart pub global list 2>/dev/null | grep -q "^$tool $tool_version\b"; then
    skip "$tool $tool_version already activated against Flutter's Dart $flutter_dart_version"
  else
    info "dart pub global activate $tool $tool_version (Flutter's Dart $flutter_dart_version)"
    flutter-dart pub global activate "$tool" "$tool_version" >/dev/null
  fi
done
chown -R root:root "$PUB_CACHE_DIR"
ok "dependencies resolved"

# --- 10. Verification --------------------------------------------------------

step "Installed"

printf '    %-14s %s\n' "node"     "$node_version_output"
printf '    %-14s %s\n' "pnpm"     "$pnpm_version_output"
printf '    %-14s %s\n' "dart"     "$DART_VERSION"
printf '    %-14s %s\n' "flutter"  "$FLUTTER_VERSION (bundled Dart $flutter_dart_version)"
printf '    %-14s %s\n' "supabase" "$supabase_version_output"
printf '    %-14s %s\n' "chromium" "$chrome_binary"
printf '    %-14s %s\n' "docker"   "${docker_version_output:-not available}"

if [ "$VERIFY" -eq 1 ]; then
  step "Verifying (the CI jobs, minus the ones that need a secret)"

  info "tripwire: no workaround comments, no suppression without a reason"
  (cd "$REPO_ROOT" && pnpm tripwire)

  info "agent: lint, typecheck, tests, contract tripwire"
  (cd "$REPO_ROOT" && pnpm lint && pnpm typecheck && pnpm -r --if-present test)
  (cd "$REPO_ROOT" && pnpm --filter @emotely/contract schema \
    && git diff --exit-code packages/contract/contract.schema.json)
  SKIPPED+=("agent eval (needs AI_GATEWAY_API_KEY)")

  # The same melos scripts CI runs, per package. Through flutter-dart so that
  # every `dart` the scripts start is Flutter's, not the landing page's pin.
  info "app: codegen check, format, analyze, tests — every package in apps/mobile"
  (cd "$REPO_ROOT/apps/mobile" && flutter-dart pub global run melos:melos run ci)

  info "web: format, analyze, tests (VM + Chrome), build"
  (cd "$REPO_ROOT/apps/web" \
    && dart format --set-exit-if-changed . \
    && dart analyze --fatal-infos \
    && dart test \
    && dart test -p chrome test/client \
    && jaspr build --sitemap-domain https://getemotely.com \
    && git diff --exit-code -- lib)

  if [ "$docker_ready" -eq 1 ]; then
    info "supabase: migrations + pgTAP row-level-security suite"
    # CI gets a fresh Postgres every run, so its `db start` always replays the
    # migrations. Here the container usually already exists and `db start` is a
    # no-op against it, which would test a new migration against the old schema
    # and pass. `db reset` is what replays them, as the supabase skill says.
    (cd "$REPO_ROOT" && supabase db start && supabase db reset --local \
      && supabase test db --local && supabase db lint --local --fail-on warning)
    info "the database container is left running; 'supabase stop' shuts it down"
  else
    info "supabase: SKIPPED — no usable Docker, so the schema suite did not run"
  fi

  if [ ${#SKIPPED[@]} -gt 0 ]; then
    ok "every check that could run passed"
    for skipped in "${SKIPPED[@]}"; do
      info "  not run: $skipped"
    done
  else
    ok "every check passed"
  fi
fi

printf '\n%s%sEnvironment ready.%s Open a new shell, or: . %s\n' \
  "$C_BOLD" "$C_GREEN" "$C_OFF" "$ENV_FILE"

cat <<'NOTES'

What this does NOT set up, on purpose:

  · Secrets. apps/agent/.env.local is where AI_GATEWAY_API_KEY goes, for
    `pnpm --filter @emotely/agent session` and for the evals; a template is
    written for you, empty. A human fills it in. Note that every model round
    asks the gateway for Zero Data Retention, which is Pro-only -- a key on a
    Hobby team fails every round, and that is billing, not a broken machine.
  · Entire. Its hooks in .claude/settings.json no-op while the CLI is absent,
    so commits made here carry no Entire-Checkpoint trailer. Installing it
    means running `entire enable`, which writes git hooks and pushes to a
    private checkpoint repo: the maintainer's call, see docs/tooling/entire.md.
  · fvm. The run-app skill drives apps/mobile/app through `fvm flutter` / `fvm dart`;
    here the pinned SDK is on PATH directly, as `flutter` and `flutter-dart`.
  · The GitHub CLI. `main` is protected and merges go through PRs; the release
    and supabase skills shell out to `gh`. Install and authenticate it yourself
    if you need those.
  · Anything that runs the app on a device. No Android SDK, no JDK, no
    emulator, no Xcode: `flutter run`, `flutter build`, integration_test and
    the android half of app-release.yml are all out of reach on this machine.
    apps/mobile's unit and widget tests do run, package by package.
NOTES
