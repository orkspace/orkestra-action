#!/usr/bin/env bash
set -euo pipefail

KATALOG_INPUT="$1"
ORK_VERSION="$2"
OUTDIR="$3"
DO_KOMPOSE="$4"
DO_VALIDATE="$5"
DO_TEMPLATE="$6"
DO_RBAC="$7"
DO_CONFIGMAP="$8"
DO_BUNDLE="$9"
INIT_ARGS="${10}"
DO_RUN="${11:-false}"
RUN_TIMEOUT="${12:-30}"

echo "==> Orkestra CI Action starting"

# -------------------------------
# 0. Setup persistent cache directory
# -------------------------------
CACHE_DIR="${HOME}/.ork_cache"
mkdir -p "$CACHE_DIR"
export PATH="${CACHE_DIR}:$PATH"

# -------------------------------
# 1. Install Ork CLI (with caching)
# -------------------------------
install_ork() {
    local version="$1"
    echo "==> Installing Ork CLI version: ${version:-latest}"
    ORKESTRA_RELEASES="https://raw.githubusercontent.com/ialexeze/orkestra/main/install.sh"

    # Pass version (empty = latest) and custom install dir to install script
    curl -sSL "${ORKESTRA_RELEASES}" | ORK_VERSION="$version" ORK_INSTALL_DIR="$CACHE_DIR" bash
}

# Check if ork is already available and matches requested version
if command -v ork >/dev/null 2>&1; then
    INSTALLED_VERSION=$(ork version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
    REQ_VERSION="$ORK_VERSION"

    if [[ "$REQ_VERSION" == "latest" ]]; then
        # Always re‑install "latest" to ensure we have the most recent build
        install_ork ""
    elif [[ "$INSTALLED_VERSION" == "$REQ_VERSION" ]]; then
        echo "Ork CLI $INSTALLED_VERSION already installed in cache, skipping download."
    else
        echo "Found ork $INSTALLED_VERSION, but requested $REQ_VERSION. Reinstalling."
        install_ork "$REQ_VERSION"
    fi
else
    # No ork found, perform fresh install
    if [[ "$ORK_VERSION" == "latest" ]]; then
        install_ork ""
    else
        install_ork "$ORK_VERSION"
    fi
fi

echo "Using Ork version:"
ork version || true

# -------------------------------
# 2. Resolve katalog file
# -------------------------------
if [[ -n "$KATALOG_INPUT" ]]; then
    KATALOG="$KATALOG_INPUT"
elif [[ -f "katalog.yaml" ]]; then
    KATALOG="katalog.yaml"
elif [[ -f "komposer.yaml" ]]; then
    KATALOG="komposer.yaml"
else
    echo "ERROR: No katalog.yaml or komposer.yaml found, and no katalog input provided."
    exit 1
fi

echo "Using katalog: $KATALOG"

# -------------------------------
# 3. Prepare output directory
# -------------------------------
mkdir -p "$OUTDIR"

# -------------------------------
# 4. ork kompose (optional)
# -------------------------------
if [[ "$DO_KOMPOSE" == "true" ]]; then
    echo "==> Running: ork kompose"
    mkdir -p "$OUTDIR/komposed"
    ork kompose -k "$KATALOG" -o "$OUTDIR/komposed/katalog.yaml"
    KATALOG="$OUTDIR/komposed/katalog.yaml"
    echo "komposed_katalog=$KATALOG" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 5. Run ork init (optional)
# -------------------------------
if [[ -n "$INIT_ARGS" ]]; then
    echo "==> Running: ork init $INIT_ARGS"
    ork init $INIT_ARGS -o "$OUTDIR/init"
    echo "init_dir=$OUTDIR/init" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 6. ork validate
# -------------------------------
if [[ "$DO_VALIDATE" == "true" ]]; then
    echo "==> Running: ork validate"
    ork validate -k "$KATALOG" | tee "$OUTDIR/validate.log"
    echo "validate_log=$OUTDIR/validate.log" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 7. ork template
# -------------------------------
if [[ "$DO_TEMPLATE" == "true" ]]; then
    echo "==> Running: ork template"
    mkdir -p "$OUTDIR/template"
    ork template -k "$KATALOG" -o "$OUTDIR/template"
    echo "template_dir=$OUTDIR/template" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 8. ork generate rbac
# -------------------------------
if [[ "$DO_RBAC" == "true" ]]; then
    echo "==> Running: ork generate rbac"
    ork generate rbac -k "$KATALOG" -o "$OUTDIR/rbac.yaml"
    echo "rbac_file=$OUTDIR/rbac.yaml" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 9. ork generate configmap
# -------------------------------
if [[ "$DO_CONFIGMAP" == "true" ]]; then
    echo "==> Running: ork generate configmap"
    ork generate configmap -k "$KATALOG" -o "$OUTDIR/configmap.yaml"
    echo "configmap_file=$OUTDIR/configmap.yaml" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 10. ork generate bundle
# -------------------------------
if [[ "$DO_BUNDLE" == "true" ]]; then
    echo "==> Running: ork generate bundle"
    ork generate bundle -k "$KATALOG" -o "$OUTDIR/bundle.yaml"
    echo "bundle_file=$OUTDIR/bundle.yaml" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 11. ork run (optional)
# -------------------------------
if [[ "$DO_RUN" == "true" ]]; then
    echo "==> Running: ork run (timeout: ${RUN_TIMEOUT}s)"

    mkdir -p "$OUTDIR/run"
    RUN_LOG="$OUTDIR/run/ork-run.log"

    # Start ork run in background
    ork run -k "$KATALOG" > "$RUN_LOG" 2>&1 &
    RUN_PID=$!

    echo "run_pid=$RUN_PID" >> "$GITHUB_OUTPUT"
    echo "run_log=$RUN_LOG" >> "$GITHUB_OUTPUT"

    # Timeout loop
    SECONDS=0
    while kill -0 "$RUN_PID" 2>/dev/null; do
        if (( SECONDS >= RUN_TIMEOUT )); then
            echo "==> ork run timed out after ${RUN_TIMEOUT}s, stopping..."
            kill "$RUN_PID" || true
            break
        fi
        sleep 1
    done

    echo "==> ork run completed or stopped"
fi

echo "==> Orkestra CI Action completed successfully"