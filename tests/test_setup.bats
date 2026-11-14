#!/usr/bin/env bats

setup() {
  export SETUP_TEST_INSTALL_DIR="$BATS_TEST_TMPDIR/install directory/bin"
  export SETUP_TEST_PAYLOAD="$BATS_TEST_DIRNAME/../transcryptito"
  export SETUP_TEST_CURL_STATUS=0
  export SETUP_TEST_REAL_INSTALL=$(command -v install)
  export SETUP_TEST_REAL_MKDIR=$(command -v mkdir)
  export TMPDIR="$BATS_TEST_TMPDIR/downloads"
  mkdir -p "$TMPDIR" "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $SETUP_TEST_CURL_STATUS != 0 ]]; then
  exit "$SETUP_TEST_CURL_STATUS"
fi
while [[ $# -gt 0 ]]; do
  if [[ $1 == -o ]]; then
    cp "$SETUP_TEST_PAYLOAD" "$2"
    exit 0
  fi
  shift
done
exit 1
EOF
  cat > "$BATS_TEST_TMPDIR/bin/install" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $4 == /usr/local/bin/transcryptito ]]
"$SETUP_TEST_REAL_MKDIR" -p "$SETUP_TEST_INSTALL_DIR"
"$SETUP_TEST_REAL_INSTALL" -m 0755 "$3" "$SETUP_TEST_INSTALL_DIR/transcryptito"
EOF
  cat > "$BATS_TEST_TMPDIR/bin/mkdir" <<'EOF'
#!/usr/bin/env bash
if [[ $* != '-p /usr/local/bin' ]]; then
  exec "$SETUP_TEST_REAL_MKDIR" "$@"
fi
EOF
  cat > "$BATS_TEST_TMPDIR/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/"*
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "setup: downloads and installs the single executable command" {
  run bash "$BATS_TEST_DIRNAME/../setup"

  [ "$status" -eq 0 ]
  [ -x "$SETUP_TEST_INSTALL_DIR/transcryptito" ]
  cmp "$SETUP_TEST_PAYLOAD" "$SETUP_TEST_INSTALL_DIR/transcryptito"
  run "$SETUP_TEST_INSTALL_DIR/transcryptito" --version
  [ "$status" -eq 0 ]
  [[ "$output" = transcryptito\ * ]]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "setup: works when piped into bash" {
  run bash -c 'cat "$1" | bash' _ "$BATS_TEST_DIRNAME/../setup"

  [ "$status" -eq 0 ]
  [ -x "$SETUP_TEST_INSTALL_DIR/transcryptito" ]
}

@test "setup: replaces an existing installation" {
  mkdir -p "$SETUP_TEST_INSTALL_DIR"
  printf 'old version\n' > "$SETUP_TEST_INSTALL_DIR/transcryptito"

  run bash "$BATS_TEST_DIRNAME/../setup"

  [ "$status" -eq 0 ]
  cmp "$SETUP_TEST_PAYLOAD" "$SETUP_TEST_INSTALL_DIR/transcryptito"
}

@test "setup: failed download preserves an existing installation and cleans up" {
  mkdir -p "$SETUP_TEST_INSTALL_DIR"
  printf 'old version\n' > "$SETUP_TEST_INSTALL_DIR/transcryptito"
  export SETUP_TEST_CURL_STATUS=22

  run bash "$BATS_TEST_DIRNAME/../setup"

  [ "$status" -ne 0 ]
  [[ "$output" = *'Download failed'* ]]
  [ "$(cat "$SETUP_TEST_INSTALL_DIR/transcryptito")" = 'old version' ]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "setup: rejects an empty download" {
  export SETUP_TEST_PAYLOAD="$BATS_TEST_TMPDIR/empty"
  touch "$SETUP_TEST_PAYLOAD"

  run bash "$BATS_TEST_DIRNAME/../setup"

  [ "$status" -ne 0 ]
  [[ "$output" = *'Downloaded script is empty'* ]]
  [ ! -e "$SETUP_TEST_INSTALL_DIR/transcryptito" ]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "setup: rejects invalid shell syntax" {
  export SETUP_TEST_PAYLOAD="$BATS_TEST_TMPDIR/invalid"
  printf 'if\n' > "$SETUP_TEST_PAYLOAD"

  run bash "$BATS_TEST_DIRNAME/../setup"

  [ "$status" -ne 0 ]
  [[ "$output" = *'Downloaded script is invalid'* ]]
  [ ! -e "$SETUP_TEST_INSTALL_DIR/transcryptito" ]
  [ -z "$(ls -A "$TMPDIR")" ]
}
