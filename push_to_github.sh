#!/bin/bash
# Запуск: ./push_to_github.sh https://github.com/USER/aura_player.git
set -e
REPO_URL=$1
if [ -z "$REPO_URL" ]; then
  echo "Usage: ./push_to_github.sh https://github.com/USER/aura_player.git"
  exit 1
fi
git init -b main 2>/dev/null || git branch -M main
git add .
git commit -m "feat: AURA Player 2.0 ready to build" 2>/dev/null || echo "Already committed"
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL"
git push -u origin main
echo "Done! Check https://github.com/USER/aura_player/actions"
