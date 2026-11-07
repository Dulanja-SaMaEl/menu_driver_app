import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';

class OrderChecklistSheet extends StatefulWidget {
  final Order order;
  final VoidCallback? onVerified;

  const OrderChecklistSheet({
    super.key,
    required this.order,
    this.onVerified,
  });

  static Future<void> show(
    BuildContext context, {
    required Order order,
    VoidCallback? onVerified,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => OrderChecklistSheet(order: order, onVerified: onVerified),
    );
  }

  @override
  State<OrderChecklistSheet> createState() => _OrderChecklistSheetState();
}

class _OrderChecklistSheetState extends State<OrderChecklistSheet> {
  late List<OrderItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.order.items;
  }

  @override
  Widget build(BuildContext context) {
    final verifiedCount = _items.where((i) => i.isChecked).length;
    final totalCount = _items.length;
    final isAllDone = totalCount > 0 && verifiedCount == totalCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item Verification',
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Check off items before leaving store for ${widget.order.orderNumber}',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isAllDone ? AppTheme.success : const Color(0xFF2563EB))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$verifiedCount / $totalCount Checked',
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isAllDone ? AppTheme.success : const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar
            LinearProgressIndicator(
              value: totalCount == 0 ? 1 : verifiedCount / totalCount,
              backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              color: isAllDone ? AppTheme.success : const Color(0xFF2563EB),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),

            const SizedBox(height: 16),

            // Item Checklist List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = _items[i];
                  return CheckboxListTile(
                    value: item.isChecked,
                    activeColor: AppTheme.success,
                    title: Text(
                      '${item.quantity}x ${item.name}',
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        decoration: item.isChecked ? TextDecoration.lineThrough : null,
                        color: item.isChecked
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: item.notes != null && item.notes!.isNotEmpty
                        ? Text(
                            item.notes!,
                            style: GoogleFonts.lato(fontSize: 12, color: Colors.orange),
                          )
                        : null,
                    onChanged: (val) {
                      setState(() {
                        item.isChecked = val ?? false;
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            if (isAllDone)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All items verified! Package ready for delivery.',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (isAllDone && widget.onVerified != null) {
                    widget.onVerified!();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAllDone ? AppTheme.success : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isAllDone ? 'Done & Ready to Deliver' : 'Close Checklist',
                  style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
