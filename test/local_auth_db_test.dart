import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bmsmobileapp/services/local_auth_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await SharedPreferences.getInstance();
  });

  test('keeps pending rows when sync fails', () async {
    final db = LocalAuthDB(databaseFactory: databaseFactoryFfi);
    await db.clearBMSCache();
    await db.enqueueForSync('tests', {'status': 'queued'});

    final synced = await db.syncPendingEntries(
      syncFn: (_, __, ___) async {
        throw Exception('offline');
      },
    );

    expect(synced, 0);
    expect(await db.getPendingSyncCount(), 1);
    expect(await db.getLastSyncTime(), isNull);
  });

  test('removes queued rows and stores last sync time after successful sync', () async {
    final db = LocalAuthDB(databaseFactory: databaseFactoryFfi);
    await db.clearBMSCache();
    await db.enqueueForSync('tests', {'status': 'ok'});

    final synced = await db.syncPendingEntries(
      syncFn: (_, __, ___) async {},
    );

    expect(synced, 1);
    expect(await db.getPendingSyncCount(), 0);
    expect(await db.getLastSyncTime(), isNotNull);
  });
}
