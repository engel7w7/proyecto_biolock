import 'package:flutter/material.dart';
import '../services/service_locator.dart';
import '../services/bluetooth_service.dart';
import '../services/auth_service.dart';
import 'enrollment_screen.dart';
import 'settings_screen.dart';
import 'unlock_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late BluetoothService _bluetoothService;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _bluetoothService = getIt<BluetoothService>();
    _authService = getIt<AuthService>();
    _authService.loadPersistedUsers();
  }

  @override
  void dispose() {
    _bluetoothService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BioLock'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: const Color(0xFF6A3E7A),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.home_outlined, size: 26),
                text: 'Inicio',
              ),
              Tab(
                icon: Icon(Icons.person_add_alt_1_outlined, size: 26),
                text: 'Registrar',
              ),
              Tab(
                icon: Icon(Icons.tune_outlined, size: 26),
                text: 'Ajustes',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            _HomeTab(),
            _EnrollmentTab(),
            _SettingsTab(),
          ],
        ),
      ),
    );
  }
}

/// TAB 1: HOME
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  Widget build(BuildContext context) {
    final authService = getIt<AuthService>();
    final bluetoothService = getIt<BluetoothService>();
    final users = authService.getAllEnrolledUsers();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status card
          Card(
            elevation: 2,
            color: const Color(0xFF1A1F2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF1F5BA6), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.verified, size: 48, color: Color(0xFF1F5BA6)),
                  const SizedBox(height: 12),
                  const Text(
                    'Sistema Biométrico Activado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bluetooth ${bluetoothService.isConnected ? 'Conectado' : 'Desconectado'}',
                    style: TextStyle(
                      color: bluetoothService.isConnected ? Color(0xFF17A697) : Color(0xFFE53935),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Main unlock button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F5BA6),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UnlockScreen()),
            ),
            icon: const Icon(Icons.lock_open_outlined, size: 28),
            label: const Text(
              'Desbloquear',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Usuarios Registrados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          users.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF505050)),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF1A1F2E),
                  ),
                  child: const Text(
                    'No hay usuarios registrados',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) => Card(
                    color: const Color(0xFF1A1F2E),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: Color(0xFF1F5BA6),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1F5BA6),
                        child: Text(
                          users[index][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      title: Text(
                        users[index],
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            onTap: () => _renameUser(users[index]),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: Color(0xFF1F5BA6),
                                ),
                                SizedBox(width: 8),
                                Text('Renombrar'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            onTap: () => _deleteUser(users[index]),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Color(0xFFE53935),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _renameUser(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Renombrar Usuario',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Color(0xFFFFFFFF)),
          decoration: InputDecoration(
            hintText: 'Nuevo nombre',
            hintStyle: const TextStyle(color: Color(0xFF808080)),
            fillColor: Colors.white.withOpacity(0.05),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1F5BA6),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFFB0B0B0)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F5BA6),
            ),
            onPressed: () {
              getIt<AuthService>().renameUser(oldName, controller.text);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Usuario renombrado exitosamente'),
                  backgroundColor: Color(0xFF17A697),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(String userName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Eliminar usuario',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Estás a punto de eliminar a $userName. Esta acción no se puede deshacer.',
          style: const TextStyle(color: Color(0xFFB0B0B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFFB0B0B0)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () {
              getIt<AuthService>().deleteUser(userName);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Usuario eliminado exitosamente'),
                  backgroundColor: Color(0xFFE53935),
                ),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

/// TAB 2: ENROLLMENT
class _EnrollmentTab extends StatelessWidget {
  const _EnrollmentTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: const Color(0xFF1A1F2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: Color(0xFF1F5BA6),
                width: 1,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 48,
                    color: Color(0xFF1F5BA6),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Registrar Nuevo Usuario',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Captura tu rostro para crear acceso biométrico',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F5BA6),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EnrollmentScreen()),
            ),
            icon: const Icon(Icons.add_a_photo_outlined, size: 28),
            label: const Text(
              'Nuevo Registro',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TAB 3: SETTINGS
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.orange.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.tune_outlined, size: 48, color: Color(0xFFFFA500)),
                  SizedBox(height: 12),
                  Text(
                    'Configuración del Sistema',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFA500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Conectar Bluetooth'),
            subtitle: const Text('HC-05 / HC-06'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('Historial de Acceso'),
            subtitle: const Text('Auditoría y registros'),
            onTap: () => Navigator.pushNamed(context, '/audit'),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar Sesión'),
            subtitle: const Text('Desconectarse'),
            onTap: () {
              final authService = getIt<AuthService>();
              authService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
