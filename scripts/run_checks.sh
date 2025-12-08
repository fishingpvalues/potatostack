#!/bin/bash
#
# This script runs all the pre-commit checks on all files.
# It is a convenience script to ensure that the code is clean
# before pushing to the repository.

set -euo pipefail

echo "Running all pre-commit checks..."
pre-commit run --all-files
