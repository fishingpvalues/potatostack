#!/bin/bash
set -euo pipefail

echo "Installing dependencies..."
pip install --no-cache-dir trafilatura newspaper3k lxml_html_clean

echo "Starting article extractor server..."
exec python /app/article-extractor.py
