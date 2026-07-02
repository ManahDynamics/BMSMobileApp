// lib/services/google_auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInResult {
  final UserCredential credential;
  final String? firebaseIdToken;

  GoogleSignInResult({
    required this.credential,
    required this.firebaseIdToken,
  });
}

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize(
      serverClientId:
          '947445061824-q2f09l531q695tlusjbqhubvpres9um2.apps.googleusercontent.com',
    );
    _initialized = true;
  }

  /// Returns null if the user cancels the sign-in flow.
  /// Throws [GoogleSignInException] or other exceptions on real failures —
  /// callers should catch and surface a message.
  Future<GoogleSignInResult?> signIn() async {
    try {
      await _ensureInitialized();

      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('No idToken returned from Google Sign-In');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final firebaseIdToken = await userCredential.user!.getIdToken(true);

      return GoogleSignInResult(
        credential: userCredential,
        firebaseIdToken: firebaseIdToken,
      );
    } on GoogleSignInException catch (e) {
      // ---- Debug: remove/replace with real logging once diagnosed ----
      // ignore: avoid_print
      print('[GoogleAuthService] GoogleSignInException '
          'code=${e.code} description=${e.description}');

      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User backed out of the picker — not an error.
        return null;
      }
      // Real failure (config, network, provider issue, etc).
      rethrow;
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('[GoogleAuthService] FirebaseAuthException '
          'code=${e.code} message=${e.message}');
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('[GoogleAuthService] Unexpected error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}