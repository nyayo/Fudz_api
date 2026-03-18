class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String userType;
  final bool isVerified;
  final String authProvider;
  final bool googleLinked;
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
    this.authProvider = 'email',
    this.googleLinked = false,
    this.profile,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String firstName = json['first_name']?.toString() ?? '';
    String lastName = json['last_name']?.toString() ?? '';

    if (firstName.isEmpty || lastName.isEmpty) {
      final fullName = json['full_name']?.toString().trim() ?? '';
      if (fullName.isNotEmpty && !fullName.contains('@')) {
        final parts = fullName.split(RegExp(r'\s+'));
        if (firstName.isEmpty && parts.isNotEmpty) {
          firstName = parts.first;
        }
        if (lastName.isEmpty && parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }
    }

    if ((firstName.isEmpty || lastName.isEmpty) && json['display_name'] != null) {
      final displayName = json['display_name'].toString().trim();
      if (displayName.isNotEmpty && !displayName.contains('@')) {
        final parts = displayName.split(RegExp(r'\s+'));
        if (firstName.isEmpty && parts.isNotEmpty) {
          firstName = parts.first;
        }
        if (lastName.isEmpty && parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }
    }

    return User(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: firstName,
      lastName: lastName,
      phone: json['phone'] ?? '',
      userType: json['user_type'] ?? 'customer',
      isVerified: json['is_verified'] ?? false,
      authProvider: json['auth_provider'] ?? 'email',
      googleLinked: json['google_id'] != null && json['google_id'].toString().isNotEmpty,
      profile: json['profile'],
      createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'])
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'user_type': userType,
      'is_verified': isVerified,
      'auth_provider': authProvider,
      'profile': profile,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated Google link status
  User copyWith({bool? googleLinked}) {
    return User(
      id: id,
      username: username,
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      userType: userType,
      isVerified: isVerified,
      authProvider: authProvider,
      googleLinked: googleLinked ?? this.googleLinked,
      profile: profile,
      createdAt: createdAt,
    );
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

  String get fullName {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    }
    return displayName;
  }
}