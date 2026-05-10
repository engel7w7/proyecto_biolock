import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'dart:async';

class CameraService {
  static final Logger _logger = Logger();
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  bool get isInitialized => _controller != null && _controller!.value.isInitialized;
  CameraController? get controller => _controller;

  /// Inicializa la cámara
  Future<bool> initializeCamera() async {
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
      
      // Buscar cámara frontal
      CameraDescription? frontCamera;
      for (var camera in _cameras!) {
        print('[CameraService] Camera: ${camera.name}, Lens: ${camera.lensDirection}');
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }
      
      if (frontCamera == null) {
        print('[CameraService] Front camera not found, using first available');
        frontCamera = _cameras!.first;
      }

      print('[CameraService] Step 3: Creating NEW controller for camera ${frontCamera.name}');
      _controller = CameraController(
        frontCamera,
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
      _controller!.startImageStream(onImageAvailable);
      _logger.i('Stream de cámara iniciado');
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
