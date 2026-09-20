import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../data/datasources/service_locator.dart';
import '../../cubits/cubits.dart';

class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  bool _exporting = false;

  Future<void> _exportCsv() async {
    final userState = context.read<UserCubit>().state;
    final user = userState is UserLoaded ? userState.user : null;
    if (user == null || !user.hasFeature('csv_export')) {
      if (mounted) {
        context.push('${MintflowRoutes.paywall}?feature=csv_export');
      }
      return;
    }

    setState(() => _exporting = true);
    try {
      final result =
          await ServiceLocator.instance.api.exportTransactionsCsv();
      if (result.bytes.isEmpty) {
        throw Exception('Export returned no data');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${result.filename}');
      await file.writeAsBytes(result.bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Mintflow transactions',
          text: 'Your Mintflow transaction export',
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 403) {
        context.push('${MintflowRoutes.paywall}?feature=csv_export');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyAuthError(e)),
          backgroundColor: MintflowColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        final user = state is UserLoaded ? state.user : null;
        final canExport = user?.hasFeature('csv_export') ?? false;

        return Scaffold(
          backgroundColor: MintflowColors.cream,
          appBar: AppBar(
            backgroundColor: MintflowColors.green900,
            foregroundColor: MintflowColors.cream,
            title: Text(
              'Export data',
              style: MintflowTextStyles.displaySmall
                  .copyWith(color: MintflowColors.cream),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
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
                            color: MintflowColors.blueSoft,
                            borderRadius: MintflowRadius.lg_,
                          ),
                          child: const Icon(Icons.download_outlined,
                              color: MintflowColors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CSV export',
                                  style: MintflowTextStyles.labelLarge),
                              Text(
                                canExport
                                    ? 'Download all transactions for tax prep or spreadsheets'
                                    : 'Pro feature — upgrade to export your data',
                                style: MintflowTextStyles.bodySmall
                                    .copyWith(color: MintflowColors.ink60),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Includes date, amount, type, merchant, category, needs/wants, and notes.',
                      style: MintflowTextStyles.bodySmall
                          .copyWith(color: MintflowColors.ink60),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _exporting ? null : _exportCsv,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canExport
                              ? MintflowColors.green400
                              : MintflowColors.purple,
                          foregroundColor: canExport
                              ? MintflowColors.green900
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: MintflowRadius.lg_,
                          ),
                        ),
                        child: _exporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MintflowColors.green900,
                                ),
                              )
                            : Text(
                                canExport
                                    ? 'Export & share CSV'
                                    : 'Upgrade to Pro',
                                style: MintflowTextStyles.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: canExport
                                      ? MintflowColors.green900
                                      : Colors.white,
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
      },
    );
  }
}
