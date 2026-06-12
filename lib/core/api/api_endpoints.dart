class ApiEndpoints {
  // 🔹 Base URL
  static const String baseUrl = "http://15.207.26.224:3020/api";

  // 🔹 Auth
  static const String login = "$baseUrl/auth/login";
  static const String register = "$baseUrl/auth/register";
  static const String refreshToken = "$baseUrl/auth/refresh";

  // 🔹 Dashboard
  static const String dashboardSummary = "$baseUrl/dashboard/summary";
  // 🔹 Update
  static const String updateInfo = "$baseUrl/app-version/upgrade";
}
