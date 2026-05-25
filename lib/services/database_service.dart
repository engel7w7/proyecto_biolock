import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static final Logger _logger = Logger();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'biolock.db');

      print('[DatabaseService] Inicializando base de datos en: $path');

      return await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('[DatabaseService] Error inicializando DB: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      // Tabla de usuarios con credenciales
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          face_data TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_active INTEGER DEFAULT 1
        )
      ''');

      // Tabla de sesiones
      await db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          token TEXT UNIQUE NOT NULL,
          created_at TEXT NOT NULL,
          expires_at TEXT NOT NULL,
          is_active INTEGER DEFAULT 1,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      // Tabla de auditoría (logs de acceso)
      await db.execute('''
        CREATE TABLE access_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          action TEXT NOT NULL,
          status TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          details TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
        )
      ''');

      // === NUEVA TABLA: TELEMETRÍA DE TIEMPO REAL (CAPÍTULO 4 - PRODUCCIÓN) ===
      await db.execute('''
        CREATE TABLE str_telemetry_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_code TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          execution_time_ms REAL NOT NULL,
          deadline_ms REAL NOT NULL,
          alert_flag INTEGER NOT NULL
        )
      ''');

      print('[DatabaseService] Base de datos creada exitosamente con soporte STR');
    } catch (e) {
      print('[DatabaseService] Error creando tablas: $e');
      rethrow;
    }
  }

  /// Migración de la base de datos de v1 a v2
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      print('[DatabaseService] Migrando de v$oldVersion a v$newVersion');
      
      if (oldVersion < 2) {
        // Agregar tabla de telemetría STR si no existe
        await db.execute('''
          CREATE TABLE IF NOT EXISTS str_telemetry_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_code TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            execution_time_ms REAL NOT NULL,
            deadline_ms REAL NOT NULL,
            alert_flag INTEGER NOT NULL
          )
        ''');
        print('[DatabaseService] Tabla str_telemetry_logs creada/verificada');
      }
    } catch (e) {
      print('[DatabaseService] Error migrando DB: $e');
    }
  }

  // === NUEVO MÉTODO: INSERCIÓN SÍNCRONA DE MÉTRICAS STR ===
  Future<void> logSTRMetrics(String taskCode, double executionTimeMs, double deadlineMs) async {
    try {
      final db = await database;
      // Si el tiempo real medido supera el plazo (Deadline), se activa la Alerta (1)
      int alertFlag = (executionTimeMs > deadlineMs) ? 1 : 0;

      await db.insert('str_telemetry_logs', {
        'task_code': taskCode,
        'timestamp': DateTime.now().toIso8601String(),
        'execution_time_ms': executionTimeMs,
        'deadline_ms': deadlineMs,
        'alert_flag': alertFlag,
      });
      _logger.d('[STR Telemetry] Log insertado para $taskCode: ${executionTimeMs}ms (Alert: $alertFlag)');
    } catch (e) {
      print('[DatabaseService] Error insertando telemetría STR: $e');
    }
  }

  /// Obtiene todos los logs de telemetría STR (Para mostrar en pantallas de control)
  Future<List<Map<String, dynamic>>> getSTRTelemetryLogs() async {
    try {
      final db = await database;
      return await db.query('str_telemetry_logs', orderBy: 'id DESC');
    } catch (e) {
      print('[DatabaseService] Error obteniendo telemetría STR: $e');
      return [];
    }
  }

  /// Obtiene todos los usuarios
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final db = await database;
      final users = await db.query('users', where: 'is_active = ?', whereArgs: [1]);
      return users;
    } catch (e) {
      print('[DatabaseService] Error obteniendo usuarios: $e');
      return [];
    }
  }

  /// Obtiene un usuario por nombre de usuario
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'username = ? AND is_active = ?',
        whereArgs: [username, 1],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('[DatabaseService] Error obteniendo usuario: $e');
      return null;
    }
  }

  /// Crea un nuevo usuario
  Future<int?> createUser({
    required String username,
    required String passwordHash,
    required String faceData,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final id = await db.insert('users', {
        'username': username,
        'password_hash': passwordHash,
        'face_data': faceData,
        'created_at': now,
        'updated_at': now,
        'is_active': 1,
      });

      print('[DatabaseService] Usuario creado: $username');
      await _logAccess(id, 'USER_CREATED', 'SUCCESS', 'Usuario creado exitosamente');

      return id;
    } catch (e) {
      print('[DatabaseService] Error creando usuario: $e');
      return null;
    }
  }

  /// Actualiza un usuario
  Future<bool> updateUser({
    required int id,
    String? username,
    String? passwordHash,
    String? faceData,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final updates = <String, dynamic>{
        'updated_at': now,
      };

      if (username != null) updates['username'] = username;
      if (passwordHash != null) updates['password_hash'] = passwordHash;
      if (faceData != null) updates['face_data'] = faceData;

      final result = await db.update(
        'users',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );

      print('[DatabaseService] Usuario actualizado: $id');
      await _logAccess(id, 'USER_UPDATED', 'SUCCESS', 'Usuario actualizado');

      return result > 0;
    } catch (e) {
      print('[DatabaseService] Error actualizando usuario: $e');
      return false;
    }
  }

  /// Elimina un usuario (soft delete)
  Future<bool> deleteUser(int id) async {
    try {
      final db = await database;

      final result = await db.update(
        'users',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      print('[DatabaseService] Usuario eliminado: $id');
      await _logAccess(id, 'USER_DELETED', 'SUCCESS', 'Usuario eliminado');

      return result > 0;
    } catch (e) {
      print('[DatabaseService] Error eliminando usuario: $e');
      return false;
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
      final db = await database;
      await db.insert('access_logs', {
        'user_id': userId,
        'action': action,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
        'details': details,
      });
    } catch (e) {
      print('[DatabaseService] Error registrando log: $e');
    }
  }

  /// Limpia base de datos (para testing)
  Future<void> clear() async {
    try {
      final db = await database;
      await db.delete('sessions');
      await db.delete('access_logs');
      await db.delete('str_telemetry_logs'); // Limpiar telemetría también
      await db.delete('users');
      print('[DatabaseService] Base de datos limpiada');
    } catch (e) {
      print('[DatabaseService] Error limpiando BD: $e');
    }
  }
}
