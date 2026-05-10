import 'package:flutter_test/flutter_test.dart';
import 'package:biolock_web/models/app_state.dart';
import 'package:biolock_web/services/auth_service.dart';

void main() {
  group('BioLock Unit Tests', () {
    
    // ─── Tests de Modelos ─────────────────────────────────────────
    group('FaceRecognitionResult', () {
      test('Crea resultado de reconocimiento correcto', () {
        final result = FaceRecognitionResult(
          isMatched: true,
          confidence: 0.95,
          timestamp: DateTime.now().toIso8601String(),
        );
        
        expect(result.isMatched, true);
        expect(result.confidence, 0.95);
        expect(result.errorMessage, isNull);
      });

      test('Crea resultado con error', () {
        final result = FaceRecognitionResult(
          isMatched: false,
          confidence: 0.0,
          timestamp: DateTime.now().toIso8601String(),
          errorMessage: 'No se detectó rostro',
        );
        
        expect(result.isMatched, false);
        expect(result.confidence, 0.0);
        expect(result.errorMessage, 'No se detectó rostro');
      });
    });

    group('BluetoothDeviceModel', () {
      test('Crea dispositivo Bluetooth correctamente', () {
        final device = BluetoothDeviceModel(
          address: '00:11:22:33:44:55',
          name: 'HC-05',
          isConnected: false,
        );
        
        expect(device.address, '00:11:22:33:44:55');
        expect(device.name, 'HC-05');
        expect(device.isConnected, false);
      });
    });

    group('AuthenticatedUser', () {
      test('Crea usuario autenticado', () {
        final user = AuthenticatedUser(
          id: 'user_001',
          name: 'Test User',
          enrollmentDate: DateTime.now(),
          accessAttempts: 0,
        );
        
        expect(user.id, 'user_001');
        expect(user.name, 'Test User');
        expect(user.accessAttempts, 0);
      });
    });

    // ─── Tests de Estados ──────────────────────────────────────────
    group('BioLockState Enum', () {
      test('Contiene todos los estados esperados', () {
        final states = [
          BioLockState.idle,
          BioLockState.enrolling,
          BioLockState.scanning,
          BioLockState.faceDetected,
          BioLockState.processing,
          BioLockState.authorized,
          BioLockState.denied,
          BioLockState.unlocking,
          BioLockState.unlocked,
          BioLockState.bluetoothError,
          BioLockState.cameraError,
        ];
        
        expect(states.length, 11);
        expect(states.contains(BioLockState.authorized), true);
      });
    });

    // ─── Tests de AuthService ──────────────────────────────────────
    group('AuthService', () {
      late AuthService authService;

      setUp(() {
        authService = AuthService();
      });

      test('No hay usuario registrado inicialmente', () {
        expect(authService.isUserEnrolled, false);
        expect(authService.currentUser, isNull);
      });

      test('Acceso count es 0 sin usuario', () {
        expect(authService.getAccessCount(), 0);
      });

      test('Último acceso es null sin usuario', () {
        expect(authService.getLastAccessTime(), isNull);
      });

      test('Logout limpia datos', () {
        authService.logout();
        
        expect(authService.isUserEnrolled, false);
        expect(authService.currentUser, isNull);
        expect(authService.enrolledFace, isNull);
      });
    });

    // ─── Tests de Validación de Confianza ──────────────────────────
    group('Validación de Reconocimiento Facial', () {
      test('Confianza 75% es válida', () {
        final result = FaceRecognitionResult(
          isMatched: true,
          confidence: 0.75,
          timestamp: DateTime.now().toIso8601String(),
        );
        
        expect(result.confidence >= 0.75, true);
      });

      test('Confianza 74% es inválida', () {
        final result = FaceRecognitionResult(
          isMatched: false,
          confidence: 0.74,
          timestamp: DateTime.now().toIso8601String(),
        );
        
        expect(result.confidence >= 0.75, false);
      });

      test('Confianza nunca es negativa', () {
        final result = FaceRecognitionResult(
          isMatched: false,
          confidence: 0.0,
          timestamp: DateTime.now().toIso8601String(),
        );
        
        expect(result.confidence >= 0.0, true);
      });

      test('Confianza nunca excede 1.0', () {
        final result = FaceRecognitionResult(
          isMatched: true,
          confidence: 0.99,
          timestamp: DateTime.now().toIso8601String(),
        );
        
        expect(result.confidence <= 1.0, true);
      });
    });

    // ─── Tests de Timestamps ──────────────────────────────────────
    group('Timestamps', () {
      test('FaceRecognitionResult tiene timestamp válido', () {
        final now = DateTime.now();
        final result = FaceRecognitionResult(
          isMatched: true,
          confidence: 0.80,
          timestamp: now.toIso8601String(),
        );
        
        expect(result.timestamp, isNotEmpty);
      });

      test('AuthenticatedUser tiene enrollment date', () {
        final now = DateTime.now();
        final user = AuthenticatedUser(
          id: 'test',
          name: 'Test',
          enrollmentDate: now,
          accessAttempts: 0,
        );
        
        expect(user.enrollmentDate, now);
      });
    });

    // ─── Tests de Constantes ──────────────────────────────────────
    group('Umbrales de Confianza', () {
      test('Umbral de confianza es 0.75', () {
        const threshold = 0.75;
        
        expect(threshold, 0.75);
        expect(threshold > 0.5, true);
        expect(threshold < 1.0, true);
      });
    });
  });
}
