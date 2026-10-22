import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/ui.dart';
import 'question_list_screen.dart';

/// Signed out → sign-in form. Signed in without the `amoreAdmin` claim (or
/// with an unverified email) → "No access". Admin → the question list.
class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  String? _checkedUid;
  Future<bool>? _isAdmin;

  Future<bool> _check(User user) async {
    final token = await user.getIdTokenResult(true); // pick up new claims
    return token.claims?['amoreAdmin'] == true && user.emailVerified;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: AppLoader()));
        }
        final user = snap.data;
        if (user == null) {
          _checkedUid = null;
          return const _SignInPage();
        }
        if (_checkedUid != user.uid) {
          _checkedUid = user.uid;
          _isAdmin = _check(user);
        }
        return FutureBuilder<bool>(
          future: _isAdmin,
          builder: (context, admin) {
            if (!admin.hasData && !admin.hasError) {
              return const Scaffold(body: Center(child: AppLoader()));
            }
            return admin.data == true
                ? const QuestionListScreen()
                : _NoAccessPage(email: user.email);
          },
        );
      },
    );
  }
}

class _SignInPage extends StatefulWidget {
  const _SignInPage();

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() signIn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await signIn();
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = switch (e.code) {
          'invalid-credential' ||
          'wrong-password' ||
          'user-not-found' => 'Wrong email or password.',
          'popup-closed-by-user' => null,
          _ => 'Sign-in failed (${e.code}).',
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = FirebaseAuth.instance;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.favorite, color: AppColors.rose, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Amore Admin',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _email,
                    autofillHints: const [AutofillHints.email],
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(hintText: 'Password'),
                    onSubmitted: (_) => _signInWithEmail(auth),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.rose),
                    ),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    text: 'Sign in',
                    loading: _busy,
                    onPressed: () => _signInWithEmail(auth),
                  ),
                  const SizedBox(height: 12),
                  AppButton.light(
                    text: 'Continue with Google',
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => auth.signInWithPopup(GoogleAuthProvider()),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _signInWithEmail(FirebaseAuth auth) => _run(
    () => auth.signInWithEmailAndPassword(
      email: _email.text.trim(),
      password: _password.text,
    ),
  );
}

class _NoAccessPage extends StatelessWidget {
  final String? email;
  const _NoAccessPage({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              'No admin access',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '${email ?? 'This account'} is not an Amore admin.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: FirebaseAuth.instance.signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
