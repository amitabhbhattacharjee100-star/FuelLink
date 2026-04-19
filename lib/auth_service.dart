import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current authenticated user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Stream of auth state changes (for UI updates)
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Sign in with Google
  /// Stores user profile in Firestore with subscription preferences
  /// Returns: User email or null if sign-in failed
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print("[Auth] Sign-in cancelled by user");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        print("[Auth] User signed in: ${user.email}");
        
        // Create user profile in Firestore (if first time)
        // CRITICAL: This is where we track subscription status
        await _initializeUserProfile(user);
        
        return user.email;
      }
      
      return null;
    } catch (e) {
      print("[Auth] Google Sign-In error: $e");
      return null;
    }
  }

  /// Initialize user profile in Firestore on first sign-in
  /// Creates default subscription opt-in and stores email
  Future<void> _initializeUserProfile(User user) async {
    final userDocRef = _firestore.collection('users').doc(user.uid);
    
    // Check if user profile already exists
    final docSnapshot = await userDocRef.get();
    
    if (!docSnapshot.exists) {
      // First time sign-in: create profile
      await userDocRef.set({
        'email': user.email,
        'displayName': user.displayName ?? 'FuelLink User',
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'isSubscribed': true, // Default: opt-in to daily emails
        'lastEmailSent': null,
        'province': 'ON', // Default: Ontario (primary market)
        'preferredVehicleSize': 65.0, // Default: RAV4 (65L)
      });
      print("[Auth] User profile created in Firestore");
    }
  }

  /// Update email subscription preference
  /// When user toggles "Receive Daily Gas Reports"
  Future<void> updateSubscriptionStatus(bool isSubscribed) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isSubscribed': isSubscribed,
        'lastToggleTime': FieldValue.serverTimestamp(),
      });
      
      final status = isSubscribed ? 'subscribed' : 'unsubscribed';
      print("[Auth] User $status from daily emails");
    } catch (e) {
      print("[Auth] Error updating subscription status: $e");
    }
  }

  /// Handle unsubscribe link clicked (from email)
  /// Can be called from web or deep link
  /// Example: https://fuellink.app/unsubscribe?email=user@gmail.com&token=xyz
  Future<void> unsubscribeFromEmail(String email, String token) async {
    try {
      // Validate token for security (prevents abuse)
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final docId = query.docs.first.id;
        await _firestore.collection('users').doc(docId).update({
          'isSubscribed': false,
          'unsubscribeTime': FieldValue.serverTimestamp(),
        });
        print("[Auth] User unsubscribed: $email");
      }
    } catch (e) {
      print("[Auth] Error unsubscribing user: $e");
    }
  }

  /// Get user's subscription status
  /// Used before sending daily email
  Future<bool> getUserSubscriptionStatus(String userId) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      return docSnapshot.get('isSubscribed') ?? false;
    } catch (e) {
      print("[Auth] Error fetching subscription status: $e");
      return false;
    }
  }

  /// Get current user's profile data
  /// Includes email, province, vehicle preference, subscription status
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
      return docSnapshot.data();
    } catch (e) {
      print("[Auth] Error fetching user profile: $e");
      return null;
    }
  }

  /// Update user preferences (vehicle size, location, etc.)
  Future<void> updateUserPreferences({
    double? preferredVehicleSize,
    String? province,
  }) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final updateData = <String, dynamic>{};
      if (preferredVehicleSize != null) {
        updateData['preferredVehicleSize'] = preferredVehicleSize;
      }
      if (province != null) {
        updateData['province'] = province;
      }

      await _firestore.collection('users').doc(user.uid).update(updateData);
      print("[Auth] User preferences updated");
    } catch (e) {
      print("[Auth] Error updating preferences: $e");
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      print("[Auth] User signed out");
    } catch (e) {
      print("[Auth] Error signing out: $e");
    }
  }

  /// Delete user account and all associated data
  /// CRITICAL: Comply with GDPR/privacy regulations
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;

    try {
      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete Firebase Auth account
      await user.delete();
      
      print("[Auth] User account deleted");
    } catch (e) {
      print("[Auth] Error deleting account: $e");
    }
  }
}
