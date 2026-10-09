#!/bin/sh
set -e
cd "$(dirname "$0")"
python3 make_icon.py
node render.js .