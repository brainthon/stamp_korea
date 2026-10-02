import 'package:flutter/material.dart';
import '../screens/membership_policy_screen.dart';
import '../theme/app_theme.dart';

/// The same invitation is used at each member-only entry point.
class MemberAccessCard extends StatelessWidget {
  const MemberAccessCard({
    super.key,
    required this.title,
    required this.description,
    required this.onLogin,
    required this.onSignup,
    this.icon = Icons.collections_bookmark_outlined,
    this.compact = false,
  });

  final String title, description;
  final VoidCallback onLogin, onSignup;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 16 : 22),
    decoration: BoxDecoration(
      color: AppTheme.mint,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.borderGray),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryBlack, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          )
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Icon(icon, color: AppTheme.primaryBlack, size: 30),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
        SizedBox(height: compact ? 6 : 8),
        Text(description, style: const TextStyle(fontSize: 14, height: 1.6)),
        SizedBox(height: compact ? 12 : 20),
        FilledButton(onPressed: onSignup, child: const Text('무료 회원가입')),
        const SizedBox(height: 4),
        TextButton(onPressed: onLogin, child: const Text('이미 회원이라면 로그인')),
        TextButton(
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MembershipPolicyScreen(),
                ),
              ),
          child: const Text('회원별 이용 범위 보기'),
        ),
      ],
    ),
  );
}
