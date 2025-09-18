#!/usr/bin/env bash
set -euo pipefail

SRC="/home/usereyebottle/projects/eyebottlelee/"
DEST="/mnt/c/ws-workspace/eyebottlelee/"

rsync -a --delete \
  --exclude '.git/' \
  --exclude 'build/' \
  --exclude '.dart_tool/' \
  --exclude '.claude/' \
  --exclude 'windows/flutter/ephemeral/' \
  "$SRC" "$DEST"
