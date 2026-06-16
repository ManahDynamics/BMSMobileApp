// lib/modules/auth/models/register_request.dart

class RegisterRequest {
  final String fullName;
  final String password;
  final String? email;
  final String? mobileNo;

  RegisterRequest({
    required this.fullName,
    required this.password,
    this.email,
    this.mobileNo,
  });

  Map<String, dynamic> toJson() {
    return {
      "fullName": fullName.trim(),
      "password": password,
      if (email != null) "email": email,
      if (mobileNo != null) "mobileNo": mobileNo,
    };
  }
}