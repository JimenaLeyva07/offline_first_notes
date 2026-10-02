import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/local/notes_local_datasource.dart';
import 'data/notes_repository.dart';
import 'data/remote/notes_remote_datasource.dart';
import 'models/note.dart';
import 'models/note_hive_adapters.dart';
import 'services/connectivity_service.dart';
import 'ui/notes_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Inicializamos Hive: nuestra caja de caché local persistente.
  await Hive.initFlutter();
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(SyncStatusAdapter());
  await Hive.openBox<Note>(NotesLocalDataSource.boxName);

  runApp(const OfflineDemoApp());
}

class OfflineDemoApp extends StatefulWidget {
  const OfflineDemoApp({super.key});

  @override
  State<OfflineDemoApp> createState() => _OfflineDemoAppState();
}

class _OfflineDemoAppState extends State<OfflineDemoApp> {
  late final ConnectivityService _connectivity;
  late final NotesRepository _repository;

  @override
  void initState() {
    super.initState();
    // 2) Ensamblamos las piezas: local + remoto + conectividad -> repo.
    _connectivity = ConnectivityService();
    _repository = NotesRepository(
      local: NotesLocalDataSource(),
      remote: NotesRemoteDataSource(),
      connectivity: _connectivity,
    );
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notas offline-first',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: NotesPage(repository: _repository, connectivity: _connectivity),
    );
  }
}
