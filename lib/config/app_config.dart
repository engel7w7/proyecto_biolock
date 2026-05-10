class AppConfig {
  // Configuración de Arduino/Bluetooth
  static const String defaultBluetoothDeviceName = 'HC-05';
  static const int bluetoothBaudRate = 9600;

  // Configuración de reconocimiento facial
  static const bool enableFaceTracking = true;
  static const bool enableFaceClassification = true;
  static const bool enableFaceLandmarks = true;
  static const double minFaceConfidence = 0.75;

  // Configuración de cámara
  static const int cameraPresetQuality = 1; // medium: 0=low, 1=medium, 2=high, 3=veryHigh, 4=ultraHigh
  static const bool enableAudio = false;
  static const bool useFrontCamera = true;

  // Configuración de experiencia de usuario
  static const Duration recognitionCheckInterval = Duration(milliseconds: 500);
  static const Duration unlockButtonCooldown = Duration(seconds: 2);
  static const int maxFailedAuthAttempts = 5;

  // Almacenamiento
  static const String storageKeyEnrolledFace = 'enrolled_face_data';
  static const String storageKeyUserId = 'user_id';
  static const String storageKeyUserName = 'user_name';
}
