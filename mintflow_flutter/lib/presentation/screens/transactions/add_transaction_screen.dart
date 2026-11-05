import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/theme/mint_inputs.dart';
import '../../cubits/cubits.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});
  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountCtrl = TextEditingController();
  final _merchantCtrl = TextEditingController();
  String _type = 'expense';
  bool? _isNeed;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero')),
      );
      return;
    }
    setState(() => _saving = true);
    final cubit = context.read<TransactionCubit>();
    await cubit.createTransaction(
      amount: amount,
      transactionType: _type,
      date: DateTime.now(),
      merchantName: _merchantCtrl.text.trim().isEmpty
          ? null
          : _merchantCtrl.text.trim(),
      isNeed: _type == 'expense' ? _isNeed : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final state = cubit.state;
    if (state is TransactionError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: MintflowColors.red,
        ),
      );
      return;
    }
    context.read<DashboardCubit>().refresh();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      appBar: AppBar(
        backgroundColor: MintflowColors.page(context),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: Icon(Icons.close, color: MintflowColors.textPrimary(context)),
          onPressed: () => context.pop(),
        ),
        title: Text('Add transaction',
            style: MintflowTextStyles.displaySmall
                .copyWith(color: MintflowColors.textPrimary(context))),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          MintBreakpoints.pageGutter(context),
          20,
          MintBreakpoints.pageGutter(context),
          20 + bottomInset,
        ),
        child: MintAdaptiveWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            label: 'Transaction type',
            child: Container(
              decoration: BoxDecoration(
                color: MintflowColors.softFill(context),
                borderRadius: MintflowRadius.lg_,
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                  children: ['expense', 'income', 'transfer'].map((t) {
                final active = _type == t;
                final label = t[0].toUpperCase() + t.substring(1);
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: active,
                    label: label,
                    child: InkWell(
                      borderRadius: MintflowRadius.md_,
                      onTap: () => setState(() => _type = t),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? MintflowColors.card(context)
                              : Colors.transparent,
                          borderRadius: MintflowRadius.md_,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: MintflowTextStyles.labelMedium.copyWith(
                            color: active
                                ? MintflowColors.textPrimary(context)
                                : MintflowColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList()),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            maxLength: 14,
            style: MintflowTextStyles.amountSmall,
            decoration: mintInputDecoration(
              context,
              label: 'Amount',
              hint: '0.00',
            ).copyWith(prefixText: '\$ ', counterText: ''),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _merchantCtrl,
            maxLength: 120,
            decoration: mintInputDecoration(
              context,
              label: 'Merchant / description',
              hint: 'e.g. Whole Foods',
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 16),
          if (_type == 'expense') ...[
            Text(
              'Classification',
              style: MintflowTextStyles.labelMedium.copyWith(
                color: MintflowColors.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _ClassChip(
                  label: 'Need',
                  selected: _isNeed == true,
                  onTap: () => setState(() => _isNeed = true)),
              const SizedBox(width: 10),
              _ClassChip(
                  label: 'Want',
                  selected: _isNeed == false,
                  onTap: () => setState(() => _isNeed = false)),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MintflowColors.mintWash(context),
                borderRadius: MintflowRadius.md_,
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome,
                    size: 13, color: MintflowColors.green500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AI will classify automatically if you skip.',
                    style: MintflowTextStyles.chip.copyWith(
                      color: MintflowColors.green600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MintflowColors.onBrand(context),
                      ),
                    )
                  : const Text('Save transaction'),
            ),
          ),
        ]),
        ),
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ClassChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: MintflowRadius.lg_,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? MintflowColors.mintWash(context)
                    : MintflowColors.card(context),
                borderRadius: MintflowRadius.lg_,
                border: Border.all(
                  color: selected
                      ? MintflowColors.green400
                      : MintflowColors.hairline(context),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: MintflowTextStyles.labelMedium.copyWith(
                      color: selected
                          ? MintflowColors.green600
                          : MintflowColors.textSecondary(context))),
            ),
          ),
        ),
      );
}
