import 'package:hive/hive.dart';
import '../../models/note.dart';

/// La UI SIEMPRE lee de aquí, nunca directo de la red.
///
/// Esta es la estrategia "cache-first" en su forma más pura: Hive es la
/// fuente de verdad para la pantalla. La red solo entra para refrescar
/// esta caja en background y para enviar cambios pendientes.
class NotesLocalDataSource {
  static const boxName = 'notes_box';

  Box<Note> get _box => Hive.box<Note>(boxName);

  /// Notas visibles en la UI (oculta las que están pendientes de borrado,
  /// aunque técnicamente sigan en la caja hasta confirmarse con el server).
  List<Note> getAll() {
    final notes = _box.values
        .where((n) => n.syncStatus != SyncStatus.pendingDelete)
        .toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  /// Todo lo que hay en caché, sin filtrar. La usa la cola de
  /// sincronización para poder drenar también los borrados pendientes.
  List<Note> getAllRaw() => _box.values.toList();

  Future<void> upsert(Note note) async {
    await _box.put(note.id, note);
  }

  Future<void> replaceId(String oldId, Note updatedNote) async {
    if (oldId != updatedNote.id) {
      await _box.delete(oldId);
    }
    await _box.put(updatedNote.id, updatedNote);
  }

  Future<void> markDeleted(String id) async {
    final note = _box.get(id);
    if (note == null) return;
    // No borramos físicamente todavía: la marcamos como pendiente de
    // borrado para poder avisarle al servidor cuando volvamos a tener red.
    note
      ..syncStatus = SyncStatus.pendingDelete
      ..updatedAt = DateTime.now();
    await note.save();
  }

  Future<void> hardDelete(String id) async {
    await _box.delete(id);
  }

  /// Reemplaza la caché local con la "verdad" que llega del servidor,
  /// preservando las notas que aún tienen cambios locales pendientes
  /// (para no pisar algo que el usuario editó offline).
  Future<void> replaceSyncedData(List<Note> serverNotes) async {
    final pendingIds = _box.values
        .where((n) => n.syncStatus != SyncStatus.synced)
        .map((n) => n.id)
        .toSet();

    await _box.clear();
    for (final note in serverNotes) {
      if (!pendingIds.contains(note.id)) {
        await _box.put(note.id, note);
      }
    }
  }
}
