import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'dart:math'; // Requerido para operaciones matemáticas de raíz cuadrada
import 'dart:async'; // Necesario para TimeoutException y timeout
import '../models/app_state.dart';
import '../utils/str_constants.dart'; // Importa deadlines STR
import 'database_service.dart'; // Importación requerida para guardar métricas STR

class FaceDetectionService {
  static final Logger _logger = Logger();
  late FaceDetector _faceDetector;
  bool _isInitialized = false;
  int _frameCount = 0;
  int _successfulDetections = 0;

  bool get isInitialized => _isInitialized;

  /// Inicializa el detector de rostros
  Future<void> initialize() async {
    try {
      final options = FaceDetectorOptions(
        enableTracking: true,
        enableClassification: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.fast, // Modo rápido para mejor performance
      );
      _faceDetector = FaceDetector(options: options);
      _isInitialized = true;
      _logger.i('✓ FaceDetector inicializado en modo FAST');
    } catch (e) {
      _logger.e('✗ Error inicializando FaceDetector: $e');
    }
  }

  /// Detecta rostros en una imagen e instrumenta T-DET
  Future<List<Face>> detectFaces(CameraImage image) async {
    late final Stopwatch stopwatch;
    
    try {
      if (!_isInitialized) {
        _logger.w('FaceDetector no inicializado');
        return [];
      }

      _frameCount++;
      
      // === INSTRUMENTACIÓN STR: INICIO MEDICIÓN T-DET ===
      stopwatch = Stopwatch()..start();
      
      final planes = image.planes;
      final int width = image.width;
      final int height = image.height;
      
      // NV21 = Y plane + interleaved UV
      // Size = width*height + (width/2)*(height/2)*2
      final int ySize = width * height;
      final int uvSize = (width ~/ 2) * (height ~/ 2);
      
      final Uint8List nv21 = Uint8List(ySize + uvSize * 2);
      
      // Copiar Y plane
      final Uint8List yBytes = planes[0].bytes;
      final int yRowPadding = planes[0].bytesPerRow - width;
      
      int pixelIndex = 0;
      for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
          nv21[pixelIndex] = yBytes[i * (width + yRowPadding) + j];
          pixelIndex++;
        }
      }
      
      // Copiar UV interleaved (V, U, V, U...)
      final Uint8List uBytes = planes[1].bytes;
      final Uint8List vBytes = planes[2].bytes;
      final int pixelStride = planes[1].bytesPerPixel ?? 1;
      
      int uvPixelIndex = 0;
      for (int i = 0; i < uvSize; i++) {
        final int uvPos = i * pixelStride;
        
        // Asegurar que no excedemos los límites
        if (uvPos < vBytes.length) {
          nv21[ySize + uvPixelIndex++] = vBytes[uvPos];
        }
        if (uvPos < uBytes.length) {
          nv21[ySize + uvPixelIndex++] = uBytes[uvPos];
        }
      }
      
