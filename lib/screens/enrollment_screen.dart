import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:async';
import '../services/service_locator.dart';
import '../services/camera_service.dart';
import '../services/face_detection_service.dart';
import '../services/auth_service.dart';
import '../widgets/camera_preview_widget.dart';

class EnrollmentScreen extends StatefulWidget {
  final Function(bool)? onEnrollmentComplete;

  const EnrollmentScreen({
    Key? key,
    this.onEnrollmentComplete,
  }) : super(key: key);

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  late CameraService _cameraService;
  late FaceDetectionService _faceDetectionService;
  late AuthService _authService;

  String? _userName;
  String? _userPassword;
  bool _cameraInitialized = false;
  bool _isProcessing = false;
  int _detectedFaceCount = 0;
  final int _requiredDetections = 3;
  String _statusMessage = 'Acerca tu rostro a la cámara...';
  Color _statusColor = Colors.blue;
  Timer? _timeoutTimer;
  bool _enrollmentDone = false;
  Face? _lastDetectedFace;
  
  bool _cameraFailure = false;
  String _cameraErrorMessage = '';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    // NO llamar a showDialog() en initState - el contexto no está listo
    // En su lugar, usar addPostFrameCallback
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initServices();
  }

  Future<void> _initServices() async {
    _cameraService = getIt<CameraService>();
    _faceDetectionService = getIt<FaceDetectionService>();
    _authService = getIt<AuthService>();
    
    // Mostrar diálogo después de que el widget esté montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showNameDialog();
      }
    });
  }

  void _showNameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Crear Nueva Cuenta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Nombre de usuario',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    hintText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordConfirmController,
                  obscureText: !_showPassword,
                  decoration: const InputDecoration(
                    hintText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _nameController.text.trim();
                final password = _passwordController.text;
                final passwordConfirm = _passwordConfirmController.text;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor ingresa un nombre')),
                  );
                  return;
                }

                if (password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor ingresa una contraseña')),
                  );
                  return;
                }

                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres')),
                  );
                  return;
                }

                if (password != passwordConfirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Las contraseñas no coinciden')),
                  );
                  return;
                }

                if (_authService.getAllEnrolledUsers().contains(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Este usuario ya está registrado'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                setState(() {
                  _userName = name;
                  _userPassword = password;
                });
                _initializeCamera();
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;
    
    try {
      print('[EnrollmentScreen] Starting camera initialization...');
      
      if (_cameraService.isInitialized && _cameraService.controller != null) {
        print('[EnrollmentScreen] Camera already ready');
        await _faceDetectionService.initialize();
        if (mounted) {
          setState(() => _cameraInitialized = true);
          _startDetection();
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
        print('[EnrollmentScreen] Timeout 15s');
        success = false;
      }

      if (!success) {
        print('[EnrollmentScreen] Camera init failed');
        if (mounted) {
          setState(() {
            _cameraFailure = true;
            _cameraErrorMessage = 'Cámara no disponible. Reinicia la app.';
          });
        }
        return;
      }

      print('[EnrollmentScreen] Camera ready');
      
      // Validate controller before proceeding
      if (_cameraService.controller == null) {
        print('[EnrollmentScreen] Controller is null after init');
        if (mounted) {
          setState(() {
            _cameraFailure = true;
            _cameraErrorMessage = 'Error de controlador. Reinicia la app.';
          });
        }
        return;
      }

      await _faceDetectionService.initialize();

      if (mounted) {
        setState(() => _cameraInitialized = true);
        _startDetection();
      }
    } catch (e) {
      print('❌ [EnrollmentScreen] Exception: $e');
      if (mounted) {
        setState(() {
          _cameraFailure = true;
          _cameraErrorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  void _startDetection() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!_enrollmentDone && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiempo agotado')),
        );
        Navigator.pop(context);
      }
    });

    _cameraService.startImageStream((image) async {
      if (_isProcessing || _enrollmentDone) return;

      _isProcessing = true;

      try {
        final faces = await _faceDetectionService.detectFaces(image);

        if (faces.isNotEmpty && _detectedFaceCount < _requiredDetections) {
          setState(() {
            _detectedFaceCount++;
            _statusColor = Colors.blue;
            _statusMessage = 'Rostro detectado ($_detectedFaceCount/$_requiredDetections)';
          });

          if (_detectedFaceCount >= _requiredDetections) {
            await _completeEnrollment(faces.first);
          }
        } else if (faces.isEmpty) {
          if (mounted) {
            setState(() {
              _statusColor = Colors.orange;
              _statusMessage = 'Acerca tu rostro a la cámara...';
            });
          }
        }
      } catch (e) {
        print('Error detectando: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<void> _completeEnrollment(Face detectedFace) async {
    setState(() {
      _enrollmentDone = true;
      _statusMessage = '✅ Registrando...';
      _statusColor = Colors.green;
    });

    _timeoutTimer?.cancel();
    await _cameraService.stopImageStream();

    try {
      final success = await _authService.enrollUser(
        _userName!,
        detectedFace,
        password: _userPassword,
      );

      if (mounted) {
        if (success) {
          await Future.delayed(const Duration(seconds: 1));
          _onEnrollmentComplete();
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error guardando usuario'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _onEnrollmentComplete() {
    _cameraService.dispose();
    _faceDetectionService.dispose();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Usuario $_userName registrado correctamente'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Navegar directo a HomeScreen
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _timeoutTimer?.cancel();
    _cameraService.stopImageStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Usuario'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0066CC),
      ),
      body: _cameraFailure
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _cameraErrorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _cameraFailure = false;
                        _cameraErrorMessage = '';
                      });
                      _initializeCamera();
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
          : !_cameraInitialized
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Inicializando cámara...'),
                    ],
                  ),
                )
              : _cameraService.controller == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Error: Controlador de cámara no disponible',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _cameraInitialized = false;
                                _cameraFailure = false;
                              });
                              _initializeCamera();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        CameraPreviewWidget(
                          controller: _cameraService.controller!,
                          isAuthorized: true,
                        ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _statusColor.withAlpha(40),
                          border: Border.all(color: _statusColor, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: _detectedFaceCount / _requiredDetections,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
