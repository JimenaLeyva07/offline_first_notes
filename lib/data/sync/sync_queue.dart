import '../../models/note.dart';
import '../local/notes_local_datasource.dart';
import '../remote/notes_remote_datasource.dart';

/// Recorre las notas marcadas como pendientes y las reenvía al servidor
/// en orden. Esta es la estrategia de "cola de sincronización": cada
/// operación offline (crear/editar/borrar) queda registrada en el propio
/// modelo local vía `syncStatus`, y esta clase se encarga de "drenar"
/// esa cola cuando hay conexión.
class SyncQueue {
  final NotesLocalDataSource local;
  final NotesRemoteDataSource remote;

  SyncQueue({required this.local, required this.remote});

  /// Devuelve true si hubo al menos un cambio sincronizado.
  Future<bool> drain() async {
    // Usamos getAllRaw() porque getAll() oculta a propósito las notas
    // pendientes de borrado (no queremos que reaparezcan en la UI).
    final toProcess = local
        .getAllRaw()
        .where((n) => n.syncStatus != SyncStatus.synced)
        .toList();

    if (toProcess.isEmpty) return false;

    for (final note in toProcess) {
      switch (note.syncStatus) {
        case SyncStatus.pendingCreate:
          final synced = await remote.create(note);
          // Con otras API, `synced.id` puede venir distinto al id local
          // temporal (`note.id`) porque el servidor asigna su propio id
          // al crear. replaceId() "muda" el registro de Hive a la
          // clave correcta. Con JSONBin esto es un no-op (los ids
          // coinciden), así que el mismo código sirve para ambos
          // backends sin ramas condicionales.
          await local.replaceId(note.id, synced);
          break;
        case SyncStatus.pendingUpdate:
          final synced = await remote.update(note);
          await local.upsert(synced);
          break;
        case SyncStatus.pendingDelete:
          await remote.delete(note.id);
          await local.hardDelete(note.id);
          break;
        case SyncStatus.synced:
          break; // No debería llegar aquí.
      }
    }
    return true;
  }
}
