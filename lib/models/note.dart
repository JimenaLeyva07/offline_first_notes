import 'package:hive/hive.dart';

/// Estados posibles de sincronización de una nota.
///
/// Esta es la pieza clave del modelo offline-first: cada registro local
/// sabe si ya está confirmado por el servidor o si todavía tiene cambios
/// pendientes de enviar (creado, editado o borrado sin conexión).
enum SyncStatus {
  synced, // Coincide con el servidor.
  pendingCreate, // Se creó offline, falta enviarla.
  pendingUpdate, // Se editó offline, falta enviar el cambio.
  pendingDelete, // Se borró offline, falta confirmar el borrado remoto.
}

class Note extends HiveObject {
  String id; // Id local (uuid) o remoto una vez sincronizada.
  String title;
  String content;
  DateTime updatedAt;
  SyncStatus syncStatus;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  /// Lo que se envía/recibe de la API. No incluye `syncStatus`: ese
  /// campo es un detalle puramente local, el servidor no lo necesita
  /// conocer porque para él, todo lo que tiene ya está "sincronizado".
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'].toString(),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['updatedAt'] as num).toInt(),
        ),
        syncStatus: SyncStatus.synced,
      );

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
