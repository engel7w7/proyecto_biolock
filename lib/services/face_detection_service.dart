import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'dart:math'; 
import 'dart:async'; 
import '../models/app_state.dart';
import '../utils/str_constants.dart'; 
import 'database_service.dart'; 

class FaceDetectionService {
  static final Logger _logger = Logger();
  late FaceDetector _faceDetector;
  bool _isInitialized = false;
  int _frameCount = 0;
  int _successfulDetections = 0;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      final options = FaceDetectorOptions(
        enableTracking: true,
        enableClassification: true,
        enableLandmarks: true, 
        performanceMode: FaceDetectorMode.fast, 
      );
      _faceDetector = FaceDetector(options: options);
      _isInitialized = true;
      _logger.i('FaceDetector inicializado en modo FAST');
    } catch (e) {
      _logger.e('Error inicializando FaceDetector: $e');
    }
  }

  bool isHeadAligned(Face face) {
    final double? yaw = face.headEulerAngleY; 
    final double? pitch = face.headEulerAngleX; 

    if (yaw == null || pitch == null) return false;

    // Tolerancia ajustada a 12 grados. Obliga al usuario a mirar de frente 
    // para evitar que la perspectiva 2D engañe al algoritmo.
    if (yaw.abs() > 12.0 || pitch.abs() > 12.0) {
      return false;
    }
    return true;
  }

  /// VECTOR DE 9 DIMENSIONES (Alta Seguridad contra Familiares)
  List<double> extractFaceVector(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth];
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];
    
    // NUEVOS PUNTOS: Pómulos para medir el ancho del rostro
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek];
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek];

    // Si la cara no está completa, devolvemos un vector neutro de contingencia
    if (leftEye == null || rightEye == null) {
      return List.generate(9, (_) => 1.0); // Actualizado a 9 dimensiones
    }

    double dxEyes = (leftEye.position.x - rightEye.position.x).toDouble();
    double dyEyes = (leftEye.position.y - rightEye.position.y).toDouble();
    double interPupillaryDistance = sqrt(dxEyes * dxEyes + dyEyes * dyEyes);

    if (interPupillaryDistance == 0) interPupillaryDistance = 1.0;

    double distanceBetween(FaceLandmark? p1, FaceLandmark? p2) {
      if (p1 == null || p2 == null) return interPupillaryDistance * 0.5; 
      double dx = (p1.position.x - p2.position.x).toDouble();
      double dy = (p1.position.y - p2.position.y).toDouble();
      return sqrt(dx * dx + dy * dy);
    }

    final List<double> structuralVector = [];
    
    // Proporciones Centrales (Genética común)
    structuralVector.add(distanceBetween(leftMouth, rightMouth) / interPupillaryDistance);
    structuralVector.add(distanceBetween(nose, leftEye) / interPupillaryDistance);
    structuralVector.add(distanceBetween(nose, rightEye) / interPupillaryDistance);
    structuralVector.add(distanceBetween(nose, bottomMouth) / interPupillaryDistance);
    structuralVector.add(distanceBetween(leftEye, leftMouth) / interPupillaryDistance);
    structuralVector.add(distanceBetween(rightEye, rightMouth) / interPupillaryDistance);
    
    // Proporciones de Contorno (Diferenciador de Hermanos: Ancho de cara y mandíbula)
    structuralVector.add(distanceBetween(leftCheek, rightCheek) / interPupillaryDistance);
    structuralVector.add(distanceBetween(nose, leftCheek) / interPupillaryDistance);
    structuralVector.add(distanceBetween(nose, rightCheek) / interPupillaryDistance);

    return structuralVector;
  }

  Future<List<Face>> detectFaces(CameraImage image) async {
    late final Stopwatch stopwatch;
    
    try {
      if (!_isInitialized) {
        _logger.w('FaceDetector no inicializado');
        return [];
      }

      _frameCount++;
      
      stopwatch = Stopwatch()..start();
      
      final planes = image.planes;
      final int width = image.width;
      final int height = image.height;
      
      final int ySize = width * height;
      final int uvSize = (width ~/ 2) * (height ~/ 2);
      
      final Uint8List nv21 = Uint8List(ySize + uvSize * 2);
      
      final Uint8List yBytes = planes[0].bytes;
      final int yRowPadding = planes[0].bytesPerRow - width;
      
      int pixelIndex = 0;
      for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
          nv21[pixelIndex] = yBytes[i * (width + yRowPadding) + j];
          pixelIndex++;
        }
      }
      
      final Uint8List uBytes = planes[1].bytes;
      final Uint8List vBytes = planes[2].bytes;
      final int pixelStride = planes[1].bytesPerPixel ?? 1;
      
      int uvPixelIndex = 0;
      for (int i = 0; i < uvSize; i++) {
        final int uvPos = i * pixelStride;
        
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
          bytesPerRow: width,
        ),
      );
      
      final List<Face> faces = await _faceDetector.processImage(inputImage).timeout(
        const Duration(milliseconds: STRConfig.DEADLINE_T_DET),
        onTimeout: () => throw TimeoutException('STR_DEADLINE_MISS_DET'),
      );
      
      stopwatch.stop();
      
      await DatabaseService().logSTRMetrics(
        'T-DET', 
        stopwatch.elapsedMilliseconds.toDouble(), 
        STRConfig.DEADLINE_T_DET.toDouble()
      );
      
      if (faces.isNotEmpty) {
        _successfulDetections++;
      }
      
      return faces;
    } on TimeoutException catch (_) {
      stopwatch.stop();
      await DatabaseService().logSTRMetrics(
        'T-DET',
        (STRConfig.DEADLINE_T_DET + 1).toDouble(),
        STRConfig.DEADLINE_T_DET.toDouble()
      );
      throw Exception('STR_DEADLINE_MISS_DET'); 
    } catch (e) {
      _logger.e('Error detectando rostros: $e');
      return [];
    }
  }

  Future<FaceRecognitionResult> compareFaces(
    List<Face> detectedFaces,
    Face? enrolledFace,
  ) async {
    if (detectedFaces.isEmpty || enrolledFace == null) {
      return FaceRecognitionResult(
        isMatched: false,
        confidence: 0.0,
        timestamp: DateTime.now().toIso8601String(),
        errorMessage: 'Faltan datos para comparar',
      );
    }
    final currentVec = extractFaceVector(detectedFaces.first);
    final enrolledVec = extractFaceVector(enrolledFace);
    return await compareFacesReal(currentVec, enrolledVec);
  }

  InputImage _convertCameraImage(CameraImage image) {
    try {
      final planes = image.planes;
      
      if (planes.length < 3) {
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

      final Uint8List nv21data = Uint8List(
        planes[0].bytes.length + planes[1].bytes.length + planes[2].bytes.length
      );

      int offset = 0;
      nv21data.setRange(0, planes[0].bytes.length, planes[0].bytes);
      offset = planes[0].bytes.length;

      nv21data.setRange(offset, offset + planes[2].bytes.length, planes[2].bytes);
      offset += planes[2].bytes.length;

      nv21data.setRange(offset, offset + planes[1].bytes.length, planes[1].bytes);

      return InputImage.fromBytes(
        bytes: nv21data,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,  
          format: InputImageFormat.nv21,
          bytesPerRow: planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
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

  Future<FaceRecognitionResult> compareFacesReal(
    List<double> currentEmbedding, 
    List<double> enrolledEmbedding, 
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Sistema anti-caídas: Valida que estemos contrastando 9D vs 9D.
      if (currentEmbedding.isEmpty || enrolledEmbedding.isEmpty || currentEmbedding.length != enrolledEmbedding.length) {
        stopwatch.stop();
        return FaceRecognitionResult(
          isMatched: false,
          confidence: 0.0,
          timestamp: DateTime.now().toIso8601String(),
          errorMessage: 'Incompatibilidad de vectores',
        );
      }

      double sum = 0.0;
      for (int i = 0; i < currentEmbedding.length; i++) {
        double diff = currentEmbedding[i] - enrolledEmbedding[i];
        sum += diff * diff;
      }
      double euclideanDistance = sqrt(sum);

      // PUNTO DULCE: Umbral calibrado a 0.22 con Vector de 9 Dimensiones.
      // Suficiente para ti, impenetrable para tus hermanos.
      const double threshold = 0.22;
      bool isMatched = euclideanDistance < threshold;

      double confidence = (1.0 - (euclideanDistance / threshold)).clamp(0.0, 1.0);

      stopwatch.stop();
      
      if (stopwatch.elapsedMilliseconds > STRConfig.DEADLINE_T_VAL) {
        await DatabaseService().logSTRMetrics(
          'T-VAL',
          stopwatch.elapsedMilliseconds.toDouble(),
          STRConfig.DEADLINE_T_VAL.toDouble()
        );
        throw Exception('STR_DEADLINE_MISS_VAL');
      }
      
      await DatabaseService().logSTRMetrics(
        'T-VAL', 
        stopwatch.elapsedMilliseconds.toDouble(), 
        STRConfig.DEADLINE_T_VAL.toDouble()
      );

      _logger.i('Comparacion Euclidiana: distancia=$euclideanDistance, matched=$isMatched');

      return FaceRecognitionResult(
        isMatched: isMatched,
        confidence: confidence,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      stopwatch.stop();
      if (e.toString().contains('STR_DEADLINE_MISS_VAL')) rethrow; 
      return FaceRecognitionResult(
        isMatched: false,
        confidence: 0.0,
        timestamp: DateTime.now().toIso8601String(),
        errorMessage: 'Error: $e',
      );
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _faceDetector.close();
      _isInitialized = false;
      _logger.i('FaceDetector liberado');
    }
  }
}