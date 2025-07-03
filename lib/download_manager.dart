import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;
  Directory? _saigonEdtechDir;

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // STABLE STORAGE LOGIC
      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir = await getExternalStorageDirectory();
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      if (baseDir != null) {
        _saigonEdtechDir = Directory('${baseDir.path}/SAIGON_EDTECH');

        Directory directoryToScan = _saigonEdtechDir!;

        if (await directoryToScan.exists()) {
          final items = directoryToScan.listSync();
          setState(() {
            _files = items
              ..sort((a, b) =>
                  b.statSync().modified.compareTo(a.statSync().modified));
          });
        } else {
          setState(() {
            _files = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                AppLocalizations.of(context)!.cannotReadFiles(e.toString()))));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFileActions(FileSystemEntity file) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: Text(AppLocalizations.of(context)!.viewFile),
              onTap: () {
                Navigator.pop(context);
                OpenFile.open(file.path);
              },
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(AppLocalizations.of(context)!.goToFolder),
                onTap: () async {
                  Navigator.pop(context);
                  if (_saigonEdtechDir != null &&
                      await _saigonEdtechDir!.exists()) {
                    try {
                      final AndroidIntent intent = AndroidIntent(
                        action: 'android.intent.action.VIEW',
                        data: Uri.decodeFull(
                            Uri.file(_saigonEdtechDir!.path).toString()),
                      );
                      await intent.launch();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              AppLocalizations.of(context)!.folderOpenError)));
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(AppLocalizations.of(context)!.share),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(file.path)]);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text(AppLocalizations.of(context)!.delete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(file);
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(FileSystemEntity file) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              Text(AppLocalizations.of(context)!.deleteFileConfirmationTitle),
          content:
              Text(AppLocalizations.of(context)!.deleteFileConfirmationContent),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.no),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppLocalizations.of(context)!.yes,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await file.delete();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${p.basename(file.path)} đã được xóa.')));
        _loadDownloadedFiles(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không thể xóa file: $e')));
      }
    }
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) +
        ' ' +
        suffixes[i];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.downloadedFiles),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloadedFiles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Text(
                  AppLocalizations.of(context)!.noFilesDownloaded,
                  style: const TextStyle(fontSize: 16),
                ))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final stat = file.statSync();
                    final lastModified =
                        DateFormat.yMd().add_jm().format(stat.modified);
                    final fileSize = _formatBytes(stat.size, 2);

                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(p.basename(file.path)),
                      subtitle: Text('$fileSize - $lastModified'),
                      onTap: () => _showFileActions(file),
                    );
                  },
                ),
    );
  }
}
