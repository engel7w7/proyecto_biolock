import 'package:logger/logger.dart';

/// Simula un dispositivo Bluetooth
class BluetoothDevice {
  final String address;
  final String name;
  
  BluetoothDevice({required this.address, required this.name});
}

/// Servicio de Bluetooth simulado (para desarrollo)
/// En producción, reemplazarcon flutter_bluetooth_serial_module o native
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final _logger = Logger();
  
  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;

  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Obtener dispositivos emparejados disponibles
  Future<List<BluetoothDevice>> getAvailableDevices() async {
    _logger.i('📱 Buscando dispositivos Bluetooth...');
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Simulación de dispositivos HC-05 típicos
    return [
      BluetoothDevice(address: '00:1A:7D:DA:71:13', name: 'HC-05'),
      BluetoothDevice(address: '00:21:13:00:ED:8F', name: 'HC-06'),
    ];
  }

  /// Conectar a un dispositivo Bluetooth específico
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _logger.i('🔗 Conectando a ${device.name}...');
      await Future.delayed(const Duration(milliseconds: 800));
      
      _isConnected = true;
      _connectedDevice = device;
      _logger.i('✅ Conectado a ${device.name}');
      return true;
    } catch (e) {
      _logger.e('✗ Error conectando: $e');
      return false;
    }
  }

  /// Desconectar del dispositivo actual
  Future<void> disconnect() async {
    try {
      if (_isConnected) {
        _isConnected = false;
        _connectedDevice = null;
        _logger.i('💔 Desconectado');
      }
    } catch (e) {
      _logger.e('✗ Error desconectando: $e');
    }
  }

  /// Enviar comando al ESP32 (simulado)
  Future<bool> sendCommand(String command) async {
    try {
      if (!_isConnected) {
        _logger.w('⚠ No hay conexión Bluetooth');
        return false;
      }

      _logger.i('📤 Comando enviado: "$command"');
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    } catch (e) {
      _logger.e('✗ Error enviando comando: $e');
      return false;
    }
  }

  /// Abrir cerradura (enviar '1' al ESP32)
  Future<bool> openLock() async {
    _logger.i('🔓 Enviando comando de apertura...');
    return await sendCommand('1');
  }

  /// Verificar si Bluetooth está disponible
  Future<bool> isBluetoothAvailable() async {
    return true; // Simulado
  }
}



