import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../core/utils/format.dart';
import '../../../data/datasources/service_locator.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';
import '../../widgets/upgrade_soft_gate.dart';

/// Pro receipt OCR — camera or gallery → create expense transaction.
class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final _picker = ImagePicker();
  bool _busy = false;
  ReceiptOcrResult? _result;
  String? _error;
  Uint8List? _preview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserCubit>().state;
      final u = user is UserLoaded ? user.user : null;
      if (u != null && !u.hasFeature('receipt_ocr')) {
        openUpgradeFlow(context, feature: 'receipt_ocr');
      }
    });
  }

  Future<void> _pick(ImageSource source) async {
    final user = context.read<UserCubit>().state;
    final u = user is UserLoaded ? user.user : null;
    if (u == null || !u.hasFeature('receipt_ocr')) {
      await openUpgradeFlow(context, feature: 'receipt_ocr');
      return;
    }

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final bytes = await file.readAsBytes();
      setState(() => _preview = bytes);
      final result = await ServiceLocator.instance.api.scanReceipt(
        bytes: bytes,
        filename: file.name.isNotEmpty ? file.name : 'receipt.jpg',
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
      context.read<TransactionCubit>().load();
      context.read<DashboardCubit>().load(forceRefresh: true);
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 403) {
        setState(() => _busy = false);
        await openUpgradeFlow(context, feature: 'receipt_ocr');
        return;
      }
      final detail = e.response?.data is Map
          ? (e.response!.data['detail']?.toString())
          : null;
      setState(() {
        _busy = false;
        _error = detail ?? friendlyAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MintBreakpoints.pageGutter(context);
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      appBar: AppBar(
        backgroundColor: MintflowColors.green900,
        foregroundColor: MintflowColors.cream,
        title: Text(
          'Scan receipt',
          style: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.cream),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 40),
        children: [
          MintAdaptiveWidth(
            maxWidth: MintBreakpoints.formMax,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mintflow reads the total and merchant, then logs an expense. '
                  'The photo is not stored.',
                  style: MintflowTextStyles.bodyMedium.copyWith(
                    color: MintflowColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 24),
                if (_preview != null) ...[
                  ClipRRect(
                    borderRadius: MintflowRadius.lg_,
                    child: Image.memory(
                      _preview!,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
                if (_busy) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  Text(
                    'Reading receipt…',
                    textAlign: TextAlign.center,
                    style: MintflowTextStyles.bodySmall.copyWith(
                      color: MintflowColors.textSecondary(context),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _error!,
                    style: MintflowTextStyles.bodySmall
                        .copyWith(color: MintflowColors.red),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MintflowColors.card(context),
                      borderRadius: MintflowRadius.xl_,
                      border:
                          Border.all(color: MintflowColors.hairline(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Logged', style: MintflowTextStyles.labelLarge),
                        const SizedBox(height: 8),
                        Text(
                          _result!.merchantName ?? 'Receipt',
                          style: MintflowTextStyles.displaySmall,
                        ),
                        Text(
                          MintflowFormat.currency(_result!.amount),
                          style: MintflowTextStyles.labelLarge.copyWith(
                            color: MintflowColors.green600,
                          ),
                        ),
                        if (_result!.categoryName != null)
                          Text(
                            _result!.categoryName!,
                            style: MintflowTextStyles.bodySmall.copyWith(
                              color: MintflowColors.textSecondary(context),
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () =>
                              context.go(MintflowRoutes.transactions),
                          child: const Text('View transactions'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
