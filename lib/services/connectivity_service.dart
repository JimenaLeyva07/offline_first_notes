import 'package:connectivity_plus/connectivity_plus.dart';

/// Expone si el dispositivo tiene conexión en este momento y un stream
/// que emite cada vez que cambia el estado (online <-> offline).
///
/// Este servicio es el "sensor" que dispara la sincronización: cuando
/// pasamos de offline a online, el repositorio escucha este stream y
/// procesa la cola de cambios pendientes.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged.map(
        (results) => _isOnline(results),
      );

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
