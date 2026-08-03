import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_services/providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(trashProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('无法读取回收站：$error')),
        data: (notes) {
          if (notes.isEmpty) return const Center(child: Text('回收站为空'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final days = note.deletedAt == null
                  ? 30
                  : 30 - DateTime.now().difference(note.deletedAt!).inDays;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(note.title),
                  subtitle: Text('约 ${days.clamp(0, 30)} 天后自动清理'),
                  trailing: Wrap(
                    children: [
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(trashProvider.notifier)
                              .restore(note.id);
                          ref.invalidate(notesProvider);
                        },
                        child: const Text('恢复'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _confirmPermanentDelete(context, ref, note.id),
                        child: const Text('永久删除'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmPermanentDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除这条纪要？'),
        content: const Text('音频、转写和纪要正文都会被删除，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(trashProvider.notifier).permanentlyDelete(id);
    }
  }
}
