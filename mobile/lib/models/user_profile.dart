import 'package:rico_investidor/models/subscription_plan.dart';

class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.plan,
    this.photoUrl,
    this.email,
    this.userId,
    this.isAnonymous = true,
  });

  final String displayName;
  final SubscriptionPlan plan;
  final String? photoUrl;
  final String? email;
  final String? userId;
  final bool isAnonymous;

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  bool get isRegistered => !isAnonymous;

  UserProfile copyWith({
    String? displayName,
    SubscriptionPlan? plan,
    String? photoUrl,
    String? email,
    String? userId,
    bool? isAnonymous,
    bool clearPhoto = false,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      plan: plan ?? this.plan,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      email: email ?? this.email,
      userId: userId ?? this.userId,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}
