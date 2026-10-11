import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/offline_controller.dart';
import '../widgets/home_widgets.dart';
import '../widgets/offline_widgets.dart';
import '../widgets/settings_widgets.dart' show SubScreenHeader;

/// Opened from the Profile screen. Lets the user download subjects for
/// offline use, shows what is available offline and when it was last
/// downloaded, and lets them remove downloads.
class OfflineContentScreen extends StatefulWidget {
  const OfflineContentScreen({super.key});

  @override
  State<OfflineContentScreen> createState() => _OfflineContentScreenState();
}

class _OfflineContentScreenState extends State<OfflineContentScreen> {
  late final OfflineController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OfflineController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmRemoveAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Remove all downloads?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: primaryTextColor(context),
          ),
        ),
        content: Text(
          'Downloaded PDFs are deleted from this device. Lesson text and '
          'quiz questions you have already opened stay cached. You can '
          'download everything again any time.',
          style: TextStyle(color: primaryTextColor(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: secondaryTextColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: kMaroon, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.removeAll();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: kMaroon,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              children: [
                Container(
                  color: kMaroon,
                  height: MediaQuery.of(context).padding.top,
                ),
                const SubScreenHeader(
                  title: 'Offline Content',
                  icon: Icons.cloud_download_rounded,
                ),
                Expanded(
                  child: _controller.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: kMaroon))
                      : RefreshIndicator(
                          color: kMaroon,
                          onRefresh: _controller.refresh,
                          child: _buildBody(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    final c = _controller;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfflineStatusCard(
            isOnline: c.isOnline,
            percent: c.availablePercent,
            completeSubjects: c.completeSubjects,
            totalSubjects: c.totalSubjects,
            pdfBytes: c.totalPdfBytes,
            lastDownloadedAt: c.lastDownloadedAt,
          ),
          const SizedBox(height: 14),
          Text(
            'Download subjects to study without a connection. Lessons, '
            'quizzes and PDFs are saved on this device. Your progress '
            'syncs automatically when you are back online.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: secondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: c.isDownloading ? null : c.downloadAll,
                    icon: Icon(c.allComplete
                        ? Icons.refresh_rounded
                        : Icons.download_rounded),
                    label: Text(
                      c.allComplete ? 'Update All' : 'Download All',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMaroon,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
              if (c.downloadedSubjects > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: c.isDownloading ? null : _confirmRemoveAll,
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: kMaroon),
                      label: const Text(
                        'Remove All',
                        style: TextStyle(
                            color: kMaroon, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kMaroon),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (c.downloadedSubjects > 0 && !c.allComplete) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: c.isDownloading ? null : c.updateDownloaded,
                child: const Text(
                  'Update downloaded subjects',
                  style: TextStyle(
                      color: kMaroon,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ),
          ],
          if (c.isDownloading) ...[
            const SizedBox(height: 12),
            DownloadProgressCard(
              label: c.progressLabel,
              progress: c.progress,
              onCancel: c.cancelDownload,
            ),
          ],
          if (c.message != null && !c.isDownloading) ...[
            const SizedBox(height: 12),
            Text(
              c.message!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor(context),
              ),
            ),
          ],
          const SizedBox(height: 24),
          for (final group in c.groups) ...[
            _buildGroup(group),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildGroup(OfflineCategoryGroup group) {
    final c = _controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor(context),
                  fontFamily: 'Georgia',
                ),
              ),
            ),
            TextButton(
              onPressed:
                  c.isDownloading ? null : () => c.downloadCategory(group.code),
              child: Text(
                group.allComplete ? 'Update' : 'Download',
                style: const TextStyle(
                    color: kMaroon, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < group.subjects.length; i++) ...[
                OfflineSubjectTile(
                  status: group.subjects[i],
                  busy: c.isDownloading,
                  onDownload: () => c.downloadSubject(group.subjects[i].subjectId),
                  onRemove: () => c.removeSubject(group.subjects[i].subjectId),
                ),
                if (i != group.subjects.length - 1)
                  Divider(height: 1, color: Theme.of(context).dividerColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
