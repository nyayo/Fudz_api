class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String userType;
  final bool isVerified;
  final Map<String, dynamic>? profile;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.userType,
    required this.isVerified,
    this.profile,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'] ?? '',
      userType: json['user_type'],
      isVerified: json['is_verified'] ?? false,
      profile: json['profile'],
    createdAt: json['created_at'] != null
      ? DateTime.tryParse(json['created_at'])
      : null,
    );
  }

  Map<String, dynamic> toJson(){
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'user_type': userType,
      'is_verified': isVerified,
      'profile': profile,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get displayName {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (username.isNotEmpty) {
      return username;
    }
    return email.split('@').first;
  }

  String get fullName => '$firstName $lastName';
}