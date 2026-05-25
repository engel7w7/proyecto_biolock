import 'dart:convert';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'; // Librería nativa hardware
import 'package:permission_handler/permission_handler.dart';
import 'database_service.dart';

class BluetoothDevice {
  final String address;
  final String name;
  
  BluetoothDevice({required this.address, required this.name});
}

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final _logger = Logger();
  
  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;
  BluetoothConnection? _connection; // Conexión por socket RFCOMM real

  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Obtiene los dispositivos vinculados físicamente en el teléfono Android
  Future<List<BluetoothDevice>> getAvailableDevices() async {
    _logger.i('📱 Buscando dispositivos vinculados en el sistema...');
    try {
      // Solicitar permisos de Bluetooth para Android 12+
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      
      if (!bluetoothConnectStatus.isGranted || !bluetoothScanStatus.isGranted) {
        _logger.w('⚠️ Permisos de Bluetooth denegados');
        return [];
      }
      
      final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      return bondedDevices.map((d) => BluetoothDevice(
        address: d.address!, 
        name: d.name ?? 'Dispositivo desconocido'
      )).toList();
    } catch (e) {
      _logger.e('Error mapeando hardware Bluetooth: $e');
      return [];
    }
  }

  /// Establece el canal de datos síncrono con el ESP32
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _logger.i('🔗 Abriendo Socket RFCOMM hacia ${device.name} [${device.address}]...');
      
      _connection = await BluetoothConnection.toAddress(device.address);
      
      _isConnected = true;
      _connectedDevice = device;
      _logger.i('✅ Conexión establecida por hardware con éxito');

      // Escucha en segundo plano para evitar hilos bloqueados (Manejador de Comunicaciones)
      _connection!.input!.listen((Uint8List data) {
        String msg = utf8.decode(data);
        _logger.d('📥 Datos entrantes desde ESP32: $msg');
      }).onDone(() {
        _logger.w('💔 El canal remoto cerró la conexión');
        _isConnected = false;
        _connectedDevice = null;
      });

      return true;
    } catch (e) {
      _logger.e('✗ Fallo crítico en apertura de Socket: $e');
      _isConnected = false;
      _connectedDevice = null;
      return false;
    }
  }

  /// Libera el puerto y cierra el descriptor del socket
  Future<void> disconnect() async {
    try {
      if (_connection != null && _connection!.isConnected) {
        await _connection!.close();
        _isConnected = false;
        _connectedDevice = null;
        _logger.i('💔 Puerto serial liberado correctamente');
      }
    } catch (e) {
      _logger.e('✗ Error cerrando descriptor de Socket: $e');
    }
  }

  /// Envía un byte de comando y mide T-BTX con precisión de tiempo real
  Future<bool> sendCommand(String command) async {
    if (!_isConnected || _connection == null || !_connection!.isConnected) {
      _logger.w('⚠ Error: Tráfico denegado. Sin enlace de hardware activo.');
      return false;
    }

    // === INSTRUMENTACIÓN STR: INICIO MEDICIÓN T-BTX ===
    final stopwatch = Stopwatch()..start();

    try {
      _connection!.output.add(utf8.encode(command));
      await _connection!.output.allSent; // Fuerza el vaciado del búfer de salida serial
      
      stopwatch.stop();
      // === INSTRUMENTACIÓN STR: REGISTRO T-BTX ===
      // Código: T-BTX, Deadline Nominal de diseño: 10.0 ms
      await DatabaseService().logSTRMetrics(
        'T-BTX', 
        stopwatch.elapsedMilliseconds.toDouble(), 
        10.0
      );

      _logger.i('📤 Stream serial despachado: "$command"');
      return true;
    } catch (e) {
      stopwatch.stop();
      _logger.e('✗ Error en transmisión de flujo serial: $e');
      return false;
    }
  }

  /// Envía la orden de apertura ('1') al ESP32
  Future<bool> openLock() async {
    _logger.i('🔓 Comando de validación biométrica positiva concedida.');
    return await sendCommand('1');
  }

  /// Envía la orden de rechazo ('0') al ESP32 para activar Buzzer y LED Rojo
  Future<bool> rejectAccess() async {
    _logger.i('🔒 Comando de validación biométrica negativa/rechazo.');
    return await sendCommand('0');
  }

  Future<bool> isBluetoothAvailable() async {
    return await FlutterBluetoothSerial.instance.isAvailable ?? false;
  }
}

