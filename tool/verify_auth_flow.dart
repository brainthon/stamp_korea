import '../lib/services/auth_flow.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  check(
    authFailureMessage('identity_already_exists').contains('다른 회원'),
    'Linked identity conflicts must not imply accounts were merged',
  );
  check(
    authFailureMessage('manual_linking_disabled').contains('활성화'),
    'Disabled linking should explain configuration requirement',
  );

  check(
    authRedirectUrl(
          web: true,
          base: Uri.parse(
            'http://127.0.0.1:8320/?v=test&code=private#access_token=private',
          ),
        ) ==
        'http://127.0.0.1:8320/',
    'Web callback must not carry auth codes or UI parameters',
  );
  check(
    authRedirectUrl(
          web: true,
          base: Uri.parse('https://example.invalid/stamps/?admin=true'),
        ) ==
        'https://example.invalid/stamps/',
    'Preserve deployment directory',
  );
  check(
    authRedirectUrl(web: false, base: Uri.parse('https://evil.invalid')) ==
        mobileAuthRedirect,
    'Native callback fixed to app',
  );
  check(
    authProviderEnabled({
      'external': {'kakao': true},
    }, 'kakao'),
    'Enabled provider',
  );
  check(
    !authProviderEnabled({
      'external': {'google': false},
    }, 'google'),
    'Disabled provider',
  );
  for (final settings in <Map<String, dynamic>>[
    {},
    {'external': {}},
    {
      'external': {'kakao': 'true'},
    },
  ]) {
    try {
      authProviderEnabled(settings, 'kakao');
      throw StateError('Invalid provider settings accepted');
    } on FormatException {
      /* expected */
    }
  }
  check(
    authCallbackFailure(
          Uri.parse('https://example.invalid/?error=access_denied'),
        ) ==
        authFailureMessage('access_denied'),
    'Query cancellation',
  );
  check(
    authCallbackFailure(
          Uri.parse(
            'https://example.invalid/#error_code=otp_expired&error_description=private',
          ),
        ) ==
        authFailureMessage('otp_expired'),
    'Fragment expiry',
  );
  check(
    authCallbackFailure(
          Uri.parse(
            'https://example.invalid/?code=private#access_token=private',
          ),
        ) ==
        null,
    'Success callback left to Supabase SDK',
  );
  check(
    !authCallbackFailure(
      Uri.parse(
        'https://example.invalid/?error=other&error_description=private%3Cscript%3E',
      ),
    )!.contains('private'),
    'Never show raw provider details',
  );
  check(
    authFailureMessage('provider_disabled_kakao').contains('카카오'),
    'Specific Kakao configuration message',
  );
  check(
    authFailureMessage('provider_disabled_google').contains('Google'),
    'Specific Google configuration message',
  );
  print(
    'PASS: web/native redirects, provider settings validation, cancellation, expiry and callback detail sanitization',
  );
}
