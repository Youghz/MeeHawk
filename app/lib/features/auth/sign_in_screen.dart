import 'package:app/core/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _error = e.toString());
      }
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MH.paper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CRABCOACH',
                style: MH.sans(
                  size: 36,
                  weight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Beach volleyball analysis',
                style: MH.sans(color: MH.inkSoft),
              ),
              const SizedBox(height: 48),
              if (_loading)
                const CircularProgressIndicator(color: MH.ball)
              else
                _GoogleSignInButton(onPressed: _signIn),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: MH.sans(size: 12, color: MH.bad),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: MH.ink,
          side: const BorderSide(color: MH.rule),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: MH.sand,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ColoredG(),
            const SizedBox(width: 12),
            Text(
              'Continuer avec Google',
              style: MH.sans(size: 15, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColoredG extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GLogoPainter()),
    );
  }
}

class _GLogoPainter extends CustomPainter {
  const _GLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final arcRect = Rect.fromCircle(center: center, radius: r * 0.75);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.44
      ..strokeCap = StrokeCap.butt;

    const kPi = 3.1415926535897932;
    // Blue: -30° to 90°
    p.color = _blue;
    canvas.drawArc(arcRect, -kPi / 6, kPi * 2 / 3, false, p);
    // Red: 90° to 210°
    p.color = _red;
    canvas.drawArc(arcRect, kPi / 2, kPi * 2 / 3, false, p);
    // Yellow: 210° to 270°
    p.color = _yellow;
    canvas.drawArc(arcRect, kPi * 7 / 6, kPi / 3, false, p);
    // Green: 270° to 330°
    p.color = _green;
    canvas.drawArc(arcRect, kPi * 3 / 2, kPi / 3, false, p);

    // Horizontal arm of the G (blue)
    p
      ..color = _blue
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(r, r),
      Offset(r + r * 0.75, r),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
