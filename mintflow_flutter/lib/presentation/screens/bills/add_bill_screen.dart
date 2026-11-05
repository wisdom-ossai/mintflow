import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../cubits/cubits.dart';

class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController(text: '1');
  bool _autopay = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _dueDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final dueDay = int.tryParse(_dueDayCtrl.text.trim());
    final amountRaw = _amountCtrl.text.trim().replaceAll(',', '');
    final amount = amountRaw.isEmpty ? null : double.tryParse(amountRaw);

    if (name.isEmpty) {
      setState(() => _error = 'Enter a bill name');
      return;
    }
    if (dueDay == null || dueDay < 1 || dueDay > 31) {
      setState(() => _error = 'Due day must be between 1 and 31');
      return;
    }
    if (amountRaw.isNotEmpty && amount == null) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final err = await context.read<BillCubit>().create(
          name: name,
          amount: amount,
          dueDay: dueDay,
          isAutopay: _autopay,
        );
    if (!mounted) return;
    if (err != null) {
      final isUpgrade = err.toLowerCase().contains('upgrade') ||
          err.toLowerCase().contains('growth') ||
          err.toLowerCase().contains('limit');
      if (isUpgrade) {
        context.push('${MintflowRoutes.paywall}?feature=unlimited_bills');
        setState(() => _saving = false);
        return;
      }
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      appBar: AppBar(
        backgroundColor: MintflowColors.green900,
        foregroundColor: MintflowColors.cream,
        title: Text(
          'Add bill',
          style: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.cream),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          MintBreakpoints.pageGutter(context),
          20,
          MintBreakpoints.pageGutter(context),
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          MintAdaptiveWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          Text(
            'Track rent, utilities, insurance, or any obligation with a monthly due day.',
            style: MintflowTextStyles.bodySmall
                .copyWith(color: MintflowColors.textSecondary(context)),
          ),
          const SizedBox(height: 20),
          _Field(
            controller: _nameCtrl,
            label: 'Name',
            hint: 'Rent, Electric, Car insurance…',
            textInputAction: TextInputAction.next,
            maxLength: 80,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _amountCtrl,
            label: 'Amount (optional)',
            hint: '0.00',
            prefix: '\$ ',
            maxLength: 14,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _dueDayCtrl,
            label: 'Due day of month',
            hint: '1–31',
            maxLength: 2,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Autopay', style: MintflowTextStyles.labelMedium),
            subtitle: Text(
              'Reminder only — Mintflow does not move money',
              style: MintflowTextStyles.overline
                  .copyWith(color: MintflowColors.textSecondary(context)),
            ),
            value: _autopay,
            activeTrackColor: MintflowColors.green400,
            onChanged: (v) => setState(() => _autopay = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: MintflowTextStyles.bodySmall
                  .copyWith(color: MintflowColors.red),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: MintflowColors.green400,
                foregroundColor: MintflowColors.green900,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: MintflowRadius.lg_,
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save bill',
                      style: MintflowTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MintflowColors.green900,
                      ),
                      ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? prefix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        counterText: '',
        filled: true,
        fillColor: MintflowColors.card(context),
        border: OutlineInputBorder(
          borderRadius: MintflowRadius.lg_,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
