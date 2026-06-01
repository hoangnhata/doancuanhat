import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/datasources/local_storage.dart';
import 'package:expense_manager/domain/models/user.dart';
import 'package:expense_manager/domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final ApiClient _api;
  final LocalStorage _storage;

  UserRepositoryImpl(this._api, this._storage);

  @override
  Future<User> getCurrentUser() async {
    final response = await _api.get(ApiConstants.usersMe);
    final data = response['data'] as Map<String, dynamic>;
    return _parseUser(data);
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.patch(ApiConstants.usersMePassword, data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  @override
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? botPersonality,
    bool? onboardingCompleted,
    String? walletName,
    String? currencyCode,
    double? initialBalance,
    double? savingsGoalMonthly,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (phone != null) body['phone'] = phone;
    if (botPersonality != null) body['botPersonality'] = botPersonality;
    if (onboardingCompleted != null) body['onboardingCompleted'] = onboardingCompleted;
    if (walletName != null) body['walletName'] = walletName;
    if (currencyCode != null) body['currencyCode'] = currencyCode;
    if (initialBalance != null) body['initialBalance'] = initialBalance;
    if (savingsGoalMonthly != null) body['savingsGoalMonthly'] = savingsGoalMonthly;

    final response = await _api.patch(ApiConstants.usersMeProfile, data: body);
    final data = response['data'] as Map<String, dynamic>;
    final user = _parseUser(data);
    await _storage.saveUser(user);
    return user;
  }

  User _parseUser(Map<String, dynamic> data) {
    final initBal = data['initialBalance'];
    return User(
      id: data['id'] as int,
      fullName: data['fullName'] as String,
      email: data['email'] as String,
      phone: data['phone'] as String?,
      botPersonality: data['botPersonality'] as String?,
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      walletName: data['walletName'] as String?,
      currencyCode: data['currencyCode'] as String?,
      initialBalance: initBal != null ? (initBal is num ? initBal.toDouble() : double.tryParse(initBal.toString())) : null,
      savingsGoalMonthly: data['savingsGoalMonthly'] != null ? (data['savingsGoalMonthly'] is num ? (data['savingsGoalMonthly'] as num).toDouble() : double.tryParse(data['savingsGoalMonthly'].toString())) : null,
    );
  }
}
