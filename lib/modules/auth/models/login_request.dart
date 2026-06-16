// modules/auth/models/login_request.dart

class LoginRequest {
  final String email;
  final String password;
  final String deviceId;
  final String devicePlatform;
  final String deviceToken;

  LoginRequest({
    required this.email,
    required this.password,
    required this.deviceId,
    required this.devicePlatform,
    required this.deviceToken,
  });

  Map<String, dynamic> toJson() {
    return {
      "email": email.trim().toLowerCase(),
      "password": password,
      "deviceId": deviceId,
      "devicePlatform": devicePlatform,
      "deviceToken": deviceToken,
    };
  }
}
