import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/rewards_controller.dart';
import '../data/level_data.dart';
import '../data/unlockable_data.dart';
import '../widgets/home_widgets.dart';
import '../widgets/level_widgets.dart';
import '../widgets/rewards_widgets.dart';
import '../widgets/settings_widgets.dart' show SubScreenHeader;

/// Shows the user's level, what each level unlocks, and lets them
/// equip any unlocked avatar frame / flair. Opened from the "Rewards"
/// button on the Profile screen.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late final RewardsController _controller;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = RewardsController(uid: uid);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTapItem(Unlockable item) async {
    final message = await _controller.equip(item);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
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
                  title: 'Rewards',
                  icon: Icons.card_giftcard_rounded,
                ),
                Expanded(
                  child: _controller.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: kMaroon))
                      : RefreshIndicator(
                          color: kMaroon,
                          onRefresh: _controller.load,
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

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: primaryTextColor(context),
            fontFamily: 'Georgia',
          ),
        ),
      );

  Widget _buildBody() {
    final level = _controller.level;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLevelCard(),
          const SizedBox(height: 24),
          _sectionTitle('Streak Freeze'),
          StreakFreezeCard(level: level.number),
          const SizedBox(height: 24),
          _sectionTitle('Avatar Frames'),
          _buildGrid(kFrames),
          const SizedBox(height: 24),
          _sectionTitle('Flair'),
          _buildGrid(kFlairs),
        ],
      ),
    );
  }

  Widget _buildLevelCard() {
    final level = _controller.level;
    final next = nextLevelAfter(level);
    final nextUnlocks =
        next == null ? <Unlockable>[] : unlocksAtLevel(next.number);

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
              Flexible(child: LevelBadge(level: level, onMaroon: true)),
              const Spacer(),
              Text(
                '${_controller.points} pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LevelProgressBar(points: _controller.points),
          if (next != null && nextUnlocks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Next unlock (Lv. ${next.number}): '
              '${nextUnlocks.map((u) => u.name).join(', ')}',
              style: const TextStyle(
                color: kGold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid(List<Unlockable> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final tileWidth = (constraints.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: UnlockableTile(
                  item: item,
                  unlocked: _controller.isUnlocked(item),
                  equipped: _controller.isEquipped(item),
                  onTap: () => _onTapItem(item),
                ),
              ),
          ],
        );
      },
    );
  }
}
