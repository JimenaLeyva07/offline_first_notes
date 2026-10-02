# Demo en vivo — Notas offline-first en Flutter (con API real)

Proyecto base para la charla **"Estrategias de Caché y Sincronización Offline en Flutter"**.

Backend **activo por defecto: JSONBin.io** — recomendado para live
coding por ser el más simple de configurar y de explicar (2 endpoints,
sin casos especiales). Se incluye también una implementación
alternativa con **MockAPI.io** (REST por recurso, sin key) para quien
quiera algo más cercano a una API real — ver la última sección.

---

## 0. Configurar JSONBin.io (lo único que tienes que tocar)

1. Crea una cuenta gratis en **https://jsonbin.io**
2. Click en **"Create Bin"** y pega como contenido inicial: `[]`
3. Guarda el bin y copia su **Bin ID** (está en la URL / en el dashboard).
4. Ve a tu perfil → **"API Keys"** y copia tu **X-Master-Key**.
5. Abre `lib/config/api_config.dart` y pega ambos valores:

```dart
static const String jsonBinId = 'TU_BIN_ID_AQUI';
static const String jsonBinMasterKey = 'TU_MASTER_KEY_AQUI';
```

Eso es todo (~3 minutos). No hay que tocar ningún otro archivo del
proyecto: `NotesRepository`, `SyncQueue` y la UI ya están cableados
contra `NotesRemoteDataSource`, que es la única clase que habla con
JSONBin. Si olvidas este paso, la app lo avisa con un banner rojo en
vez de fallar en silencio.

## 1. Instalar dependencias

```bash
flutter pub get
```

## 2. Levantar dos emuladores a la vez

```bash
flutter emulators                 # lista los AVDs disponibles
flutter emulators --launch <avd_1>
flutter emulators --launch <avd_2>

flutter devices                   # confirma los device-id (ej: emulator-5554, emulator-5556)
```

Corre la app en cada uno, en dos terminales separadas:

```bash
flutter run -d emulator-5554   # Emulador A
flutter run -d emulator-5556   # Emulador B
```

## 3. Simular que un emulador se queda sin wifi

```bash
# Apagar wifi solo en el Emulador A
adb -s emulator-5554 shell svc wifi disable

# Volver a encenderla
adb -s emulator-5554 shell svc wifi enable
```

(También puedes usar los controles extendidos del emulador: ícono
"..." → Cellular/Wi-Fi). El `ConnectivityService` detecta el cambio en
tiempo real, sin reiniciar nada.

---

## Explicación del código y la lógica (para conducir la charla)

### 1. `lib/config/api_config.dart`
Único punto de configuración: `jsonBinId` + `jsonBinMasterKey`.
`isJsonBinConfigured` evita que la app llame a la API con los valores
de ejemplo sin configurar.

### 2. `lib/models/note.dart`
El modelo central. El campo clave para toda la charla es
`syncStatus`: cada nota sabe si está `synced`, o si tiene un cambio
pendiente de enviar (`pendingCreate`, `pendingUpdate`,
`pendingDelete`). `toJson()`/`fromJson()` son el "traductor" entre el
objeto Dart y el JSON que viaja por HTTP.

### 3. `lib/data/local/notes_local_datasource.dart`
La caché real (Hive). La UI **nunca** lee de la red directamente,
siempre lee de aquí — esto es la estrategia *cache-first*.

### 4. `lib/data/remote/notes_remote_datasource.dart` ← el corazón de la demo
Solo 2 endpoints: `GET /latest` para traer el bin completo, `PUT` para
sobrescribirlo completo. El patrón se repite igual en `create`,
`update` y `delete`:
1. Traer el arreglo completo (`fetchAll()`).
2. Modificarlo en memoria (agregar / reemplazar / quitar un ítem).
3. Guardar el arreglo completo de vuelta (`_saveAll()`).

Es la pieza más fácil de dictar en vivo: no hay rutas por id ni verbos
distintos por operación, todo es "traer todo" / "guardar todo".

### 5. `lib/data/sync/sync_queue.dart`
Recorre las notas con `syncStatus != synced` y las reenvía en orden,
una por una, según su estado (crear → `remote.create`, editar →
`remote.update`, borrar → `remote.delete`).

### 6. `lib/data/notes_repository.dart`
El orquestador. Expone `watchNotes()` (stream que la UI escucha), hace
las escrituras optimistas (`createNote`, `updateNote`, `deleteNote` —
la UI ve el cambio antes de que exista confirmación del servidor) y
dispara la sincronización en dos momentos: apenas vuelve la conexión
(listener de `connectivity.onStatusChange`) y cada 5 segundos mientras
hay red (`Timer.periodic`, estrategia de *polling*). Este polling es
lo que hace que el segundo emulador reciba los cambios del primero sin
que nadie toque nada.

