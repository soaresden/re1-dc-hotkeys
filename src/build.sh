#!/bin/bash
# Kept for habit: the build is src/build.py (Windows and Linux).
cd "$(dirname "$0")/.." && exec python3 src/build.py "$@"
