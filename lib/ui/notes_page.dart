import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
import '../services/connectivity_service.dart';

class NotesPage extends StatefulWidget {
  final NotesRepository repository;
  final ConnectivityService connectivity;

  const NotesPage({
    super.key,
    required this.repository,
    required this.connectivity,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    widget.connectivity.isOnline.then((v) => setState(() => _isOnline = v));
    widget.connectivity.onStatusChange.listen((v) {
      if (mounted) setState(() => _isOnline = v);
    });
    widget.repository.initialLoad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas (offline-first)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Forzar sincronización',
            onPressed: widget.repository.forceSync,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(ApiConfig.isConfigured ? 28 : 56),
          child: Column(
            children: [
              _ConnectivityBanner(isOnline: _isOnline),
              if (!ApiConfig.isConfigured) const _ConfigWarningBanner(),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Note>>(
        stream: widget.repository.watchNotes(),
        builder: (context, snapshot) {
          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            return const Center(child: Text('Sin notas todavía. Crea una ⬇️'));
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, i) => _NoteTile(
              note: notes[i],
              onDelete: () => widget.repository.deleteNote(notes[i]),
              onEdit: () => _openEditor(note: notes[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openEditor({Note? note}) async {
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: 'Contenido'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (note == null) {
                  widget.repository.createNote(
                    titleCtrl.text,
                    contentCtrl.text,
                  );
                } else {
                  widget.repository.updateNote(
                    note,
                    title: titleCtrl.text,
                    content: contentCtrl.text,
                  );
                }
                Navigator.pop(context);
              },
              child: Text(note == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  final bool isOnline;
  const _ConnectivityBanner({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 28,
      color: isOnline ? Colors.green.shade600 : Colors.orange.shade700,
      alignment: Alignment.center,
      child: Text(
        isOnline ? 'En línea · sincronizando cambios' : 'Sin conexión · trabajando desde caché',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _ConfigWarningBanner extends StatelessWidget {
  const _ConfigWarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 28,
      color: Colors.red.shade700,
      alignment: Alignment.center,
      child: const Text(
        '⚠️ Falta configurar lib/config/api_config.dart (jsonBinId y jsonBinMasterKey)',
        style: TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _NoteTile({
    required this.note,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(note.title),
      subtitle: Text(note.content, maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: _SyncBadge(status: note.syncStatus),
      onTap: onEdit,
      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  final SyncStatus status;
  const _SyncBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      SyncStatus.synced => (Icons.cloud_done, Colors.green),
      SyncStatus.pendingCreate => (Icons.cloud_upload, Colors.orange),
      SyncStatus.pendingUpdate => (Icons.cloud_sync, Colors.orange),
      SyncStatus.pendingDelete => (Icons.cloud_off, Colors.red),
    };
    return Icon(icon, color: color);
  }
}
