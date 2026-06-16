import '../../../models/base_model.dart';

class LoginResponse extends BaseModel {
  String? accessToken;
  String? refreshToken;
  String? userId;
  String? name;
  String? email;

  LoginResponse({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.name,
    this.email,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final res = LoginResponse(
      accessToken: data['accessToken'],
      refreshToken: data['refreshToken'],
      userId: data['_id'],
      name: data['name'],
      email: data['email'],
    );

    res.fromJson(data); // base fields
    return res;
  }

  @override
  Map<String, dynamic> toJson() {
    final map = super.toJson();
    map.addAll({
      "accessToken": accessToken,
      "refreshToken": refreshToken,
      "userId": userId,
      "name": name,
      "email": email,
    });
    return map;
  }
}
