import 'package:rico_investidor/models/subscription_plan.dart';

class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.plan,
    this.photoUrl,
    this.email,
    this.userId,
    this.countryCode,
    this.isAnonymous = true,
  });

  final String displayName;
  final SubscriptionPlan plan;
  final String? photoUrl;
  final String? email;
  final String? userId;
  final String? countryCode;
  final bool isAnonymous;

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  bool get isRegistered => !isAnonymous;

  bool get hasCountryCode => countryCode?.trim().isNotEmpty == true;

  UserProfile copyWith({
    String? displayName,
    SubscriptionPlan? plan,
    String? photoUrl,
    String? email,
    String? userId,
    String? countryCode,
    bool? isAnonymous,
    bool clearPhoto = false,
    bool clearCountryCode = false,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      plan: plan ?? this.plan,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      email: email ?? this.email,
      userId: userId ?? this.userId,
      countryCode: clearCountryCode ? null : (countryCode ?? this.countryCode),
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}
