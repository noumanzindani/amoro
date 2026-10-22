import 'package:flutter/material.dart';

import '../onboarding/questions.dart';
import '../services/question_repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'option_editor.dart';
import 'question_preview.dart';

const _typeLabels = {
  QuestionType.single: 'Choose one',
  QuestionType.multi: 'Choose several',
  QuestionType.text: 'Short text',
  QuestionType.longText: 'Long text',
  QuestionType.scale: 'Slider',
  QuestionType.photos: 'Upload photos',
  QuestionType.video: 'Record video',
  QuestionType.date: 'Date',
  QuestionType.height: 'Height',
};

/// Create or edit one question. Works on a draft in the `toMap` shape;
/// nothing is written until Save passes [validateQuestionDefinition].
class QuestionEditorScreen extends StatefulWidget {
  final ProfileQuestion? existing;
  final List<ProfileQuestion> all;
  const QuestionEditorScreen({super.key, this.existing, required this.all});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  final _repo = QuestionRepository();
  late final bool _isNew = widget.existing == null;
  late final Set<String> _ids = {for (final q in widget.all) q.id};
  late final Map<String, dynamic> _draft =
      widget.existing?.toMap() ??
      {
        'type': QuestionType.single.name,
        'group': QuestionGroup.about.name,
        'title': '',
        'required': false,
        'private': false,
        'active': true,
        'order':
            widget.all.fold<double>(0, (m, q) => q.order > m ? q.order : m) +
            10,
        'options': <Map<String, dynamic>>[],
      };
  late final _id = TextEditingController(text: widget.existing?.id ?? '');
  late final Set<String> _savedValues = {
    for (final o in widget.existing?.options ?? const <QuestionOption>[])
      o.value,
  };
  bool _idEdited = false;
  bool _saving = false;
  List<String> _errors = const [];

  QuestionType get _type =>
      QuestionType.values.firstWhere((t) => t.name == _draft['type']);


  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  void _update(String key, Object? value) => setState(() {
    value == null || value == '' ? _draft.remove(key) : _draft[key] = value;
  });

  void _onTitle(String title) {
    _update('title', title);
    if (_isNew && !_idEdited) _id.text = slugId(title, _ids);
  }

  void _onType(QuestionType t) => setState(() {
    _draft['type'] = t.name;
    if (t == QuestionType.video) {
      _draft['private'] = true;
      _draft['videoSeconds'] ??= 30;
    }
    if (t == QuestionType.photos) _draft['maxSelect'] ??= 3;
  });

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> _confirmRemoveOption(String value) async {
    if (!_savedValues.contains(value)) return true; // never saved
    final dependents = dependentsOf(_id.text, widget.all, value: value);
    final core = widget.existing?.system == true;
    return _confirm(
      'Remove this option?',
      [
        'People who already chose it keep it in their profile data, but it '
            'won\'t show on their profile any more.',
        if (core) 'This is a core question: matching uses these values.',
        if (dependents.isNotEmpty)
          'These questions are shown only when it is chosen and will stop '
              'appearing for new answers: '
              '${dependents.map((d) => d.title).join(', ')}.',
      ].join('\n\n'),
    );
  }

