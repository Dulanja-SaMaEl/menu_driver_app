import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';

class ProofOfDeliverySheet extends StatefulWidget {
  final Order order;
  final Function({String? notes, String? photoBase64, String? recipientName}) onConfirm;

  const ProofOfDeliverySheet({
    super.key,
    required this.order,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required Order order,
    required Function({String? notes, String? photoBase64, String? recipientName}) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ProofOfDeliverySheet(order: order, onConfirm: onConfirm),
      ),
    );
  }

  @override
  State<ProofOfDeliverySheet> createState() => _ProofOfDeliverySheetState();
}

class _ProofOfDeliverySheetState extends State<ProofOfDeliverySheet> {
  final ImagePicker _picker = ImagePicker();
  XFile? _capturedImage;
  String? _imageBase64;
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _recipientCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _recipientCtrl.text = widget.order.customerName;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _recipientCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _capturedImage = file;
          _imageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access camera/gallery: $e')),
        );
      }
    }
  }

  void _submit() {
    setState(() => _isProcessing = true);
    Navigator.pop(context);
    widget.onConfirm(
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      photoBase64: _imageBase64,
      recipientName: _recipientCtrl.text.trim().isEmpty ? null : _recipientCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
                      'Proof of Delivery',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Confirm order completion for ${widget.order.orderNumber}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded, color: AppTheme.success, size: 22),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Camera / Doorstep Photo Preview Card
            GestureDetector(
              onTap: () => _pickImage(ImageSource.camera),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _capturedImage != null
                        ? AppTheme.success
                        : Theme.of(context).dividerColor,
                    width: _capturedImage != null ? 2 : 1,
                  ),
                ),
                child: _capturedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: kIsWeb
                                ? Image.network(_capturedImage!.path, fit: BoxFit.cover)
                                : Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            size: 34,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Take Handover Photo (Optional)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Eliminates delivery disputes with customer & admin',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 8),

            // Choose from Gallery option
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 15),
                  label: const Text('Choose from Gallery', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Received By Name
            Text(
              'Received By',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _recipientCtrl,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Customer / Recipient Name',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 14),

            // Delivery Notes
            Text(
              'Delivery Notes',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g., Handed to customer, Left with security guard',
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 22),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(
                  'Confirm & Mark Delivered',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
