import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/note.dart';

/// Fuente remota real, usando JSONBin.io como backend.
///
/// JSONBin guarda un único documento JSON (un "bin") por proyecto. Aquí
/// ese documento es, literalmente, el arreglo completo de notas. Por
/// eso cada escritura (crear/editar/borrar) sigue siempre el mismo
/// patrón de 3 pasos:
///   1. Leer el estado actual completo del bin.
///   2. Aplicarle el cambio en memoria (agregar/reemplazar/quitar).
///   3. Volver a escribir el bin completo.
///
/// El resto del proyecto (Repository, SyncQueue, UI) no sabe ni
/// le importa que por dentro funcione así: para ellos, esta clase sigue
/// exponiendo los mismos 4 métodos de siempre.
class NotesRemoteDataSource {
  Uri get _binUrl =>
      Uri.parse('${ApiConfig.jsonBinBaseUrl}/${ApiConfig.jsonBinId}');
  Uri get _latestUrl =>
      Uri.parse('${ApiConfig.jsonBinBaseUrl}/${ApiConfig.jsonBinId}/latest');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Master-Key': ApiConfig.jsonBinMasterKey,
        'X-Bin-Meta': 'false', // Respuesta "limpia", sin metadata extra.
      };

  Future<List<Note>> fetchAll() async {
    _assertConfigured();
    final response = await http.get(_latestUrl, headers: _headers);
    _throwIfError(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Note> create(Note note) async {
    final current = await fetchAll();
    final synced = note.copyWith(syncStatus: SyncStatus.synced);
    current.add(synced);
    await _saveAll(current);
    return synced;
  }

  Future<Note> update(Note note) async {
    final current = await fetchAll();
    final synced = note.copyWith(syncStatus: SyncStatus.synced);
    final index = current.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      current[index] = synced;
    } else {
      current.add(synced);
    }
    await _saveAll(current);
    return synced;
  }

  Future<void> delete(String id) async {
    final current = await fetchAll();
    current.removeWhere((n) => n.id == id);
    await _saveAll(current);
  }

  Future<void> _saveAll(List<Note> notes) async {
    final body = jsonEncode(notes.map((n) => n.toJson()).toList());
    final response = await http.put(_binUrl, headers: _headers, body: body);
    _throwIfError(response);
  }

  void _assertConfigured() {
    if (!ApiConfig.isJsonBinConfigured) {
      throw Exception(
        'Falta configurar lib/config/api_config.dart con tu jsonBinId y jsonBinMasterKey de jsonbin.io',
      );
    }
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error JSONBin (${response.statusCode}): ${response.body}',
      );
    }
  }
}
