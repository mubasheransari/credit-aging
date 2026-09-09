
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/background_monitor_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authService.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final result = await _authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.success) {
      _showMessage(result.message, error: true);
      return;
    }

    await startBackgroundMonitoring();
    await _showWelcomePopup(result.role ?? '');
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? kRed : kInk,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            message,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  Future<void> _showWelcomePopup(String role) async {
    final prettyRole = role.isEmpty ? 'User' : prettyStatus(role);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(30),
            decoration: softCardDecoration(
              radius: 28,
              border: false,
              shadow: true,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    color: kInk,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  'Welcome back',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Signed in as $prettyRole',
                  style: GoogleFonts.manrope(
                    color: kMutedInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 850;

            return desktop
                ? Row(
                    children: [
                      Expanded(flex: 5, child: _BrandPanel()),
                      Expanded(flex: 4, child: _FormArea()),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                    child: _FormArea(compact: true),
                  );
          },
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(46),
      decoration: BoxDecoration(
        color: kInk,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrandMark(inverted: true),
          const Spacer(),
          Text(
            'Credit\nAging.',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 62,
              height: .98,
              fontWeight: FontWeight.w800,
              letterSpacing: -2.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 390,
            child: Text(
              'A simple workspace for reviewing credit requests, approvals and decisions.',
              style: GoogleFonts.manrope(
                color: Colors.white.withOpacity(.68),
                fontSize: 16,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 34),
          Row(
            children: [
              _TinyDot(color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Finance workflow',
                style: GoogleFonts.manrope(
                  color: Colors.white.withOpacity(.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 22),
              _TinyDot(color: const Color(0xFFB8E8D0)),
              const SizedBox(width: 8),
              Text(
                'Approval ready',
                style: GoogleFonts.manrope(
                  color: Colors.white.withOpacity(.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'MEZAN TEA  /  INTERNAL',
            style: GoogleFonts.manrope(
              color: Colors.white.withOpacity(.42),
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormArea extends StatelessWidget {
  final bool compact;

  const _FormArea({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_LoginScreenState>()!;

    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            _BrandMark(),
            const SizedBox(height: 44),
          ] else ...[
            Center(child: _BrandMark()),
            const SizedBox(height: 42),
          ],
          Text(
            'Sign in',
            style: GoogleFonts.manrope(
              fontSize: 38,
              height: 1.05,
              letterSpacing: -1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Use your work account to continue.',
            style: GoogleFonts.manrope(
              color: kMutedInk,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 34),
          Form(
            key: state._formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('Work email'),
                const SizedBox(height: 9),
                TextFormField(
                  controller: state._emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    hintText: 'name@mezantea.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email is required';
                    if (!text.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _FieldLabel('Password'),
                const SizedBox(height: 9),
                TextFormField(
                  controller: state._passwordController,
                  obscureText: state._obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => state._submit(),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      onPressed: () => state.setState(
                        () => state._obscurePassword = !state._obscurePassword,
                      ),
                      icon: Icon(
                        state._obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'Password is required' : null,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state._isSubmitting ? null : state._submit,
                    child: state._isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Continue'),
                              const SizedBox(width: 9),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: Divider(color: kLine)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'SECURE ACCESS',
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: kMutedInk,
                  ),
                ),
              ),
              Expanded(child: Divider(color: kLine)),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} Mezan Tea · Credit Aging',
            style: GoogleFonts.manrope(
              color: kMutedInk,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 0 : 42,
          vertical: compact ? 0 : 32,
        ),
        child: form,
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final bool inverted;

  const _BrandMark({this.inverted = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: inverted ? Colors.white : kInk,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.show_chart_rounded,
            color: inverted ? kInk : Colors.white,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'MEZAN',
          style: GoogleFonts.manrope(
            color: inverted ? Colors.white : kInk,
            fontSize: 13,
            letterSpacing: 2.1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: kInk,
      ),
    );
  }
}

class _TinyDot extends StatelessWidget {
  final Color color;

  const _TinyDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
