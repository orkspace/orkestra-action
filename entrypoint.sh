#!/usr/bin/env bash
set -euo pipefail

KATALOG_INPUT="$1"
PACK_NAME="$2"
EXAMPLE_SUBDIR="$3"
ORK_VERSION="$4"
OUTDIR="$5"
DO_KOMPOSE="$6"
DO_VALIDATE="$7"
DO_TEMPLATE="$8"
DO_RBAC="$9"
DO_CONFIGMAP="${10}"
DO_BUNDLE="${11}"

OPERATOR_NAME="orkestra-operator"

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
    curl -sSL "${ORKESTRA_RELEASES}" | ORK_VERSION="$version" ORK_INSTALL_DIR="$CACHE_DIR" bash
}

if command -v ork >/dev/null 2>&1; then
    INSTALLED_VERSION=$(ork version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
    REQ_VERSION="$ORK_VERSION"
    if [[ "$REQ_VERSION" == "latest" ]]; then
        install_ork ""
    elif [[ "$INSTALLED_VERSION" == "$REQ_VERSION" ]]; then
        echo "Ork CLI $INSTALLED_VERSION already installed in cache, skipping download."
    else
        echo "Found ork $INSTALLED_VERSION, but requested $REQ_VERSION. Reinstalling."
        install_ork "$REQ_VERSION"
    fi
else
    if [[ "$ORK_VERSION" == "latest" ]]; then
        install_ork ""
    else
        install_ork "$ORK_VERSION"
    fi
fi

echo "Using Ork version:"
ork version || true

# -------------------------------
# 2. Determine katalog file (may be created via init)
# -------------------------------
KATALOG=""
NEEDS_INIT=false

if [[ -n "$KATALOG_INPUT" ]]; then
    KATALOG="$KATALOG_INPUT"
elif [[ -f "katalog.yaml" ]]; then
    KATALOG="katalog.yaml"
elif [[ -f "komposer.yaml" ]]; then
    KATALOG="komposer.yaml"
else
    NEEDS_INIT=true
fi

# -------------------------------
# 3. Initialize operator if needed
# -------------------------------
CRD_PATH=""
CR_PATH=""
EXAMPLE_DIR=""
OPERATOR_ROOT=""
EXAMPLES_BASE=""

if [[ "$NEEDS_INIT" == "true" ]]; then
    echo "==> Initializing operator: $OPERATOR_NAME with pack: $PACK_NAME"
    ork init "$OPERATOR_NAME" --pack "$PACK_NAME"

    OPERATOR_ROOT="$OPERATOR_NAME"
    EXAMPLES_BASE="$OPERATOR_NAME/examples/$PACK_NAME"

    if [[ -z "$EXAMPLE_SUBDIR" ]]; then
        echo "ERROR: example-subdir is required when initializing a new operator"
        exit 1
    fi

    EXAMPLE_DIR="$EXAMPLES_BASE/$EXAMPLE_SUBDIR"
    if [[ ! -d "$EXAMPLE_DIR" ]]; then
        echo "ERROR: Example directory not found: $EXAMPLE_DIR"
        echo "Available examples:"
        ls -1 "$EXAMPLES_BASE" || true
        exit 1
    fi

    KATALOG="$EXAMPLE_DIR/katalog.yaml"
    CRD_PATH="$EXAMPLE_DIR/crd.yaml"
    CR_PATH="$EXAMPLE_DIR/cr.yaml"

    if [[ ! -f "$KATALOG" ]]; then
        echo "ERROR: katalog.yaml not found in $EXAMPLE_DIR"
        exit 1
    fi

    echo "init_dir=$OPERATOR_ROOT" >> "$GITHUB_OUTPUT"
    echo "operator_dir=$OPERATOR_ROOT" >> "$GITHUB_OUTPUT"
    echo "katalog_path=$KATALOG" >> "$GITHUB_OUTPUT"
    echo "crd_path=$CRD_PATH" >> "$GITHUB_OUTPUT"
    echo "cr_path=$CR_PATH" >> "$GITHUB_OUTPUT"
    echo "example_dir=$EXAMPLE_DIR" >> "$GITHUB_OUTPUT"

    echo "==> Operator initialized:"
    echo "    root:        $OPERATOR_ROOT"
    echo "    pack:        $PACK_NAME"
    echo "    example:     $EXAMPLE_SUBDIR"
    echo "    katalog:     $KATALOG"
else
    # If katalog provided without init, we still need to output katalog_path
    echo "katalog_path=$KATALOG" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 4. Prepare output directory
# -------------------------------
mkdir -p "$OUTDIR"

# -------------------------------
# 5. ork kompose (optional)
# -------------------------------
if [[ "$DO_KOMPOSE" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot run kompose without a katalog file."
        exit 1
    fi
    echo "==> Running: ork kompose"
    mkdir -p "$OUTDIR/komposed"
    ork kompose -k "$KATALOG" -o "$OUTDIR/komposed/katalog.yaml"
    KATALOG="$OUTDIR/komposed/katalog.yaml"
    echo "komposed_katalog=$KATALOG" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 6. ork validate
# -------------------------------
if [[ "$DO_VALIDATE" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot validate without a katalog file."
        exit 1
    fi
    echo "==> Running: ork validate"
    ork validate -k "$KATALOG" | tee "$OUTDIR/validate.log"
    echo "validate_log=$OUTDIR/validate.log" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 7. ork template
# -------------------------------
if [[ "$DO_TEMPLATE" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot template without a katalog file."
        exit 1
    fi
    echo "==> Running: ork template"
    mkdir -p "$OUTDIR/template"
    ork template -k "$KATALOG" -o "$OUTDIR/template"
    echo "template_dir=$OUTDIR/template" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 8. ork generate rbac
# -------------------------------
if [[ "$DO_RBAC" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot generate RBAC without a katalog file."
        exit 1
    fi
    echo "==> Running: ork generate rbac"
    ork generate rbac -k "$KATALOG" -o "$OUTDIR/rbac.yaml"
    echo "rbac_file=$OUTDIR/rbac.yaml" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 9. ork generate configmap
# -------------------------------
if [[ "$DO_CONFIGMAP" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot generate ConfigMap without a katalog file."
        exit 1
    fi
    echo "==> Running: ork generate configmap"
    ork generate configmap -k "$KATALOG" -o "$OUTDIR/configmap.yaml"
    echo "configmap_file=$OUTDIR/configmap.yaml" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 10. ork generate bundle
# -------------------------------
if [[ "$DO_BUNDLE" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot generate bundle without a katalog file."
        exit 1
    fi
    echo "==> Running: ork generate bundle"
    ork generate bundle -k "$KATALOG" -o "$OUTDIR/bundle.yaml"
    echo "bundle_file=$OUTDIR/bundle.yaml" >> "$GITHUB_OUTPUT"
fi

echo "==> Orkestra CI Action completed successfully"