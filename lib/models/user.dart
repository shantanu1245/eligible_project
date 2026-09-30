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

  static const UserModel admin = UserModel(
    id: 'U-001',
    name: 'Shantanu',
    email: 'admin@eligiblecrm.com',
    role: UserRole.administrator,
    initial: 'S',
  );

  static const UserModel executiveAmit = UserModel(
    id: 'U-002',
    name: 'Amit Patil',
    email: 'amit@eligiblecrm.com',
    role: UserRole.salesExecutive,
    initial: 'A',
  );

  static const UserModel executivePriya = UserModel(
    id: 'U-003',
    name: 'Priya Shah',
    email: 'priya@eligiblecrm.com',
    role: UserRole.salesExecutive,
    initial: 'P',
  );

  static const List<UserModel> demoUsers = [
    admin,
    executiveAmit,
    executivePriya,
  ];

  static const List<UserModel> salesExecutives = [
    executiveAmit,
    executivePriya,
  ];
}
