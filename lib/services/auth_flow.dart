const mobileAuthRedirect = 'io.supabase.stampkorea://login-callback/';

String authRedirectUrl({required bool web, required Uri base}) {
  if (!web) return mobileAuthRedirect;
  // Preserve a deployment subdirectory, never callback credentials or UI query parameters.
  return base
      .replace(query: '', fragment: '')
      .toString()
      .split('?')
      .first
      .split('#')
      .first;
}

bool authProviderEnabled(Map<String, dynamic> settings, String provider) {
  final external = settings['external'];
  if (external is! Map || external[provider] is! bool) {
    throw const FormatException('Invalid authentication settings');
  }
  return external[provider] == true;
}

String authFailureMessage(String? code) => switch (code) {
  'provider_disabled_kakao' => '카카오 로그인이 아직 연결되지 않았어요. 설정 완료 후 이용할 수 있습니다.',
  'provider_disabled_google' => 'Google 로그인이 아직 연결되지 않았어요. 설정 완료 후 이용할 수 있습니다.',
  'manual_linking_disabled' => '로그인 계정 연결이 아직 활성화되지 않았어요. 관리자 설정이 필요합니다.',
  'identity_already_exists' ||
  'email_exists' => '이미 다른 회원에 연결된 계정이에요. 기존 계정의 데이터 통합은 별도 확인이 필요합니다.',
  'provider_already_linked' => '이미 연결된 로그인 방식이에요.',
  'session_not_found' || 'session_expired' => '기존 계정으로 다시 로그인한 뒤 연결해 주세요.',
  'invalid_credentials' => '이메일 또는 비밀번호를 확인해 주세요.',
  'email_not_confirmed' => '받은 메일에서 이메일 인증을 완료해 주세요. 아래에서 확인 메일을 다시 받을 수 있어요.',
  'access_denied' || 'user_cancelled' => '로그인을 취소했어요. 원하실 때 다시 시도해 주세요.',
  'otp_expired' ||
  'flow_state_expired' ||
  'flow_state_not_found' ||
  'bad_code_verifier' => '인증 링크가 만료되었거나 로그인 요청을 확인할 수 없어요. 이 기기에서 다시 시작해 주세요.',
  'over_email_send_rate_limit' ||
  'over_request_rate_limit' ||
  'over_email_send_limit' => '요청이 많아요. 잠시 후 다시 시도해 주세요.',
  'oauth_launch_failed' => '로그인 페이지를 열지 못했어요. 브라우저 설정을 확인하고 다시 시도해 주세요.',
  'weak_password' => '더 안전한 비밀번호를 입력해 주세요. 8자 이상을 권장합니다.',
  'same_password' => '이전과 다른 비밀번호를 입력해 주세요.',
  'signup_disabled' => '현재 회원가입을 잠시 사용할 수 없습니다.',
  'auth_settings_unavailable' => '로그인 설정을 확인하지 못했어요. 연결을 확인하고 다시 시도해 주세요.',
  'provider_disabled' ||
  'validation_failed' ||
  'bad_oauth_callback' ||
  'bad_oauth_state' => '소셜 로그인 연결 설정을 확인해야 합니다. 잠시 후 다시 시도해 주세요.',
  _ => '인증을 완료하지 못했어요. 입력 내용과 연결 상태를 확인해 주세요.',
};

String? authCallbackFailure(Uri uri) {
  Map<String, String> fragment = {};
  try {
    fragment = Uri.splitQueryString(uri.fragment);
  } on FormatException {
    return authFailureMessage(null);
  }
  final values = {...fragment, ...uri.queryParameters};
  if (!values.containsKey('error') && !values.containsKey('error_code')) {
    return null;
  }
  // Do not show provider-supplied descriptions, tokens, URLs, or HTML.
  return authFailureMessage(values['error_code'] ?? values['error']);
}
