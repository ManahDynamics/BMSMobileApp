import 'api_provider.dart';

enum MaintenanceStatus { ok, maintenance }

class MaintenanceService {
  static Future<MaintenanceStatus> check() async {
    try {
      final response = await ApiProvider.apiClient.get('/health');
      final isMaintenance = response['maintenance'] == true;
      return isMaintenance
          ? MaintenanceStatus.maintenance
          : MaintenanceStatus.ok;
    } catch (e) {
      // health check failed → continue normally
      return MaintenanceStatus.ok;
    }
  }
}