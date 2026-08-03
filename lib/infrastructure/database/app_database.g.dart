// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MeetingsTable extends Meetings with TableInfo<$MeetingsTable, Meeting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
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
    startedAt,
    endedAt,
    durationMs,
    templateJson,
    highlightsJson,
    status,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meetings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meeting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
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
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
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
  Meeting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meeting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      templateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_json'],
      )!,
      highlightsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}highlights_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
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
  $MeetingsTable createAlias(String alias) {
    return $MeetingsTable(attachedDatabase, alias);
  }
}

class Meeting extends DataClass implements Insertable<Meeting> {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationMs;
  final String templateJson;
  final String highlightsJson;
  final String status;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Meeting({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.durationMs,
    required this.templateJson,
    required this.highlightsJson,
    required this.status,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['template_json'] = Variable<String>(templateJson);
    map['highlights_json'] = Variable<String>(highlightsJson);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MeetingsCompanion toCompanion(bool nullToAbsent) {
    return MeetingsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      durationMs: Value(durationMs),
      templateJson: Value(templateJson),
      highlightsJson: Value(highlightsJson),
      status: Value(status),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Meeting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meeting(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      templateJson: serializer.fromJson<String>(json['templateJson']),
      highlightsJson: serializer.fromJson<String>(json['highlightsJson']),
      status: serializer.fromJson<String>(json['status']),
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
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'templateJson': serializer.toJson<String>(templateJson),
      'highlightsJson': serializer.toJson<String>(highlightsJson),
      'status': serializer.toJson<String>(status),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Meeting copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? durationMs,
    String? templateJson,
    String? highlightsJson,
    String? status,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Meeting(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    durationMs: durationMs ?? this.durationMs,
    templateJson: templateJson ?? this.templateJson,
    highlightsJson: highlightsJson ?? this.highlightsJson,
    status: status ?? this.status,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Meeting copyWithCompanion(MeetingsCompanion data) {
    return Meeting(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      templateJson: data.templateJson.present
          ? data.templateJson.value
          : this.templateJson,
      highlightsJson: data.highlightsJson.present
          ? data.highlightsJson.value
          : this.highlightsJson,
      status: data.status.present ? data.status.value : this.status,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meeting(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('templateJson: $templateJson, ')
          ..write('highlightsJson: $highlightsJson, ')
          ..write('status: $status, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    durationMs,
    templateJson,
    highlightsJson,
    status,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meeting &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationMs == this.durationMs &&
          other.templateJson == this.templateJson &&
          other.highlightsJson == this.highlightsJson &&
          other.status == this.status &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MeetingsCompanion extends UpdateCompanion<Meeting> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> durationMs;
  final Value<String> templateJson;
  final Value<String> highlightsJson;
  final Value<String> status;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MeetingsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.templateJson = const Value.absent(),
    this.highlightsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeetingsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required int durationMs,
    required String templateJson,
    required String highlightsJson,
    required String status,
    this.deletedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       durationMs = Value(durationMs),
       templateJson = Value(templateJson),
       highlightsJson = Value(highlightsJson),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Meeting> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationMs,
    Expression<String>? templateJson,
    Expression<String>? highlightsJson,
    Expression<String>? status,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (templateJson != null) 'template_json': templateJson,
      if (highlightsJson != null) 'highlights_json': highlightsJson,
      if (status != null) 'status': status,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeetingsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? durationMs,
    Value<String>? templateJson,
    Value<String>? highlightsJson,
    Value<String>? status,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MeetingsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMs: durationMs ?? this.durationMs,
      templateJson: templateJson ?? this.templateJson,
      highlightsJson: highlightsJson ?? this.highlightsJson,
      status: status ?? this.status,
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
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (templateJson.present) {
      map['template_json'] = Variable<String>(templateJson.value);
    }
    if (highlightsJson.present) {
      map['highlights_json'] = Variable<String>(highlightsJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
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
    return (StringBuffer('MeetingsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('templateJson: $templateJson, ')
          ..write('highlightsJson: $highlightsJson, ')
          ..write('status: $status, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptsTable extends Transcripts
    with TableInfo<$TranscriptsTable, Transcript> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerProtocolMeta = const VerificationMeta(
    'providerProtocol',
  );
  @override
  late final GeneratedColumn<String> providerProtocol = GeneratedColumn<String>(
    'provider_protocol',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coveredDurationMsMeta = const VerificationMeta(
    'coveredDurationMs',
  );
  @override
  late final GeneratedColumn<int> coveredDurationMs = GeneratedColumn<int>(
    'covered_duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyPathMeta = const VerificationMeta(
    'bodyPath',
  );
  @override
  late final GeneratedColumn<String> bodyPath = GeneratedColumn<String>(
    'body_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gapsJsonMeta = const VerificationMeta(
    'gapsJson',
  );
  @override
  late final GeneratedColumn<String> gapsJson = GeneratedColumn<String>(
    'gaps_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _frozenAtMeta = const VerificationMeta(
    'frozenAt',
  );
  @override
  late final GeneratedColumn<DateTime> frozenAt = GeneratedColumn<DateTime>(
    'frozen_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    meetingId,
    kind,
    status,
    providerProtocol,
    model,
    language,
    coveredDurationMs,
    bodyPath,
    revision,
    gapsJson,
    frozenAt,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcripts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transcript> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('provider_protocol')) {
      context.handle(
        _providerProtocolMeta,
        providerProtocol.isAcceptableOrUnknown(
          data['provider_protocol']!,
          _providerProtocolMeta,
        ),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('covered_duration_ms')) {
      context.handle(
        _coveredDurationMsMeta,
        coveredDurationMs.isAcceptableOrUnknown(
          data['covered_duration_ms']!,
          _coveredDurationMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_coveredDurationMsMeta);
    }
    if (data.containsKey('body_path')) {
      context.handle(
        _bodyPathMeta,
        bodyPath.isAcceptableOrUnknown(data['body_path']!, _bodyPathMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('gaps_json')) {
      context.handle(
        _gapsJsonMeta,
        gapsJson.isAcceptableOrUnknown(data['gaps_json']!, _gapsJsonMeta),
      );
    }
    if (data.containsKey('frozen_at')) {
      context.handle(
        _frozenAtMeta,
        frozenAt.isAcceptableOrUnknown(data['frozen_at']!, _frozenAtMeta),
      );
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {meetingId, kind, revision},
  ];
  @override
  Transcript map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transcript(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      providerProtocol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_protocol'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      coveredDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}covered_duration_ms'],
      )!,
      bodyPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_path'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      gapsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gaps_json'],
      )!,
      frozenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}frozen_at'],
      ),
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
  $TranscriptsTable createAlias(String alias) {
    return $TranscriptsTable(attachedDatabase, alias);
  }
}

class Transcript extends DataClass implements Insertable<Transcript> {
  final String id;
  final String meetingId;
  final String kind;
  final String status;
  final String? providerProtocol;
  final String? model;
  final String? language;
  final int coveredDurationMs;
  final String? bodyPath;
  final int revision;
  final String gapsJson;
  final DateTime? frozenAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Transcript({
    required this.id,
    required this.meetingId,
    required this.kind,
    required this.status,
    this.providerProtocol,
    this.model,
    this.language,
    required this.coveredDurationMs,
    this.bodyPath,
    required this.revision,
    required this.gapsJson,
    this.frozenAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || providerProtocol != null) {
      map['provider_protocol'] = Variable<String>(providerProtocol);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    map['covered_duration_ms'] = Variable<int>(coveredDurationMs);
    if (!nullToAbsent || bodyPath != null) {
      map['body_path'] = Variable<String>(bodyPath);
    }
    map['revision'] = Variable<int>(revision);
    map['gaps_json'] = Variable<String>(gapsJson);
    if (!nullToAbsent || frozenAt != null) {
      map['frozen_at'] = Variable<DateTime>(frozenAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TranscriptsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      kind: Value(kind),
      status: Value(status),
      providerProtocol: providerProtocol == null && nullToAbsent
          ? const Value.absent()
          : Value(providerProtocol),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      coveredDurationMs: Value(coveredDurationMs),
      bodyPath: bodyPath == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyPath),
      revision: Value(revision),
      gapsJson: Value(gapsJson),
      frozenAt: frozenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(frozenAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Transcript.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transcript(
      id: serializer.fromJson<String>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      providerProtocol: serializer.fromJson<String?>(json['providerProtocol']),
      model: serializer.fromJson<String?>(json['model']),
      language: serializer.fromJson<String?>(json['language']),
      coveredDurationMs: serializer.fromJson<int>(json['coveredDurationMs']),
      bodyPath: serializer.fromJson<String?>(json['bodyPath']),
      revision: serializer.fromJson<int>(json['revision']),
      gapsJson: serializer.fromJson<String>(json['gapsJson']),
      frozenAt: serializer.fromJson<DateTime?>(json['frozenAt']),
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
      'meetingId': serializer.toJson<String>(meetingId),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'providerProtocol': serializer.toJson<String?>(providerProtocol),
      'model': serializer.toJson<String?>(model),
      'language': serializer.toJson<String?>(language),
      'coveredDurationMs': serializer.toJson<int>(coveredDurationMs),
      'bodyPath': serializer.toJson<String?>(bodyPath),
      'revision': serializer.toJson<int>(revision),
      'gapsJson': serializer.toJson<String>(gapsJson),
      'frozenAt': serializer.toJson<DateTime?>(frozenAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Transcript copyWith({
    String? id,
    String? meetingId,
    String? kind,
    String? status,
    Value<String?> providerProtocol = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> language = const Value.absent(),
    int? coveredDurationMs,
    Value<String?> bodyPath = const Value.absent(),
    int? revision,
    String? gapsJson,
    Value<DateTime?> frozenAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Transcript(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    providerProtocol: providerProtocol.present
        ? providerProtocol.value
        : this.providerProtocol,
    model: model.present ? model.value : this.model,
    language: language.present ? language.value : this.language,
    coveredDurationMs: coveredDurationMs ?? this.coveredDurationMs,
    bodyPath: bodyPath.present ? bodyPath.value : this.bodyPath,
    revision: revision ?? this.revision,
    gapsJson: gapsJson ?? this.gapsJson,
    frozenAt: frozenAt.present ? frozenAt.value : this.frozenAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Transcript copyWithCompanion(TranscriptsCompanion data) {
    return Transcript(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      providerProtocol: data.providerProtocol.present
          ? data.providerProtocol.value
          : this.providerProtocol,
      model: data.model.present ? data.model.value : this.model,
      language: data.language.present ? data.language.value : this.language,
      coveredDurationMs: data.coveredDurationMs.present
          ? data.coveredDurationMs.value
          : this.coveredDurationMs,
      bodyPath: data.bodyPath.present ? data.bodyPath.value : this.bodyPath,
      revision: data.revision.present ? data.revision.value : this.revision,
      gapsJson: data.gapsJson.present ? data.gapsJson.value : this.gapsJson,
      frozenAt: data.frozenAt.present ? data.frozenAt.value : this.frozenAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transcript(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('providerProtocol: $providerProtocol, ')
          ..write('model: $model, ')
          ..write('language: $language, ')
          ..write('coveredDurationMs: $coveredDurationMs, ')
          ..write('bodyPath: $bodyPath, ')
          ..write('revision: $revision, ')
          ..write('gapsJson: $gapsJson, ')
          ..write('frozenAt: $frozenAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    kind,
    status,
    providerProtocol,
    model,
    language,
    coveredDurationMs,
    bodyPath,
    revision,
    gapsJson,
    frozenAt,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transcript &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.providerProtocol == this.providerProtocol &&
          other.model == this.model &&
          other.language == this.language &&
          other.coveredDurationMs == this.coveredDurationMs &&
          other.bodyPath == this.bodyPath &&
          other.revision == this.revision &&
          other.gapsJson == this.gapsJson &&
          other.frozenAt == this.frozenAt &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TranscriptsCompanion extends UpdateCompanion<Transcript> {
  final Value<String> id;
  final Value<String> meetingId;
  final Value<String> kind;
  final Value<String> status;
  final Value<String?> providerProtocol;
  final Value<String?> model;
  final Value<String?> language;
  final Value<int> coveredDurationMs;
  final Value<String?> bodyPath;
  final Value<int> revision;
  final Value<String> gapsJson;
  final Value<DateTime?> frozenAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TranscriptsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.providerProtocol = const Value.absent(),
    this.model = const Value.absent(),
    this.language = const Value.absent(),
    this.coveredDurationMs = const Value.absent(),
    this.bodyPath = const Value.absent(),
    this.revision = const Value.absent(),
    this.gapsJson = const Value.absent(),
    this.frozenAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptsCompanion.insert({
    required String id,
    required String meetingId,
    required String kind,
    required String status,
    this.providerProtocol = const Value.absent(),
    this.model = const Value.absent(),
    this.language = const Value.absent(),
    required int coveredDurationMs,
    this.bodyPath = const Value.absent(),
    required int revision,
    this.gapsJson = const Value.absent(),
    this.frozenAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       meetingId = Value(meetingId),
       kind = Value(kind),
       status = Value(status),
       coveredDurationMs = Value(coveredDurationMs),
       revision = Value(revision),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Transcript> custom({
    Expression<String>? id,
    Expression<String>? meetingId,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? providerProtocol,
    Expression<String>? model,
    Expression<String>? language,
    Expression<int>? coveredDurationMs,
    Expression<String>? bodyPath,
    Expression<int>? revision,
    Expression<String>? gapsJson,
    Expression<DateTime>? frozenAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (providerProtocol != null) 'provider_protocol': providerProtocol,
      if (model != null) 'model': model,
      if (language != null) 'language': language,
      if (coveredDurationMs != null) 'covered_duration_ms': coveredDurationMs,
      if (bodyPath != null) 'body_path': bodyPath,
      if (revision != null) 'revision': revision,
      if (gapsJson != null) 'gaps_json': gapsJson,
      if (frozenAt != null) 'frozen_at': frozenAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptsCompanion copyWith({
    Value<String>? id,
    Value<String>? meetingId,
    Value<String>? kind,
    Value<String>? status,
    Value<String?>? providerProtocol,
    Value<String?>? model,
    Value<String?>? language,
    Value<int>? coveredDurationMs,
    Value<String?>? bodyPath,
    Value<int>? revision,
    Value<String>? gapsJson,
    Value<DateTime?>? frozenAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TranscriptsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      providerProtocol: providerProtocol ?? this.providerProtocol,
      model: model ?? this.model,
      language: language ?? this.language,
      coveredDurationMs: coveredDurationMs ?? this.coveredDurationMs,
      bodyPath: bodyPath ?? this.bodyPath,
      revision: revision ?? this.revision,
      gapsJson: gapsJson ?? this.gapsJson,
      frozenAt: frozenAt ?? this.frozenAt,
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
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (providerProtocol.present) {
      map['provider_protocol'] = Variable<String>(providerProtocol.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (coveredDurationMs.present) {
      map['covered_duration_ms'] = Variable<int>(coveredDurationMs.value);
    }
    if (bodyPath.present) {
      map['body_path'] = Variable<String>(bodyPath.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (gapsJson.present) {
      map['gaps_json'] = Variable<String>(gapsJson.value);
    }
    if (frozenAt.present) {
      map['frozen_at'] = Variable<DateTime>(frozenAt.value);
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
    return (StringBuffer('TranscriptsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('providerProtocol: $providerProtocol, ')
          ..write('model: $model, ')
          ..write('language: $language, ')
          ..write('coveredDurationMs: $coveredDurationMs, ')
          ..write('bodyPath: $bodyPath, ')
          ..write('revision: $revision, ')
          ..write('gapsJson: $gapsJson, ')
          ..write('frozenAt: $frozenAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _transcriptIdMeta = const VerificationMeta(
    'transcriptId',
  );
  @override
  late final GeneratedColumn<String> transcriptId = GeneratedColumn<String>(
    'transcript_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transcripts (id) ON DELETE SET NULL',
    ),
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
    meetingId,
    transcriptId,
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
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    }
    if (data.containsKey('transcript_id')) {
      context.handle(
        _transcriptIdMeta,
        transcriptId.isAcceptableOrUnknown(
          data['transcript_id']!,
          _transcriptIdMeta,
        ),
      );
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
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      ),
      transcriptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_id'],
      ),
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
  final String? meetingId;
  final String? transcriptId;
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
    this.meetingId,
    this.transcriptId,
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
    if (!nullToAbsent || meetingId != null) {
      map['meeting_id'] = Variable<String>(meetingId);
    }
    if (!nullToAbsent || transcriptId != null) {
      map['transcript_id'] = Variable<String>(transcriptId);
    }
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
      meetingId: meetingId == null && nullToAbsent
          ? const Value.absent()
          : Value(meetingId),
      transcriptId: transcriptId == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptId),
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
      meetingId: serializer.fromJson<String?>(json['meetingId']),
      transcriptId: serializer.fromJson<String?>(json['transcriptId']),
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
      'meetingId': serializer.toJson<String?>(meetingId),
      'transcriptId': serializer.toJson<String?>(transcriptId),
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
    Value<String?> meetingId = const Value.absent(),
    Value<String?> transcriptId = const Value.absent(),
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
    meetingId: meetingId.present ? meetingId.value : this.meetingId,
    transcriptId: transcriptId.present ? transcriptId.value : this.transcriptId,
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
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      transcriptId: data.transcriptId.present
          ? data.transcriptId.value
          : this.transcriptId,
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
          ..write('updatedAt: $updatedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('transcriptId: $transcriptId')
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
    meetingId,
    transcriptId,
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
          other.updatedAt == this.updatedAt &&
          other.meetingId == this.meetingId &&
          other.transcriptId == this.transcriptId);
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
  final Value<String?> meetingId;
  final Value<String?> transcriptId;
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
    this.meetingId = const Value.absent(),
    this.transcriptId = const Value.absent(),
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
    this.meetingId = const Value.absent(),
    this.transcriptId = const Value.absent(),
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
    Expression<String>? meetingId,
    Expression<String>? transcriptId,
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
      if (meetingId != null) 'meeting_id': meetingId,
      if (transcriptId != null) 'transcript_id': transcriptId,
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
    Value<String?>? meetingId,
    Value<String?>? transcriptId,
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
      meetingId: meetingId ?? this.meetingId,
      transcriptId: transcriptId ?? this.transcriptId,
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
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (transcriptId.present) {
      map['transcript_id'] = Variable<String>(transcriptId.value);
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
          ..write('meetingId: $meetingId, ')
          ..write('transcriptId: $transcriptId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordingAssetsTable extends RecordingAssets
    with TableInfo<$RecordingAssetsTable, RecordingAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelsMeta = const VerificationMeta(
    'channels',
  );
  @override
  late final GeneratedColumn<int> channels = GeneratedColumn<int>(
    'channels',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _byteLengthMeta = const VerificationMeta(
    'byteLength',
  );
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
    'byte_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceProfileMeta = const VerificationMeta(
    'sourceProfile',
  );
  @override
  late final GeneratedColumn<String> sourceProfile = GeneratedColumn<String>(
    'source_profile',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finalizedAtMeta = const VerificationMeta(
    'finalizedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finalizedAt = GeneratedColumn<DateTime>(
    'finalized_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
    meetingId,
    path,
    mimeType,
    sampleRate,
    channels,
    durationMs,
    byteLength,
    sha256,
    sourceProfile,
    finalizedAt,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recording_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordingAsset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('channels')) {
      context.handle(
        _channelsMeta,
        channels.isAcceptableOrUnknown(data['channels']!, _channelsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('byte_length')) {
      context.handle(
        _byteLengthMeta,
        byteLength.isAcceptableOrUnknown(data['byte_length']!, _byteLengthMeta),
      );
    } else if (isInserting) {
      context.missing(_byteLengthMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('source_profile')) {
      context.handle(
        _sourceProfileMeta,
        sourceProfile.isAcceptableOrUnknown(
          data['source_profile']!,
          _sourceProfileMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceProfileMeta);
    }
    if (data.containsKey('finalized_at')) {
      context.handle(
        _finalizedAtMeta,
        finalizedAt.isAcceptableOrUnknown(
          data['finalized_at']!,
          _finalizedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_finalizedAtMeta);
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {meetingId},
  ];
  @override
  RecordingAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordingAsset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      channels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channels'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      byteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_length'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      sourceProfile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_profile'],
      )!,
      finalizedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finalized_at'],
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
  $RecordingAssetsTable createAlias(String alias) {
    return $RecordingAssetsTable(attachedDatabase, alias);
  }
}

class RecordingAsset extends DataClass implements Insertable<RecordingAsset> {
  final String id;
  final String meetingId;
  final String path;
  final String mimeType;
  final int? sampleRate;
  final int? channels;
  final int durationMs;
  final int byteLength;
  final String? sha256;
  final String sourceProfile;
  final DateTime finalizedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RecordingAsset({
    required this.id,
    required this.meetingId,
    required this.path,
    required this.mimeType,
    this.sampleRate,
    this.channels,
    required this.durationMs,
    required this.byteLength,
    this.sha256,
    required this.sourceProfile,
    required this.finalizedAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['path'] = Variable<String>(path);
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || channels != null) {
      map['channels'] = Variable<int>(channels);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['byte_length'] = Variable<int>(byteLength);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    map['source_profile'] = Variable<String>(sourceProfile);
    map['finalized_at'] = Variable<DateTime>(finalizedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecordingAssetsCompanion toCompanion(bool nullToAbsent) {
    return RecordingAssetsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      path: Value(path),
      mimeType: Value(mimeType),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      channels: channels == null && nullToAbsent
          ? const Value.absent()
          : Value(channels),
      durationMs: Value(durationMs),
      byteLength: Value(byteLength),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      sourceProfile: Value(sourceProfile),
      finalizedAt: Value(finalizedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecordingAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordingAsset(
      id: serializer.fromJson<String>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      path: serializer.fromJson<String>(json['path']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      channels: serializer.fromJson<int?>(json['channels']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      byteLength: serializer.fromJson<int>(json['byteLength']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      sourceProfile: serializer.fromJson<String>(json['sourceProfile']),
      finalizedAt: serializer.fromJson<DateTime>(json['finalizedAt']),
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
      'meetingId': serializer.toJson<String>(meetingId),
      'path': serializer.toJson<String>(path),
      'mimeType': serializer.toJson<String>(mimeType),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'channels': serializer.toJson<int?>(channels),
      'durationMs': serializer.toJson<int>(durationMs),
      'byteLength': serializer.toJson<int>(byteLength),
      'sha256': serializer.toJson<String?>(sha256),
      'sourceProfile': serializer.toJson<String>(sourceProfile),
      'finalizedAt': serializer.toJson<DateTime>(finalizedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecordingAsset copyWith({
    String? id,
    String? meetingId,
    String? path,
    String? mimeType,
    Value<int?> sampleRate = const Value.absent(),
    Value<int?> channels = const Value.absent(),
    int? durationMs,
    int? byteLength,
    Value<String?> sha256 = const Value.absent(),
    String? sourceProfile,
    DateTime? finalizedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RecordingAsset(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    path: path ?? this.path,
    mimeType: mimeType ?? this.mimeType,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    channels: channels.present ? channels.value : this.channels,
    durationMs: durationMs ?? this.durationMs,
    byteLength: byteLength ?? this.byteLength,
    sha256: sha256.present ? sha256.value : this.sha256,
    sourceProfile: sourceProfile ?? this.sourceProfile,
    finalizedAt: finalizedAt ?? this.finalizedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RecordingAsset copyWithCompanion(RecordingAssetsCompanion data) {
    return RecordingAsset(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      path: data.path.present ? data.path.value : this.path,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      channels: data.channels.present ? data.channels.value : this.channels,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      byteLength: data.byteLength.present
          ? data.byteLength.value
          : this.byteLength,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      sourceProfile: data.sourceProfile.present
          ? data.sourceProfile.value
          : this.sourceProfile,
      finalizedAt: data.finalizedAt.present
          ? data.finalizedAt.value
          : this.finalizedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordingAsset(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('path: $path, ')
          ..write('mimeType: $mimeType, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('channels: $channels, ')
          ..write('durationMs: $durationMs, ')
          ..write('byteLength: $byteLength, ')
          ..write('sha256: $sha256, ')
          ..write('sourceProfile: $sourceProfile, ')
          ..write('finalizedAt: $finalizedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    path,
    mimeType,
    sampleRate,
    channels,
    durationMs,
    byteLength,
    sha256,
    sourceProfile,
    finalizedAt,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordingAsset &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.path == this.path &&
          other.mimeType == this.mimeType &&
          other.sampleRate == this.sampleRate &&
          other.channels == this.channels &&
          other.durationMs == this.durationMs &&
          other.byteLength == this.byteLength &&
          other.sha256 == this.sha256 &&
          other.sourceProfile == this.sourceProfile &&
          other.finalizedAt == this.finalizedAt &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecordingAssetsCompanion extends UpdateCompanion<RecordingAsset> {
  final Value<String> id;
  final Value<String> meetingId;
  final Value<String> path;
  final Value<String> mimeType;
  final Value<int?> sampleRate;
  final Value<int?> channels;
  final Value<int> durationMs;
  final Value<int> byteLength;
  final Value<String?> sha256;
  final Value<String> sourceProfile;
  final Value<DateTime> finalizedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RecordingAssetsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.path = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.channels = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.sourceProfile = const Value.absent(),
    this.finalizedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordingAssetsCompanion.insert({
    required String id,
    required String meetingId,
    required String path,
    required String mimeType,
    this.sampleRate = const Value.absent(),
    this.channels = const Value.absent(),
    required int durationMs,
    required int byteLength,
    this.sha256 = const Value.absent(),
    required String sourceProfile,
    required DateTime finalizedAt,
    this.deletedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       meetingId = Value(meetingId),
       path = Value(path),
       mimeType = Value(mimeType),
       durationMs = Value(durationMs),
       byteLength = Value(byteLength),
       sourceProfile = Value(sourceProfile),
       finalizedAt = Value(finalizedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RecordingAsset> custom({
    Expression<String>? id,
    Expression<String>? meetingId,
    Expression<String>? path,
    Expression<String>? mimeType,
    Expression<int>? sampleRate,
    Expression<int>? channels,
    Expression<int>? durationMs,
    Expression<int>? byteLength,
    Expression<String>? sha256,
    Expression<String>? sourceProfile,
    Expression<DateTime>? finalizedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (path != null) 'path': path,
      if (mimeType != null) 'mime_type': mimeType,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (channels != null) 'channels': channels,
      if (durationMs != null) 'duration_ms': durationMs,
      if (byteLength != null) 'byte_length': byteLength,
      if (sha256 != null) 'sha256': sha256,
      if (sourceProfile != null) 'source_profile': sourceProfile,
      if (finalizedAt != null) 'finalized_at': finalizedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordingAssetsCompanion copyWith({
    Value<String>? id,
    Value<String>? meetingId,
    Value<String>? path,
    Value<String>? mimeType,
    Value<int?>? sampleRate,
    Value<int?>? channels,
    Value<int>? durationMs,
    Value<int>? byteLength,
    Value<String?>? sha256,
    Value<String>? sourceProfile,
    Value<DateTime>? finalizedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RecordingAssetsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      path: path ?? this.path,
      mimeType: mimeType ?? this.mimeType,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      durationMs: durationMs ?? this.durationMs,
      byteLength: byteLength ?? this.byteLength,
      sha256: sha256 ?? this.sha256,
      sourceProfile: sourceProfile ?? this.sourceProfile,
      finalizedAt: finalizedAt ?? this.finalizedAt,
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
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (channels.present) {
      map['channels'] = Variable<int>(channels.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (sourceProfile.present) {
      map['source_profile'] = Variable<String>(sourceProfile.value);
    }
    if (finalizedAt.present) {
      map['finalized_at'] = Variable<DateTime>(finalizedAt.value);
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
    return (StringBuffer('RecordingAssetsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('path: $path, ')
          ..write('mimeType: $mimeType, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('channels: $channels, ')
          ..write('durationMs: $durationMs, ')
          ..write('byteLength: $byteLength, ')
          ..write('sha256: $sha256, ')
          ..write('sourceProfile: $sourceProfile, ')
          ..write('finalizedAt: $finalizedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptSegmentsTable extends TranscriptSegments
    with TableInfo<$TranscriptSegmentsTable, TranscriptSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptIdMeta = const VerificationMeta(
    'transcriptId',
  );
  @override
  late final GeneratedColumn<String> transcriptId = GeneratedColumn<String>(
    'transcript_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transcripts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerItemIdMeta = const VerificationMeta(
    'providerItemId',
  );
  @override
  late final GeneratedColumn<String> providerItemId = GeneratedColumn<String>(
    'provider_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptTextMeta = const VerificationMeta(
    'transcriptText',
  );
  @override
  late final GeneratedColumn<String> transcriptText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFinalMeta = const VerificationMeta(
    'isFinal',
  );
  @override
  late final GeneratedColumn<bool> isFinal = GeneratedColumn<bool>(
    'is_final',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_final" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speakerIdMeta = const VerificationMeta(
    'speakerId',
  );
  @override
  late final GeneratedColumn<String> speakerId = GeneratedColumn<String>(
    'speaker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    transcriptId,
    providerItemId,
    ordinal,
    startMs,
    endMs,
    transcriptText,
    isFinal,
    source,
    speakerId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('transcript_id')) {
      context.handle(
        _transcriptIdMeta,
        transcriptId.isAcceptableOrUnknown(
          data['transcript_id']!,
          _transcriptIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptIdMeta);
    }
    if (data.containsKey('provider_item_id')) {
      context.handle(
        _providerItemIdMeta,
        providerItemId.isAcceptableOrUnknown(
          data['provider_item_id']!,
          _providerItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerItemIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _transcriptTextMeta,
        transcriptText.isAcceptableOrUnknown(
          data['text']!,
          _transcriptTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptTextMeta);
    }
    if (data.containsKey('is_final')) {
      context.handle(
        _isFinalMeta,
        isFinal.isAcceptableOrUnknown(data['is_final']!, _isFinalMeta),
      );
    } else if (isInserting) {
      context.missing(_isFinalMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('speaker_id')) {
      context.handle(
        _speakerIdMeta,
        speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta),
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {transcriptId, providerItemId},
  ];
  @override
  TranscriptSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      transcriptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_id'],
      )!,
      providerItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_item_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      transcriptText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      isFinal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_final'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      speakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_id'],
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
  $TranscriptSegmentsTable createAlias(String alias) {
    return $TranscriptSegmentsTable(attachedDatabase, alias);
  }
}

class TranscriptSegment extends DataClass
    implements Insertable<TranscriptSegment> {
  final String id;
  final String transcriptId;
  final String providerItemId;
  final int ordinal;
  final int startMs;
  final int endMs;
  final String transcriptText;
  final bool isFinal;
  final String source;
  final String? speakerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TranscriptSegment({
    required this.id,
    required this.transcriptId,
    required this.providerItemId,
    required this.ordinal,
    required this.startMs,
    required this.endMs,
    required this.transcriptText,
    required this.isFinal,
    required this.source,
    this.speakerId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['transcript_id'] = Variable<String>(transcriptId);
    map['provider_item_id'] = Variable<String>(providerItemId);
    map['ordinal'] = Variable<int>(ordinal);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['text'] = Variable<String>(transcriptText);
    map['is_final'] = Variable<bool>(isFinal);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || speakerId != null) {
      map['speaker_id'] = Variable<String>(speakerId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TranscriptSegmentsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSegmentsCompanion(
      id: Value(id),
      transcriptId: Value(transcriptId),
      providerItemId: Value(providerItemId),
      ordinal: Value(ordinal),
      startMs: Value(startMs),
      endMs: Value(endMs),
      transcriptText: Value(transcriptText),
      isFinal: Value(isFinal),
      source: Value(source),
      speakerId: speakerId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TranscriptSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSegment(
      id: serializer.fromJson<String>(json['id']),
      transcriptId: serializer.fromJson<String>(json['transcriptId']),
      providerItemId: serializer.fromJson<String>(json['providerItemId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      transcriptText: serializer.fromJson<String>(json['transcriptText']),
      isFinal: serializer.fromJson<bool>(json['isFinal']),
      source: serializer.fromJson<String>(json['source']),
      speakerId: serializer.fromJson<String?>(json['speakerId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'transcriptId': serializer.toJson<String>(transcriptId),
      'providerItemId': serializer.toJson<String>(providerItemId),
      'ordinal': serializer.toJson<int>(ordinal),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'transcriptText': serializer.toJson<String>(transcriptText),
      'isFinal': serializer.toJson<bool>(isFinal),
      'source': serializer.toJson<String>(source),
      'speakerId': serializer.toJson<String?>(speakerId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TranscriptSegment copyWith({
    String? id,
    String? transcriptId,
    String? providerItemId,
    int? ordinal,
    int? startMs,
    int? endMs,
    String? transcriptText,
    bool? isFinal,
    String? source,
    Value<String?> speakerId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TranscriptSegment(
    id: id ?? this.id,
    transcriptId: transcriptId ?? this.transcriptId,
    providerItemId: providerItemId ?? this.providerItemId,
    ordinal: ordinal ?? this.ordinal,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    transcriptText: transcriptText ?? this.transcriptText,
    isFinal: isFinal ?? this.isFinal,
    source: source ?? this.source,
    speakerId: speakerId.present ? speakerId.value : this.speakerId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TranscriptSegment copyWithCompanion(TranscriptSegmentsCompanion data) {
    return TranscriptSegment(
      id: data.id.present ? data.id.value : this.id,
      transcriptId: data.transcriptId.present
          ? data.transcriptId.value
          : this.transcriptId,
      providerItemId: data.providerItemId.present
          ? data.providerItemId.value
          : this.providerItemId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      transcriptText: data.transcriptText.present
          ? data.transcriptText.value
          : this.transcriptText,
      isFinal: data.isFinal.present ? data.isFinal.value : this.isFinal,
      source: data.source.present ? data.source.value : this.source,
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegment(')
          ..write('id: $id, ')
          ..write('transcriptId: $transcriptId, ')
          ..write('providerItemId: $providerItemId, ')
          ..write('ordinal: $ordinal, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('transcriptText: $transcriptText, ')
          ..write('isFinal: $isFinal, ')
          ..write('source: $source, ')
          ..write('speakerId: $speakerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transcriptId,
    providerItemId,
    ordinal,
    startMs,
    endMs,
    transcriptText,
    isFinal,
    source,
    speakerId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSegment &&
          other.id == this.id &&
          other.transcriptId == this.transcriptId &&
          other.providerItemId == this.providerItemId &&
          other.ordinal == this.ordinal &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.transcriptText == this.transcriptText &&
          other.isFinal == this.isFinal &&
          other.source == this.source &&
          other.speakerId == this.speakerId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TranscriptSegmentsCompanion extends UpdateCompanion<TranscriptSegment> {
  final Value<String> id;
  final Value<String> transcriptId;
  final Value<String> providerItemId;
  final Value<int> ordinal;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String> transcriptText;
  final Value<bool> isFinal;
  final Value<String> source;
  final Value<String?> speakerId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TranscriptSegmentsCompanion({
    this.id = const Value.absent(),
    this.transcriptId = const Value.absent(),
    this.providerItemId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.transcriptText = const Value.absent(),
    this.isFinal = const Value.absent(),
    this.source = const Value.absent(),
    this.speakerId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptSegmentsCompanion.insert({
    required String id,
    required String transcriptId,
    required String providerItemId,
    required int ordinal,
    required int startMs,
    required int endMs,
    required String transcriptText,
    required bool isFinal,
    required String source,
    this.speakerId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       transcriptId = Value(transcriptId),
       providerItemId = Value(providerItemId),
       ordinal = Value(ordinal),
       startMs = Value(startMs),
       endMs = Value(endMs),
       transcriptText = Value(transcriptText),
       isFinal = Value(isFinal),
       source = Value(source),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TranscriptSegment> custom({
    Expression<String>? id,
    Expression<String>? transcriptId,
    Expression<String>? providerItemId,
    Expression<int>? ordinal,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? transcriptText,
    Expression<bool>? isFinal,
    Expression<String>? source,
    Expression<String>? speakerId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transcriptId != null) 'transcript_id': transcriptId,
      if (providerItemId != null) 'provider_item_id': providerItemId,
      if (ordinal != null) 'ordinal': ordinal,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (transcriptText != null) 'text': transcriptText,
      if (isFinal != null) 'is_final': isFinal,
      if (source != null) 'source': source,
      if (speakerId != null) 'speaker_id': speakerId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? transcriptId,
    Value<String>? providerItemId,
    Value<int>? ordinal,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String>? transcriptText,
    Value<bool>? isFinal,
    Value<String>? source,
    Value<String?>? speakerId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TranscriptSegmentsCompanion(
      id: id ?? this.id,
      transcriptId: transcriptId ?? this.transcriptId,
      providerItemId: providerItemId ?? this.providerItemId,
      ordinal: ordinal ?? this.ordinal,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      transcriptText: transcriptText ?? this.transcriptText,
      isFinal: isFinal ?? this.isFinal,
      source: source ?? this.source,
      speakerId: speakerId ?? this.speakerId,
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
    if (transcriptId.present) {
      map['transcript_id'] = Variable<String>(transcriptId.value);
    }
    if (providerItemId.present) {
      map['provider_item_id'] = Variable<String>(providerItemId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (transcriptText.present) {
      map['text'] = Variable<String>(transcriptText.value);
    }
    if (isFinal.present) {
      map['is_final'] = Variable<bool>(isFinal.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (speakerId.present) {
      map['speaker_id'] = Variable<String>(speakerId.value);
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
    return (StringBuffer('TranscriptSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('transcriptId: $transcriptId, ')
          ..write('providerItemId: $providerItemId, ')
          ..write('ordinal: $ordinal, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('transcriptText: $transcriptText, ')
          ..write('isFinal: $isFinal, ')
          ..write('source: $source, ')
          ..write('speakerId: $speakerId, ')
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
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _jobTypeMeta = const VerificationMeta(
    'jobType',
  );
  @override
  late final GeneratedColumn<String> jobType = GeneratedColumn<String>(
    'job_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkpointJsonMeta = const VerificationMeta(
    'checkpointJson',
  );
  @override
  late final GeneratedColumn<String> checkpointJson = GeneratedColumn<String>(
    'checkpoint_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    meetingId,
    jobType,
    checkpointJson,
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
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    }
    if (data.containsKey('job_type')) {
      context.handle(
        _jobTypeMeta,
        jobType.isAcceptableOrUnknown(data['job_type']!, _jobTypeMeta),
      );
    }
    if (data.containsKey('checkpoint_json')) {
      context.handle(
        _checkpointJsonMeta,
        checkpointJson.isAcceptableOrUnknown(
          data['checkpoint_json']!,
          _checkpointJsonMeta,
        ),
      );
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
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      ),
      jobType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_type'],
      ),
      checkpointJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint_json'],
      ),
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
  final String? meetingId;
  final String? jobType;
  final String? checkpointJson;
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
    this.meetingId,
    this.jobType,
    this.checkpointJson,
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
    if (!nullToAbsent || meetingId != null) {
      map['meeting_id'] = Variable<String>(meetingId);
    }
    if (!nullToAbsent || jobType != null) {
      map['job_type'] = Variable<String>(jobType);
    }
    if (!nullToAbsent || checkpointJson != null) {
      map['checkpoint_json'] = Variable<String>(checkpointJson);
    }
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
      meetingId: meetingId == null && nullToAbsent
          ? const Value.absent()
          : Value(meetingId),
      jobType: jobType == null && nullToAbsent
          ? const Value.absent()
          : Value(jobType),
      checkpointJson: checkpointJson == null && nullToAbsent
          ? const Value.absent()
          : Value(checkpointJson),
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
      meetingId: serializer.fromJson<String?>(json['meetingId']),
      jobType: serializer.fromJson<String?>(json['jobType']),
      checkpointJson: serializer.fromJson<String?>(json['checkpointJson']),
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
      'meetingId': serializer.toJson<String?>(meetingId),
      'jobType': serializer.toJson<String?>(jobType),
      'checkpointJson': serializer.toJson<String?>(checkpointJson),
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
    Value<String?> meetingId = const Value.absent(),
    Value<String?> jobType = const Value.absent(),
    Value<String?> checkpointJson = const Value.absent(),
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
    meetingId: meetingId.present ? meetingId.value : this.meetingId,
    jobType: jobType.present ? jobType.value : this.jobType,
    checkpointJson: checkpointJson.present
        ? checkpointJson.value
        : this.checkpointJson,
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
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      jobType: data.jobType.present ? data.jobType.value : this.jobType,
      checkpointJson: data.checkpointJson.present
          ? data.checkpointJson.value
          : this.checkpointJson,
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
          ..write('updatedAt: $updatedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('jobType: $jobType, ')
          ..write('checkpointJson: $checkpointJson')
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
    meetingId,
    jobType,
    checkpointJson,
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
          other.updatedAt == this.updatedAt &&
          other.meetingId == this.meetingId &&
          other.jobType == this.jobType &&
          other.checkpointJson == this.checkpointJson);
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
  final Value<String?> meetingId;
  final Value<String?> jobType;
  final Value<String?> checkpointJson;
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
    this.meetingId = const Value.absent(),
    this.jobType = const Value.absent(),
    this.checkpointJson = const Value.absent(),
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
    this.meetingId = const Value.absent(),
    this.jobType = const Value.absent(),
    this.checkpointJson = const Value.absent(),
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
    Expression<String>? meetingId,
    Expression<String>? jobType,
    Expression<String>? checkpointJson,
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
      if (meetingId != null) 'meeting_id': meetingId,
      if (jobType != null) 'job_type': jobType,
      if (checkpointJson != null) 'checkpoint_json': checkpointJson,
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
    Value<String?>? meetingId,
    Value<String?>? jobType,
    Value<String?>? checkpointJson,
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
      meetingId: meetingId ?? this.meetingId,
      jobType: jobType ?? this.jobType,
      checkpointJson: checkpointJson ?? this.checkpointJson,
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
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (jobType.present) {
      map['job_type'] = Variable<String>(jobType.value);
    }
    if (checkpointJson.present) {
      map['checkpoint_json'] = Variable<String>(checkpointJson.value);
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
          ..write('meetingId: $meetingId, ')
          ..write('jobType: $jobType, ')
          ..write('checkpointJson: $checkpointJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MeetingsTable meetings = $MeetingsTable(this);
  late final $TranscriptsTable transcripts = $TranscriptsTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $RecordingAssetsTable recordingAssets = $RecordingAssetsTable(
    this,
  );
  late final $TranscriptSegmentsTable transcriptSegments =
      $TranscriptSegmentsTable(this);
  late final $ProcessingJobsTable processingJobs = $ProcessingJobsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    meetings,
    transcripts,
    notes,
    recordingAssets,
    transcriptSegments,
    processingJobs,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcripts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transcripts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recording_assets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transcripts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcript_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('processing_jobs', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$MeetingsTableCreateCompanionBuilder =
    MeetingsCompanion Function({
      required String id,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required int durationMs,
      required String templateJson,
      required String highlightsJson,
      required String status,
      Value<DateTime?> deletedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MeetingsTableUpdateCompanionBuilder =
    MeetingsCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> durationMs,
      Value<String> templateJson,
      Value<String> highlightsJson,
      Value<String> status,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$MeetingsTableReferences
    extends BaseReferences<_$AppDatabase, $MeetingsTable, Meeting> {
  $$MeetingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TranscriptsTable, List<Transcript>>
  _transcriptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transcripts,
    aliasName: 'meetings__id__transcripts__meeting_id',
  );

  $$TranscriptsTableProcessedTableManager get transcriptsRefs {
    final manager = $$TranscriptsTableTableManager(
      $_db,
      $_db.transcripts,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transcriptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: 'meetings__id__notes__meeting_id',
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecordingAssetsTable, List<RecordingAsset>>
  _recordingAssetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recordingAssets,
    aliasName: 'meetings__id__recording_assets__meeting_id',
  );

  $$RecordingAssetsTableProcessedTableManager get recordingAssetsRefs {
    final manager = $$RecordingAssetsTableTableManager(
      $_db,
      $_db.recordingAssets,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recordingAssetsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProcessingJobsTable, List<ProcessingJob>>
  _processingJobsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.processingJobs,
    aliasName: 'meetings__id__processing_jobs__meeting_id',
  );

  $$ProcessingJobsTableProcessedTableManager get processingJobsRefs {
    final manager = $$ProcessingJobsTableTableManager(
      $_db,
      $_db.processingJobs,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_processingJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MeetingsTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateJson => $composableBuilder(
    column: $table.templateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get highlightsJson => $composableBuilder(
    column: $table.highlightsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
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

  Expression<bool> transcriptsRefs(
    Expression<bool> Function($$TranscriptsTableFilterComposer f) f,
  ) {
    final $$TranscriptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableFilterComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recordingAssetsRefs(
    Expression<bool> Function($$RecordingAssetsTableFilterComposer f) f,
  ) {
    final $$RecordingAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recordingAssets,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingAssetsTableFilterComposer(
            $db: $db,
            $table: $db.recordingAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> processingJobsRefs(
    Expression<bool> Function($$ProcessingJobsTableFilterComposer f) f,
  ) {
    final $$ProcessingJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.processingJobs,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProcessingJobsTableFilterComposer(
            $db: $db,
            $table: $db.processingJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeetingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateJson => $composableBuilder(
    column: $table.templateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get highlightsJson => $composableBuilder(
    column: $table.highlightsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
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

class $$MeetingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateJson => $composableBuilder(
    column: $table.templateJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get highlightsJson => $composableBuilder(
    column: $table.highlightsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> transcriptsRefs<T extends Object>(
    Expression<T> Function($$TranscriptsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recordingAssetsRefs<T extends Object>(
    Expression<T> Function($$RecordingAssetsTableAnnotationComposer a) f,
  ) {
    final $$RecordingAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recordingAssets,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordingAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> processingJobsRefs<T extends Object>(
    Expression<T> Function($$ProcessingJobsTableAnnotationComposer a) f,
  ) {
    final $$ProcessingJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.processingJobs,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProcessingJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.processingJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeetingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingsTable,
          Meeting,
          $$MeetingsTableFilterComposer,
          $$MeetingsTableOrderingComposer,
          $$MeetingsTableAnnotationComposer,
          $$MeetingsTableCreateCompanionBuilder,
          $$MeetingsTableUpdateCompanionBuilder,
          (Meeting, $$MeetingsTableReferences),
          Meeting,
          PrefetchHooks Function({
            bool transcriptsRefs,
            bool notesRefs,
            bool recordingAssetsRefs,
            bool processingJobsRefs,
          })
        > {
  $$MeetingsTableTableManager(_$AppDatabase db, $MeetingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> templateJson = const Value.absent(),
                Value<String> highlightsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                durationMs: durationMs,
                templateJson: templateJson,
                highlightsJson: highlightsJson,
                status: status,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required int durationMs,
                required String templateJson,
                required String highlightsJson,
                required String status,
                Value<DateTime?> deletedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                durationMs: durationMs,
                templateJson: templateJson,
                highlightsJson: highlightsJson,
                status: status,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MeetingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transcriptsRefs = false,
                notesRefs = false,
                recordingAssetsRefs = false,
                processingJobsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transcriptsRefs) db.transcripts,
                    if (notesRefs) db.notes,
                    if (recordingAssetsRefs) db.recordingAssets,
                    if (processingJobsRefs) db.processingJobs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transcriptsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          Transcript
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._transcriptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (notesRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          Note
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recordingAssetsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          RecordingAsset
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._recordingAssetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).recordingAssetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (processingJobsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          ProcessingJob
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._processingJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).processingJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MeetingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingsTable,
      Meeting,
      $$MeetingsTableFilterComposer,
      $$MeetingsTableOrderingComposer,
      $$MeetingsTableAnnotationComposer,
      $$MeetingsTableCreateCompanionBuilder,
      $$MeetingsTableUpdateCompanionBuilder,
      (Meeting, $$MeetingsTableReferences),
      Meeting,
      PrefetchHooks Function({
        bool transcriptsRefs,
        bool notesRefs,
        bool recordingAssetsRefs,
        bool processingJobsRefs,
      })
    >;
typedef $$TranscriptsTableCreateCompanionBuilder =
    TranscriptsCompanion Function({
      required String id,
      required String meetingId,
      required String kind,
      required String status,
      Value<String?> providerProtocol,
      Value<String?> model,
      Value<String?> language,
      required int coveredDurationMs,
      Value<String?> bodyPath,
      required int revision,
      Value<String> gapsJson,
      Value<DateTime?> frozenAt,
      Value<DateTime?> deletedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TranscriptsTableUpdateCompanionBuilder =
    TranscriptsCompanion Function({
      Value<String> id,
      Value<String> meetingId,
      Value<String> kind,
      Value<String> status,
      Value<String?> providerProtocol,
      Value<String?> model,
      Value<String?> language,
      Value<int> coveredDurationMs,
      Value<String?> bodyPath,
      Value<int> revision,
      Value<String> gapsJson,
      Value<DateTime?> frozenAt,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TranscriptsTableReferences
    extends BaseReferences<_$AppDatabase, $TranscriptsTable, Transcript> {
  $$TranscriptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('transcripts__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: 'transcripts__id__notes__transcript_id',
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.transcriptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TranscriptSegmentsTable, List<TranscriptSegment>>
  _transcriptSegmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transcriptSegments,
        aliasName: 'transcripts__id__transcript_segments__transcript_id',
      );

  $$TranscriptSegmentsTableProcessedTableManager get transcriptSegmentsRefs {
    final manager = $$TranscriptSegmentsTableTableManager(
      $_db,
      $_db.transcriptSegments,
    ).filter((f) => f.transcriptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transcriptSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TranscriptsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerProtocol => $composableBuilder(
    column: $table.providerProtocol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coveredDurationMs => $composableBuilder(
    column: $table.coveredDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyPath => $composableBuilder(
    column: $table.bodyPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gapsJson => $composableBuilder(
    column: $table.gapsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get frozenAt => $composableBuilder(
    column: $table.frozenAt,
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

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.transcriptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transcriptSegmentsRefs(
    Expression<bool> Function($$TranscriptSegmentsTableFilterComposer f) f,
  ) {
    final $$TranscriptSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.transcriptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TranscriptsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerProtocol => $composableBuilder(
    column: $table.providerProtocol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coveredDurationMs => $composableBuilder(
    column: $table.coveredDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyPath => $composableBuilder(
    column: $table.bodyPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gapsJson => $composableBuilder(
    column: $table.gapsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get frozenAt => $composableBuilder(
    column: $table.frozenAt,
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

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get providerProtocol => $composableBuilder(
    column: $table.providerProtocol,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get coveredDurationMs => $composableBuilder(
    column: $table.coveredDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyPath =>
      $composableBuilder(column: $table.bodyPath, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get gapsJson =>
      $composableBuilder(column: $table.gapsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get frozenAt =>
      $composableBuilder(column: $table.frozenAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.transcriptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transcriptSegmentsRefs<T extends Object>(
    Expression<T> Function($$TranscriptSegmentsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptSegments,
          getReferencedColumn: (t) => t.transcriptId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TranscriptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptsTable,
          Transcript,
          $$TranscriptsTableFilterComposer,
          $$TranscriptsTableOrderingComposer,
          $$TranscriptsTableAnnotationComposer,
          $$TranscriptsTableCreateCompanionBuilder,
          $$TranscriptsTableUpdateCompanionBuilder,
          (Transcript, $$TranscriptsTableReferences),
          Transcript,
          PrefetchHooks Function({
            bool meetingId,
            bool notesRefs,
            bool transcriptSegmentsRefs,
          })
        > {
  $$TranscriptsTableTableManager(_$AppDatabase db, $TranscriptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> providerProtocol = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<int> coveredDurationMs = const Value.absent(),
                Value<String?> bodyPath = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> gapsJson = const Value.absent(),
                Value<DateTime?> frozenAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptsCompanion(
                id: id,
                meetingId: meetingId,
                kind: kind,
                status: status,
                providerProtocol: providerProtocol,
                model: model,
                language: language,
                coveredDurationMs: coveredDurationMs,
                bodyPath: bodyPath,
                revision: revision,
                gapsJson: gapsJson,
                frozenAt: frozenAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String meetingId,
                required String kind,
                required String status,
                Value<String?> providerProtocol = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> language = const Value.absent(),
                required int coveredDurationMs,
                Value<String?> bodyPath = const Value.absent(),
                required int revision,
                Value<String> gapsJson = const Value.absent(),
                Value<DateTime?> frozenAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TranscriptsCompanion.insert(
                id: id,
                meetingId: meetingId,
                kind: kind,
                status: status,
                providerProtocol: providerProtocol,
                model: model,
                language: language,
                coveredDurationMs: coveredDurationMs,
                bodyPath: bodyPath,
                revision: revision,
                gapsJson: gapsJson,
                frozenAt: frozenAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TranscriptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                meetingId = false,
                notesRefs = false,
                transcriptSegmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (notesRefs) db.notes,
                    if (transcriptSegmentsRefs) db.transcriptSegments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (meetingId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.meetingId,
                                    referencedTable:
                                        $$TranscriptsTableReferences
                                            ._meetingIdTable(db),
                                    referencedColumn:
                                        $$TranscriptsTableReferences
                                            ._meetingIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (notesRefs)
                        await $_getPrefetchedData<
                          Transcript,
                          $TranscriptsTable,
                          Note
                        >(
                          currentTable: table,
                          referencedTable: $$TranscriptsTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TranscriptsTableReferences(
                                db,
                                table,
                                p0,
                              ).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transcriptId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transcriptSegmentsRefs)
                        await $_getPrefetchedData<
                          Transcript,
                          $TranscriptsTable,
                          TranscriptSegment
                        >(
                          currentTable: table,
                          referencedTable: $$TranscriptsTableReferences
                              ._transcriptSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TranscriptsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transcriptId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TranscriptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptsTable,
      Transcript,
      $$TranscriptsTableFilterComposer,
      $$TranscriptsTableOrderingComposer,
      $$TranscriptsTableAnnotationComposer,
      $$TranscriptsTableCreateCompanionBuilder,
      $$TranscriptsTableUpdateCompanionBuilder,
      (Transcript, $$TranscriptsTableReferences),
      Transcript,
      PrefetchHooks Function({
        bool meetingId,
        bool notesRefs,
        bool transcriptSegmentsRefs,
      })
    >;
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
      Value<String?> meetingId,
      Value<String?> transcriptId,
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
      Value<String?> meetingId,
      Value<String?> transcriptId,
      Value<int> rowid,
    });

final class $$NotesTableReferences
    extends BaseReferences<_$AppDatabase, $NotesTable, Note> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('notes__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager? get meetingId {
    final $_column = $_itemColumn<String>('meeting_id');
    if ($_column == null) return null;
    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TranscriptsTable _transcriptIdTable(_$AppDatabase db) =>
      db.transcripts.createAlias('notes__transcript_id__transcripts__id');

  $$TranscriptsTableProcessedTableManager? get transcriptId {
    final $_column = $_itemColumn<String>('transcript_id');
    if ($_column == null) return null;
    final manager = $$TranscriptsTableTableManager(
      $_db,
      $_db.transcripts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transcriptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

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

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TranscriptsTableFilterComposer get transcriptId {
    final $$TranscriptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptId,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableFilterComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TranscriptsTableOrderingComposer get transcriptId {
    final $$TranscriptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptId,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableOrderingComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TranscriptsTableAnnotationComposer get transcriptId {
    final $$TranscriptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptId,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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
          (Note, $$NotesTableReferences),
          Note,
          PrefetchHooks Function({bool meetingId, bool transcriptId})
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
                Value<String?> meetingId = const Value.absent(),
                Value<String?> transcriptId = const Value.absent(),
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
                meetingId: meetingId,
                transcriptId: transcriptId,
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
                Value<String?> meetingId = const Value.absent(),
                Value<String?> transcriptId = const Value.absent(),
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
                meetingId: meetingId,
                transcriptId: transcriptId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NotesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false, transcriptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable: $$NotesTableReferences
                                    ._meetingIdTable(db),
                                referencedColumn: $$NotesTableReferences
                                    ._meetingIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (transcriptId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transcriptId,
                                referencedTable: $$NotesTableReferences
                                    ._transcriptIdTable(db),
                                referencedColumn: $$NotesTableReferences
                                    ._transcriptIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
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
      (Note, $$NotesTableReferences),
      Note,
      PrefetchHooks Function({bool meetingId, bool transcriptId})
    >;
typedef $$RecordingAssetsTableCreateCompanionBuilder =
    RecordingAssetsCompanion Function({
      required String id,
      required String meetingId,
      required String path,
      required String mimeType,
      Value<int?> sampleRate,
      Value<int?> channels,
      required int durationMs,
      required int byteLength,
      Value<String?> sha256,
      required String sourceProfile,
      required DateTime finalizedAt,
      Value<DateTime?> deletedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$RecordingAssetsTableUpdateCompanionBuilder =
    RecordingAssetsCompanion Function({
      Value<String> id,
      Value<String> meetingId,
      Value<String> path,
      Value<String> mimeType,
      Value<int?> sampleRate,
      Value<int?> channels,
      Value<int> durationMs,
      Value<int> byteLength,
      Value<String?> sha256,
      Value<String> sourceProfile,
      Value<DateTime> finalizedAt,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$RecordingAssetsTableReferences
    extends
        BaseReferences<_$AppDatabase, $RecordingAssetsTable, RecordingAsset> {
  $$RecordingAssetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('recording_assets__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecordingAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordingAssetsTable> {
  $$RecordingAssetsTableFilterComposer({
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceProfile => $composableBuilder(
    column: $table.sourceProfile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
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

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordingAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordingAssetsTable> {
  $$RecordingAssetsTableOrderingComposer({
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceProfile => $composableBuilder(
    column: $table.sourceProfile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
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

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordingAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordingAssetsTable> {
  $$RecordingAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get sourceProfile => $composableBuilder(
    column: $table.sourceProfile,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordingAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordingAssetsTable,
          RecordingAsset,
          $$RecordingAssetsTableFilterComposer,
          $$RecordingAssetsTableOrderingComposer,
          $$RecordingAssetsTableAnnotationComposer,
          $$RecordingAssetsTableCreateCompanionBuilder,
          $$RecordingAssetsTableUpdateCompanionBuilder,
          (RecordingAsset, $$RecordingAssetsTableReferences),
          RecordingAsset,
          PrefetchHooks Function({bool meetingId})
        > {
  $$RecordingAssetsTableTableManager(
    _$AppDatabase db,
    $RecordingAssetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> channels = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> byteLength = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<String> sourceProfile = const Value.absent(),
                Value<DateTime> finalizedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordingAssetsCompanion(
                id: id,
                meetingId: meetingId,
                path: path,
                mimeType: mimeType,
                sampleRate: sampleRate,
                channels: channels,
                durationMs: durationMs,
                byteLength: byteLength,
                sha256: sha256,
                sourceProfile: sourceProfile,
                finalizedAt: finalizedAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String meetingId,
                required String path,
                required String mimeType,
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> channels = const Value.absent(),
                required int durationMs,
                required int byteLength,
                Value<String?> sha256 = const Value.absent(),
                required String sourceProfile,
                required DateTime finalizedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecordingAssetsCompanion.insert(
                id: id,
                meetingId: meetingId,
                path: path,
                mimeType: mimeType,
                sampleRate: sampleRate,
                channels: channels,
                durationMs: durationMs,
                byteLength: byteLength,
                sha256: sha256,
                sourceProfile: sourceProfile,
                finalizedAt: finalizedAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecordingAssetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable:
                                    $$RecordingAssetsTableReferences
                                        ._meetingIdTable(db),
                                referencedColumn:
                                    $$RecordingAssetsTableReferences
                                        ._meetingIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecordingAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordingAssetsTable,
      RecordingAsset,
      $$RecordingAssetsTableFilterComposer,
      $$RecordingAssetsTableOrderingComposer,
      $$RecordingAssetsTableAnnotationComposer,
      $$RecordingAssetsTableCreateCompanionBuilder,
      $$RecordingAssetsTableUpdateCompanionBuilder,
      (RecordingAsset, $$RecordingAssetsTableReferences),
      RecordingAsset,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$TranscriptSegmentsTableCreateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      required String id,
      required String transcriptId,
      required String providerItemId,
      required int ordinal,
      required int startMs,
      required int endMs,
      required String transcriptText,
      required bool isFinal,
      required String source,
      Value<String?> speakerId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TranscriptSegmentsTableUpdateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      Value<String> id,
      Value<String> transcriptId,
      Value<String> providerItemId,
      Value<int> ordinal,
      Value<int> startMs,
      Value<int> endMs,
      Value<String> transcriptText,
      Value<bool> isFinal,
      Value<String> source,
      Value<String?> speakerId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TranscriptSegmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegment
        > {
  $$TranscriptSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TranscriptsTable _transcriptIdTable(_$AppDatabase db) => db
      .transcripts
      .createAlias('transcript_segments__transcript_id__transcripts__id');

  $$TranscriptsTableProcessedTableManager get transcriptId {
    final $_column = $_itemColumn<String>('transcript_id')!;

    final manager = $$TranscriptsTableTableManager(
      $_db,
      $_db.transcripts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transcriptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TranscriptSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableFilterComposer({
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

  ColumnFilters<String> get providerItemId => $composableBuilder(
    column: $table.providerItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptText => $composableBuilder(
    column: $table.transcriptText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinal => $composableBuilder(
    column: $table.isFinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerId => $composableBuilder(
    column: $table.speakerId,
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

  $$TranscriptsTableFilterComposer get transcriptId {
    final $$TranscriptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptId,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableFilterComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableOrderingComposer({
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

  ColumnOrderings<String> get providerItemId => $composableBuilder(
    column: $table.providerItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptText => $composableBuilder(
    column: $table.transcriptText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinal => $composableBuilder(
    column: $table.isFinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerId => $composableBuilder(
    column: $table.speakerId,
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

  $$TranscriptsTableOrderingComposer get transcriptId {
    final $$TranscriptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptId,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableOrderingComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerItemId => $composableBuilder(
    column: $table.providerItemId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get transcriptText => $composableBuilder(
    column: $table.transcriptText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFinal =>
      $composableBuilder(column: $table.isFinal, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get speakerId =>
      $composableBuilder(column: $table.speakerId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TranscriptsTableAnnotationComposer get transcriptId {
    final $$TranscriptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptId,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegment,
          $$TranscriptSegmentsTableFilterComposer,
          $$TranscriptSegmentsTableOrderingComposer,
          $$TranscriptSegmentsTableAnnotationComposer,
          $$TranscriptSegmentsTableCreateCompanionBuilder,
          $$TranscriptSegmentsTableUpdateCompanionBuilder,
          (TranscriptSegment, $$TranscriptSegmentsTableReferences),
          TranscriptSegment,
          PrefetchHooks Function({bool transcriptId})
        > {
  $$TranscriptSegmentsTableTableManager(
    _$AppDatabase db,
    $TranscriptSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> transcriptId = const Value.absent(),
                Value<String> providerItemId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String> transcriptText = const Value.absent(),
                Value<bool> isFinal = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> speakerId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion(
                id: id,
                transcriptId: transcriptId,
                providerItemId: providerItemId,
                ordinal: ordinal,
                startMs: startMs,
                endMs: endMs,
                transcriptText: transcriptText,
                isFinal: isFinal,
                source: source,
                speakerId: speakerId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String transcriptId,
                required String providerItemId,
                required int ordinal,
                required int startMs,
                required int endMs,
                required String transcriptText,
                required bool isFinal,
                required String source,
                Value<String?> speakerId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion.insert(
                id: id,
                transcriptId: transcriptId,
                providerItemId: providerItemId,
                ordinal: ordinal,
                startMs: startMs,
                endMs: endMs,
                transcriptText: transcriptText,
                isFinal: isFinal,
                source: source,
                speakerId: speakerId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TranscriptSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transcriptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transcriptId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transcriptId,
                                referencedTable:
                                    $$TranscriptSegmentsTableReferences
                                        ._transcriptIdTable(db),
                                referencedColumn:
                                    $$TranscriptSegmentsTableReferences
                                        ._transcriptIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TranscriptSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptSegmentsTable,
      TranscriptSegment,
      $$TranscriptSegmentsTableFilterComposer,
      $$TranscriptSegmentsTableOrderingComposer,
      $$TranscriptSegmentsTableAnnotationComposer,
      $$TranscriptSegmentsTableCreateCompanionBuilder,
      $$TranscriptSegmentsTableUpdateCompanionBuilder,
      (TranscriptSegment, $$TranscriptSegmentsTableReferences),
      TranscriptSegment,
      PrefetchHooks Function({bool transcriptId})
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
      Value<String?> meetingId,
      Value<String?> jobType,
      Value<String?> checkpointJson,
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
      Value<String?> meetingId,
      Value<String?> jobType,
      Value<String?> checkpointJson,
      Value<int> rowid,
    });

final class $$ProcessingJobsTableReferences
    extends BaseReferences<_$AppDatabase, $ProcessingJobsTable, ProcessingJob> {
  $$ProcessingJobsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('processing_jobs__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager? get meetingId {
    final $_column = $_itemColumn<String>('meeting_id');
    if ($_column == null) return null;
    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

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

  ColumnFilters<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkpointJson => $composableBuilder(
    column: $table.checkpointJson,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  ColumnOrderings<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkpointJson => $composableBuilder(
    column: $table.checkpointJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  GeneratedColumn<String> get jobType =>
      $composableBuilder(column: $table.jobType, builder: (column) => column);

  GeneratedColumn<String> get checkpointJson => $composableBuilder(
    column: $table.checkpointJson,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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
          (ProcessingJob, $$ProcessingJobsTableReferences),
          ProcessingJob,
          PrefetchHooks Function({bool meetingId})
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
                Value<String?> meetingId = const Value.absent(),
                Value<String?> jobType = const Value.absent(),
                Value<String?> checkpointJson = const Value.absent(),
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
                meetingId: meetingId,
                jobType: jobType,
                checkpointJson: checkpointJson,
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
                Value<String?> meetingId = const Value.absent(),
                Value<String?> jobType = const Value.absent(),
                Value<String?> checkpointJson = const Value.absent(),
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
                meetingId: meetingId,
                jobType: jobType,
                checkpointJson: checkpointJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProcessingJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable: $$ProcessingJobsTableReferences
                                    ._meetingIdTable(db),
                                referencedColumn:
                                    $$ProcessingJobsTableReferences
                                        ._meetingIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
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
      (ProcessingJob, $$ProcessingJobsTableReferences),
      ProcessingJob,
      PrefetchHooks Function({bool meetingId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MeetingsTableTableManager get meetings =>
      $$MeetingsTableTableManager(_db, _db.meetings);
  $$TranscriptsTableTableManager get transcripts =>
      $$TranscriptsTableTableManager(_db, _db.transcripts);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$RecordingAssetsTableTableManager get recordingAssets =>
      $$RecordingAssetsTableTableManager(_db, _db.recordingAssets);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(_db, _db.transcriptSegments);
  $$ProcessingJobsTableTableManager get processingJobs =>
      $$ProcessingJobsTableTableManager(_db, _db.processingJobs);
}
