@echo off
cd /d "%~dp0"
title Auto Push Ritod Hub to GitHub
color 0A

echo ========================================================
echo          🚀 RITOD HUB - GITHUB AUTO PUSH 🚀
echo ========================================================
echo.

:: Pastikan remote origin sudah terpasang
git remote remove origin >nul 2>&1
git remote add origin https://github.com/RyuZeed/capybara.git

echo [1/3] Menyiapkan semua file script...
git add .

echo.
set msg=Update Ritod Hub Modular %date% %time%
echo [2/3] Membuat commit: "%msg%"...
git commit -m "%msg%"

echo.
echo [3/3] Menyelaraskan branch dan mengunggah ke GitHub...
git branch -M main
git pull --rebase origin main
git push -u origin main

echo.
if %errorlevel% equ 0 (
    echo ========================================================
    echo      SUKSES! Script terbaru aktif di GitHub!
    echo ========================================================
) else (
    echo ========================================================
    echo   Gagal mengunggah. Pastikan internet dan login aktif.
    echo ========================================================
)
echo.
pause
