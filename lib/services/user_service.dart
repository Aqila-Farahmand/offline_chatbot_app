import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // USER PROFILE OPERATIONS
  /// Creates or updates the user profile document
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String lastname,
    required String email,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set({
            'name': name,
            'lastname': lastname,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Firestore operation timed out - check your internet connection',
              );
            },
          );
    } on TimeoutException {
      rethrow;
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  /// Get user profile by UID
  Future<DocumentSnapshot> getUserProfile(String uid) async {
    try {
      return await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Firestore operation timed out - check your internet connection',
              );
            },
          );
    } on TimeoutException {
      rethrow;
    } catch (e) {
      print('Error getting user profile: $e');
      rethrow;
    }
  }

  /// Update user profile fields
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .update(data)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Firestore operation timed out - check your internet connection',
              );
            },
          );
    } on TimeoutException {
      rethrow;
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Listen to user profile changes
  Stream<DocumentSnapshot> listenToUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }
}
