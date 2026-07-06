@echo off
setlocal enabledelayedexpansion
title uz_ai_dev - Windows Auto Builder

REM ============================================================
REM   Avtomatik Windows release builder.
REM   Ikki marta bosib ishga tushiring - qolganini o'zi qiladi.
REM
REM   ESLATMA (tekshirilgan ishlaydigan ketma-ketlik):
REM     1) Loyiha ASCII papkaga (C:\uzbuild) ko'chiriladi, chunki
REM        Cyrillic user-papka (Administrator) path da release build buziladi.
REM     2) flutter pub get + flutter build windows --release.
REM     3) Release bundle zip qilinib, shu papkaga qo'yiladi.
REM ============================================================

REM --- Manba papka (oxiridagi backslash olib tashlanadi, robocopy uchun) ---
set "SRC=%~dp0"
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"

set "DEST=C:\uzbuild"

echo.
echo ============================================================
echo   uz_ai_dev  -  Windows Auto Builder
echo ============================================================
echo   Manba : %SRC%
echo   Build : %DEST%
echo ============================================================
echo.

REM --- Versiyani pubspec.yaml dan o'qish (version: 0.4.9+49) ---
set "VERSION="
for /f "tokens=2 delims= " %%a in ('findstr /b "version:" "%SRC%\pubspec.yaml"') do set "VERFULL=%%a"
for /f "tokens=1 delims=+" %%b in ("%VERFULL%") do set "VERSION=%%b"
if "%VERSION%"=="" set "VERSION=dev"
echo   Versiya : %VERSION%
echo.

REM --- flutter borligini tekshirish ---
where flutter >nul 2>nul
if errorlevel 1 (
    echo [XATO] 'flutter' PATH da topilmadi. Flutter SDK ni PATH ga qo'shing.
    goto :fail
)

REM --- 0/4: git pull (oxirgi o'zgarishlarni olish; xato bo'lsa davom etadi) ---
where git >nul 2>nul
if errorlevel 1 (
    echo [OGOHLANTIRISH] 'git' topilmadi - pull o'tkazib yuborildi.
) else (
    echo [0/4] git pull...
    pushd "%SRC%"
    git pull
    if errorlevel 1 (
        echo [OGOHLANTIRISH] git pull muvaffaqiyatsiz ^(lokal o'zgarishlar bo'lishi mumkin^) - mavjud kod bilan davom etiladi.
    )
    popd
)
echo.

REM --- 1/4: ASCII papkaga ko'chirish (build, .git, .dart_tool va eski zip tashlanadi) ---
echo [1/4] Loyiha %DEST% ga ko'chirilmoqda...
if not exist "%DEST%" mkdir "%DEST%"
robocopy "%SRC%" "%DEST%" /E /XD "build" ".git" ".dart_tool" /XF "*.zip" /NFL /NDL /NJH /NJS /NP /R:1 /W:1 >nul
REM robocopy 0..7 = muvaffaqiyat, 8+ = xato
if %errorlevel% geq 8 (
    echo [XATO] Nusxa ko'chirishda xatolik ^(robocopy=%errorlevel%^).
    goto :fail
)

REM --- ASCII papkaga o'tib build ---
pushd "%DEST%"

echo [2/4] flutter pub get...
call flutter pub get
if errorlevel 1 (
    echo [XATO] flutter pub get muvaffaqiyatsiz.
    popd
    goto :fail
)

echo [3/4] flutter build windows --release  ^(biroz vaqt oladi^)...
call flutter build windows --release
if errorlevel 1 (
    echo [XATO] Build muvaffaqiyatsiz tugadi.
    popd
    goto :fail
)
popd

REM --- 4/4: Release bundle ni zip qilish ---
set "RELDIR=%DEST%\build\windows\x64\runner\Release"
if not exist "%RELDIR%\uz_ai_dev.exe" (
    echo [XATO] Release bundle topilmadi: %RELDIR%
    goto :fail
)

set "ZIPNAME=uz_ai_dev_v%VERSION%_windows.zip"
echo [4/4] Zip yaratilmoqda: %ZIPNAME%
if exist "%SRC%\%ZIPNAME%" del /f /q "%SRC%\%ZIPNAME%"
powershell -NoProfile -Command "Compress-Archive -Path '%RELDIR%\*' -DestinationPath '%SRC%\%ZIPNAME%' -Force"
if errorlevel 1 (
    echo [XATO] Zip yaratishda xatolik.
    goto :fail
)

REM --- Release bundle ni Desktop\Release_uz_ai_dev papkaga nusxalash ---
set "OUTDIR=%USERPROFILE%\Desktop\Release_uz_ai_dev"
echo [+] Release papkaga nusxalanmoqda: %OUTDIR%
robocopy "%RELDIR%" "%OUTDIR%" /MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1 >nul
if %errorlevel% geq 8 (
    echo [XATO] Release papkaga nusxalashda xatolik ^(robocopy=%errorlevel%^).
    goto :fail
)

echo.
echo ============================================================
echo   TAYYOR!
echo   Bundle : %RELDIR%
echo   Zip    : %SRC%\%ZIPNAME%
echo   Release: %OUTDIR%
echo ============================================================
echo.
pause
exit /b 0

:fail
echo.
echo ============================================================
echo   BUILD TUGAMADI - yuqoridagi xatoga qarang.
echo ============================================================
echo.
pause
exit /b 1
