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
import 'package:flutter/scheduler.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import 'settings_provider.dart';
import 'app_drawer.dart';
import 'config.dart';
import 'settings.dart';

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

  final String _url = baseUrl;

  bool _isError = false;
  double _progress = 0;
  bool _canGoBack = false;
  bool _isAccessDenied = false;
  bool _onLoginPage = false;
  bool _isLoggingOut = false;

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

  Future<void> _goBack() async {
    // Hide overlay screens
    setState(() {
      _isError = false;
      _isAccessDenied = false;
    });

    if (_webViewController != null && await _webViewController!.canGoBack()) {
      _webViewController!.goBack();
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
      _isAccessDenied = false;
    });
    if (_webViewController != null) {
      await _webViewController!
          .loadUrl(urlRequest: URLRequest(url: WebUri(_url)));
    }
  }

  Future<void> _syncThemeWithWebView() async {
    if (_webViewController == null) return;

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final themeMode = settingsProvider.themeMode;

    final isDarkMode = themeMode == ThemeMode.dark;

    final script = '''
      try {
        let currentSettings = JSON.parse(localStorage.getItem('themeSettings')) || {};
        let newSettings = {
            ...currentSettings,
            isDarkMode: $isDarkMode,
            isAutoMode: false,
            manualOverride: true
        };
        localStorage.setItem('themeSettings', JSON.stringify(newSettings));
      } catch (e) {
        console.error('Failed to sync theme settings:', e);
      }
    ''';

    await _webViewController!.evaluateJavascript(source: script);
  }

  Future<void> _syncThemeFromWebView() async {
    if (_webViewController == null) return;

    try {
      final result = await _webViewController!
          .evaluateJavascript(source: "localStorage.getItem('themeSettings');");

      if (result != null && result is String && result.isNotEmpty) {
        final settingsJson = json.decode(result);

        final isDarkMode = settingsJson['isDarkMode'] as bool? ?? false;

        final newThemeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;

        final settingsProvider =
            Provider.of<SettingsProvider>(context, listen: false);
        if (newThemeMode != settingsProvider.themeMode) {
          settingsProvider.setThemeMode(newThemeMode);
        }
      }
    } catch (e) {
      debugPrint('Failed to sync theme from webview: $e');
    }
  }

  Future<void> _applyThemeToWebView() async {
    if (_webViewController == null) return;

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isDarkMode = settingsProvider.themeMode == ThemeMode.dark;

    // Call the specific function on the website to apply the theme.
    final script = '''
      if (typeof window.enableDarkMode === 'function') {
        window.enableDarkMode($isDarkMode);
      }
    ''';
    await _webViewController!.evaluateJavascript(source: script);
  }

  Future<void> _syncLangFromWebView() async {
    if (_webViewController == null) return;

    try {
      // evaluateJavascript can return a JSON-encoded string on Android ('"vi"')
      // and a raw string on iOS ('vi'). We need to handle both.
      final result = await _webViewController!
          .evaluateJavascript(source: "localStorage.getItem('portal_locale');");

      if (result != null && result is String && result.isNotEmpty) {
        String portalLocale = result;
        if (Platform.isAndroid &&
            portalLocale.startsWith('"') &&
            portalLocale.endsWith('"')) {
          portalLocale = portalLocale.substring(1, portalLocale.length - 1);
        }

        final settingsProvider =
            Provider.of<SettingsProvider>(context, listen: false);
        final currentAppLocaleCode = settingsProvider.locale.languageCode;

        if (portalLocale != currentAppLocaleCode) {
          final newLocale = Locale(portalLocale);
          if (L10n.all.contains(newLocale)) {
            settingsProvider.setLocale(newLocale, syncToWebView: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to sync language from webview: $e');
    }
  }

  Future<void> _navigateToSettings() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    settingsProvider.clearChangeFlags();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );

    if (mounted) {
      if (settingsProvider.themeChanged) {
        await _applyThemeToWebView();
      }
      if (settingsProvider.languageChanged) {
        _showRefreshToast();
      }
    }
  }

  void _showRefreshToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.applySettingsPrompt),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.refresh.toUpperCase(),
          onPressed: () {
            _webViewController?.reload();
          },
        ),
      ),
    );
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
          onNavigateToSettings: _navigateToSettings,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_url)),
                pullToRefreshController: _pullToRefreshController,
                onWebViewCreated: (controller) {
                  _webViewController = controller;

                  controller.addJavaScriptHandler(
                      handlerName: 'themeChanged',
                      callback: (args) {
                        _syncThemeFromWebView();
                      });
                },
                onLoadStart: (controller, url) {
                  // When a logout is in progress and we are being redirected to the login page,
                  // clear history at the earliest possible moment to prevent user from going back.
                  if (_isLoggingOut &&
                      url != null &&
                      url.path.endsWith('/login')) {
                    controller.clearHistory();
                    setState(() {
                      _isLoggingOut = false; // Reset the flag
                    });
                  }

                  setState(() {
                    _isError = false;
                    _isAccessDenied = false;
                    _progress = 0;
                  });
                },
                onLoadStop: (controller, url) async {
                  _pullToRefreshController.endRefreshing();

                  if (url != null) {
                    // If we just navigated away from the login page (successful login), clear the history.
                    if (_onLoginPage && !url.path.endsWith('/login')) {
                      await _webViewController?.clearHistory();
                    }
                    // Update the flag for the next navigation event.
                    _onLoginPage = url.path.endsWith('/login');
                  }

                  // Sync FROM webview first, as it's the source of truth on page load.
                  await _syncThemeFromWebView();
                  await _syncLangFromWebView();

                  final canGoBack =
                      await _webViewController?.canGoBack() ?? false;
                  setState(() {
                    _progress = 1.0;
                    _canGoBack = canGoBack;
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
                    // Load a blank page to hide the default error page and the URL.
                    controller.loadData(data: '<html><body></body></html>');
                    setState(() {
                      _isError = true;
                    });
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  _pullToRefreshController.endRefreshing();
                  if (request.isForMainFrame ?? false) {
                    // Load a blank page to hide the default error page and the URL.
                    controller.loadData(data: '<html><body></body></html>');
                    setState(() {
                      _isError = true;
                    });
                  }
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final request = navigationAction.request;
                  final requestedUri = request.url;

                  if (requestedUri != null && requestedUri.scheme == 'tel') {
                    if (await canLaunchUrl(requestedUri)) {
                      await launchUrl(requestedUri);
                    }
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (request.method == "POST" &&
                      requestedUri != null &&
                      requestedUri.path.endsWith('/logout')) {
                    setState(() {
                      _isLoggingOut = true;
                    });
                  }

                  final allowedHost = Uri.parse(baseUrl).host;

                  if (requestedUri != null &&
                      requestedUri.host != allowedHost) {
                    setState(() {
                      _isAccessDenied = true;
                    });
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
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
                          if (_canGoBack)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: ElevatedButton.icon(
                                onPressed: _goBack,
                                icon: const Icon(Icons.arrow_back),
                                label: Text(AppLocalizations.of(context)!.back),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 12),
                                ),
                              ),
                            ),
                          TextButton(
                            onPressed: _goToHome,
                            child: Text(AppLocalizations.of(context)!.home),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_isAccessDenied)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.block_flipped,
                            color: Colors.red,
                            size: 80,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            AppLocalizations.of(context)!.accessDeniedTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.accessDeniedContent,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _goBack,
                            icon: const Icon(Icons.arrow_back),
                            label: Text(AppLocalizations.of(context)!.back),
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
