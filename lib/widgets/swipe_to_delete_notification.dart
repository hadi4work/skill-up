import 'package:flutter/material.dart';

/// سحب أفقيًا لإظهار الحذف ثم إزالة العنصر. يستخدم اتجاهًا أفقيًا مزدوجًا
/// ليعمل مع RTL وليتفادى تعارضًا شائعًا مع [DismissDirection.startToEnd] فقط.
///
/// يفضّل إخفاء [notificationId] من القائمة مؤقتاً في الأب حتى يكتمل الحذف من Firestore.
class SwipeToDeleteNotification extends StatelessWidget {
  const SwipeToDeleteNotification({
    super.key,
    required this.notificationId,
    required this.onDismissed,
    required this.child,
  });

  final String notificationId;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (notificationId.isEmpty) {
      return child;
    }

    final deleteBg = Container(
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.only(start: 20, end: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 28),
    );

    return Dismissible(
      key: ValueKey('swipe_notif_$notificationId'),
      direction: DismissDirection.horizontal,
      // اتجاه أفقي يتطلب خلفيتين غير null في إصدارات Flutter الحديثة.
      background: deleteBg,
      secondaryBackground: deleteBg,
      dismissThresholds: const {
        DismissDirection.horizontal: 0.25,
      },
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onDismissed(),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}
