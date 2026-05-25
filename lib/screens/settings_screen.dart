import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/service_locator.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late BluetoothService _bluetoothService;
  List<BluetoothDevice> _availableDevices = [];
  bool _isLoading = false;
  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _bluetoothService = getIt<BluetoothService>();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    
    try {
      final devices = await _bluetoothService.getAvailableDevices();
      setState(() {
        _availableDevices = devices;
        _isConnected = _bluetoothService.isConnected;
        _connectedDevice = _bluetoothService.connectedDevice;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _bluetoothService.connect(device);
      
      if (mounted) {
        if (success) {
          setState(() {
            _isConnected = true;
            _connectedDevice = device;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conectado a ${device.name}'),
              backgroundColor: const Color(0xFF17A697),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo conectar a ${device.name}'),
              backgroundColor: const Color(0xFFE53935),
            ),
          );
        }
        
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _disconnect() async {
    await _bluetoothService.disconnect();
    setState(() {
      _isConnected = false;
      _connectedDevice = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Desconectado'),
        backgroundColor: Color(0xFF808080),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A1F2E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Estado actual de Bluetooth
            Card(
              elevation: 2,
              color: const Color(0xFF1A1F2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _isConnected ? const Color(0xFF17A697) : const Color(0xFF505050),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      size: 48,
                      color: _isConnected ? const Color(0xFF17A697) : const Color(0xFF808080),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bluetooth ${_isConnected ? 'Conectado' : 'Desconectado'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _isConnected ? const Color(0xFF17A697) : const Color(0xFFB0B0B0),
                      ),
                    ),
                    if (_connectedDevice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Dispositivo: ${_connectedDevice!.name}',
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _disconnect,
                        icon: const Icon(Icons.close),
                        label: const Text('Desconectar'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Dispositivos disponibles
            const Text(
              'Dispositivos Disponibles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_availableDevices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF505050)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.bluetooth_disabled, color: Color(0xFF808080)),
                    SizedBox(height: 8),
                    Text(
                      'No hay dispositivos emparejados',
                      style: TextStyle(color: Color(0xFFB0B0B0)),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availableDevices.length,
                itemBuilder: (context, index) {
                  final device = _availableDevices[index];
                  final isThis = _connectedDevice?.address == device.address;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: const Color(0xFF1A1F2E),
                    child: ListTile(
                      leading: Icon(
                        Icons.bluetooth,
                        color: isThis ? const Color(0xFF17A697) : const Color(0xFF1F5BA6),
                      ),
                      title: Text(
                        device.name,
                        style: const TextStyle(color: Color(0xFFFFFFFF)),
                      ),
                      subtitle: Text(
                        device.address,
                        style: const TextStyle(color: Color(0xFFB0B0B0)),
                      ),
                      trailing: isThis
                          ? const Chip(
                              label: Text('Conectado'),
                              backgroundColor: Color(0xFF17A697),
                              labelStyle: TextStyle(color: Colors.white),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F5BA6),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => _connectToDevice(device),
                              child: const Text('Conectar'),
                            ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F5BA6),
              ),
              onPressed: _isLoading ? null : _loadDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar Dispositivos'),
            ),
          ],
        ),
      ),
    );
  }
}
