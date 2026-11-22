import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/theme/mint_inputs.dart';
import '../../cubits/cubits.dart';
import '../../widgets/upgrade_soft_gate.dart';

/// Creates a real savings goal — name + target is the activation aha.
class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  DateTime? _targetDate;
  bool _saving = false;
  String? _error;

  static const _templates = <({String name, double amount})>[
    (name: 'Emergency fund', amount: 1000),
    (name: 'Trip', amount: 1500),
    (name: 'Buffer', amount: 500),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate(({String name, double amount}) t) {
    setState(() {
      _nameCtrl.text = t.name;
      _amountCtrl.text = t.amount.toStringAsFixed(0);
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year, now.month + 3, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      setState(() {
        _targetDate = picked;
        _dateCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amountRaw = _amountCtrl.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountRaw);

    if (name.isEmpty) {
      setState(() => _error = 'Enter a goal name');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a target greater than zero');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final err = await context.read<GoalCubit>().create(
          name: name,
          targetAmount: amount,
          targetDate: _targetDate,
        );
    if (!mounted) return;
    if (err != null) {
      final isUpgrade = err.toLowerCase().contains('upgrade') ||
          err.toLowerCase().contains('growth') ||
          err.toLowerCase().contains('limit');
      if (isUpgrade) {
        await openUpgradeFlow(context, feature: 'unlimited_goals');
        if (mounted) setState(() => _saving = false);
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
          'Add goal',
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
            'Name a target and an amount. Progress fills as you contribute.',
            style: MintflowTextStyles.bodySmall.copyWith(
              color: MintflowColors.textSecondary(context),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start from a template',
            style: MintflowTextStyles.labelMedium.copyWith(
              color: MintflowColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _templates
                .map(
                  (t) => ActionChip(
                    label: Text(t.name),
                    onPressed: () => _applyTemplate(t),
                    backgroundColor: MintflowColors.softFill(context),
                    side: BorderSide(color: MintflowColors.hairline(context)),
                    labelStyle: MintflowTextStyles.labelMedium.copyWith(
                      color: MintflowColors.textPrimary(context),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            maxLength: 80,
            decoration: mintInputDecoration(
              context,
              label: 'Goal name',
              hint: 'Emergency fund',
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            maxLength: 14,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: mintInputDecoration(
              context,
              label: 'Target amount',
              hint: '0.00',
            ).copyWith(prefixText: '\$ ', counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            readOnly: true,
            controller: _dateCtrl,
            onTap: _pickDate,
            decoration: mintInputDecoration(
              context,
              label: 'Target date (optional)',
              hint: 'Pick a deadline',
              suffixIcon: Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: MintflowColors.textTertiary(context),
              ),
            ),
          ),
          if (_targetDate != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _targetDate = null;
                  _dateCtrl.clear();
                }),
                child: const Text('Clear date'),
              ),
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
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MintflowColors.green900,
                      ),
                    )
                  : const Text('Create goal'),
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
