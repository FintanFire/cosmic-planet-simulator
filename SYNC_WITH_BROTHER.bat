@echo off
title Cosmic Planet Simulator - Brother Sync & Build
cd /d "%~dp0"
echo ========================================================
echo   COSMIC PLANET SIMULATOR - GIT SYNC ^& ROJO BUILD
echo ========================================================
echo.
echo [1/4] Pulling latest updates from GitHub...
git pull --rebase origin main
echo.
echo [2/4] Rebuilding CosmicPlanetSimulator.rbxl with Rojo ^& staging custom UI icons...
for /d %%D in ("%LOCALAPPDATA%\Roblox\Versions\*") do (
    if exist "%%D\RobloxStudioBeta.exe" (
        if not exist "%%D\content\cosmic_ui" mkdir "%%D\content\cosmic_ui"
        copy /Y "assets\ui\*.png" "%%D\content\cosmic_ui\" >nul 2>&1
    )
)
if exist "%USERPROFILE%\.rojo\rojo.exe" (
    "%USERPROFILE%\.rojo\rojo.exe" build "default.project.json" -o "CosmicPlanetSimulator.rbxl"
) else (
    rojo build "default.project.json" -o "CosmicPlanetSimulator.rbxl"
)
echo.
echo [3/4] Staging and committing any local changes...
git add -A
git diff --cached --quiet || git commit -m "Sync Cosmic Planet Simulator update"
echo.
echo [4/4] Pushing latest version to GitHub...
git push origin main
echo.
echo ========================================================
echo   DONE! You and your brother are 100%% in sync!
echo   Open CosmicPlanetSimulator.rbxl in Roblox Studio!
echo ========================================================
pause