  Future<void> _save() async {
    final id = _id.text.trim();
    final errors = validateQuestionDefinition(
      _draft,
      id: id,
      isNew: _isNew,
      existingIds: _ids,
    );
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    final existing = widget.existing;
    if (existing != null &&
        existing.system &&
        existing.required &&
        _draft['required'] != true &&
        !await _confirm(
          'Make a core question optional?',
          'Sign-up and matching rely on "${existing.title}". People who skip '
              'it may not appear in Discover.',
        )) {
      return;
    }
    // Round-trip through the model so only known fields are saved.
    final clean = ProfileQuestion.fromMap(id, _draft)!.toMap();
    setState(() => _saving = true);
    try {
      await _repo.upsert(id, clean);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errors = ['Couldn\'t save: $e'];
        });
      }
    }
  }

  int? _int(String key) => (_draft[key] as num?)?.toInt();

  Widget _numberField(String key, String label, {String? helper}) => SizedBox(
    width: 160,
    child: TextFormField(
      key: ValueKey('$key-${_draft['type']}'),
      initialValue: _int(key)?.toString() ?? '',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, helperText: helper),
      onChanged: (v) => _update(key, int.tryParse(v.trim())),
    ),
  );

  Widget _textField(String key, String label, {String? helper}) =>
      TextFormField(
        initialValue: _draft[key] as String? ?? '',
        decoration: InputDecoration(labelText: label, helperText: helper),
        onChanged: (v) => _update(key, v),
      );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.rose,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  List<Widget> _typeSettings() {
    switch (_type) {
      case QuestionType.single:
      case QuestionType.multi:
        return [
          _section('Options', [
            const Text(
              'Add a picture to any option to show the choices as pictures.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            OptionEditor(
              questionId: _id.text.isEmpty ? 'new' : _id.text,
              options: [
                for (final o in (_draft['options'] as List? ?? const []))
                  Map<String, dynamic>.from(o as Map),
              ],
              onChanged: (opts) => _update('options', opts),
              confirmRemove: _confirmRemoveOption,
            ),
            if (_type == QuestionType.multi) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                children: [
                  _numberField('minSelect', 'Pick at least'),
                  _numberField('maxSelect', 'Pick at most'),
                ],
              ),
            ],
          ]),
        ];
      case QuestionType.text:
      case QuestionType.longText:
        return [
          _section('Text', [_numberField('maxLength', 'Max characters')]),
        ];
      case QuestionType.scale:
        return [
          _section('Slider', [
            Wrap(
              spacing: 16,
              children: [
                _numberField('scaleMin', 'Lowest value'),
                _numberField('scaleMax', 'Highest value'),
              ],
            ),
            const SizedBox(height: 12),
            _textField('lowLabel', 'Label under the lowest end'),
            _textField('highLabel', 'Label under the highest end'),
            _textField(
              'scaleFormat',
              'How a value reads',
              helper: '{v} is the value, e.g. "{v} / 10" or "Age {v}"',
            ),
          ]),
        ];
      case QuestionType.photos:
        return [
          _section('Photos', [
            Wrap(
              spacing: 16,
              children: [
                _numberField('minSelect', 'At least'),
                _numberField('maxSelect', 'At most', helper: '1 to 10'),
              ],
            ),
          ]),
        ];
      case QuestionType.video:
        return [
          _section('Video', [
            _numberField(
              'videoSeconds',
              'Exact length (seconds)',
              helper: '5 to 180',
            ),
          ]),
        ];
      case QuestionType.date:
      case QuestionType.height:
        return const [];
    }
  }

  Widget _conditionSection() {
    final showIf = ShowIf.fromMap(_draft['showIf']);
    final sources = [
      for (final q in widget.all)
        if (q.id != _id.text &&
            (q.type == QuestionType.single || q.type == QuestionType.multi))
          q,
    ];
    final source = sources.where((q) => q.id == showIf?.questionId).firstOrNull;
    return _section('Show only if…', [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ask this only when an earlier answer matches'),
        value: showIf != null,
        onChanged: sources.isEmpty
            ? null
            : (on) => _update(
                'showIf',
                on ? ShowIf(sources.first.id, const []).toMap() : null,
              ),
      ),
      if (showIf != null) ...[
        DropdownButtonFormField<String>(
          initialValue: source?.id,
          decoration: const InputDecoration(labelText: 'Question'),
          items: [
            for (final q in sources)
              DropdownMenuItem(value: q.id, child: Text(q.title)),
          ],
          onChanged: (id) => _update('showIf', ShowIf(id!, const []).toMap()),
        ),
        const SizedBox(height: 12),
        const Text('…is any of:', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in source?.options ?? const <QuestionOption>[])
              FilterChip(
                label: Text(o.display),
                selected: showIf.values.contains(o.value),
                onSelected: (on) => _update(
                  'showIf',
                  ShowIf(showIf.questionId, [
                    for (final v in showIf.values)
                      if (v != o.value) v,
                    if (on) o.value,
                  ]).toMap(),
                ),
              ),
          ],
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final isVideo = _type == QuestionType.video;
    final preview = ProfileQuestion.fromMap(
      _id.text.isEmpty ? 'preview' : _id.text,
      _draft,
    );
    final form = ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
      children: [
        if (existing?.system == true)
          const Card(
            color: AppColors.surfaceHigh,
            child: ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Core question'),
              subtitle: Text(
                'Sign-up and matching depend on it. You can reword it and '
                'edit option labels, but not delete it or change its type.',
              ),
            ),
          ),
        _section('Question', [
          TextFormField(
            initialValue: _draft['title'] as String?,
            decoration: const InputDecoration(labelText: 'Question title'),
            onChanged: _onTitle,
          ),
          const SizedBox(height: 12),
          _textField('subtitle', 'Subtitle (optional)'),
          const SizedBox(height: 12),
          TextField(
            controller: _id,
            enabled: _isNew,
            decoration: InputDecoration(
              labelText: 'ID',
              helperText: _isNew
                  ? 'Where answers are saved. Can\'t be changed later.'
                  : 'Fixed after creation',
            ),
            onChanged: (_) => setState(() => _idEdited = true),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<QuestionType>(
                  initialValue: _type,
                  decoration: InputDecoration(
                    labelText: 'Answer type',
                    helperText: _isNew ? null : 'Fixed after creation',
                  ),
                  items: [
                    for (final e in _typeLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: _isNew ? (t) => _onType(t!) : null,
                ),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  initialValue: _draft['group'] as String?,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: [
                    for (final g in QuestionGroup.values)
                      DropdownMenuItem(value: g.name, child: Text(g.label)),
                  ],
                  onChanged: (g) => _update('group', g),
                ),
              ),
            ],
          ),
        ]),
        _section('Rules', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Required'),
            subtitle: const Text('Off: people can skip it'),
            value: _draft['required'] == true,
            onChanged: (v) => _update('required', v),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.public),
                label: Text('Public on profile'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.lock),
                label: Text('Private'),
              ),
            ],
            selected: {_draft['private'] == true},
            onSelectionChanged: _isNew && !isVideo
                ? (s) => _update('private', s.first)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            isVideo
                ? 'Videos are always private.'
                : _isNew
                ? 'Private answers are seen only by the person (and you).'
                : 'Fixed after creation: duplicate the question to change it.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 240,
            child: _textField(
              'chipIcon',
              'Profile chip emoji (optional)',
              helper: 'Shown before public answers, e.g. 🍷',
            ),
          ),
        ]),
        ..._typeSettings(),
        _conditionSection(),
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.rose),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final e in _errors) Text('• $e')],
            ),
          ),
        ],
        const SizedBox(height: 24),
        AppButton(text: 'Save', loading: _saving, onPressed: _save),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New question' : 'Edit question')),
      body: LayoutBuilder(
        builder: (context, box) => box.maxWidth < 1000
            ? form
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: form),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: QuestionPreview(question: preview),
                  ),
                ],
              ),
      ),
    );
  }
}
