package com.meetingnotes.audio_capture

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class AudioCapturePluginTest {
    @Test
    fun unknownMethodIsNotImplemented() {
        val plugin = AudioCapturePlugin()
        val call = MethodCall("unknown", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)
        Mockito.verify(mockResult).notImplemented()
    }
}
