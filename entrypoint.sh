#!/usr/bin/env bash
set -euo pipefail

KATALOG_INPUT="${1:-}"
DO_INIT="${2:-false}"
PACK_NAME="${3:-beginner}"
EXAMPLE_SUBDIR="${4:-}"
ORK_VERSION="${5:-latest}"
OUTDIR="${6:-orkestra-artifacts}"
DO_KOMPOSE="${7:-false}"
DO_VALIDATE="${8:-false}"
DO_TEMPLATE="${9:-false}"
DO_RBAC="${10:-false}"
DO_CONFIGMAP="${11:-false}"
DO_BUNDLE="${12:-false}"
NAMESPACE="${13:-orkestra-system}"
DO_REGISTRY="${14:-false}"

# Set default namespace if not provided
TARGET_NAMESPACE="${NAMESPACE:-orkestra-system}"
echo "Using namespace: $TARGET_NAMESPACE"

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
# 2. Initialize operator (if requested)
# -------------------------------
KATALOG=""
CRD_PATH=""
CR_PATH=""
EXAMPLE_DIR=""
OPERATOR_ROOT=""
EXAMPLES_BASE=""
KATALOG_ABS=""

if [[ "$DO_INIT" == "true" ]]; then
    echo "==> Initializing operator: $OPERATOR_NAME with pack: $PACK_NAME"
    ork init "$OPERATOR_NAME" --pack "$PACK_NAME"

    OPERATOR_ROOT="$OPERATOR_NAME"
    EXAMPLES_BASE="$OPERATOR_NAME/examples/$PACK_NAME"

    if [[ -z "$EXAMPLE_SUBDIR" ]]; then
        echo "ERROR: example-subdir is required when init=true"
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

    # Convert to absolute path for later use
    if command -v realpath >/dev/null 2>&1; then
        KATALOG_ABS=$(realpath "$KATALOG")
    else
        KATALOG_ABS=$(cd "$(dirname "$KATALOG")" && pwd)/$(basename "$KATALOG")
    fi

    echo "init_dir=$OPERATOR_ROOT" >> "$GITHUB_OUTPUT"
    echo "operator_dir=$OPERATOR_ROOT" >> "$GITHUB_OUTPUT"
    echo "katalog_path=$KATALOG" >> "$GITHUB_OUTPUT"
    echo "katalog_abs=$KATALOG_ABS" >> "$GITHUB_OUTPUT"
    echo "crd_path=$CRD_PATH" >> "$GITHUB_OUTPUT"
    echo "cr_path=$CR_PATH" >> "$GITHUB_OUTPUT"
    echo "example_dir=$EXAMPLE_DIR" >> "$GITHUB_OUTPUT"

    echo "==> Operator initialized:"
    echo "    root:        $OPERATOR_ROOT"
    echo "    pack:        $PACK_NAME"
    echo "    example:     $EXAMPLE_SUBDIR"
    echo "    katalog:     $KATALOG"
    echo "    katalog_abs: $KATALOG_ABS"
else
    # No init – we must have a katalog file
    if [[ -n "$KATALOG_INPUT" ]]; then
        KATALOG="$KATALOG_INPUT"
    elif [[ -f "katalog.yaml" ]]; then
        KATALOG="katalog.yaml"
    elif [[ -f "komposer.yaml" ]]; then
        KATALOG="komposer.yaml"
    else
        echo "ERROR: No katalog file found and init=false. Please provide katalog input or set init=true."
        exit 1
    fi
    # Convert to absolute path
    if command -v realpath >/dev/null 2>&1; then
        KATALOG_ABS=$(realpath "$KATALOG")
    else
        KATALOG_ABS=$(cd "$(dirname "$KATALOG")" && pwd)/$(basename "$KATALOG")
    fi
    echo "katalog_path=$KATALOG" >> "$GITHUB_OUTPUT"
    echo "katalog_abs=$KATALOG_ABS" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 3. Prepare output directory
# -------------------------------
mkdir -p "$OUTDIR"

# -------------------------------
# 4. ork kompose (optional)
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
    # Update katalog_path output after kompose
    echo "katalog_path=$KATALOG" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 5. ork validate
# -------------------------------
if [[ "$DO_VALIDATE" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot validate without a katalog file."
        exit 1
    fi
    echo "==> Running: ork validate"
    set +e
    ork validate -k "$KATALOG" > "$OUTDIR/validate.log" 2>&1
    set -e
    echo "validate_log=$OUTDIR/validate.log" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 6. ork template
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
# 7. ork generate rbac
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
# 8. ork generate configmap
# -------------------------------
if [[ "$DO_CONFIGMAP" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot generate ConfigMap without a katalog file."
        exit 1
    fi
    echo "==> Running: ork generate configmap -k \"$KATALOG\" -o \"$OUTDIR/configmap.yaml\" -n \"$TARGET_NAMESPACE\""
    ork generate configmap -k "$KATALOG" -o "$OUTDIR/configmap.yaml" -n "$TARGET_NAMESPACE"
    echo "configmap_file=$OUTDIR/configmap.yaml" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 9. ork generate bundle
# -------------------------------
if [[ "$DO_BUNDLE" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot generate bundle without a katalog file."
        exit 1
    fi
    echo "==> Running: ork generate bundle -k \"$KATALOG\" -o \"$OUTDIR/bundle.yaml\" -n \"$TARGET_NAMESPACE\""
    ork generate bundle -k "$KATALOG" -o "$OUTDIR/bundle.yaml" -n "$TARGET_NAMESPACE"
    echo "bundle_file=$OUTDIR/bundle.yaml" >> "$GITHUB_OUTPUT"
    echo "namespace=$TARGET_NAMESPACE" >> "$GITHUB_OUTPUT"
fi

# -------------------------------
# 10. ork generate registry (typed mode)
# -------------------------------
if [[ "$DO_REGISTRY" == "true" ]]; then
    if [[ -z "$KATALOG" ]]; then
        echo "ERROR: Cannot generate registry without a katalog file."
        exit 1
    fi
    if [[ "$DO_INIT" != "true" ]]; then
        echo "ERROR: generate-registry requires init=true (operator must be generated)."
        exit 1
    fi
    # cd into the example directory where go.mod and katalog.yaml live
    if [[ ! -d "$EXAMPLE_DIR" ]]; then
        echo "ERROR: Example directory not found: $EXAMPLE_DIR"
        exit 1
    fi
    pushd "$EXAMPLE_DIR" > /dev/null
    echo "==> Running: go mod tidy"
    go mod tidy
    echo "==> Running: ork generate registry -k katalog.yaml"
    ork generate registry -k katalog.yaml
    # Locate the generated file (should be pkg/runtime/zz_generated_runtime_registry.go)
    REGISTRY_FILE=$(find . -name "zz_generated_runtime_registry.go" -type f | head -1)
    if [[ -z "$REGISTRY_FILE" ]]; then
        echo "ERROR: Could not find generated registry file."
        ls -la pkg/ 2>/dev/null || echo "pkg directory not found"
        exit 1
    fi
    REGISTRY_FILE_ABS=$(realpath "$REGISTRY_FILE")
    echo "registry_file=$REGISTRY_FILE_ABS" >> "$GITHUB_OUTPUT"
    echo "Generated registry: $REGISTRY_FILE_ABS"
    popd > /dev/null
fi

echo "==> Orkestra CI Action completed successfully"