      final inputImage = InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: width,  // Usar width directo, sin padding
        ),
      );
      
      final List<Face> faces = await _faceDetector.processImage(inputImage).timeout(
        const Duration(milliseconds: STRConfig.DEADLINE_T_DET),
        onTimeout: () => throw TimeoutException('STR_DEADLINE_MISS_DET'),
      );
      
      stopwatch.stop();
      // === INSTRUMENTACIÓN STR: REGISTRO EN BASE DE DATOS ===
      // Código: T-DET, Deadline Nominal de diseño: 100.0 ms
      await DatabaseService().logSTRMetrics(
        'T-DET', 
        stopwatch.elapsedMilliseconds.toDouble(), 
        STRConfig.DEADLINE_T_DET.toDouble()
      );
      
      if (faces.isNotEmpty) {
        _successfulDetections++;
        _logger.i('DETECTADO! Frame $_frameCount | Rostros: ${faces.length}');
      } else if (_frameCount % 30 == 1) {
        _logger.w('Frame $_frameCount (NV21 optimal)');
      }
      
      return faces;
    } on TimeoutException catch (_) {
      stopwatch.stop();
      // Registrar el Deadline Miss
      await DatabaseService().logSTRMetrics(
        'T-DET',
        (STRConfig.DEADLINE_T_DET + 1).toDouble(),
        STRConfig.DEADLINE_T_DET.toDouble()
      );
      _logger.e('FALLO STR: T-DET excedio el plazo de ${STRConfig.DEADLINE_T_DET}ms');
      throw Exception('STR_DEADLINE_MISS_DET'); // Lanza error para abortar el acceso
    } catch (e) {
      _logger.e('Error detectando rostros (frame $_frameCount): $e');
      return [];
    }
  }

  /// Compara rostros con embeddings e instrumenta T-VAL
  Future<FaceRecognitionResult> compareFaces(
    List<Face> detectedFaces,
    Face? enrolledFace,
  ) async {
    // === INSTRUMENTACIÓN STR: INICIO MEDICIÓN T-VAL ===
    final stopwatch = Stopwatch()..start();
    
    try {
      if (detectedFaces.isEmpty) {
        stopwatch.stop();
        return FaceRecognitionResult(
          isMatched: false,
          confidence: 0.0,
          timestamp: DateTime.now().toIso8601String(),
          errorMessage: 'No se detecto rostro',
        );
      }

      if (enrolledFace == null) {
        stopwatch.stop();
        return FaceRecognitionResult(
          isMatched: false,
          confidence: 0.0,
          timestamp: DateTime.now().toIso8601String(),
          errorMessage: 'No hay rostro registrado',
        );
      }

      // Simulación: comparar características básicas (ancho de cara)
      final detectedFace = detectedFaces.first;
      
      // ML Kit 0.13.2 usa diferentes métricas
      // Usamos simulation simple basada en boundingBox
      final enrolledBounds = enrolledFace.boundingBox;
      final detectedBounds = detectedFace.boundingBox;
      
      // Comparar tamaño relativo de bounding boxes
      final widthRatio = detectedBounds.width / enrolledBounds.width;
      final heightRatio = detectedBounds.height / enrolledBounds.height;
      
      // Si el ratio está entre 0.8 y 1.2, es una coincidencia potencial
      final double sizeMatch = 1.0 - ((widthRatio - 1.0).abs() + (heightRatio - 1.0).abs()) / 2;
      final double confidence = (sizeMatch * 100).clamp(0.0, 1.0);
      
      // Umbral de confianza
      const double confidenceThreshold = 0.75;
      final bool isMatched = confidence >= confidenceThreshold;

      stopwatch.stop();
      
      // === ENFORZAMIENTO STR (T-VAL = 50ms) ===
      if (stopwatch.elapsedMilliseconds > STRConfig.DEADLINE_T_VAL) {
        await DatabaseService().logSTRMetrics(
          'T-VAL',
          stopwatch.elapsedMilliseconds.toDouble(),
          STRConfig.DEADLINE_T_VAL.toDouble()
        );
        _logger.e('FALLO STR: T-VAL excedio el plazo de ${STRConfig.DEADLINE_T_VAL}ms');
        throw Exception('STR_DEADLINE_MISS_VAL');
      }
      
      // === INSTRUMENTACIÓN STR: REGISTRO T-VAL ===
      // Código: T-VAL, Deadline Nominal de diseño: 50.0 ms
      await DatabaseService().logSTRMetrics(
        'T-VAL', 
        stopwatch.elapsedMilliseconds.toDouble(), 
        STRConfig.DEADLINE_T_VAL.toDouble()
      );

      _logger.i('Comparacion: matched=$isMatched, confidence=${(confidence * 100).toStringAsFixed(1)}%');

      return FaceRecognitionResult(
        isMatched: isMatched,
        confidence: confidence,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      stopwatch.stop();
      if (e.toString().contains('STR_DEADLINE_MISS_VAL')) rethrow; // Pasa el error critico arriba
      _logger.e('Error comparando rostros: $e');
      return FaceRecognitionResult(
        isMatched: false,
        confidence: 0.0,
        timestamp: DateTime.now().toIso8601String(),
        errorMessage: 'Error: $e',
      );
    }
  }

  /// Convierte CameraImage a InputImage para ML Kit  
  InputImage _convertCameraImage(CameraImage image) {
    // Estrategia: intentar diferentes formatos y rotaciones
    // Device: Xiaomi M2012K10C, Android 13, Landscape 720x480
    
    try {
      // Obtener los tres planos YUV
      final planes = image.planes;
      
      if (planes.length < 3) {
        _logger.w('⚠ Menos de 3 planos: ${planes.length}');
        return InputImage.fromBytes(
          bytes: planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: planes[0].bytesPerRow,
          ),
        );
      }

      // Concatenar todos los planos en el orden correcto para NV21
      // NV21 = Y plane + interleaved (V, U) planes
      final Uint8List nv21data = Uint8List(
        planes[0].bytes.length + planes[1].bytes.length + planes[2].bytes.length
      );

      // Copiar Y plane (full resolution)
      int offset = 0;
      nv21data.setRange(0, planes[0].bytes.length, planes[0].bytes);
      offset = planes[0].bytes.length;

      // Copiar V plane (quarter resolution)
      nv21data.setRange(offset, offset + planes[2].bytes.length, planes[2].bytes);
      offset += planes[2].bytes.length;

      // Copiar U plane (quarter resolution)
      nv21data.setRange(offset, offset + planes[1].bytes.length, planes[1].bytes);

      _logger.d('Imagen convertida: ${image.width}x${image.height}, '
        'bytes=${nv21data.length}, stride=${planes[0].bytesPerRow}');

      return InputImage.fromBytes(
        bytes: nv21data,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,  // CRÍTICO: 0deg para landscape
          format: InputImageFormat.nv21,
          bytesPerRow: planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      _logger.e('Error en conversión de imagen: $e');
      return InputImage.fromBytes(
        bytes: Uint8List(0),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 0,
        ),
      );
    }
  }

  /// Compara el rostro actual contra el almacenado usando Distancia Euclidiana Real
  Future<FaceRecognitionResult> compareFacesReal(
    List<double> currentEmbedding, // El vector de 128 datos extraído por MobileFaceNet
    List<double> enrolledEmbedding, // El vector cargado desde tu SQLite
  ) async {
    // === INSTRUMENTACIÓN STR: INICIO MEDICIÓN T-VAL ===
    final stopwatch = Stopwatch()..start();

    try {
      if (currentEmbedding.isEmpty || enrolledEmbedding.isEmpty) {
        stopwatch.stop();
        return FaceRecognitionResult(
          isMatched: false,
          confidence: 0.0,
          timestamp: DateTime.now().toIso8601String(),
          errorMessage: 'Embeddings vacios',
        );
      }

      if (currentEmbedding.length != enrolledEmbedding.length) {
        stopwatch.stop();
        return FaceRecognitionResult(
          isMatched: false,
          confidence: 0.0,
          timestamp: DateTime.now().toIso8601String(),
          errorMessage: 'Incompatibilidad de vectores (${currentEmbedding.length} vs ${enrolledEmbedding.length})',
        );
      }

      // Algoritmo STR: Cálculo de Distancia Euclidiana Pura
      double sum = 0.0;
      for (int i = 0; i < currentEmbedding.length; i++) {
        double diff = currentEmbedding[i] - enrolledEmbedding[i];
        sum += diff * diff;
      }
      double euclideanDistance = sqrt(sum);

      // Umbral estricto de aceptación en biometría (0.6)
      // Menor distancia implica mayor similitud geométrica
      const double threshold = 0.6;
      bool isMatched = euclideanDistance < threshold;

      // Normalización matemática para mostrar porcentaje de confianza
      double confidence = (1.0 - (euclideanDistance / threshold)).clamp(0.0, 1.0);

      stopwatch.stop();
      
      // === ENFORZAMIENTO STR (T-VAL = 50ms) ===
      if (stopwatch.elapsedMilliseconds > STRConfig.DEADLINE_T_VAL) {
        await DatabaseService().logSTRMetrics(
          'T-VAL',
          stopwatch.elapsedMilliseconds.toDouble(),
          STRConfig.DEADLINE_T_VAL.toDouble()
        );
        _logger.e('FALLO STR: T-VAL excedio el plazo de ${STRConfig.DEADLINE_T_VAL}ms');
        throw Exception('STR_DEADLINE_MISS_VAL');
      }
      
      // === INSTRUMENTACIÓN STR: REGISTRO T-VAL ===
      // Código: T-VAL, Deadline Nominal de diseño: 50.0 ms
      await DatabaseService().logSTRMetrics(
        'T-VAL', 
        stopwatch.elapsedMilliseconds.toDouble(), 
        STRConfig.DEADLINE_T_VAL.toDouble()
      );

      _logger.i('Comparacion Euclidiana: distancia=$euclideanDistance, matched=$isMatched, confidence=${(confidence * 100).toStringAsFixed(1)}%');

      return FaceRecognitionResult(
        isMatched: isMatched,
        confidence: confidence,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      stopwatch.stop();
      if (e.toString().contains('STR_DEADLINE_MISS_VAL')) rethrow; // Pasa el error critico arriba
      _logger.e('Error en comparacion Euclidiana: $e');
      return FaceRecognitionResult(
        isMatched: false,
        confidence: 0.0,
        timestamp: DateTime.now().toIso8601String(),
        errorMessage: 'Error: $e',
      );
    }
  }

  /// Libera recursos
  Future<void> dispose() async {
    if (_isInitialized) {
      await _faceDetector.close();
      _isInitialized = false;
      _logger.i('FaceDetector liberado');
    }
  }
}
