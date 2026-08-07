@echo off
title Auto Push Ritod Hub to GitHub
color 0A

echo ========================================================
echo          🚀 RITOD HUB - GITHUB AUTO PUSH 🚀
echo ========================================================
echo.
echo Menyiapkan file untuk diunggah ke GitHub...
git add .

set /p msg="Masukkan pesan update (tekan Enter untuk default): "
if "%msg%"=="" set msg=Update Ritod Hub Modular %date% %time%

echo.
echo Melakukan commit: "%msg%"...
git commit -m "%msg%"

echo.
echo Mengunggah ke https://github.com/RyuZeed/capybara...
git push origin main

echo.
if %errorlevel% equ 0 (
    echo ========================================================
    echo      🎉 SUKSES! Script terbaru aktif di GitHub!
    echo ========================================================
) else (
    echo ========================================================
    echo   ❌ Gagal mengunggah. Pastikan internet & login aktif.
    echo ========================================================
)
echo.
pause