### 7. `lib/ui/notes_page.dart`
La vista: pinta el stream de notas, el estado de conexión, y el ícono
de sincronización de cada nota (☁️✅ sincronizada, ☁️⬆️ pendiente de
crear/editar, ☁️🚫 pendiente de borrar).

---

## ¿Quedan pasos pendientes para que funcione?

**No.** Con JSONBin, el id que genera la app localmente (un `uuid`) es
el mismo que queda guardado en el servidor — no hay ninguna
reconciliación que resolver. Con pegar tu `jsonBinId` y
`jsonBinMasterKey` en `api_config.dart`, la app ya queda lista para la
demo.

**Un matiz que sí vale la pena mencionar en la charla** (no requiere
cambio de código, pero es una buena discusión de trade-offs): como
cada escritura sobrescribe el documento completo, si los **dos
emuladores escriben al mismo tiempo mientras ambos están online**,
el último `PUT` en llegar "gana" y puede pisar el cambio del otro
(esto se conoce como *lost update*). Para la demo no es un problema —
el flujo es A offline → A reconecta → B hace polling —, pero es un
buen punto para explicar por qué, en un backend real, normalmente se
prefiere REST por recurso (como MockAPI) o un control de versiones
(ETags, campo `rev`, etc.) en vez de sobrescribir todo el documento.

## Guion sugerido para la charla (≈15-20 min)

1. **Mostrar `lib/config/api_config.dart`** — solo 2 valores a pegar.
2. **Mostrar `data/remote/notes_remote_datasource.dart`** — el patrón
   "traer todo → modificar en memoria → guardar todo" en `create`,
   `update` y `delete`. Es el único archivo que alguien tendría que
   adaptar para cambiar de backend.
3. **Correr ambos emuladores** con wifi activa en los dos. Crear una
   nota en el Emulador A y mostrar cómo aparece sola en el Emulador B
   a los pocos segundos (polling automático).
4. **Apagar el wifi del Emulador A** (`adb ... svc wifi disable`).
   Crear 2-3 notas ahí: la barra superior cambia a "Sin conexión", los
   íconos quedan en ☁️⬆️ (pendiente), nada se pierde.
5. **Mostrar que el Emulador B no ve nada nuevo todavía** — esas notas
   siguen solo en la caché local del Emulador A.
6. **Reconectar el wifi del Emulador A** (`adb ... svc wifi enable`).
   Mostrar cómo `NotesRepository` detecta el cambio, drena el
   `SyncQueue` (sube los cambios) y los íconos pasan a ☁️✅. Opcional:
   abrir el dashboard de JSONBin y mostrar el JSON actualizado en vivo.
7. **Esperar unos segundos (o tocar 🔄 en el Emulador B)** — las notas
   nuevas aparecen ahí también.
8. **Cierre:** mencionar el trade-off de *lost update* explicado
   arriba, y señalar `pollInterval` en `NotesRepository` como el lugar
   para ajustar qué tan "en vivo" se siente la sincronización.

---

## Alternativa: usar MockAPI.io en vez de JSONBin

El proyecto incluye también `lib/data/remote/notes_remote_datasource_mockapi.dart`,
con REST real por recurso y sin necesidad de key. Para activarlo:

1. Completa `mockApiBaseUrl` en `api_config.dart` (instrucciones de
   registro dentro del propio archivo).
2. En `lib/main.dart`, cambia la instancia que se le pasa a
   `NotesRepository`:
   ```dart
   remote: NotesRemoteDataSourceMockApi(), // en vez de NotesRemoteDataSource()
   ```
   y agrega el import correspondiente.
3. A diferencia de JSONBin, MockAPI asigna su propio `id` al crear un
   recurso, distinto del `uuid` local usado para la escritura
   optimista offline — por eso `SyncQueue.drain()` ya llama a
   `NotesLocalDataSource.replaceId()` en vez de `upsert()` al procesar
   un `pendingCreate`. Con JSONBin ese mismo código es un no-op (los
   ids ya coinciden), así que sirve para ambos backends sin ramas
   condicionales — es un buen punto para mostrar en vivo el contraste
   entre los dos enfoques si el tiempo de la charla lo permite.

## Estrategias que ilustra este proyecto

| Estrategia | Dónde está en el código |
|---|---|
| Cache-first | `NotesRepository.watchNotes()` / `initialLoad()` |
| Escritura optimista | `createNote`, `updateNote`, `deleteNote` |
| Cola de sincronización | `data/sync/sync_queue.dart` |
| Disparo automático al reconectar | Listener de `connectivity.onStatusChange` en `NotesRepository` |
| Sincronización por polling | `Timer.periodic` en `NotesRepository` (`pollInterval`) |
| Resolución simple de conflictos | `NotesLocalDataSource.replaceSyncedData` (los pendientes locales no se pisan) |
| Consumo de API real | `data/remote/notes_remote_datasource.dart` + `config/api_config.dart` |
