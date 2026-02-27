#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/opt/AverroesTeam"
BACKEND_DIR="$REPO_DIR/apps/backend"
SERVICE_NAME="averroes-backend"

echo "[deploy] updating repository in $REPO_DIR"
cd "$REPO_DIR"
git fetch origin main
git reset --hard origin/main

echo "[deploy] installing backend dependencies"
cd "$BACKEND_DIR"
source .venv/bin/activate
pip install -r requirements.txt

echo "[deploy] syncing migration state"
flask --app run.py db stamp head

echo "[deploy] restarting services"
sudo systemctl restart "$SERVICE_NAME"
sudo systemctl restart nginx

echo "[deploy] done"
