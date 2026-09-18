import '../models/feature_flags.dart';
import 'api_service.dart';
import 'user_data_service.dart';

class FeatureFlagsService {
  static FeatureFlags _cached = FeatureFlags.disabled;

  static FeatureFlags get current => _cached;

  static Future<FeatureFlags> refresh() async {
    final isLocalMode = await UserDataService.getIsLocalMode();
    if (isLocalMode) {
      _cached = FeatureFlags.disabled;
      return _cached;
    }

    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/server-config',
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );

    if (!response.success || response.data == null) {
      _cached = FeatureFlags.disabled;
      return _cached;
    }

    _cached = FeatureFlags.fromJson(response.data!);
    return _cached;
  }
}
