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

  Future<GoogleSignInResult?> signIn() async {
    await _googleSignIn.initialize(
      serverClientId:
          '947445061824-q2f09l531q695tlusjbqhubvpres9um2.apps.googleusercontent.com',
    );

    final GoogleSignInAccount googleUser =
        await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _auth.signInWithCredential(credential);

    final firebaseIdToken =
        await userCredential.user!.getIdToken();
        print('Firebase ID Token: $firebaseIdToken');

    return GoogleSignInResult(
      credential: userCredential,
      firebaseIdToken: firebaseIdToken,
    );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}