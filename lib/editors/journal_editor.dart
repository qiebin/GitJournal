import 'dart:io';

import 'package:flutter/material.dart';

import 'package:gitjournal/core/note.dart';
import 'package:gitjournal/editors/common.dart';
import 'package:gitjournal/editors/disposable_change_notifier.dart';
import 'package:gitjournal/editors/heuristics.dart';
import 'package:gitjournal/editors/note_body_editor.dart';
import 'package:gitjournal/error_reporting.dart';
import 'package:gitjournal/utils/logger.dart';
import 'package:gitjournal/widgets/editor_scroll_view.dart';
import 'package:gitjournal/widgets/journal_editor_header.dart';
import 'package:intl/intl.dart';

class JournalEditor extends StatefulWidget implements Editor {
  final Note note;
  final bool noteModified;

  @override
  final NoteCallback noteDeletionSelected;
  @override
  final NoteCallback noteEditorChooserSelected;
  @override
  final NoteCallback exitEditorSelected;
  @override
  final NoteCallback renameNoteSelected;
  @override
  final NoteCallback editTagsSelected;
  @override
  final NoteCallback moveNoteToFolderSelected;
  @override
  final NoteCallback discardChangesSelected;

  final bool editMode;

  JournalEditor({
    Key key,
    @required this.note,
    @required this.noteModified,
    @required this.noteDeletionSelected,
    @required this.noteEditorChooserSelected,
    @required this.exitEditorSelected,
    @required this.renameNoteSelected,
    @required this.editTagsSelected,
    @required this.moveNoteToFolderSelected,
    @required this.discardChangesSelected,
    this.editMode = false,
  }) : super(key: key);

  @override
  JournalEditorState createState() {
    return JournalEditorState(note);
  }
}

class JournalEditorState extends State<JournalEditor>
    with DisposableChangeNotifier
    implements EditorState {
  Note note;
  TextEditingController _textController = TextEditingController();
  bool _noteModified;

  EditorHeuristics _heuristics;


  String getWeek(DateTime dateTime) {
    ///当前选中时间 周几
    var currentWeekDay = dateTime.weekday;

    ///周四
    //int WEEK_DAY = DateTime.thursday;

    DateTime epoch = DateTime.utc(dateTime.year);

    int offset = DateTime.monday - currentWeekDay;

    int delta =  - offset;

    int week = (dateTime.difference(epoch).inDays - delta) ~/ 7 + 1;
    return intToStr(week);
  }

  String intToStr(int v) {
    return (v < 10) ? "0$v" : "$v";
  }///周,如果当年的12月31是周四，则当年有53周 （国际规定是周四为一周的第一天）
  JournalEditorState(this.note) {
    if(note.body == ''){
      var nowTime = DateTime.now();
      note.body="# "+DateFormat('yyyy-MM-dd').format(nowTime)+"\n\n"

      +"[["+nowTime.year.toString()+"-W"+getWeek(nowTime)+"]]\n\n"

      +"```expander\n"
      +"{{tag:#FleetingNote -path:Templates}}\n"
    +"```\n"
    +"<--->\n\n"

    +"## Day Planner\n\n"

    +"### Morning Prep 🤠\n\n"

    +"- [ ] 09:30 Review yesterday\n"
    +"- [ ] 10:30 Reading\n"
          +"- [ ] 11:30 Writing\n\n"

          +"### Reading 👓\n\n"

          +"- [ ] 12:00 Reading\n"
          +"- [ ] 14:00 Writing\n\n"

          +"### Afternoon Review 🚀\n\n"

          +"- [ ] 15:00 Reading\n"
          +"- [ ] 16:30 Writing\n"
          +"- [ ] 17:20 Prep for tomorrow\n"
          +"- [ ] 18:00 Review today\n\n"

          +"## 间隔笔记：\n"
          +"- "
      ;
    }
    _textController = TextEditingController(text: note.body);
  }

  @override
  void initState() {
    super.initState();
    _noteModified = widget.noteModified;
    _heuristics = EditorHeuristics(text: note.body);
  }

  @override
  void dispose() {
    _textController.dispose();

    super.disposeListenables();
    super.dispose();
  }

  @override
  void didUpdateWidget(JournalEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.noteModified != widget.noteModified) {
      _noteModified = widget.noteModified;
    }
  }

  @override
  Widget build(BuildContext context) {
    var editor = EditorScrollView(
      child: Column(
        children: <Widget>[
          //JournalEditorHeader(note),
          NoteBodyEditor(
            textController: _textController,
            autofocus: widget.editMode,
            onChanged: _noteTextChanged,
          ),
        ],
      ),
    );

    return EditorScaffold(
      editor: widget,
      editorState: this,
      noteModified: _noteModified,
      editMode: widget.editMode,
      parentFolder: note.parent,
      body: editor,
      onUndoSelected: _undo,
      onRedoSelected: _redo,
      undoAllowed: null,
      redoAllowed: null,
    );
  }

  @override
  Note getNote() {
    note.body = _textController.text.trim();
    note.type = NoteType.Journal;
    return note;
  }

  void _noteTextChanged() {
    try {
      _applyHeuristics();
    } catch (e, stackTrace) {
      Log.e("EditorHeuristics: $e");
      logExceptionWarning(e, stackTrace);
    }

    if (_noteModified && !widget.editMode) {
      notifyListeners();
      return;
    }

    var newState = !(widget.editMode && _textController.text.trim().isEmpty);
    if (newState != _noteModified) {
      setState(() {
        _noteModified = newState;
      });
    }

    notifyListeners();
  }

  void _applyHeuristics() {
    var editState = TextEditorState.fromValue(_textController.value);
    var es = _heuristics.textChanged(editState);
    if (es != null) {
      _textController.value = es.toValue();
    }
  }

  @override
  Future<void> addImage(File file) async {
    await getNote().addImage(file);
    setState(() {
      _textController.text = note.body;
      _noteModified = true;
    });
  }

  @override
  bool get noteModified => _noteModified;

  Future<void> _undo() async {}

  Future<void> _redo() async {}
}
