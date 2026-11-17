# Запуск: .\push_to_github.ps1 https://github.com/USER/aura_player.git
param([string]$RepoUrl)
if (-not $RepoUrl) { Write-Host "Usage: .\push_to_github.ps1 https://github.com/USER/aura_player.git"; exit 1 }
git init -b main 2>$null; git branch -M main
git add .
try { git commit -m "feat: AURA Player 2.0 ready to build" } catch {}
git remote remove origin 2>$null
git remote add origin $RepoUrl
git push -u origin main
Write-Host "Done! Check Actions"
