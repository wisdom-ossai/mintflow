import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/service_locator.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _loading = true;
  String? _error;
  List<_NotifPref> _prefs = const [];

  static const Map<String, String> _labelMap = {
    'daily_summary': 'Daily summary',
    'weekly_digest': 'Weekly digest',
    'monthly_report': 'Monthly report',
    'budget_50': 'Budget 50% alert',
    'budget_80': 'Budget 80% alert',
    'budget_exceeded': 'Budget exceeded',
    'milestone': 'Milestone reached',
    'inactivity': 'Inactivity reminder',
    'ai_nudge': 'AI nudge',
    'salary_detected': 'Salary detected',
    'card_payment_due': 'Card payment due',
    'subscription_renewal': 'Subscription renewal',
    'high_utilization': 'High utilization',
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ServiceLocator.instance.api.getNotificationPrefs();
      final prefs = rows
          .map(
            (row) => _NotifPref(
              type: (row['notification_type'] ?? '').toString(),
              enabled: row['enabled'] == true,
              timeOfDay: row['time_of_day']?.toString(),
            ),
          )
          .where((p) => p.type.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load notifications: $e';
        });
      }
    }
  }

  Future<void> _togglePref(_NotifPref pref, bool next) async {
    final index = _prefs.indexWhere((p) => p.type == pref.type);
    if (index < 0) return;
    setState(() {
      _prefs[index] = _prefs[index].copyWith(enabled: next, saving: true);
    });
    try {
      final updated = await ServiceLocator.instance.api.updateNotificationPref(
        pref.type,
        next,
        timeOfDay: pref.timeOfDay,
      );
      if (!mounted) return;
      setState(() {
        _prefs[index] = _NotifPref(
          type: (updated['notification_type'] ?? pref.type).toString(),
          enabled: updated['enabled'] == true,
          timeOfDay: updated['time_of_day']?.toString(),
          saving: false,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prefs[index] = _prefs[index].copyWith(enabled: pref.enabled, saving: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update ${_titleFor(pref.type)}: $e'),
          backgroundColor: FlowraColors.red,
        ),
      );
    }
  }

  String _titleFor(String type) {
    return _labelMap[type] ??
        type
            .split('_')
            .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
            .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowraColors.cream,
      appBar: AppBar(
        backgroundColor: FlowraColors.green900,
        title: Text(
          'Notification settings',
          style: FlowraTextStyles.displaySmall.copyWith(color: FlowraColors.cream),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      style: FlowraTextStyles.bodySmall.copyWith(color: FlowraColors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: FlowraRadius.xl_,
                        border: Border.all(color: FlowraColors.ink10),
                      ),
                      child: Column(
                        children: _prefs
                            .map(
                              (p) => SwitchListTile.adaptive(
                                value: p.enabled,
                                onChanged: p.saving ? null : (v) => _togglePref(p, v),
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  _titleFor(p.type),
                                  style: FlowraTextStyles.bodySmall
                                      .copyWith(fontWeight: FontWeight.w500),
                                ),
                                subtitle: p.timeOfDay != null
                                    ? Text(
                                        'Time: ${p.timeOfDay}',
                                        style: FlowraTextStyles.overline
                                            .copyWith(color: FlowraColors.ink60),
                                      )
                                    : null,
                                secondary: p.saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.notifications_outlined),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _NotifPref {
  final String type;
  final bool enabled;
  final String? timeOfDay;
  final bool saving;

  const _NotifPref({
    required this.type,
    required this.enabled,
    this.timeOfDay,
    this.saving = false,
  });

  _NotifPref copyWith({
    String? type,
    bool? enabled,
    String? timeOfDay,
    bool? saving,
  }) {
    return _NotifPref(
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      saving: saving ?? this.saving,
    );
  }
}
