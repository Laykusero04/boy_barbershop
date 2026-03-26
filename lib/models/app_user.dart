import 'package:equatable/equatable.dart';

import 'package:boy_barbershop/models/user_role.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;

  String get displayName {
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? email : combined;
  }

  @override
  List<Object?> get props => [uid, email, firstName, lastName, role];
}
