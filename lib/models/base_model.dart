abstract class BaseModel {
  String? id;
  DateTime? createdAt;
  DateTime? updatedAt;

  void fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['id'];

    if (json['createdAt'] != null) {
      createdAt = DateTime.parse(json['createdAt']);
    }

    if (json['updatedAt'] != null) {
      updatedAt = DateTime.parse(json['updatedAt']);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "createdAt": createdAt?.toIso8601String(),
      "updatedAt": updatedAt?.toIso8601String(),
    };
  }
}
