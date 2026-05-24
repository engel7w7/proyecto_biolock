#!/bin/bash
# BioLock - Quick Start Script
# Ejecuta este script para preparar y compilar la app

echo "════════════════════════════════════════════════════"
echo "  🔐 BioLock - Sistema de Acceso Biométrico"
echo "════════════════════════════════════════════════════"
echo ""

# Variables
PROJECT_DIR="$(pwd)"
echo "📁 Directorio del proyecto: $PROJECT_DIR"
echo ""

# Paso 1: Limpiar
echo "🧹 Paso 1: Limpiando proyecto..."
flutter clean
echo "✓ Proyecto limpiado"
echo ""

# Paso 2: Obtener dependencias
echo "📦 Paso 2: Descargando dependencias..."
flutter pub get
echo "✓ Dependencias descargadas"
echo ""

# Paso 3: Verificar dispositivos conectados
echo "📱 Paso 3: Verificando dispositivos..."
adb devices
echo ""
read -p "¿Hay un dispositivo conectado? (s/n): " device_connected

if [ "$device_connected" = "s" ] || [ "$device_connected" = "S" ]; then
    echo ""
    echo "🚀 Paso 4: Compilando APK (Debug)..."
    flutter build apk --debug
    
    if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
        echo "✓ APK compilado exitosamente"
        echo ""
        echo "📲 Paso 5: Instalando en dispositivo..."
        adb install build/app/outputs/flutter-apk/app-debug.apk
        echo "✓ App instalada"
        echo ""
        echo "🎮 Paso 6: Ejecutando app..."
        flutter run
    else
        echo "✗ Error: No se pudo compilar el APK"
        exit 1
    fi
else
    echo ""
    echo "💻 Sin dispositivo conectado. Compilando solo APK..."
    flutter build apk --debug
    
    if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
        echo "✓ APK compilado en: build/app/outputs/flutter-apk/app-debug.apk"
        echo ""
        echo "Para instalar manualmente:"
        echo "  adb install build/app/outputs/flutter-apk/app-debug.apk"
    else
        echo "✗ Error: No se pudo compilar el APK"
        exit 1
    fi
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  ✨ ¡BioLock está listo!"
echo "════════════════════════════════════════════════════"
