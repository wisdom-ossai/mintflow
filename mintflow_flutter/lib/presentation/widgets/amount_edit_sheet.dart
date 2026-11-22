import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/theme/mint_inputs.dart';

/// Modal amount editor used for monthly budget / savings targets.
class AmountEditSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final double? initial;
  final String confirmLabel;

  const AmountEditSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.confirmLabel,
  });

  /// Shows the sheet and returns the confirmed amount, or null if dismissed.
  static Future<double?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double? initial,
    required String confirmLabel,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: MintBreakpoints.formMax),
      builder: (_) => AmountEditSheet(
        title: title,
        subtitle: subtitle,
        initial: initial,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  State<AmountEditSheet> createState() => _AmountEditSheetState();
}

class _AmountEditSheetState extends State<AmountEditSheet> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initial != null
          ? widget.initial!.toStringAsFixed(
              widget.initial! == widget.initial!.roundToDouble() ? 0 : 2)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _ctrl.text.replaceAll(',', '').trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: MintflowColors.page(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          MintflowSpacing.xxl,
          MintflowSpacing.xl,
          MintflowSpacing.xxl,
          MintflowSpacing.xxl + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintflowColors.hairline(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MintflowSpacing.xl),
            Text(
              widget.title,
              style: MintflowTextStyles.displaySmall
                  .copyWith(color: MintflowColors.textPrimary(context)),
            ),
            const SizedBox(height: MintflowSpacing.sm),
            Text(
              widget.subtitle,
              style: MintflowTextStyles.bodySmall
                  .copyWith(color: MintflowColors.textSecondary(context)),
            ),
            const SizedBox(height: MintflowSpacing.xl),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLength: 14,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: MintflowTextStyles.amountSmall
                  .copyWith(color: MintflowColors.textPrimary(context)),
              decoration: mintInputDecoration(
                context,
                label: widget.title,
                hint: '0',
              ).copyWith(
                prefixText: '\$ ',
                errorText: _error,
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: MintflowSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
