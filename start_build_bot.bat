@echo off
title uz_ai_dev - Telegram Build Bot
cd /d "%~dp0"

REM Bot yiqilib qolsa avtomatik qayta ishga tushadi
:loop
echo [%date% %time%] Bot ishga tushmoqda...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0telegram_build_bot.ps1"
echo [%date% %time%] Bot to'xtadi. 5 soniyada qayta urinaman... (yopish uchun oynani yoping)
timeout /t 5 /nobreak >nul
goto loop
