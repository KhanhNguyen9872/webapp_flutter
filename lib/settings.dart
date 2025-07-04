import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'settings_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(AppLocalizations.of(context)!.language,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<Locale>(
            title: Text(AppLocalizations.of(context)!.vietnamese),
            value: const Locale('vi'),
            groupValue: settingsProvider.locale,
            onChanged: (Locale? value) {
              if (value != null) {
                settingsProvider.setLocale(value);
              }
            },
          ),
          RadioListTile<Locale>(
            title: Text(AppLocalizations.of(context)!.english),
            value: const Locale('en'),
            groupValue: settingsProvider.locale,
            onChanged: (Locale? value) {
              if (value != null) {
                settingsProvider.setLocale(value);
              }
            },
          ),
          const Divider(),
          ListTile(
            title: Text(AppLocalizations.of(context)!.theme,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ThemeMode>(
            title: Text(AppLocalizations.of(context)!.light),
            value: ThemeMode.light,
            groupValue: settingsProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                settingsProvider.setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(AppLocalizations.of(context)!.dark),
            value: ThemeMode.dark,
            groupValue: settingsProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                settingsProvider.setThemeMode(value);
              }
            },
          ),
          const Divider(),
          ListTile(
            title: Text(AppLocalizations.of(context)!.appVersion),
            subtitle: Text(_version),
          ),
        ],
      ),
    );
  }
}
