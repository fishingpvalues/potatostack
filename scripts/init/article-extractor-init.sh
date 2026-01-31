#!/bin/sh
set -eu

BPC_URL="https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass-paywalls-chrome-clean-latest.crx&branch=main"
BPC_DIR="/app/bpc-extension"

echo "Installing system dependencies..."
apk add --no-cache chromium chromium-chromedriver unzip curl

echo "Installing Python dependencies..."
pip install --no-cache-dir selenium trafilatura

echo "Downloading Bypass Paywalls Clean extension..."
mkdir -p "$BPC_DIR"
curl -fsSL "$BPC_URL" -o /tmp/bpc.crx
# CRX files are zip with a header — unzip handles it
cd "$BPC_DIR" && unzip -o /tmp/bpc.crx && rm /tmp/bpc.crx
echo "BPC extension installed to $BPC_DIR"

echo "Starting article extractor server..."
exec python /app/article-extractor.py
