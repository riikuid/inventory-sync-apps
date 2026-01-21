import 'dart:convert';

class User {
  int? id;
  String? uuid;
  String? name;
  String? sectionId;
  String? username;
  dynamic email;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? lastLoginAt;
  Section? section;

  User({
    this.id,
    this.uuid,
    this.name,
    this.sectionId,
    this.username,
    this.email,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.section,
  });

  factory User.fromRawJson(String str) => User.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"],
    uuid: json["uuid"],
    name: json["name"],
    sectionId: json["section_id"],
    username: json["username"],
    email: json["email"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    lastLoginAt: json["last_login_at"] == null
        ? null
        : DateTime.parse(json["last_login_at"]),
    section: json["section"] == null ? null : Section.fromJson(json["section"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "uuid": uuid,
    "name": name,
    "section_id": sectionId,
    "username": username,
    "email": email,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "last_login_at": lastLoginAt?.toIso8601String(),
    "section": section?.toJson(),
  };
}

class Section {
  String? id;
  String? code;
  String? name;
  dynamic alias;

  Section({this.id, this.code, this.name, this.alias});

  factory Section.fromRawJson(String str) => Section.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Section.fromJson(Map<String, dynamic> json) => Section(
    id: json["id"],
    code: json["code"],
    name: json["name"],
    alias: json["alias"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "code": code,
    "name": name,
    "alias": alias,
  };
}
