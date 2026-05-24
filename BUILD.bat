@echo off
REM BioLock - Quick Start Script para Windows
REM Ejecuta este script para preparar y compilar la app

echo.
echo ════════════════════════════════════════════════════
echo   🔐 BioLock - Sistema de Acceso Biométrico
echo ════════════════════════════════════════════════════
echo.

REM Paso 1: Limpiar
echo 🧹 Paso 1: Limpiando proyecto...
call flutter clean
echo ✓ Proyecto limpiado
echo.

REM Paso 2: Obtener dependencias
echo 📦 Paso 2: Descargando dependencias...
call flutter pub get
echo ✓ Dependencias descargadas
echo.

REM Paso 3: Verificar dispositivos
echo 📱 Paso 3: Verificando dispositivos...
adb devices
echo.

REM Paso 4: Compilar
echo 🚀 Compilando APK (Debug)...
call flutter build apk --debug

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo.
    echo ✓ APK compilado exitosamente
    echo.
    echo 📍 Ubicación: build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo 📲 Para instalar:
    echo    adb install build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo 🎮 Para ejecutar:
    echo    flutter run
) else (
    echo.
    echo ✗ Error: No se pudo compilar el APK
    exit /b 1
)

echo.
echo ════════════════════════════════════════════════════
echo   ✨ ¡BioLock está listo!
echo ════════════════════════════════════════════════════
echo.
pause
