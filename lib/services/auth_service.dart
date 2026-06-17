import 'package:logger/logger.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_state.dart';
import 'database_service.dart';
import 'session_service.dart';
import 'face_detection_service.dart';
import 'service_locator.dart'; // Importación requerida para acoplar getIt centralizado

class AuthService {
  static final Logger _logger = Logger();
  final _db = DatabaseService();
  final _session = SessionService();
  
  // === ARQUITECTURA CORREGIDA: Consumo de la instancia síncrona del Singleton ===
  FaceDetectionService get _faceDetectorService => getIt<FaceDetectionService>();
  
  AuthenticatedUser? _currentUser;
  Face? _enrolledFace;
  Map<String, Map<String, dynamic>> _allUsers = {};
  
  bool get isUserEnrolled => _allUsers.isNotEmpty;
  AuthenticatedUser? get currentUser => _currentUser;
  Face? get enrolledFace => _enrolledFace;
  bool get isLoggedIn => _session.isLoggedIn;

  /// Cargar todos los usuarios desde SharedPreferences y SQLite
  Future<void> loadPersistedUsers() async {
    try {
      print('[AuthService] Cargando usuarios...');
      
      // Intentar cargar desde SQLite primero
      final users = await _db.getAllUsers();
      
      if (users.isNotEmpty) {
        _allUsers = {};
        for (var user in users) {
          _allUsers[user['username']] = {
            'id': user['id'],
            'faceEmbedding': user['face_data'],
            'enrollmentDate': user['created_at'],
            'accessCount': 0,
            'lastAccess': user['updated_at'],
          };
        }
        print('[AuthService] ${_allUsers.length} usuarios cargados desde SQLite');
        return;
      }

      // Si no hay usuarios en SQLite, intentar migrar desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('all_users_data');
      
      if (usersJson != null) {
        final usersData = jsonDecode(usersJson) as Map<String, dynamic>;
        
        for (var entry in usersData.entries) {
          final username = entry.key;
          final data = entry.value as Map<String, dynamic>;
          
          // Migrar a SQLite
          final passwordHash = SessionService.hashPassword(username);
          await _db.createUser(
            username: username,
            passwordHash: passwordHash,
            faceData: data['faceEmbedding'] ?? '',
          );
        }

        _allUsers = usersData.map((key, value) => 
          MapEntry(key, value as Map<String, dynamic>)
        );
        
        print('[AuthService] ${_allUsers.length} usuarios migrados a SQLite');
        await prefs.remove('all_users_data');
      }
    } catch (e) {
      print('[AuthService] Error cargando usuarios: $e');
      _allUsers = {};
    }
  }

  /// Obtener lista de todos los usuarios registrados
  List<String> getAllEnrolledUsers() {
    return _allUsers.keys.toList();
  }

  /// Registrar un nuevo usuario extrayendo y serializando su mapa vectorial geométrico real
  Future<bool> enrollUser(
    String userName,
    Face faceData, {
    String? password,
  }) async {
    try {
      if (_allUsers.containsKey(userName)) {
        print('[AuthService] Usuario ya existe');
        return false;
      }

      // Construcción del vector flotante analítico mediante el singleton unificado
      final vector = _faceDetectorService.extractFaceVector(faceData);
      final faceDataStr = jsonEncode(vector);
      
      // Usar contraseña proporcionada o generar una por defecto
      final passwordHash = SessionService.hashPassword(password ?? userName);
      
      final userId = await _db.createUser(
        username: userName,
        passwordHash: passwordHash,
        faceData: faceDataStr,
      );

      if (userId != null) {
        _allUsers[userName] = {
          'id': userId,
          'faceEmbedding': faceDataStr,
          'enrollmentDate': DateTime.now().toIso8601String(),
          'accessCount': 0,
          'lastAccess': null,
        };

        print('[AuthService] Usuario registrado exitosamente con mapa vectorial');
        return true;
      }

      return false;
    } catch (e) {
      print('[AuthService] Error registrando usuario: $e');
      return false;
    }
  }

  /// Renombrar un usuario existente
  Future<bool> renameUser(String oldName, String newName) async {
    try {
      if (!_allUsers.containsKey(oldName)) {
        return false;
      }

      if (_allUsers.containsKey(newName)) {
        return false;
      }

      final user = _allUsers[oldName]!;
      final userId = user['id'];

      final success = await _db.updateUser(
        id: userId,
        username: newName,
      );

      if (success) {
        _allUsers[newName] = user;
        _allUsers.remove(oldName);
        print('[AuthService] Usuario renombrado exitosamente');
      }

      return success;
    } catch (e) {
      print('[AuthService] Error renombrando usuario: $e');
      return false;
    }
  }

  /// Eliminar un usuario
  Future<bool> deleteUser(String userName) async {
    try {
      if (!_allUsers.containsKey(userName)) {
        return false;
      }

      final user = _allUsers[userName]!;
      final userId = user['id'];

      final success = await _db.deleteUser(userId);

      if (success) {
        _allUsers.remove(userName);
        print('[AuthService] Usuario eliminado exitosamente');
      }

      return success;
    } catch (e) {
      print('[AuthService] Error scrapping de usuario: $e');
      return false;
    }
  }

