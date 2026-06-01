import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor createOpenConnection() {
  return LazyDatabase(() async {
    await initSqlJs();
    final storage = await DriftWebStorage.indexedDbIfSupported('expense_drift');
    return WebDatabase.withStorage(storage);
  });
}
