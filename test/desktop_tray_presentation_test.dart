import 'package:easy_meeting/app_services/meeting_session_controller.dart';
import 'package:easy_meeting/desktop/desktop_tray_presentation.dart';
import 'package:easy_meeting/domain/models/processing_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tray stop action describes ending recording only', () {
    expect(DesktopTrayPresentation.stopRecordingLabel, '结束录音');
    expect(DesktopTrayPresentation.stopRecordingLabel, isNot('结束并生成纪要'));
  });

  test('tray maps recording, paused, and recorded states truthfully', () {
    expect(
      DesktopTrayPresentation.sessionState(
        MeetingSessionPhase.recording,
        elapsed: const Duration(minutes: 2, seconds: 3),
      ),
      '正在录音 02:03',
    );
    expect(
      DesktopTrayPresentation.sessionState(
        MeetingSessionPhase.paused,
        elapsed: const Duration(seconds: 9),
      ),
      '录音已暂停 00:09',
    );
    expect(
      DesktopTrayPresentation.sessionState(MeetingSessionPhase.completed),
      DesktopTrayPresentation.recordingSavedLabel,
    );
    expect(
      DesktopTrayPresentation.sessionState(MeetingSessionPhase.completed),
      isNot('纪要已生成'),
    );
  });

  test('only an explicit processing stage uses note-generation copy', () {
    expect(
      DesktopTrayPresentation.sessionState(
        MeetingSessionPhase.processing,
        processingStage: ProcessingStage.summarizing,
      ),
      '正在生成纪要',
    );
    expect(
      DesktopTrayPresentation.sessionState(MeetingSessionPhase.completed),
      isNot('正在生成纪要'),
    );
  });
}
