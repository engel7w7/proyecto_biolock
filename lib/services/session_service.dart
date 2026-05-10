import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();

  factory SessionService() {
    return _instance;
  }

  SessionService._internal();

  final _db = DatabaseService();
  String? _currentSessionToken;
  int? _currentUserId;

  String? get currentSessionToken => _currentSessionToken;
  int? get currentUserId => _currentUserId;
  bool get isLoggedIn => _currentSessionToken != null;

  /// Hash de contraseña (SHA-256)
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Genera un token de sesión único
  static String generateSessionToken() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return sha256.convert(utf8.encode('$random-${DateTime.now().microsecond}')).toString();
  }

  /// Login de usuario
  Future<bool> login(String username, String password) async {
    try {
      print('[SessionService] Intentando login para: $username');

      final user = await _db.getUserByUsername(username);
      if (user == null) {
        print('[SessionService] Usuario no encontrado');
        await _logAccess(null, 'LOGIN_ATTEMPT', 'FAILED', 'Usuario no existe');
        return false;
      }

      final passwordHash = hashPassword(password);
      if (user['password_hash'] != passwordHash) {
        print('[SessionService] Contraseña incorrecta');
        await _logAccess(user['id'], 'LOGIN_ATTEMPT', 'FAILED', 'Contraseña incorrecta');
        return false;
      }

      // Crear sesión
      final token = generateSessionToken();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 30));

      final db = await _db.database;
      await db.insert('sessions', {
        'user_id': user['id'],
        'token': token,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_active': 1,
      });

      _currentSessionToken = token;
      _currentUserId = user['id'];

      print('[SessionService] Login exitoso para: $username');
      await _logAccess(user['id'], 'LOGIN_SUCCESS', 'SUCCESS', 'Sesión iniciada');

      return true;
    } catch (e) {
      print('[SessionService] Error en login: $e');
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      if (_currentUserId != null && _currentSessionToken != null) {
        final db = await _db.database;
        await db.update(
          'sessions',
          {'is_active': 0},
          where: 'token = ?',
          whereArgs: [_currentSessionToken],
        );

        await _logAccess(_currentUserId, 'LOGOUT', 'SUCCESS', 'Sesión cerrada');
        print('[SessionService] Logout exitoso');
      }

      _currentSessionToken = null;
      _currentUserId = null;
    } catch (e) {
      print('[SessionService] Error en logout: $e');
    }
  }

  /// Verifica si una sesión es válida
  Future<bool> isSessionValid(String token) async {
    try {
      final db = await _db.database;
      final result = await db.query(
        'sessions',
        where: 'token = ? AND is_active = ? AND expires_at > ?',
        whereArgs: [token, 1, DateTime.now().toIso8601String()],
      );

      return result.isNotEmpty;
    } catch (e) {
      print('[SessionService] Error validando sesión: $e');
      return false;
    }
  }

  /// Obtiene el usuario actual
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUserId == null) return null;

    try {
      final db = await _db.database;
      final result = await db.query(
        'users',
        where: 'id = ? AND is_active = ?',
        whereArgs: [_currentUserId, 1],
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('[SessionService] Error obteniendo usuario actual: $e');
      return null;
    }
  }

  /// Log de acceso/auditoría
  Future<void> _logAccess(
    int? userId,
    String action,
    String status,
    String? details,
  ) async {
    try {
      final db = await _db.database;
      await db.insert('access_logs', {
        'user_id': userId,
        'action': action,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
        'details': details,
      });
    } catch (e) {
      print('[SessionService] Error registrando log: $e');
    }
  }

  /// Obtiene logs de acceso (últimos 50)
  Future<List<Map<String, dynamic>>> getAccessLogs({int limit = 50}) async {
    try {
      final db = await _db.database;
      return await db.query(
        'access_logs',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    } catch (e) {
      print('[SessionService] Error obteniendo logs: $e');
      return [];
    }
  }
}
