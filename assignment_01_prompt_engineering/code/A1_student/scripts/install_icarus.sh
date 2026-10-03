#!/usr/bin/env bash
# Install Icarus Verilog in the current user's home directory.
# This script intentionally does not require or use sudo.

set -euo pipefail

readonly ICARUS_TAG="v13_0"
readonly ICARUS_PREFIX="$HOME/.local/opt/iverilog-v13.0"
readonly PATH_LINE='export PATH="$HOME/.local/opt/iverilog-v13.0/bin:$PATH"'

required_tools=(git gcc g++ make autoconf bison flex gperf)
missing_tools=()
for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing_tools+=("$tool")
    fi
done

if ((${#missing_tools[@]} > 0)); then
    printf 'Cannot build Icarus Verilog: missing required tools: %s\n' \
        "${missing_tools[*]}" >&2
    printf 'Ask the teaching staff to provide these tools; do not use sudo.\n' >&2
    exit 1
fi

if [[ -x "$ICARUS_PREFIX/bin/iverilog" && -x "$ICARUS_PREFIX/bin/vvp" ]]; then
    printf 'Reusing existing Icarus Verilog installation: %s\n' "$ICARUS_PREFIX"
else
    build_dir="$(mktemp -d -t iverilog-build.XXXXXX)"
    cleanup() {
        rm -rf -- "$build_dir"
    }
    trap cleanup EXIT

    printf 'Building Icarus Verilog %s under %s\n' "$ICARUS_TAG" "$ICARUS_PREFIX"
    git clone --depth 1 --branch "$ICARUS_TAG" \
        https://github.com/steveicarus/iverilog.git "$build_dir/iverilog"

    cd "$build_dir/iverilog"
    sh autoconf.sh
    ./configure --prefix="$ICARUS_PREFIX"
    make -j2
    make install
fi

# Add the PATH line to the profiles for both common shells so future terminals
# (bash on Linux/WSL, zsh on macOS) pick up the install.
add_path_line() {
    local profile="$1"
    if ! grep -Fqx "$PATH_LINE" "$profile" 2>/dev/null; then
        {
            printf '\n# User-local Icarus Verilog\n'
            printf '%s\n' "$PATH_LINE"
        } >> "$profile"
    fi
}
updated_profiles=()
for profile in "$HOME/.bashrc" "$HOME/.zshrc"; do
    # Update a profile if it already exists, or create the one for the current shell.
    if [[ -f "$profile" ]] || [[ "$SHELL" == *"${profile##*/.}"* ]]; then
        add_path_line "$profile"
        updated_profiles+=("$profile")
    fi
done

export PATH="$ICARUS_PREFIX/bin:$PATH"

printf 'Icarus Verilog is ready.\n'
printf 'Current-shell PATH: %s\n' "$ICARUS_PREFIX/bin"
printf 'Future sessions load this path from: %s\n' "${updated_profiles[*]:-$HOME/.bashrc}"
iverilog -V 2>&1 | sed -n '1p'
vvp -V 2>&1 | sed -n '1p'
