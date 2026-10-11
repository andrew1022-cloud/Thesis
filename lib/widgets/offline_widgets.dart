import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/offline_controller.dart';
import 'home_widgets.dart'
    show kMaroon, kGold, primaryTextColor, secondaryTextColor;

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Maroon summary card: connection state, % available offline, last
/// download time and storage used.
class OfflineStatusCard extends StatelessWidget {
  final bool isOnline;
  final int percent;
  final int completeSubjects;
  final int totalSubjects;
  final int pdfBytes;
  final DateTime? lastDownloadedAt;

  const OfflineStatusCard({
    super.key,
    required this.isOnline,
    required this.percent,
    required this.completeSubjects,
    required this.totalSubjects,
    required this.pdfBytes,
    required this.lastDownloadedAt,
  });

  @override
  Widget build(BuildContext context) {
    final lastLabel = lastDownloadedAt == null
        ? 'Never'
        : DateFormat('MMM d, h:mm a').format(lastDownloadedAt!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kMaroon,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 14,
                      color: isOnline ? const Color(0xFF7BE0A4) : kGold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  color: kGold,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'available offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(kGold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$completeSubjects of $totalSubjects subjects downloaded',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Last downloaded: $lastLabel  ·  PDFs: ${formatBytes(pdfBytes)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Progress card shown while a download is running.
class DownloadProgressCard extends StatelessWidget {
  final String label;
  final double progress;
  final VoidCallback onCancel;

  const DownloadProgressCard({
    super.key,
    required this.label,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: primaryTextColor(context),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: kGold.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(kMaroon),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onCancel,
              child: const Text(
                'Cancel',
                style: TextStyle(color: kMaroon, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One subject row: status icon, name, counts, and download / remove
/// buttons.
class OfflineSubjectTile extends StatelessWidget {
  final SubjectOfflineStatus status;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  const OfflineSubjectTile({
    super.key,
    required this.status,
    required this.busy,
    required this.onDownload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final s = status;

    final IconData icon;
    final Color iconColor;
    final String statusText;
    if (s.isComplete) {
      icon = Icons.check_circle_rounded;
      iconColor = Colors.green;
      statusText =
          'Available offline · ${DateFormat('MMM d').format(s.downloadedAt!)}';
    } else if (s.isPartial) {
      icon = Icons.error_outline_rounded;
      iconColor = const Color(0xFFB26A00);
      statusText = 'Incomplete — download again to finish';
    } else {
      icon = Icons.cloud_download_outlined;
      iconColor = secondaryTextColor(context);
      statusText = 'Not downloaded';
    }

    final details = <String>[
      '${s.lessonCount} lesson${s.lessonCount == 1 ? '' : 's'}',
      '${s.questionCount} question${s.questionCount == 1 ? '' : 's'}',
      if (s.pdfExpected > 0)
        '${s.pdfSaved}/${s.pdfExpected} PDF${s.pdfExpected == 1 ? '' : 's'}'
      else if (s.pdfSaved > 0)
        '${s.pdfSaved} PDF${s.pdfSaved == 1 ? '' : 's'}',
      if (s.pdfBytes > 0) formatBytes(s.pdfBytes),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor(context),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details.join(' · '),
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.isComplete ? 'Update' : 'Download',
            visualDensity: VisualDensity.compact,
            onPressed: busy ? null : onDownload,
            icon: Icon(
              s.isComplete ? Icons.refresh_rounded : Icons.download_rounded,
              color: busy ? Colors.grey : kMaroon,
            ),
          ),
          if (s.isDownloaded)
            IconButton(
              tooltip: 'Remove download',
              visualDensity: VisualDensity.compact,
              onPressed: busy ? null : onRemove,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: busy ? Colors.grey : kMaroon,
              ),
            ),
        ],
      ),
    );
  }
}
