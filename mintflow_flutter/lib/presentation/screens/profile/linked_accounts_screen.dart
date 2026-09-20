import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../core/utils/format.dart';
import '../../../data/datasources/local_cache.dart';
import '../../../data/datasources/service_locator.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';

class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  bool _loading = true;
  bool _linking = false;
  String? _error;
  List<AccountModel> _accounts = const [];
  String? _busyAccountId;

  StreamSubscription<LinkSuccess>? _plaidSuccessSub;
  StreamSubscription<LinkExit>? _plaidExitSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _plaidSuccessSub?.cancel();
    _plaidExitSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await ServiceLocator.instance.api.getAccounts();
      await MintflowCache.set(
        CacheKeys.accounts,
        accounts.length,
        ttl: const Duration(minutes: 5),
      );
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  UserModel? get _user {
    final state = context.read<UserCubit>().state;
    return state is UserLoaded ? state.user : null;
  }

  Future<void> _connectBank() async {
    final user = _user;
    if (user == null || !user.hasFeature('bank_sync')) {
      if (mounted) {
        context.push('${MintflowRoutes.paywall}?feature=bank_sync');
      }
      return;
    }

    final plaidCount = _accounts.length;
    // Soft client gate — server enforces the real cap.
    if (!user.hasFeature('unlimited_accounts') && plaidCount >= 2) {
      if (mounted) {
        context.push('${MintflowRoutes.paywall}?feature=unlimited_accounts');
      }
      return;
    }

    setState(() => _linking = true);
    try {
      final tokenRes = await ServiceLocator.instance.api.getPlaidLinkToken();
      final linkToken = tokenRes['link_token'] as String?;
      if (linkToken == null || linkToken.isEmpty) {
        throw Exception('Missing link token');
      }

      await _plaidSuccessSub?.cancel();
      await _plaidExitSub?.cancel();

      _plaidSuccessSub = PlaidLink.onSuccess.listen((success) async {
        try {
          await ServiceLocator.instance.api.exchangePlaidToken(
            success.publicToken,
            institutionName: success.metadata.institution?.name,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Account linked'),
                backgroundColor: MintflowColors.green900,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
                margin: const EdgeInsets.all(16),
              ),
            );
            await _load();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(friendlyAuthError(e)),
                backgroundColor: MintflowColors.red,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _linking = false);
        }
      });

      _plaidExitSub = PlaidLink.onExit.listen((exit) {
        if (!mounted) return;
        setState(() => _linking = false);
        final msg = exit.error?.displayMessage ??
            exit.error?.message ??
            'Bank connection cancelled';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: MintflowColors.ink60,
          ),
        );
      });

      await PlaidLink.create(
        configuration: LinkTokenConfiguration(token: linkToken),
      );
      await PlaidLink.open();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _linking = false);
      if (e.response?.statusCode == 403) {
        final detail = (e.response?.data is Map)
            ? (e.response!.data['detail']?.toString() ?? '')
            : '';
        final feature = detail.toLowerCase().contains('unlimited')
            ? 'unlimited_accounts'
            : 'bank_sync';
        context.push('${MintflowRoutes.paywall}?feature=$feature');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyAuthError(e)),
          backgroundColor: MintflowColors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _linking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyAuthError(e)),
          backgroundColor: MintflowColors.red,
        ),
      );
    }
  }

  Future<void> _sync(AccountModel account) async {
    setState(() => _busyAccountId = account.id);
    try {
      final result =
          await ServiceLocator.instance.api.syncAccount(account.id);
      final added = result['added'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced — $added new transactions'),
            backgroundColor: MintflowColors.green900,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
            margin: const EdgeInsets.all(16),
          ),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyAuthError(e)),
            backgroundColor: MintflowColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAccountId = null);
    }
  }

  Future<void> _unlink(AccountModel account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: MintflowRadius.xl_),
        title: Text('Unlink account?', style: MintflowTextStyles.labelLarge),
        content: Text(
          '“${account.name}” will stop syncing. Past transactions stay in your history.',
          style: MintflowTextStyles.bodyMedium
              .copyWith(color: MintflowColors.ink60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: MintflowTextStyles.labelMedium
                    .copyWith(color: MintflowColors.ink60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unlink',
                style: MintflowTextStyles.labelMedium
                    .copyWith(color: MintflowColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyAccountId = account.id);
    try {
      await ServiceLocator.instance.api.unlinkAccount(account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account unlinked'),
            backgroundColor: MintflowColors.green900,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
            margin: const EdgeInsets.all(16),
          ),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyAuthError(e)),
            backgroundColor: MintflowColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAccountId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.cream,
      appBar: AppBar(
        backgroundColor: MintflowColors.green900,
        foregroundColor: MintflowColors.cream,
        title: Text(
          'Linked accounts',
          style: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.cream),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: MintflowColors.green400),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: MintflowColors.green400,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    children: [
                      Text(
                        _accounts.isEmpty
                            ? 'No accounts linked yet'
                            : '${_accounts.length} connected',
                        style: MintflowTextStyles.bodyMedium
                            .copyWith(color: MintflowColors.ink60),
                      ),
                      const SizedBox(height: 16),
                      if (_accounts.isEmpty)
                        _EmptyCard(onConnect: _linking ? null : _connectBank)
                      else
                        ..._accounts.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AccountCard(
                              account: a,
                              busy: _busyAccountId == a.id,
                              canSync: a.lastSyncedAt != null,
                              onSync: () => _sync(a),
                              onUnlink: () => _unlink(a),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: _accounts.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _linking ? null : _connectBank,
              backgroundColor: MintflowColors.green400,
              foregroundColor: MintflowColors.green900,
              icon: _linking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(
                _linking ? 'Opening…' : 'Link account',
                style: MintflowTextStyles.labelMedium.copyWith(
                  color: MintflowColors.green900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final VoidCallback? onConnect;
  const _EmptyCard({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: MintflowRadius.xl_,
        border: Border.all(color: MintflowColors.ink10),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_outlined,
              size: 40, color: MintflowColors.green500),
          const SizedBox(height: 12),
          Text(
            'Connect a bank or card',
            style: MintflowTextStyles.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Securely sync transactions with Plaid. Growth includes 2 accounts; Pro is unlimited.',
            style: MintflowTextStyles.bodySmall
                .copyWith(color: MintflowColors.ink60),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: MintflowColors.green400,
                foregroundColor: MintflowColors.green900,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: MintflowRadius.lg_,
                ),
              ),
              child: Text(
                'Link account',
                style: MintflowTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: MintflowColors.green900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AccountModel account;
  final bool busy;
  final bool canSync;
  final VoidCallback onSync;
  final VoidCallback onUnlink;

  const _AccountCard({
    required this.account,
    required this.busy,
    required this.canSync,
    required this.onSync,
    required this.onUnlink,
  });

  String get _typeLabel {
    switch (account.accountType) {
      case AccountType.creditCard:
        return 'Credit card';
      case AccountType.cash:
        return 'Cash';
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.loan:
        return 'Loan';
      case AccountType.bank:
        return 'Bank';
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (account.institutionName != null &&
          account.institutionName!.isNotEmpty)
        account.institutionName!,
      _typeLabel,
      if (account.lastSyncedAt != null)
        'Synced ${MintflowFormat.dateShort(account.lastSyncedAt!)}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: MintflowRadius.xl_,
        border: Border.all(color: MintflowColors.ink10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MintflowColors.green50,
                  borderRadius: MintflowRadius.lg_,
                ),
                child: Icon(
                  account.isCreditCard
                      ? Icons.credit_card_rounded
                      : Icons.account_balance_outlined,
                  color: MintflowColors.green500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: MintflowTextStyles.labelLarge,
                    ),
                    Text(
                      subtitle,
                      style: MintflowTextStyles.overline
                          .copyWith(color: MintflowColors.ink60),
                    ),
                  ],
                ),
              ),
              Text(
                MintflowFormat.currency(account.currentBalance),
                style: MintflowTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (canSync)
                TextButton.icon(
                  onPressed: busy ? null : onSync,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync'),
                  style: TextButton.styleFrom(
                    foregroundColor: MintflowColors.blue,
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: busy ? null : onUnlink,
                child: Text(
                  'Unlink',
                  style: MintflowTextStyles.labelMedium
                      .copyWith(color: MintflowColors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: MintflowTextStyles.bodyMedium
                    .copyWith(color: MintflowColors.ink60)),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
