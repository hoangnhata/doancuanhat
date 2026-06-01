import 'package:drift/drift.dart';
import 'package:expense_manager/data/local/database.dart';

extension AppDatabaseSync on AppDatabase {
  /// Một hàng outbox cho mỗi (entity, localId); ghi đè nếu gọi lại trước khi đồng bộ.
  Future<void> enqueueSync(String entity, String op, int localId, {String? payloadJson}) async {
    await (delete(syncOutbox)..where((o) => o.entity.equals(entity) & o.localId.equals(localId))).go();
    await into(syncOutbox).insert(SyncOutboxCompanion.insert(
      entity: entity,
      op: op,
      localId: localId,
      payloadJson: payloadJson != null ? Value(payloadJson) : const Value.absent(),
    ));
  }
}
