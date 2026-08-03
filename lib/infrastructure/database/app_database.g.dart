// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptPathMeta = const VerificationMeta(
    'transcriptPath',
  );
  @override
  late final GeneratedColumn<String> transcriptPath = GeneratedColumn<String>(
    'transcript_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyPathMeta = const VerificationMeta(
    'bodyPath',
  );
  @override
  late final GeneratedColumn<String> bodyPath = GeneratedColumn<String>(
    'body_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    startedAt,
    durationMs,
    templateId,
    audioPath,
    transcriptPath,
    bodyPath,
    searchText,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    } else if (isInserting) {
      context.missing(_audioPathMeta);
    }
    if (data.containsKey('transcript_path')) {
      context.handle(
        _transcriptPathMeta,
        transcriptPath.isAcceptableOrUnknown(
          data['transcript_path']!,
          _transcriptPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptPathMeta);
    }
    if (data.containsKey('body_path')) {
      context.handle(
        _bodyPathMeta,
        bodyPath.isAcceptableOrUnknown(data['body_path']!, _bodyPathMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyPathMeta);
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    } else if (isInserting) {
      context.missing(_searchTextMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      )!,
      transcriptPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_path'],
      )!,
      bodyPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_path'],
      )!,
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final String title;
  final DateTime startedAt;
  final int durationMs;
  final String templateId;
  final String audioPath;
  final String transcriptPath;
  final String bodyPath;
  final String searchText;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Note({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.durationMs,
    required this.templateId,
    required this.audioPath,
    required this.transcriptPath,
    required this.bodyPath,
    required this.searchText,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['template_id'] = Variable<String>(templateId);
    map['audio_path'] = Variable<String>(audioPath);
    map['transcript_path'] = Variable<String>(transcriptPath);
    map['body_path'] = Variable<String>(bodyPath);
    map['search_text'] = Variable<String>(searchText);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      title: Value(title),
      startedAt: Value(startedAt),
      durationMs: Value(durationMs),
      templateId: Value(templateId),
      audioPath: Value(audioPath),
      transcriptPath: Value(transcriptPath),
      bodyPath: Value(bodyPath),
      searchText: Value(searchText),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      templateId: serializer.fromJson<String>(json['templateId']),
      audioPath: serializer.fromJson<String>(json['audioPath']),
      transcriptPath: serializer.fromJson<String>(json['transcriptPath']),
      bodyPath: serializer.fromJson<String>(json['bodyPath']),
      searchText: serializer.fromJson<String>(json['searchText']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'templateId': serializer.toJson<String>(templateId),
      'audioPath': serializer.toJson<String>(audioPath),
      'transcriptPath': serializer.toJson<String>(transcriptPath),
      'bodyPath': serializer.toJson<String>(bodyPath),
      'searchText': serializer.toJson<String>(searchText),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Note copyWith({
    String? id,
    String? title,
    DateTime? startedAt,
    int? durationMs,
    String? templateId,
    String? audioPath,
    String? transcriptPath,
    String? bodyPath,
    String? searchText,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Note(
    id: id ?? this.id,
    title: title ?? this.title,
    startedAt: startedAt ?? this.startedAt,
    durationMs: durationMs ?? this.durationMs,
    templateId: templateId ?? this.templateId,
    audioPath: audioPath ?? this.audioPath,
    transcriptPath: transcriptPath ?? this.transcriptPath,
    bodyPath: bodyPath ?? this.bodyPath,
    searchText: searchText ?? this.searchText,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      transcriptPath: data.transcriptPath.present
          ? data.transcriptPath.value
          : this.transcriptPath,
      bodyPath: data.bodyPath.present ? data.bodyPath.value : this.bodyPath,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('templateId: $templateId, ')
          ..write('audioPath: $audioPath, ')
          ..write('transcriptPath: $transcriptPath, ')
          ..write('bodyPath: $bodyPath, ')
          ..write('searchText: $searchText, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    startedAt,
    durationMs,
    templateId,
    audioPath,
    transcriptPath,
    bodyPath,
    searchText,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.title == this.title &&
          other.startedAt == this.startedAt &&
          other.durationMs == this.durationMs &&
          other.templateId == this.templateId &&
          other.audioPath == this.audioPath &&
          other.transcriptPath == this.transcriptPath &&
          other.bodyPath == this.bodyPath &&
          other.searchText == this.searchText &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> startedAt;
  final Value<int> durationMs;
  final Value<String> templateId;
  final Value<String> audioPath;
  final Value<String> transcriptPath;
  final Value<String> bodyPath;
  final Value<String> searchText;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.templateId = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.transcriptPath = const Value.absent(),
    this.bodyPath = const Value.absent(),
    this.searchText = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required String title,
    required DateTime startedAt,
    required int durationMs,
    required String templateId,
    required String audioPath,
    required String transcriptPath,
    required String bodyPath,
    required String searchText,
    this.deletedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       startedAt = Value(startedAt),
       durationMs = Value(durationMs),
       templateId = Value(templateId),
       audioPath = Value(audioPath),
       transcriptPath = Value(transcriptPath),
       bodyPath = Value(bodyPath),
       searchText = Value(searchText),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<DateTime>? startedAt,
    Expression<int>? durationMs,
    Expression<String>? templateId,
    Expression<String>? audioPath,
    Expression<String>? transcriptPath,
    Expression<String>? bodyPath,
    Expression<String>? searchText,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (startedAt != null) 'started_at': startedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (templateId != null) 'template_id': templateId,
      if (audioPath != null) 'audio_path': audioPath,
      if (transcriptPath != null) 'transcript_path': transcriptPath,
      if (bodyPath != null) 'body_path': bodyPath,
      if (searchText != null) 'search_text': searchText,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? startedAt,
    Value<int>? durationMs,
    Value<String>? templateId,
    Value<String>? audioPath,
    Value<String>? transcriptPath,
    Value<String>? bodyPath,
    Value<String>? searchText,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      durationMs: durationMs ?? this.durationMs,
      templateId: templateId ?? this.templateId,
      audioPath: audioPath ?? this.audioPath,
      transcriptPath: transcriptPath ?? this.transcriptPath,
      bodyPath: bodyPath ?? this.bodyPath,
      searchText: searchText ?? this.searchText,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (transcriptPath.present) {
      map['transcript_path'] = Variable<String>(transcriptPath.value);
    }
    if (bodyPath.present) {
      map['body_path'] = Variable<String>(bodyPath.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('templateId: $templateId, ')
          ..write('audioPath: $audioPath, ')
          ..write('transcriptPath: $transcriptPath, ')
          ..write('bodyPath: $bodyPath, ')
          ..write('searchText: $searchText, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProcessingJobsTable extends ProcessingJobs
    with TableInfo<$ProcessingJobsTable, ProcessingJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessingJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateJsonMeta = const VerificationMeta(
    'templateJson',
  );
  @override
  late final GeneratedColumn<String> templateJson = GeneratedColumn<String>(
    'template_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _highlightsJsonMeta = const VerificationMeta(
    'highlightsJson',
  );
  @override
  late final GeneratedColumn<String> highlightsJson = GeneratedColumn<String>(
    'highlights_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptPathMeta = const VerificationMeta(
    'transcriptPath',
  );
  @override
  late final GeneratedColumn<String> transcriptPath = GeneratedColumn<String>(
    'transcript_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSuccessfulStageMeta =
      const VerificationMeta('lastSuccessfulStage');
  @override
  late final GeneratedColumn<String> lastSuccessfulStage =
      GeneratedColumn<String>(
        'last_successful_stage',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureMessageMeta = const VerificationMeta(
    'failureMessage',
  );
  @override
  late final GeneratedColumn<String> failureMessage = GeneratedColumn<String>(
    'failure_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    audioPath,
    templateJson,
    startedAt,
    durationMs,
    highlightsJson,
    stage,
    transcriptPath,
    noteId,
    lastSuccessfulStage,
    failureCode,
    failureMessage,
    retryCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processing_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProcessingJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    } else if (isInserting) {
      context.missing(_audioPathMeta);
    }
    if (data.containsKey('template_json')) {
      context.handle(
        _templateJsonMeta,
        templateJson.isAcceptableOrUnknown(
          data['template_json']!,
          _templateJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_templateJsonMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('highlights_json')) {
      context.handle(
        _highlightsJsonMeta,
        highlightsJson.isAcceptableOrUnknown(
          data['highlights_json']!,
          _highlightsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_highlightsJsonMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('transcript_path')) {
      context.handle(
        _transcriptPathMeta,
        transcriptPath.isAcceptableOrUnknown(
          data['transcript_path']!,
          _transcriptPathMeta,
        ),
      );
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('last_successful_stage')) {
      context.handle(
        _lastSuccessfulStageMeta,
        lastSuccessfulStage.isAcceptableOrUnknown(
          data['last_successful_stage']!,
          _lastSuccessfulStageMeta,
        ),
      );
    }
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    if (data.containsKey('failure_message')) {
      context.handle(
        _failureMessageMeta,
        failureMessage.isAcceptableOrUnknown(
          data['failure_message']!,
          _failureMessageMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProcessingJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessingJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      )!,
      templateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_json'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      highlightsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}highlights_json'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      transcriptPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_path'],
      ),
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      ),
      lastSuccessfulStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_successful_stage'],
      ),
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
      failureMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_message'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProcessingJobsTable createAlias(String alias) {
    return $ProcessingJobsTable(attachedDatabase, alias);
  }
}

class ProcessingJob extends DataClass implements Insertable<ProcessingJob> {
  final String id;
  final String audioPath;
  final String templateJson;
  final DateTime startedAt;
  final int durationMs;
  final String highlightsJson;
  final String stage;
  final String? transcriptPath;
  final String? noteId;
  final String? lastSuccessfulStage;
  final String? failureCode;
  final String? failureMessage;
  final int retryCount;
  final DateTime updatedAt;
  const ProcessingJob({
    required this.id,
    required this.audioPath,
    required this.templateJson,
    required this.startedAt,
    required this.durationMs,
    required this.highlightsJson,
    required this.stage,
    this.transcriptPath,
    this.noteId,
    this.lastSuccessfulStage,
    this.failureCode,
    this.failureMessage,
    required this.retryCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['audio_path'] = Variable<String>(audioPath);
    map['template_json'] = Variable<String>(templateJson);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['highlights_json'] = Variable<String>(highlightsJson);
    map['stage'] = Variable<String>(stage);
    if (!nullToAbsent || transcriptPath != null) {
      map['transcript_path'] = Variable<String>(transcriptPath);
    }
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<String>(noteId);
    }
    if (!nullToAbsent || lastSuccessfulStage != null) {
      map['last_successful_stage'] = Variable<String>(lastSuccessfulStage);
    }
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    if (!nullToAbsent || failureMessage != null) {
      map['failure_message'] = Variable<String>(failureMessage);
    }
    map['retry_count'] = Variable<int>(retryCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProcessingJobsCompanion toCompanion(bool nullToAbsent) {
    return ProcessingJobsCompanion(
      id: Value(id),
      audioPath: Value(audioPath),
      templateJson: Value(templateJson),
      startedAt: Value(startedAt),
      durationMs: Value(durationMs),
      highlightsJson: Value(highlightsJson),
      stage: Value(stage),
      transcriptPath: transcriptPath == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptPath),
      noteId: noteId == null && nullToAbsent
          ? const Value.absent()
          : Value(noteId),
      lastSuccessfulStage: lastSuccessfulStage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulStage),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
      failureMessage: failureMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(failureMessage),
      retryCount: Value(retryCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProcessingJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessingJob(
      id: serializer.fromJson<String>(json['id']),
      audioPath: serializer.fromJson<String>(json['audioPath']),
      templateJson: serializer.fromJson<String>(json['templateJson']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      highlightsJson: serializer.fromJson<String>(json['highlightsJson']),
      stage: serializer.fromJson<String>(json['stage']),
      transcriptPath: serializer.fromJson<String?>(json['transcriptPath']),
      noteId: serializer.fromJson<String?>(json['noteId']),
      lastSuccessfulStage: serializer.fromJson<String?>(
        json['lastSuccessfulStage'],
      ),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
      failureMessage: serializer.fromJson<String?>(json['failureMessage']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'audioPath': serializer.toJson<String>(audioPath),
      'templateJson': serializer.toJson<String>(templateJson),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'highlightsJson': serializer.toJson<String>(highlightsJson),
      'stage': serializer.toJson<String>(stage),
      'transcriptPath': serializer.toJson<String?>(transcriptPath),
      'noteId': serializer.toJson<String?>(noteId),
      'lastSuccessfulStage': serializer.toJson<String?>(lastSuccessfulStage),
      'failureCode': serializer.toJson<String?>(failureCode),
      'failureMessage': serializer.toJson<String?>(failureMessage),
      'retryCount': serializer.toJson<int>(retryCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProcessingJob copyWith({
    String? id,
    String? audioPath,
    String? templateJson,
    DateTime? startedAt,
    int? durationMs,
    String? highlightsJson,
    String? stage,
    Value<String?> transcriptPath = const Value.absent(),
    Value<String?> noteId = const Value.absent(),
    Value<String?> lastSuccessfulStage = const Value.absent(),
    Value<String?> failureCode = const Value.absent(),
    Value<String?> failureMessage = const Value.absent(),
    int? retryCount,
    DateTime? updatedAt,
  }) => ProcessingJob(
    id: id ?? this.id,
    audioPath: audioPath ?? this.audioPath,
    templateJson: templateJson ?? this.templateJson,
    startedAt: startedAt ?? this.startedAt,
    durationMs: durationMs ?? this.durationMs,
    highlightsJson: highlightsJson ?? this.highlightsJson,
    stage: stage ?? this.stage,
    transcriptPath: transcriptPath.present
        ? transcriptPath.value
        : this.transcriptPath,
    noteId: noteId.present ? noteId.value : this.noteId,
    lastSuccessfulStage: lastSuccessfulStage.present
        ? lastSuccessfulStage.value
        : this.lastSuccessfulStage,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
    failureMessage: failureMessage.present
        ? failureMessage.value
        : this.failureMessage,
    retryCount: retryCount ?? this.retryCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProcessingJob copyWithCompanion(ProcessingJobsCompanion data) {
    return ProcessingJob(
      id: data.id.present ? data.id.value : this.id,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      templateJson: data.templateJson.present
          ? data.templateJson.value
          : this.templateJson,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      highlightsJson: data.highlightsJson.present
          ? data.highlightsJson.value
          : this.highlightsJson,
      stage: data.stage.present ? data.stage.value : this.stage,
      transcriptPath: data.transcriptPath.present
          ? data.transcriptPath.value
          : this.transcriptPath,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      lastSuccessfulStage: data.lastSuccessfulStage.present
          ? data.lastSuccessfulStage.value
          : this.lastSuccessfulStage,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
      failureMessage: data.failureMessage.present
          ? data.failureMessage.value
          : this.failureMessage,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJob(')
          ..write('id: $id, ')
          ..write('audioPath: $audioPath, ')
          ..write('templateJson: $templateJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('highlightsJson: $highlightsJson, ')
          ..write('stage: $stage, ')
          ..write('transcriptPath: $transcriptPath, ')
          ..write('noteId: $noteId, ')
          ..write('lastSuccessfulStage: $lastSuccessfulStage, ')
          ..write('failureCode: $failureCode, ')
          ..write('failureMessage: $failureMessage, ')
          ..write('retryCount: $retryCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    audioPath,
    templateJson,
    startedAt,
    durationMs,
    highlightsJson,
    stage,
    transcriptPath,
    noteId,
    lastSuccessfulStage,
    failureCode,
    failureMessage,
    retryCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessingJob &&
          other.id == this.id &&
          other.audioPath == this.audioPath &&
          other.templateJson == this.templateJson &&
          other.startedAt == this.startedAt &&
          other.durationMs == this.durationMs &&
          other.highlightsJson == this.highlightsJson &&
          other.stage == this.stage &&
          other.transcriptPath == this.transcriptPath &&
          other.noteId == this.noteId &&
          other.lastSuccessfulStage == this.lastSuccessfulStage &&
          other.failureCode == this.failureCode &&
          other.failureMessage == this.failureMessage &&
          other.retryCount == this.retryCount &&
          other.updatedAt == this.updatedAt);
}

class ProcessingJobsCompanion extends UpdateCompanion<ProcessingJob> {
  final Value<String> id;
  final Value<String> audioPath;
  final Value<String> templateJson;
  final Value<DateTime> startedAt;
  final Value<int> durationMs;
  final Value<String> highlightsJson;
  final Value<String> stage;
  final Value<String?> transcriptPath;
  final Value<String?> noteId;
  final Value<String?> lastSuccessfulStage;
  final Value<String?> failureCode;
  final Value<String?> failureMessage;
  final Value<int> retryCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProcessingJobsCompanion({
    this.id = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.templateJson = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.highlightsJson = const Value.absent(),
    this.stage = const Value.absent(),
    this.transcriptPath = const Value.absent(),
    this.noteId = const Value.absent(),
    this.lastSuccessfulStage = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.failureMessage = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProcessingJobsCompanion.insert({
    required String id,
    required String audioPath,
    required String templateJson,
    required DateTime startedAt,
    required int durationMs,
    required String highlightsJson,
    required String stage,
    this.transcriptPath = const Value.absent(),
    this.noteId = const Value.absent(),
    this.lastSuccessfulStage = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.failureMessage = const Value.absent(),
    this.retryCount = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       audioPath = Value(audioPath),
       templateJson = Value(templateJson),
       startedAt = Value(startedAt),
       durationMs = Value(durationMs),
       highlightsJson = Value(highlightsJson),
       stage = Value(stage),
       updatedAt = Value(updatedAt);
  static Insertable<ProcessingJob> custom({
    Expression<String>? id,
    Expression<String>? audioPath,
    Expression<String>? templateJson,
    Expression<DateTime>? startedAt,
    Expression<int>? durationMs,
    Expression<String>? highlightsJson,
    Expression<String>? stage,
    Expression<String>? transcriptPath,
    Expression<String>? noteId,
    Expression<String>? lastSuccessfulStage,
    Expression<String>? failureCode,
    Expression<String>? failureMessage,
    Expression<int>? retryCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (audioPath != null) 'audio_path': audioPath,
      if (templateJson != null) 'template_json': templateJson,
      if (startedAt != null) 'started_at': startedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (highlightsJson != null) 'highlights_json': highlightsJson,
      if (stage != null) 'stage': stage,
      if (transcriptPath != null) 'transcript_path': transcriptPath,
      if (noteId != null) 'note_id': noteId,
      if (lastSuccessfulStage != null)
        'last_successful_stage': lastSuccessfulStage,
      if (failureCode != null) 'failure_code': failureCode,
      if (failureMessage != null) 'failure_message': failureMessage,
      if (retryCount != null) 'retry_count': retryCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProcessingJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? audioPath,
    Value<String>? templateJson,
    Value<DateTime>? startedAt,
    Value<int>? durationMs,
    Value<String>? highlightsJson,
    Value<String>? stage,
    Value<String?>? transcriptPath,
    Value<String?>? noteId,
    Value<String?>? lastSuccessfulStage,
    Value<String?>? failureCode,
    Value<String?>? failureMessage,
    Value<int>? retryCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProcessingJobsCompanion(
      id: id ?? this.id,
      audioPath: audioPath ?? this.audioPath,
      templateJson: templateJson ?? this.templateJson,
      startedAt: startedAt ?? this.startedAt,
      durationMs: durationMs ?? this.durationMs,
      highlightsJson: highlightsJson ?? this.highlightsJson,
      stage: stage ?? this.stage,
      transcriptPath: transcriptPath ?? this.transcriptPath,
      noteId: noteId ?? this.noteId,
      lastSuccessfulStage: lastSuccessfulStage ?? this.lastSuccessfulStage,
      failureCode: failureCode ?? this.failureCode,
      failureMessage: failureMessage ?? this.failureMessage,
      retryCount: retryCount ?? this.retryCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (templateJson.present) {
      map['template_json'] = Variable<String>(templateJson.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (highlightsJson.present) {
      map['highlights_json'] = Variable<String>(highlightsJson.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (transcriptPath.present) {
      map['transcript_path'] = Variable<String>(transcriptPath.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (lastSuccessfulStage.present) {
      map['last_successful_stage'] = Variable<String>(
        lastSuccessfulStage.value,
      );
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (failureMessage.present) {
      map['failure_message'] = Variable<String>(failureMessage.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJobsCompanion(')
          ..write('id: $id, ')
          ..write('audioPath: $audioPath, ')
          ..write('templateJson: $templateJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('highlightsJson: $highlightsJson, ')
          ..write('stage: $stage, ')
          ..write('transcriptPath: $transcriptPath, ')
          ..write('noteId: $noteId, ')
          ..write('lastSuccessfulStage: $lastSuccessfulStage, ')
          ..write('failureCode: $failureCode, ')
          ..write('failureMessage: $failureMessage, ')
          ..write('retryCount: $retryCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $ProcessingJobsTable processingJobs = $ProcessingJobsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [notes, processingJobs];
}

typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      required String title,
      required DateTime startedAt,
      required int durationMs,
      required String templateId,
      required String audioPath,
      required String transcriptPath,
      required String bodyPath,
      required String searchText,
      Value<DateTime?> deletedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<DateTime> startedAt,
      Value<int> durationMs,
      Value<String> templateId,
      Value<String> audioPath,
      Value<String> transcriptPath,
      Value<String> bodyPath,
      Value<String> searchText,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptPath => $composableBuilder(
    column: $table.transcriptPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyPath => $composableBuilder(
    column: $table.bodyPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptPath => $composableBuilder(
    column: $table.transcriptPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyPath => $composableBuilder(
    column: $table.bodyPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get transcriptPath => $composableBuilder(
    column: $table.transcriptPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyPath =>
      $composableBuilder(column: $table.bodyPath, builder: (column) => column);

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<String> audioPath = const Value.absent(),
                Value<String> transcriptPath = const Value.absent(),
                Value<String> bodyPath = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                title: title,
                startedAt: startedAt,
                durationMs: durationMs,
                templateId: templateId,
                audioPath: audioPath,
                transcriptPath: transcriptPath,
                bodyPath: bodyPath,
                searchText: searchText,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required DateTime startedAt,
                required int durationMs,
                required String templateId,
                required String audioPath,
                required String transcriptPath,
                required String bodyPath,
                required String searchText,
                Value<DateTime?> deletedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                title: title,
                startedAt: startedAt,
                durationMs: durationMs,
                templateId: templateId,
                audioPath: audioPath,
                transcriptPath: transcriptPath,
                bodyPath: bodyPath,
                searchText: searchText,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$ProcessingJobsTableCreateCompanionBuilder =
    ProcessingJobsCompanion Function({
      required String id,
      required String audioPath,
      required String templateJson,
      required DateTime startedAt,
      required int durationMs,
      required String highlightsJson,
      required String stage,
      Value<String?> transcriptPath,
      Value<String?> noteId,
      Value<String?> lastSuccessfulStage,
      Value<String?> failureCode,
      Value<String?> failureMessage,
      Value<int> retryCount,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProcessingJobsTableUpdateCompanionBuilder =
    ProcessingJobsCompanion Function({
      Value<String> id,
      Value<String> audioPath,
      Value<String> templateJson,
      Value<DateTime> startedAt,
      Value<int> durationMs,
      Value<String> highlightsJson,
      Value<String> stage,
      Value<String?> transcriptPath,
      Value<String?> noteId,
      Value<String?> lastSuccessfulStage,
      Value<String?> failureCode,
      Value<String?> failureMessage,
      Value<int> retryCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProcessingJobsTableFilterComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateJson => $composableBuilder(
    column: $table.templateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get highlightsJson => $composableBuilder(
    column: $table.highlightsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptPath => $composableBuilder(
    column: $table.transcriptPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSuccessfulStage => $composableBuilder(
    column: $table.lastSuccessfulStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureMessage => $composableBuilder(
    column: $table.failureMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProcessingJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateJson => $composableBuilder(
    column: $table.templateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get highlightsJson => $composableBuilder(
    column: $table.highlightsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptPath => $composableBuilder(
    column: $table.transcriptPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSuccessfulStage => $composableBuilder(
    column: $table.lastSuccessfulStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureMessage => $composableBuilder(
    column: $table.failureMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProcessingJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get templateJson => $composableBuilder(
    column: $table.templateJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get highlightsJson => $composableBuilder(
    column: $table.highlightsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get transcriptPath => $composableBuilder(
    column: $table.transcriptPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get lastSuccessfulStage => $composableBuilder(
    column: $table.lastSuccessfulStage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureMessage => $composableBuilder(
    column: $table.failureMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProcessingJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProcessingJobsTable,
          ProcessingJob,
          $$ProcessingJobsTableFilterComposer,
          $$ProcessingJobsTableOrderingComposer,
          $$ProcessingJobsTableAnnotationComposer,
          $$ProcessingJobsTableCreateCompanionBuilder,
          $$ProcessingJobsTableUpdateCompanionBuilder,
          (
            ProcessingJob,
            BaseReferences<_$AppDatabase, $ProcessingJobsTable, ProcessingJob>,
          ),
          ProcessingJob,
          PrefetchHooks Function()
        > {
  $$ProcessingJobsTableTableManager(
    _$AppDatabase db,
    $ProcessingJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProcessingJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProcessingJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProcessingJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> audioPath = const Value.absent(),
                Value<String> templateJson = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> highlightsJson = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<String?> transcriptPath = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<String?> lastSuccessfulStage = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<String?> failureMessage = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProcessingJobsCompanion(
                id: id,
                audioPath: audioPath,
                templateJson: templateJson,
                startedAt: startedAt,
                durationMs: durationMs,
                highlightsJson: highlightsJson,
                stage: stage,
                transcriptPath: transcriptPath,
                noteId: noteId,
                lastSuccessfulStage: lastSuccessfulStage,
                failureCode: failureCode,
                failureMessage: failureMessage,
                retryCount: retryCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String audioPath,
                required String templateJson,
                required DateTime startedAt,
                required int durationMs,
                required String highlightsJson,
                required String stage,
                Value<String?> transcriptPath = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<String?> lastSuccessfulStage = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<String?> failureMessage = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProcessingJobsCompanion.insert(
                id: id,
                audioPath: audioPath,
                templateJson: templateJson,
                startedAt: startedAt,
                durationMs: durationMs,
                highlightsJson: highlightsJson,
                stage: stage,
                transcriptPath: transcriptPath,
                noteId: noteId,
                lastSuccessfulStage: lastSuccessfulStage,
                failureCode: failureCode,
                failureMessage: failureMessage,
                retryCount: retryCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProcessingJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProcessingJobsTable,
      ProcessingJob,
      $$ProcessingJobsTableFilterComposer,
      $$ProcessingJobsTableOrderingComposer,
      $$ProcessingJobsTableAnnotationComposer,
      $$ProcessingJobsTableCreateCompanionBuilder,
      $$ProcessingJobsTableUpdateCompanionBuilder,
      (
        ProcessingJob,
        BaseReferences<_$AppDatabase, $ProcessingJobsTable, ProcessingJob>,
      ),
      ProcessingJob,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$ProcessingJobsTableTableManager get processingJobs =>
      $$ProcessingJobsTableTableManager(_db, _db.processingJobs);
}
