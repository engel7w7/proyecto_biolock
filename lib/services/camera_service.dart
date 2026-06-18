import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'dart:async';

class CameraService {
  static final Logger _logger = Logger();
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  // NUEVA VARIABLE: Para saber qué cámara estamos usando actualmente (Frontal o Trasera)
  CameraLensDirection _currentDirection = CameraLensDirection.front;

  bool get isInitialized => _controller != null && _controller!.value.isInitialized;
  CameraController? get controller => _controller;
  
  // NUEVO GETTER: Permite a otros servicios saber la orientación de la cámara
  CameraLensDirection get currentDirection => _currentDirection;

  /// Inicializa la cámara
  // MODIFICADO: Ahora acepta la dirección de la lente por parámetro (Frontal por defecto)
  Future<bool> initializeCamera({CameraLensDirection direction = CameraLensDirection.front}) async {
    try {
      // Limpiar controlador anterior si existe
      print('[CameraService] Cleaning up previous controller...');
      await _cleanupAsync();
      await Future.delayed(const Duration(milliseconds: 200));
      
      print('[CameraService] Step 1: Requesting permission');
      
      final cameraStatus = await Permission.camera.request();
      print('[CameraService] Permission: $cameraStatus');
      
      if (!cameraStatus.isGranted) {
        print('[CameraService] Permission denied');
        return false;
      }

      print('[CameraService] Permission granted');
      print('[CameraService] Step 2: Getting available cameras');
      
      // Obtener cámaras disponibles
      _cameras = await availableCameras();
      print('[CameraService] Available cameras: ${_cameras?.length ?? 0}');
      
      if (_cameras == null || _cameras!.isEmpty) {
        print('[CameraService] No cameras available');
        return false;
      }
      
      // Actualizamos nuestra variable de control interno
      _currentDirection = direction;

      // Buscar la cámara solicitada (Frontal o Trasera según el parámetro)
      CameraDescription? selectedCamera;
      for (var camera in _cameras!) {
        print('[CameraService] Camera: ${camera.name}, Lens: ${camera.lensDirection}');
        if (camera.lensDirection == direction) {
          selectedCamera = camera;
          break;
        }
      }
      
      // Contingencia por si el dispositivo no tiene la cámara solicitada
      if (selectedCamera == null) {
        print('[CameraService] Requested camera not found, using first available');
        selectedCamera = _cameras!.first;
        _currentDirection = selectedCamera.lensDirection; // Actualizamos a lo que realmente se usó
      }

      print('[CameraService] Step 3: Creating NEW controller for camera ${selectedCamera.name}');
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      print('[CameraService] Step 4: Calling initialize (TIMEOUT 15s)');
      
      try {
        await _controller!.initialize().timeout(
          const Duration(seconds: 15),
        );
      } on TimeoutException {
        print('[CameraService] initialize() TIMEOUT 15s - disposing controller');
        try {
          await _controller!.dispose();
        } catch (_) {}
        _controller = null;
        return false;
      }
      
      print('[CameraService] Camera initialized successfully');
      return true;
      
    } catch (e) {
      print('[CameraService] Error: $e');
      await _cleanupAsync();
      return false;
    }
  }

  Future<void> _cleanupAsync() async {
    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.dispose();
      } catch (e) {
        print('[CameraService] Error during cleanup: $e');
      }
      _controller = null;
    }
  }

  /// Inicia la captura de frames
  void startImageStream(Function(CameraImage) onImageAvailable) {
    if (_controller != null && _controller!.value.isInitialized) {
      // Validación extra para evitar "Camera is already streaming"
      if (!_controller!.value.isStreamingImages) {
        _controller!.startImageStream(onImageAvailable);
        _logger.i('Stream de cámara iniciado');
      }
    }
  }

  /// Detiene la captura de frames
  Future<void> stopImageStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
      _logger.i('Stream de cámara detenido');
    }
  }

  /// Captura una foto
  Future<XFile?> takePicture() async {
    try {
      if (!isInitialized) return null;
      final XFile image = await _controller!.takePicture();
      _logger.i('Foto capturada: ${image.path}');
      return image;
    } catch (e) {
      _logger.e('Error capturando foto: $e');
      return null;
    }
  }

  /// Limpia la cámara de forma asincrónica
  Future<void> dispose() async {
    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.dispose();
        print('[CameraService] Camera disposed cleanly');
      } catch (e) {
        print('[CameraService] Error disposing: $e');
      } finally {
        _controller = null;
      }
    }
  }
}