import 'package:rico_investidor/models/subscription_plan.dart';

class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.plan,
    this.photoUrl,
  });

  final String displayName;
  final SubscriptionPlan plan;
  final String? photoUrl;

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  UserProfile copyWith({
    String? displayName,
    SubscriptionPlan? plan,
    String? photoUrl,
    bool clearPhoto = false,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      plan: plan ?? this.plan,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
    );
  }
}