  /// Autenticar un rostro calculando la Distancia Euclidiana Real en base paralela
  Future<FaceRecognitionResult> authenticateWithFace(Face detectedFace) async {
    try {
      if (_allUsers.isEmpty) {
        return FaceRecognitionResult(
          isMatched: false,
          confidence: 0.0,
          timestamp: DateTime.now().toIso8601String(),
          errorMessage: 'No hay usuarios registrados',
        );
      }

      // 1. Obtener la firma analítica del frame mediante el singleton unificado
      final currentVector = _faceDetectorService.extractFaceVector(detectedFace);

      // 2. Iterar y decodificar cada elemento de SQLite
      for (var userName in _allUsers.keys) {
        try {
          final savedVectorStr = _allUsers[userName]!['faceEmbedding'].toString();
          final List<dynamic> decodedList = jsonDecode(savedVectorStr);
          final List<double> enrolledVector = decodedList.map((e) => (e as num).toDouble()).toList();

          // Contrastar bajo los plazos del Planificador en Tiempo Real (T-VAL = 50ms)
          final result = await _faceDetectorService.compareFacesReal(currentVector, enrolledVector);

          if (result.isMatched) {
            _allUsers[userName]!['accessCount'] = 
              (_allUsers[userName]!['accessCount'] as int) + 1;
            _allUsers[userName]!['lastAccess'] = 
              DateTime.now().toIso8601String();
            
            _currentUser = AuthenticatedUser(
              id: userName,
              name: userName,
              faceEmbedding: savedVectorStr,
              enrollmentDate: DateTime.parse(
                _allUsers[userName]!['enrollmentDate']
              ),
              accessAttempts: _allUsers[userName]!['accessCount'],
              lastAccess: DateTime.now(),
            );

            _logger.i('✅ Autenticado Biométricamente: $userName');
            return result;
          }
        } catch (jsonErr) {
          _logger.w('Ignorando registro no parseable de $userName: $jsonErr');
          continue; 
        }
      }

      return FaceRecognitionResult(
        isMatched: false,
        confidence: 0.0,
        timestamp: DateTime.now().toIso8601String(),
        errorMessage: 'Rostro no reconocido',
      );
    } catch (e) {
      _logger.e('❌ Error autenticando: $e');
      return FaceRecognitionResult(
        isMatched: false,
        confidence: 0.0,
        timestamp: DateTime.now().toIso8601String(),
        errorMessage: 'Error en autenticación: $e',
      );
    }
  }

  /// Autenticar mediante FaceRecognitionResult (legacy)
  Future<bool> authenticateUser(FaceRecognitionResult result) async {
    try {
      return result.isMatched && result.confidence > 0.75;
    } catch (e) {
      _logger.e('Error autenticando usuario: $e');
      return false;
    }
  }

  int getAccessCount() => _currentUser?.accessAttempts ?? 0;

  DateTime? getLastAccessTime() => _currentUser?.lastAccess;

  void logout() {
    _session.logout();
    _currentUser = null;
    _enrolledFace = null;
    _logger.i('Sesión cerrada');
  }

  Future<void> clearAllUsers() async {
    _allUsers.clear();
    _currentUser = null;
    _enrolledFace = null;
    await _db.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('all_users_data');
    
    _logger.i('Todos los usuarios eliminados');
  }

  /// Login con usuario y contraseña
  Future<bool> login(String username, String password) async {
    try {
      print('[AuthService] Intento de login: $username');
      
      final success = await _session.login(username, password);
      
      if (success) {
        final user = await _session.getCurrentUser();
        if (user != null) {
          _currentUser = AuthenticatedUser(
            id: user['id'].toString(),
            name: user['username'],
            enrollmentDate: DateTime.parse(user['created_at']),
            accessAttempts: user['access_count'] ?? 0,
            lastAccess: user['last_access'] != null 
              ? DateTime.parse(user['last_access'])
              : null,
          );
          print('[AuthService] Login exitoso');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('[AuthService] Error en login: $e');
      return false;
    }
  }

  /// Obtiene logs de acceso
  Future<List<Map<String, dynamic>>> getAccessLogs({int limit = 50}) async {
    return await _session.getAccessLogs(limit: limit);
  }
}

extension AuthenticatedUserCopyWith on AuthenticatedUser {
  AuthenticatedUser copyWith({
    String? id,
    String? name,
    String? faceEmbedding,
    DateTime? enrollmentDate,
    int? accessAttempts,
    DateTime? lastAccess,
  }) {
    return AuthenticatedUser(
      id: id ?? this.id,
      name: name ?? this.name,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      accessAttempts: accessAttempts ?? this.accessAttempts,
      lastAccess: lastAccess ?? this.lastAccess,
    );
  }
}