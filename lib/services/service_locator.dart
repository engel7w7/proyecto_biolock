import 'package:get_it/get_it.dart';
import 'camera_service.dart';
import 'face_detection_service.dart';
import 'bluetooth_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'session_service.dart';

final getIt = GetIt.instance;

/// Configura la inyección de dependencias
void setupServiceLocator() {
  // Servicios singleton
  getIt.registerSingleton<DatabaseService>(DatabaseService());
  getIt.registerSingleton<SessionService>(SessionService());
  getIt.registerSingleton<CameraService>(CameraService());
  getIt.registerSingleton<FaceDetectionService>(FaceDetectionService());
  getIt.registerSingleton<BluetoothService>(BluetoothService());
  getIt.registerSingleton<AuthService>(AuthService());
}
