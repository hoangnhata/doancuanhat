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
    String fmt(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final rangeTag = (startDate != null && endDate != null)
        ? '${fmt(startDate)}-${fmt(endDate)}'
        : fmt(DateTime.now());
    final filename = 'bao-cao-giao-dich-$rangeTag.$ext';

    await downloadFile(bytes, filename);
  }
}
