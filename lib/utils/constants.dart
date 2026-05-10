/// Constantes de la aplicación
import 'package:flutter/material.dart';

class BioLockConstants {
  // Temas de color
  static const Color primaryColor = Color(0xFF00E5FF);
  static const Color secondaryColor = Color(0xFF00FF87);
  static const Color errorColor = Color(0xFFFF4444);
  static const Color warningColor = Color(0xFFFFAA00);
  static const Color backgroundColor = Color(0xFF0A0E1A);
  static const Color surfaceColor = Color(0xFF111827);

  // Timeouts
  static const Duration cameraInitTimeout = Duration(seconds: 5);
  static const Duration bluetoothTimeout = Duration(seconds: 10);
  static const Duration recognitionTimeout = Duration(seconds: 15);
  static const Duration unlockDuration = Duration(seconds: 3);

  // Configuración facial
  static const double confidenceThreshold = 0.75;
  static const int maxEnrollmentAttempts = 5;

  // Mensajes
  static const String msgWelcome = 'Bienvenido a BioLock';
  static const String msgScanningFace = 'Escaneando tu rostro...';
  static const String msgFaceDetected = 'Rostro Detectado';
  static const String msgUnauthorized = 'Acceso Denegado';
  static const String msgAuthorized = 'Acceso Autorizado';
  static const String msgUnlocking = 'Desbloqueando...';
  static const String msgUnlocked = '¡Puerta Abierta!';
  static const String msgBluetoothError = 'Error de conexión Bluetooth';
  static const String msgCameraError = 'Error de cámara';
  static const String msgPlaceEnrollForAccess = 'Registra tu rostro para acceder';

  // Arduino commands
  static const String commandUnlock = '1';
  static const String commandLock = '0';
}
