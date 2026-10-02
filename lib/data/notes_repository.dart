import 'dart:async';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../services/connectivity_service.dart';
import 'local/notes_local_datasource.dart';
import 'remote/notes_remote_datasource.dart';
import 'sync/sync_queue.dart';

/// Punto único por el que la UI habla con los datos.
///
/// Implementa la estrategia "cache-first + sync queue + polling":
///  1. Toda lectura sale de Hive (instantánea, funciona offline).
///  2. Toda escritura se guarda primero en Hive (UI optimista) y se
///     marca como pendiente.
///  3. Cuando hay conexión, se intenta enviar de inmediato; si falla o
///     no hay red, queda en la cola para el próximo intento.
///  4. Al detectar que volvimos a estar online,
///     subimos nuestros cambios y se refresca la caché con la verdad
///     del servidor (bajamos los cambios de otros dispositivos).
///  5. Mientras hay conexión, un timer hace esto mismo cada pocos
///     segundos (polling).
class NotesRepository {
  final NotesLocalDataSource local;
  final NotesRemoteDataSource remote;
  final ConnectivityService connectivity;
  late final SyncQueue _syncQueue;

  final Duration pollInterval;

  final _uuid = const Uuid();
  final _notesController = StreamController<List<Note>>.broadcast();
  StreamSubscription<bool>? _connectivitySub;
  Timer? _pollTimer;

  NotesRepository({
    required this.local,
    required this.remote,
    required this.connectivity,
    this.pollInterval = const Duration(seconds: 5),
  }) {
    _syncQueue = SyncQueue(local: local, remote: remote);
    _connectivitySub = connectivity.onStatusChange.listen((isOnline) {
      if (isOnline) _syncNow();
    });
    _pollTimer = Timer.periodic(pollInterval, (_) => _syncNow());
  }

  /// Sube lo pendiente y baja lo nuevo del servidor, en ese orden.
  Future<void> _syncNow() async {
    if (!await connectivity.isOnline) return;
    await _syncPending();
    await _refreshFromServer();
  }

  /// Stream que la UI escucha para pintar la lista de notas.
  Stream<List<Note>> watchNotes() {
    _emit();
    return _notesController.stream;
  }

  void _emit() => _notesController.add(local.getAll());

  /// Carga inicial: pinta caché al instante y refresca desde red si hay
  /// conexión (estrategia cache-first / stale-while-revalidate).
  Future<void> initialLoad() async {
    _emit(); // 1) Lo que ya tengamos en caché, sin esperar nada.
    if (await connectivity.isOnline) {
      await _refreshFromServer();
      await _syncPending();
    }
  }

  Future<void> _refreshFromServer() async {
    try {
      final serverNotes = await remote.fetchAll();
      await local.replaceSyncedData(serverNotes);
      _emit();
    } catch (_) {
      // Si falla la red, simplemente nos quedamos con lo que hay en
      // caché: la app sigue siendo usable.
    }
  }

  Future<void> createNote(String title, String content) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingCreate,
    );
    await local.upsert(note); // Escritura optimista: la UI la ve YA.
    _emit();
    await _trySyncOne(note);
  }

  Future<void> updateNote(Note note, {String? title, String? content}) async {
    final updated = note.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now(),
      syncStatus: note.syncStatus == SyncStatus.pendingCreate
          ? SyncStatus.pendingCreate // Sigue sin existir en el server.
          : SyncStatus.pendingUpdate,
    );
    await local.upsert(updated);
    _emit();
    await _trySyncOne(updated);
  }

  Future<void> deleteNote(Note note) async {
    if (note.syncStatus == SyncStatus.pendingCreate) {
      // Nunca llegó a existir en el servidor: podemos borrarla directo.
      await local.hardDelete(note.id);
    } else {
      await local.markDeleted(note.id);
    }
    _emit();
    await _syncPending();
  }

  /// Intenta sincronizar una nota puntual de inmediato (para feedback
  /// rápido); si no hay red, se queda pendiente y la drenará `SyncQueue`
  /// más tarde.
  Future<void> _trySyncOne(Note note) async {
    if (!await connectivity.isOnline) return;
    await _syncPending();
  }

  Future<void> _syncPending() async {
    if (!await connectivity.isOnline) return;
    try {
      final changed = await _syncQueue.drain();
      if (changed) _emit();
    } catch (_) {
      // Sin red real a mitad de camino: puede que algunas notas de la
      // cola sí se hayan alcanzado a sincronizar antes del fallo, así
      // que igual refrescamos la UI con lo que se alcanzó a guardar.
      _emit();
    }
  }

  /// Botón de "sincronizar ahora"
  Future<void> forceSync() async {
    if (await connectivity.isOnline) {
      await _refreshFromServer();
      await _syncPending();
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pollTimer?.cancel();
    _notesController.close();
  }
}
