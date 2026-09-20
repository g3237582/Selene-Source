import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import '../services/version_service.dart';
import '../update/apk_installer.dart';
import '../utils/font_utils.dart';
import 'update_dialog_views.dart';

class UpdateDialog extends StatefulWidget {
  final VersionInfo versionInfo;

  const UpdateDialog({
    super.key,
    required this.versionInfo,
  });

  /// 显示更新对话框
  static Future<void> show(
      BuildContext context, VersionInfo versionInfo) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(versionInfo: versionInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _needsPermission = false;
  double? _progress;
  String _statusText = '';
  File? _downloadedFile;
  CancelToken? _cancelToken;

  VersionInfo get versionInfo => widget.versionInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelToken?.cancel('dismissed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _needsPermission &&
        _downloadedFile != null &&
        !_busy) {
      _installExisting();
    }
  }

  Future<void> _openReleasePage() async {
    final uri = Uri.parse(versionInfo.releasePageUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _statusText = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: FontUtils.poppins(color: Colors.white)),
        backgroundColor: const Color(0xFFef4444),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (!ApkInstaller.supportsInAppInstall) {
      await _openReleasePage();
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (_needsPermission && _downloadedFile != null) {
      await _installExisting();
      return;
    }

    setState(() {
      _busy = true;
      _progress = 0;
      _statusText = '正在下载更新…';
      _needsPermission = false;
    });
    _cancelToken = CancelToken();

    try {
      final result = await VersionService.downloadAndInstall(
        versionInfo,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            if (total > 0) {
              _progress = received / total;
              _statusText = '正在下载更新… ${(_progress! * 100).floor()}%';
            } else {
              _progress = null;
              _statusText = '正在下载更新…';
            }
          });
        },
      );
      if (!mounted) {
        return;
      }
      switch (result.status) {
        case UpdateInstallStatus.launched:
          setState(() {
            _statusText = '正在打开安装程序…';
          });
          Navigator.of(context).pop();
          break;
        case UpdateInstallStatus.needsPermission:
          setState(() {
            _busy = false;
            _needsPermission = true;
            _downloadedFile = result.file;
            _statusText = '请允许安装未知应用后继续';
          });
          break;
        case UpdateInstallStatus.noAsset:
        case UpdateInstallStatus.unsupported:
          await _openReleasePage();
          if (mounted) {
            Navigator.of(context).pop();
          }
          break;
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        if (mounted) {
          setState(() {
            _busy = false;
            _statusText = '';
          });
        }
        return;
      }
      _showError('下载失败，请稍后重试');
    } catch (_) {
      _showError('安装失败，请稍后重试');
    }
  }

  Future<void> _installExisting() async {
    final file = _downloadedFile;
    if (file == null) {
      return;
    }
    setState(() {
      _busy = true;
      _statusText = '正在打开安装程序…';
    });
    try {
      final status = await VersionService.installExisting(file);
      if (!mounted) {
        return;
      }
      if (status == UpdateInstallStatus.launched) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _busy = false;
        _needsPermission = status == UpdateInstallStatus.needsPermission;
        _statusText = _needsPermission ? '请允许安装未知应用后继续' : '';
      });
    } catch (_) {
      _showError('安装失败，请稍后重试');
    }
  }

  Future<void> _handleLater() async {
    _cancelToken?.cancel('later');
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleDismiss() async {
    if (_busy) {
      return;
    }
    await VersionService.dismissVersion(versionInfo.latestVersion);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final androidInstall = ApkInstaller.supportsInAppInstall;
        final primaryLabel = _needsPermission ? '继续安装' : '立即更新';
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: themeService.isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UpdateDialogHeader(themeService: themeService),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UpdateVersionCards(
                        themeService: themeService,
                        currentVersion: versionInfo.currentVersion,
                        latestVersion: versionInfo.latestVersion,
                      ),
                      if (versionInfo.releaseNotes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        UpdateReleaseNotes(
                          themeService: themeService,
                          notes: versionInfo.releaseNotes,
                        ),
                      ],
                      if (_statusText.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        UpdateDownloadStatus(
                          themeService: themeService,
                          statusText: _statusText,
                          busy: _busy,
                          progress: _progress,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _handleUpdate,
                          icon: Icon(
                            androidInstall
                                ? Icons.system_update_alt_rounded
                                : Icons.open_in_new_rounded,
                            size: 18,
                          ),
                          label: Text(
                            primaryLabel,
                            style: FontUtils.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27AE60),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFF27AE60).withOpacity(0.5),
                            disabledForegroundColor: Colors.white70,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        androidInstall
                            ? '本包为 CI 调试签名，若与已装版本签名不同，需先卸载再装。'
                            : '自动下载安装仅支持 Android 构建，将打开 GitHub 发布页。',
                        style: FontUtils.poppins(
                          fontSize: 11,
                          height: 1.4,
                          color: themeService.isDarkMode
                              ? const Color(0xFF999999)
                              : const Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _busy ? null : _handleDismiss,
                              style: TextButton.styleFrom(
                                foregroundColor: themeService.isDarkMode
                                    ? const Color(0xFF999999)
                                    : const Color(0xFF666666),
                              ),
                              child: Text(
                                '忽略',
                                style: FontUtils.poppins(fontSize: 14),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: _handleLater,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF27AE60),
                              ),
                              child: Text(
                                '稍后',
                                style: FontUtils.poppins(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
