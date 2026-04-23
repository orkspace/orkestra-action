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


ORKESTRA_RELEASES="https://raw.githubusercontent.com/iAlexeze/orkestra/refs/heads/main/install.sh"

echo "==> Orkestra CI Action starting"

# -------------------------------
# 1. Resolve katalog file
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
# 2. Install Ork CLI version
# -------------------------------
echo "==> Installing Ork CLI version: $ORK_VERSION"
curl -sSL "${ORKESTRA_RELEASES}" | ORK_VERSION="$ORK_VERSION" bash

chmod +x /usr/local/bin/ork

echo "Installed Ork version:"
ork version || true

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
    echo "::set-output name=komposed_katalog::$KATALOG"
fi

# -------------------------------
# 5. Run ork init (optional)
# -------------------------------
if [[ -n "$INIT_ARGS" ]]; then
    echo "==> Running: ork init $INIT_ARGS"
    ork init $INIT_ARGS -o "$OUTDIR/init"
    echo "::set-output name=init_dir::$OUTDIR/init"
fi

# -------------------------------
# 6. ork validate
# -------------------------------
if [[ "$DO_VALIDATE" == "true" ]]; then
    echo "==> Running: ork validate"
    ork validate -k "$KATALOG" | tee "$OUTDIR/validate.log"
    echo "::set-output name=validate_log::$OUTDIR/validate.log"
fi

# -------------------------------
# 7. ork template
# -------------------------------
if [[ "$DO_TEMPLATE" == "true" ]]; then
    echo "==> Running: ork template"
    mkdir -p "$OUTDIR/template"
    ork template -k "$KATALOG" -o "$OUTDIR/template"
    echo "::set-output name=template_dir::$OUTDIR/template"
fi

# -------------------------------
# 8. ork generate rbac
# -------------------------------
if [[ "$DO_RBAC" == "true" ]]; then
    echo "==> Running: ork generate rbac"
    ork generate rbac -k "$KATALOG" -o "$OUTDIR/rbac.yaml"
    echo "::set-output name=rbac_file::$OUTDIR/rbac.yaml"
fi

# -------------------------------
# 9. ork generate configmap
# -------------------------------
if [[ "$DO_CONFIGMAP" == "true" ]]; then
    echo "==> Running: ork generate configmap"
    ork generate configmap -k "$KATALOG" -o "$OUTDIR/configmap.yaml"
    echo "::set-output name=configmap_file::$OUTDIR/configmap.yaml"
fi

# -------------------------------
# 10. ork generate bundle
# -------------------------------
if [[ "$DO_BUNDLE" == "true" ]]; then
    echo "==> Running: ork generate bundle"
    ork generate bundle -k "$KATALOG" -o "$OUTDIR/bundle.yaml"
    echo "::set-output name=bundle_file::$OUTDIR/bundle.yaml"
fi

echo "==> Orkestra CI Action completed successfully"
