// lib/modules/registration/models/register_request.dart

class RegisterRequest {
  final String fullName;
  final String password;
  final String? email;
  final String? mobileNo;
  final String? deviceId;
  final String? deviceToken;
  final String? devicePlatform;

  RegisterRequest({
    required this.fullName,
    required this.password,
    this.email,
    this.mobileNo,
    this.deviceId,
    this.deviceToken,
    this.devicePlatform,
  });

  Map<String, dynamic> toJson() {
    return {
      "fullName": fullName.trim(),
      "password": password,
      if (email != null) "email": email,
      if (mobileNo != null) "mobileNo": mobileNo,
      if (deviceId != null) "deviceId": deviceId,
      if (deviceToken != null) "deviceToken": deviceToken,
      if (devicePlatform != null) "devicePlatform": devicePlatform,
    };
  }
}