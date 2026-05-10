import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../services/service_locator.dart';
import '../services/camera_service.dart';
import '../services/face_detection_service.dart';
import '../services/bluetooth_service.dart';
import '../services/auth_service.dart';
import '../widgets/camera_preview_widget.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({Key? key}) : super(key: key);

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  late CameraService _cameraService;
  late FaceDetectionService _faceDetectionService;
  late BluetoothService _bluetoothService;
  late AuthService _authService;

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _cameraFailed = false;
  String _statusMessage = 'Inicializando cámara...';
  Color _statusColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _initializeUnlock();
  }

  Future<void> _initializeUnlock() async {
    if (!mounted) return;
    
    try {
      _cameraService = getIt<CameraService>();
      _faceDetectionService = getIt<FaceDetectionService>();
      _bluetoothService = getIt<BluetoothService>();
      _authService = getIt<AuthService>();

      print('[UnlockScreen] Starting camera initialization...');
      
      if (_cameraService.isInitialized && _cameraService.controller != null) {
        print('[UnlockScreen] Camera already ready');
        await _faceDetectionService.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _statusMessage = 'Acerca tu rostro a la cámara...';
            _statusColor = const Color(0xFF00E5FF);
          });
          _startFaceDetection();
        }
        return;
      }
      
      // **15 segundos máximo** - Tiempo para hardware muy lento
      bool success = false;
      try {
        success = await _cameraService.initializeCamera().timeout(
          const Duration(seconds: 15),
        );
      } on TimeoutException {
        print('[UnlockScreen] Timeout 15s');
        success = false;
      }

      if (!success) {
        print('[UnlockScreen] Camera init failed');
        if (mounted) {
          setState(() {
            _cameraFailed = true;
            _statusMessage = 'Cámara no disponible';
          });
        }
        return;
      }

      // Validate controller before proceeding
      if (_cameraService.controller == null) {
        print('[UnlockScreen] Controller is null after init');
        if (mounted) {
          setState(() {
            _cameraFailed = true;
            _statusMessage = 'Error de controlador';
          });
        }
        return;
      }

      print('[UnlockScreen] Camera ready');
      await _faceDetectionService.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Acerca tu rostro a la cámara...';
          _statusColor = Colors.blue;
        });
        _startFaceDetection();
      }
    } catch (e) {
      print('❌ [UnlockScreen] Exception: $e');
      if (mounted) {
        setState(() {
          _cameraFailed = true;
          _statusMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  void _startFaceDetection() {
    _cameraService.startImageStream((image) async {
      if (_isProcessing) return;

      _isProcessing = true;

      try {
        final faces = await _faceDetectionService.detectFaces(image);

        if (faces.isNotEmpty) {
          // Rostro detectado - intentar autenticar
          final result = _authService.authenticateWithFace(faces.first);

          if (mounted) {
            if (result.isMatched) {
              setState(() {
                _statusMessage = '✅ ¡Acceso Concedido!';
                _statusColor = Colors.green;
              });

              await _bluetoothService.openLock();

              await Future.delayed(const Duration(seconds: 2));

              if (mounted) {
                Navigator.pop(context, true);
              }
            } else {
              setState(() {
                _statusMessage = '❌ Rostro no reconocido';
                _statusColor = Colors.red;
              });

              await Future.delayed(const Duration(seconds: 2));

              if (mounted) {
                setState(() {
                  _statusMessage = 'Acerca tu rostro a la cámara...';
                  _statusColor = Colors.blue;
                });
              }
            }
          }
        } else {
          if (mounted && _statusColor != Colors.blue) {
            setState(() {
              _statusMessage = 'Acerca tu rostro a la cámara...';
              _statusColor = Colors.blue;
            });
          }
        }
      } catch (e) {
        print('Error: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  @override
  void dispose() {
    _cameraService.stopImageStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desbloquear'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6A3E7A),
      ),
      body: _cameraFailed
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _cameraFailed = false;
                        _isInitialized = false;
                        _statusMessage = 'Inicializando cámara...';
                      });
                      _initializeUnlock();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                  ),
                ],
              ),
            )
          : _isInitialized && _cameraService.controller != null
              ? Stack(
                  children: [
                    // Vista previa de cámara
                    CameraPreviewWidget(
                      controller: _cameraService.controller!,
                      isAuthorized: true,
                    ),
                    // Overlay con status
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.2),
                            border: Border.all(color: _statusColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _statusColor == Colors.green
                                    ? Icons.check_circle
                                    : _statusColor == Colors.red
                                        ? Icons.cancel
                                        : Icons.info,
                                color: _statusColor,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
              : _isInitialized && _cameraService.controller == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Error de controlador de cámara',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            label: const Text('Volver'),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_statusMessage),
                        ],
                      ),
                    ),
    );
  }
}
