/// Estados posibles de la aplicación BioLock
enum BioLockState {
  idle,              // Estado inicial
  enrolling,         // Registrando rostro
  scanning,          // Escaneando rostro
  faceDetected,      // Rostro detectado
  processing,        // Procesando detección
  authorized,        // Acceso autorizado
  denied,            // Acceso denegado
  unlocking,         // Desbloqueando puerta
  unlocked,          // Puerta desbloqueada
  bluetoothError,    // Error de Bluetooth
  cameraError,       // Error de cámara
}

/// Resultado del reconocimiento facial
class FaceRecognitionResult {
  final bool isMatched;
  final double confidence;
  final String timestamp;
  final String? errorMessage;

  FaceRecognitionResult({
    required this.isMatched,
    required this.confidence,
    required this.timestamp,
    this.errorMessage,
  });

  @override
  String toString() =>
      'FaceRecognitionResult(matched: $isMatched, confidence: $confidence, time: $timestamp)';
}

/// Modelo para dispositivo Bluetooth
class BluetoothDeviceModel {
  final String address;
  final String name;
  final bool isConnected;

  BluetoothDeviceModel({
    required this.address,
    required this.name,
    required this.isConnected,
  });

  @override
  String toString() => 'BluetoothDevice(name: $name, address: $address)';
}

/// Modelo para usuario autenticado
class AuthenticatedUser {
  final String id;
  final String name;
  final String? faceEmbedding; // Datos de rostro guardados
  final DateTime enrollmentDate;
  final int accessAttempts;
  final DateTime? lastAccess;

  AuthenticatedUser({
    required this.id,
    required this.name,
    this.faceEmbedding,
    required this.enrollmentDate,
    required this.accessAttempts,
    this.lastAccess,
  });

  @override
  String toString() =>
      'AuthenticatedUser(id: $id, name: $name, attempts: $accessAttempts)';
}
