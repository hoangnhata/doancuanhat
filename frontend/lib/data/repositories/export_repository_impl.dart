import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/core/utils/download_utils.dart';
import 'package:expense_manager/data/datasources/api_client.dart';

class ExportRepository {
  final ApiClient _api;

  ExportRepository(this._api);

  Future<void> exportTransactions({
    required String format,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, dynamic>{'format': format};
    if (startDate != null) {
      params['startDate'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      params['endDate'] = endDate.toIso8601String().split('T')[0];
    }

    final bytes = await _api.getBytes(ApiConstants.exportTransactions, params: params);
    final f = format.toLowerCase();
    final ext = (f == 'excel' || f == 'xlsx') ? 'xlsx' : 'pdf';
    final now = DateTime.now();
    final filename = 'bao-cao-giao-dich-${now.year}${now.month.toString().padLeft(2, '0')}.$ext';

    await downloadFile(bytes, filename);
  }
}
