import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;

  Future<void> _login(OAuthProvider provider) async {
    setState(() => _loading = true);
    try {
      final redirect = kIsWeb ? '${Uri.base.origin}/' : null; // örn: http://localhost:3000/
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: redirect,
        scopes: 'read:user user:email',
      );
      if (mounted) context.go('/');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('BenefiSocial',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Sign in to continue'),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _login(OAuthProvider.github),
                    icon: const Icon(Icons.code),
                    label: const Text('Continue with GitHub'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _login(OAuthProvider.google),
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 12),
                  if (_loading) const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
