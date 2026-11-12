enum UserRole {
  administrator,
  salesExecutive,
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String initial;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.initial,
  });

  bool get isAdmin => role == UserRole.administrator;
  bool get isSalesExecutive => role == UserRole.salesExecutive;

  String get roleDisplayName {
    switch (role) {
      case UserRole.administrator:
        return 'Administrator';
      case UserRole.salesExecutive:
        return 'Sales Executive';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'initial': initial,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    UserRole parseRole(dynamic r) {
      if (r == null) return UserRole.administrator;
      final str = r.toString().toLowerCase();
      if (str.contains('executive') || str.contains('sales')) {
        return UserRole.salesExecutive;
      }
      return UserRole.administrator;
    }

    final name = json['name']?.toString() ?? 'User';
    final initial = json['initial']?.toString() ??
        (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U');

    return UserModel(
      id: json['id']?.toString() ?? 'U-001',
      name: name,
      email: json['email']?.toString() ?? '',
      role: parseRole(json['role']),
      initial: initial,
    );
  }

  static const UserModel admin = UserModel(
    id: 'U-001',
    name: 'Admin',
    email: 'admin@theligible.in',
    role: UserRole.administrator,
    initial: 'A',
  );

  static const List<UserModel> demoUsers = [
    admin,
  ];

  static const List<UserModel> salesExecutives = [];

  static const List<UserModel> teamMembers = [
    admin,
  ];
}
