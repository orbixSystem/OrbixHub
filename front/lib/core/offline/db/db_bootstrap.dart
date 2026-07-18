// Fachada web-safe do setup de plataforma do offline. `initOfflineDb()` deve ser
// chamado no bootstrap do app (antes de abrir qualquer banco). Na web resolve
// para o stub (no-op); no nativo aplica o override do SQLCipher no Android.
import 'db_stub.dart' if (dart.library.io) 'db_native.dart' as platform;

/// Prepara a plataforma para abrir o banco local cifrado. Seguro em qualquer
/// plataforma: no-op na web, override do SQLCipher (Android) no nativo.
Future<void> initOfflineDb() => platform.initOfflineDb();
