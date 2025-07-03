import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

import 'settings_provider.dart';
import 'app_drawer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'SAIGON EDTECH',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      themeMode: provider.themeMode,
      locale: provider.locale,
      supportedLocales: L10n.all,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  late PullToRefreshController _pullToRefreshController;

  final String _url = 'https://b3d5-1-54-226-63.ngrok-free.app';

  bool _isError = false;
  double _progress = 0;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadingFilename = '';
  CancelToken _cancelToken = CancelToken();

  @override
  void initState() {
    super.initState();

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.blue,
      ),
      onRefresh: () async {
        _webViewController?.reload();
      },
    );
  }

  Future<void> _startDownload(String url, String? suggestedFilename) async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(AppLocalizations.of(context)!.storagePermissionNeeded)));
      }
      return;
    }

    // STABLE STORAGE LOGIC
    Directory? targetDir;
    if (Platform.isAndroid) {
      targetDir = await getExternalStorageDirectory();
    } else {
      // iOS and other platforms
      targetDir = await getApplicationDocumentsDirectory();
    }

    if (targetDir == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.cannotFindDownloads)));
      }
      return;
    }

    final saigonEdtechDir = Directory('${targetDir.path}/SAIGON_EDTECH');
    if (!await saigonEdtechDir.exists()) {
      await saigonEdtechDir.create(recursive: true);
    }

    // Use this directory for saving
    final Directory finalDir = saigonEdtechDir;

    // Handle file name conflicts
    final baseName =
        p.basenameWithoutExtension(suggestedFilename ?? 'downloaded_file');
    final extension = p.extension(suggestedFilename ?? '');
    String filename = p.basename(suggestedFilename ?? 'downloaded_file');
    String savePath = p.join(finalDir.path, filename);
    int counter = 1;

    while (await File(savePath).exists()) {
      filename = '$baseName($counter)$extension';
      savePath = p.join(finalDir.path, filename);
      counter++;
    }

    // ... (rest of the download logic is the same)
    _cancelToken = CancelToken();

    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(url: WebUri(url));
    final cookieString =
        cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadingFilename = filename;
    });

    try {
      await Dio().download(
        url,
        savePath,
        cancelToken: _cancelToken,
        options: Options(
          headers: {
            HttpHeaders.cookieHeader: cookieString,
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                AppLocalizations.of(context)!.downloadSucceeded(filename))));
      }
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.downloadFailed),
        ));
      }
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _cancelDownload() {
    _cancelToken.cancel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.downloadCancelled),
      ));
    }
  }

  Future<void> _retry() async {
    setState(() {
      _isError = false;
    });
    if (_webViewController != null) {
      await _webViewController!
          .loadUrl(urlRequest: URLRequest(url: WebUri(_url)));
    }
  }

  Future<void> _goToHome() async {
    setState(() {
      _isError = false;
    });
    if (_webViewController != null) {
      await _webViewController!
          .loadUrl(urlRequest: URLRequest(url: WebUri(_url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_webViewController != null &&
            await _webViewController!.canGoBack()) {
          _webViewController!.goBack();
          return false;
        } else {
          final bool? shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(AppLocalizations.of(context)!.exitApp),
                content: Text(AppLocalizations.of(context)!.exitConfirmation),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(AppLocalizations.of(context)!.no),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(AppLocalizations.of(context)!.yes),
                  ),
                ],
              );
            },
          );
          return shouldPop ?? false;
        }
      },
      child: Scaffold(
        drawer: AppDrawer(
          onGoHome: _goToHome,
          onReload: () => _webViewController?.reload(),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_url)),
                pullToRefreshController: _pullToRefreshController,
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isError = false;
                    _progress = 0;
                  });
                },
                onLoadStop: (controller, url) {
                  _pullToRefreshController.endRefreshing();
                  setState(() {
                    _progress = 1.0;
                  });
                },
                onProgressChanged: (controller, progress) {
                  _pullToRefreshController.isRefreshing().then((isRefreshing) {
                    if (!isRefreshing) {
                      setState(() {
                        _progress = progress / 100;
                      });
                    }
                  });
                },
                onReceivedError: (controller, request, error) {
                  _pullToRefreshController.endRefreshing();
                  if (request.isForMainFrame ?? false) {
                    setState(() {
                      _isError = true;
                    });
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  _pullToRefreshController.endRefreshing();
                  if (request.isForMainFrame ?? false) {
                    setState(() {
                      _isError = true;
                    });
                  }
                },
                onDownloadStartRequest:
                    (controller, downloadStartRequest) async {
                  _startDownload(downloadStartRequest.url.toString(),
                      downloadStartRequest.suggestedFilename);
                },
                onPrintRequest: (controller, url, printJobController) async {
                  final screenshot = await _webViewController?.takeScreenshot(
                      screenshotConfiguration: ScreenshotConfiguration(
                          compressFormat: CompressFormat.PNG, quality: 100));

                  if (screenshot != null) {
                    await Printing.layoutPdf(
                        onLayout: (PdfPageFormat format) async {
                      final doc = pw.Document();
                      final image = pw.MemoryImage(screenshot);

                      doc.addPage(pw.Page(
                          pageFormat: format,
                          build: (pw.Context context) {
                            return pw.Center(
                              child: pw.Image(image),
                            );
                          }));

                      return doc.save();
                    });
                  }

                  return true;
                },
              ),
              if (_progress < 1.0 && !_isDownloading)
                LinearProgressIndicator(value: _progress),
              if (_isError)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.signal_wifi_off_rounded,
                            color: Colors.grey,
                            size: 80,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            AppLocalizations.of(context)!.cannotLoadPage,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.checkConnection,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: Text(AppLocalizations.of(context)!.retry),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _goToHome,
                            child: Text(AppLocalizations.of(context)!.home),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_isDownloading)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.75,
                    child: Card(
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _downloadingFilename,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: _downloadProgress,
                                    minHeight: 6,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _cancelDownload,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
