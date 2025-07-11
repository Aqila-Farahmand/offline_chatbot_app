import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Creates or updates the user profile document under the `users` collection
  /// using the provided [uid] as the document ID.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String lastname,
    required String email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'lastname': lastname,
      'email': email,
    });
  }
}
