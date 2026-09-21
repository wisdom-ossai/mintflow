import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
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
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      appBar: AppBar(
        backgroundColor: MintflowColors.page(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: MintflowColors.ink),
          onPressed: () => context.pop(),
        ),
        title: Text('Add transaction',
            style: MintflowTextStyles.displaySmall
                .copyWith(color: MintflowColors.ink)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            decoration: BoxDecoration(
              color: MintflowColors.creamDark,
              borderRadius: MintflowRadius.lg_,
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
                children: ['expense', 'income', 'transfer'].map((t) {
              final active = _type == t;
              return Expanded(
                  child: GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.transparent,
                    borderRadius: MintflowRadius.md_,
                  ),
                  child: Text(
                    t[0].toUpperCase() + t.substring(1),
                    textAlign: TextAlign.center,
                    style: MintflowTextStyles.labelMedium.copyWith(
                      color: active ? MintflowColors.ink : MintflowColors.ink60,
                    ),
                  ),
                ),
              ));
            }).toList()),
          ),
          const SizedBox(height: 24),
          _FieldLabel('Amount'),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: MintflowTextStyles.amountSmall,
            decoration: const InputDecoration(
              prefixText: '\$ ',
              hintText: '0.00',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          _FieldLabel('Merchant / description'),
          TextFormField(
            controller: _merchantCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Whole Foods'),
          ),
          const SizedBox(height: 16),
          if (_type == 'expense') ...[
            _FieldLabel('Classification'),
            const SizedBox(height: 4),
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
                color: MintflowColors.green50,
                borderRadius: MintflowRadius.md_,
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome,
                    size: 13, color: MintflowColors.green500),
                const SizedBox(width: 6),
                Text('AI will classify automatically if you skip.',
                    style: MintflowTextStyles.overline.copyWith(
                        color: MintflowColors.green600,
                        fontSize: 11,
                        fontWeight: FontWeight.w400)),
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save transaction'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style:
                MintflowTextStyles.overline.copyWith(color: MintflowColors.ink60)),
      );
}

class _ClassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ClassChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? MintflowColors.green50 : Colors.white,
              borderRadius: MintflowRadius.lg_,
              border: Border.all(
                color: selected ? MintflowColors.green400 : MintflowColors.ink10,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: MintflowTextStyles.labelMedium.copyWith(
                    color:
                        selected ? MintflowColors.green600 : MintflowColors.ink60)),
          ),
        ),
      );
}
