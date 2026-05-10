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
        version: 1,
        onCreate: _onCreate,
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

      print('[DatabaseService] Base de datos creada exitosamente');
    } catch (e) {
      print('[DatabaseService] Error creando tablas: $e');
      rethrow;
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
      await db.delete('users');
      print('[DatabaseService] Base de datos limpiada');
    } catch (e) {
      print('[DatabaseService] Error limpiando BD: $e');
    }
  }
}
