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
DO_REGISTRY="${14:-false}"      # generate registry

# Orkestra registry arguments
REGISTRY_SERVER="${15:-ghcr.io}"
REGISTRY_USERNAME="${16:-}"
REGISTRY_PASSWORD="${17:-}"
REGISTRY_COMMAND="${18:-}"
REGISTRY_REF="${19:-}"
PATTERN_DIR="${20:-}"

# Set default namespace if not provided
TARGET_NAMESPACE="${NAMESPACE:-orkestra-system}"

OPERATOR_NAME="orkestra-operator"

echo "==> Orkestra CI Action starting"

# ────────────────────────────────────────────────────────────────────────────
# 0. Persistent cache
#
# $GITHUB_WORKSPACE is bind-mounted into every Docker action container in the
# same job, so files written here survive across consecutive steps.
# $HOME is container-local and resets on every step — do NOT use it for cache.
# ────────────────────────────────────────────────────────────────────────────
CACHE_DIR="${GITHUB_WORKSPACE:-/github/workspace}/.ork_cache"
mkdir -p "$CACHE_DIR"
export PATH="${CACHE_DIR}:$PATH"

# ────────────────────────────────────────────────────────────────────────────
# 1. Install Ork CLI (cached by resolved version)
#
# "latest" is resolved to a concrete tag before the cache check so that two
# consecutive steps requesting "latest" both hit the same cached binary.
# ────────────────────────────────────────────────────────────────────────────
INSTALL_SH="https://raw.githubusercontent.com/orkspace/orkestra/main/install.sh"

resolve_ork_version() {
    curl -sSf "https://api.github.com/repos/orkspace/orkestra/releases/latest" \
        | grep '"tag_name"' \
        | sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
}

RESOLVED_VERSION="$ORK_VERSION"
if [[ "$ORK_VERSION" == "latest" || -z "$ORK_VERSION" ]]; then
    echo "==> Resolving latest ork version..."
    RESOLVED_VERSION=$(resolve_ork_version)
    echo "    → $RESOLVED_VERSION"
fi

CACHED_VERSION=""
if [[ -x "${CACHE_DIR}/ork" ]]; then
    CACHED_VERSION=$("${CACHE_DIR}/ork" version 2>/dev/null \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
fi

if [[ -n "$CACHED_VERSION" && "$CACHED_VERSION" == "$RESOLVED_VERSION" ]]; then
    echo "==> ork ${RESOLVED_VERSION} already cached — skipping download"
else
    echo "==> Installing ork ${RESOLVED_VERSION}..."
    curl -sSL "$INSTALL_SH" \
        | ORK_VERSION="$RESOLVED_VERSION" \
          ORK_INSTALL_DIR="$CACHE_DIR" \
          ORK_SKIP_CC=true \
          ORK_SKIP_COMPLETION=true \
          bash
fi

echo "==> Using ork version:"
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
    echo "Using namespace: $TARGET_NAMESPACE"
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
    echo "Using namespace: $TARGET_NAMESPACE"
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
    echo "Using namespace: $TARGET_NAMESPACE"
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

# -------------------------------
# 11. Registry operations (optional)
# -------------------------------
if [[ -n "$REGISTRY_COMMAND" ]]; then
    # Login if credentials provided
    if [[ -n "$REGISTRY_USERNAME" && -n "$REGISTRY_PASSWORD" ]]; then
        if echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY_SERVER" -u "$REGISTRY_USERNAME" --password-stdin >/dev/null 2>&1; then
            echo "✅ Logged in to $REGISTRY_SERVER"
        else
            echo "❌ Failed to log in to $REGISTRY_SERVER"
            exit 1
        fi
    fi

    case "$REGISTRY_COMMAND" in
        push)
            PATTERN_DIR="${PATTERN_DIR:-.}"
            if [[ -z "$REGISTRY_REF" ]]; then
                echo "ERROR: registry push requires registry-ref"
                exit 1
            fi
            if [[ ! -d "$PATTERN_DIR" ]]; then
                echo "ERROR: Pattern directory not found: $PATTERN_DIR"
                exit 1
            fi
            # Change to pattern directory before push
            pushd "$PATTERN_DIR" > /dev/null
            echo "==> Pushing pattern $REGISTRY_REF from $(pwd)"
            if ork registry push "$REGISTRY_REF" .; then
                popd > /dev/null
                {
                    echo "## ✅ Pattern published successfully"
                    echo '```'
                    ork registry info "$REGISTRY_REF"
                    echo '```'
                } >> "$GITHUB_STEP_SUMMARY"
            else
                popd > /dev/null
                exit 1
            fi
            ;;
        pull)
            if [[ -z "$REGISTRY_REF" ]]; then
                echo "ERROR: registry pull requires registry-ref"
                exit 1
            fi

            # Construct patternpath for output
            PATTERN_NAME=$(basename "$REGISTRY_REF" | cut -d ':' -f 1)
            WORKSPACE_OUTPUT="${GITHUB_WORKSPACE}/pulled-${PATTERN_NAME}"

            mkdir -p "$WORKSPACE_OUTPUT"
            echo "==> Pulling pattern $REGISTRY_REF to $WORKSPACE_OUTPUT"
            if ork registry pull "$REGISTRY_REF" --out "$WORKSPACE_OUTPUT"; then
                echo "pattern_path=$WORKSPACE_OUTPUT" >> "$GITHUB_OUTPUT"
                {
                    echo "## 📥 Pattern pulled: $REGISTRY_REF"
                    echo "**Extracted to:** \`$WORKSPACE_OUTPUT\`"
                    echo
                    echo '```'
                    ls -la "$WORKSPACE_OUTPUT"
                    echo '```'
                } >> "$GITHUB_STEP_SUMMARY"
            else
                {
                    echo "## ❌ Failed to pull pattern: $REGISTRY_REF"
                } >> "$GITHUB_STEP_SUMMARY"
                exit 1
            fi
            ;;
        info)
            if [[ -z "$REGISTRY_REF" ]]; then
                echo "ERROR: registry info requires registry-ref"
                exit 1
            fi
            echo "==> Getting info for $REGISTRY_REF"
            ork registry info "$REGISTRY_REF"
            ;;
        list)
            echo "==> Listing patterns in $REGISTRY_SERVER"
            ork registry list "$REGISTRY_SERVER"
            ;;
        *)
            echo "ERROR: unknown registry-command '$REGISTRY_COMMAND'"
            exit 1
            ;;
    esac
fi

echo "==> Orkestra CI Action completed successfully"
