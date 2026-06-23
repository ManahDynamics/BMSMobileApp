// lib/modules/auth/models/register_response.dart

class RegisterResponse {
  final bool success;
  final String message;
  final String? userId;
  final String? email;
  final String? mobileNo;
  final String? fullName;
  final String? deviceId;
  final String? deviceToken;
  final String? devicePlatform;

  RegisterResponse({
    required this.success,
    required this.message,
    this.userId,
    this.email,
    this.mobileNo,
    this.fullName,
    this.deviceId,
    this.deviceToken,
    this.devicePlatform,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json, {required bool success}) {
    final data = json['data'] as Map<String, dynamic>? ?? {};

    return RegisterResponse(
      success: success,
      message: json['message']?.toString() ??
          json['error']?.toString() ??
          (success ? 'Registration successful!' : 'Registration failed.'),
      userId: data['_id']?.toString() ?? data['id']?.toString(),
      email: data['email']?.toString(),
      mobileNo: data['mobileNo']?.toString(),
      fullName: data['fullName']?.toString(),
      deviceId: data['deviceId']?.toString(),
      deviceToken: data['deviceToken']?.toString(),
      devicePlatform: data['devicePlatform']?.toString(),
    );
  }
}