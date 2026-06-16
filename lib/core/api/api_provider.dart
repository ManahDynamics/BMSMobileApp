import 'api_client.dart';
import 'api_endpoints.dart';
import '../../modules/auth/services/auth_service.dart';
// import '../../modules/dashboard/services/dashboard_service.dart';

class ApiProvider {
  static final ApiClient apiClient = ApiClient(baseUrl: ApiEndpoints.baseUrl);
  static final AuthService authService = AuthService(apiClient);
  // static final DashboardService dashboardService = DashboardService(apiClient);
}
