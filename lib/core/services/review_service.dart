import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Requests an in-app review once per install.
/// Safe to call after any measurement success; no-ops if already requested.
class ReviewService {
  static const _key = 'review_requested';

  static Future<void> requestIfEligible() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_key) ?? false) return;
    final inAppReview = InAppReview.instance;
    if (!await inAppReview.isAvailable()) return;
    await inAppReview.requestReview();
    await p.setBool(_key, true);
  }
}
