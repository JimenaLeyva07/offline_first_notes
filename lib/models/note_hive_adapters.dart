import 'package:hive/hive.dart';
import 'note.dart';

class SyncStatusAdapter extends TypeAdapter<SyncStatus> {
  @override
  final int typeId = 1;

  @override
  SyncStatus read(BinaryReader reader) {
    final index = reader.readByte();
    return SyncStatus.values[index];
  }

  @override
  void write(BinaryWriter writer, SyncStatus obj) {
    writer.writeByte(obj.index);
  }
}

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 0;

  @override
  Note read(BinaryReader reader) {
    return Note(
      id: reader.readString(),
      title: reader.readString(),
      content: reader.readString(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      syncStatus: SyncStatus.values[reader.readByte()],
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.content);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
    writer.writeByte(obj.syncStatus.index);
  }
}
