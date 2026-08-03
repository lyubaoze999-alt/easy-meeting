import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_services/providers.dart';
import '../../domain/models/meeting_note.dart';
import 'note_exporter.dart';

class NotesLibraryScreen extends ConsumerStatefulWidget {
  const NotesLibraryScreen({super.key});

  @override
  ConsumerState<NotesLibraryScreen> createState() => _NotesLibraryScreenState();
}

class _NotesLibraryScreenState extends ConsumerState<NotesLibraryScreen> {
  MeetingNote? selected;
  bool imageMode = false;

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('纪要库')),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('无法读取纪要：$error')),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('还没有纪要'));
          selected ??= items.first;
          final wide = MediaQuery.sizeOf(context).width >= 820;
          final list = _NotesList(
            notes: items,
            selected: selected,
            onSelected: (note) {
              if (wide) {
                setState(() => selected = note);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(note.title)),
                      body: _NoteDetail(note: note),
                    ),
                  ),
                );
              }
            },
            onSearch: (query) =>
                ref.read(notesProvider.notifier).load(query: query),
          );
          if (!wide) return list;
          return Row(
            children: [
              SizedBox(width: 340, child: list),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const Center(child: Text('选择一条纪要'))
                    : _NoteDetail(
                        note: selected!,
                        imageMode: imageMode,
                        onImageModeChanged: (value) =>
                            setState(() => imageMode = value),
                        onDelete: () async {
                          await ref
                              .read(notesProvider.notifier)
                              .moveToTrash(selected!.id);
                          setState(() => selected = null);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.notes,
    required this.selected,
    required this.onSelected,
    required this.onSearch,
  });
  final List<MeetingNote> notes;
  final MeetingNote? selected;
  final ValueChanged<MeetingNote> onSelected;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: SearchBar(
          hintText: '搜索标题或正文',
          leading: const Icon(Icons.search),
          onChanged: onSearch,
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return ListTile(
              selected: selected?.id == note.id,
              leading: const Icon(Icons.description_outlined),
              title: Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${note.startedAt.toLocal()} · ${note.duration.inMinutes} 分钟',
              ),
              onTap: () => onSelected(note),
            );
          },
        ),
      ),
    ],
  );
}

class _NoteDetail extends StatelessWidget {
  const _NoteDetail({
    required this.note,
    this.imageMode = false,
    this.onImageModeChanged,
    this.onDelete,
  });
  final MeetingNote note;
  final bool imageMode;
  final ValueChanged<bool>? onImageModeChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                note.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('纯文本')),
                ButtonSegment(value: true, label: Text('图文')),
              ],
              selected: {imageMode},
              onSelectionChanged: onImageModeChanged == null
                  ? null
                  : (value) => onImageModeChanged!(value.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('${note.startedAt.toLocal()} · ${note.duration.inMinutes} 分钟'),
        const SizedBox(height: 24),
        if (imageMode) _Visuals(note: note),
        ...note.sections.map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (section.isHighlighted)
                          const Icon(Icons.bookmark, size: 18),
                        if (section.isHighlighted) const SizedBox(width: 6),
                        Text(
                          section.heading,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(section.content),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (note.todos.isNotEmpty) ...[
          Text('待办事项', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...note.todos.map(
            (todo) => CheckboxListTile(
              value: todo.done,
              onChanged: null,
              title: Text(todo.text),
              subtitle: Text(
                [
                  if (todo.owner != null) '负责人：${todo.owner}',
                  if (todo.dueDate != null) '截止：${todo.dueDate}',
                ].join(' · '),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => Clipboard.setData(
                ClipboardData(text: NoteExporter.markdown(note)),
              ),
              icon: const Icon(Icons.copy),
              label: const Text('复制全文'),
            ),
            OutlinedButton.icon(
              onPressed: () => _export(context),
              icon: const Icon(Icons.download),
              label: const Text('导出 Markdown'),
            ),
            if (onDelete != null)
              TextButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('移到回收站'),
              ),
          ],
        ),
      ],
    ),
  );

  Future<void> _export(BuildContext context) async {
    final location = await getSaveLocation(
      suggestedName:
          '${note.title.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')}.md',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Markdown', extensions: ['md']),
      ],
    );
    if (location == null) return;
    await File(
      location.path,
    ).writeAsString(NoteExporter.markdown(note), flush: true);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已导出 Markdown')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移到回收站？'),
        content: const Text('纪要将在回收站保留 30 天，期间可以恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移到回收站'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete?.call();
  }
}

class _Visuals extends StatelessWidget {
  const _Visuals({required this.note});
  final MeetingNote note;

  @override
  Widget build(BuildContext context) {
    final visuals = note.visuals;
    if (visuals == null || visuals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('这条纪要没有生成可视化内容。'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('可视化概览', style: Theme.of(context).textTheme.titleLarge),
            if (visuals.keyNumbers != null)
              Wrap(
                spacing: 10,
                children: visuals.keyNumbers!
                    .map(
                      (item) =>
                          Chip(label: Text('${item.label}：${item.value}')),
                    )
                    .toList(),
              ),
            if (visuals.timeline != null)
              ...visuals.timeline!.map(
                (item) => ListTile(
                  leading: Text(item.time),
                  title: Text(item.title),
                  subtitle: item.detail == null ? null : Text(item.detail!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
