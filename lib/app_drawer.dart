import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'download_manager.dart';
import 'settings.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback onGoHome;
  final VoidCallback onReload;

  const AppDrawer({
    super.key,
    required this.onGoHome,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/logo.png', // Make sure you have this file
                  height: 60,
                  // Add a fallback for the image
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.school,
                        size: 60, color: Colors.white);
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.saigonEdtech,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(AppLocalizations.of(context)!.home),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              onGoHome();
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(AppLocalizations.of(context)!.reloadPage),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              onReload();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(AppLocalizations.of(context)!.downloadedFiles),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const DownloadManagerPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(AppLocalizations.of(context)!.settings),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
