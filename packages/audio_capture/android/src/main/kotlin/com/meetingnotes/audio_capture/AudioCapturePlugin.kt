package com.meetingnotes.audio_capture

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import kotlin.math.sqrt

class AudioCapturePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware {
    private lateinit var context: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var activityBinding: ActivityPluginBinding? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingStart: MethodChannel.Result? = null
    private var capture: AndroidAudioCapture? = null

    private val activityResultListener =
        io.flutter.plugin.common.PluginRegistry.ActivityResultListener { requestCode, resultCode, data ->
            if (requestCode != REQUEST_PROJECTION) return@ActivityResultListener false
            finishStart(if (resultCode == Activity.RESULT_OK) data else null)
            true
        }
    private val permissionResultListener =
        io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener { requestCode, _, grants ->
            if (requestCode != REQUEST_MICROPHONE) return@RequestPermissionsResultListener false
            if (grants.firstOrNull() == PackageManager.PERMISSION_GRANTED) requestProjection()
            else failStart("microphone_denied", "麦克风权限未开启。")
            true
        }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "audio_capture")
        events = EventChannel(binding.binaryMessenger, "audio_capture/events")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> beginStart(result)
            "pause" -> { capture?.pause(); result.success(null) }
            "resume" -> { capture?.resume(); result.success(null) }
            "stop" -> {
                try {
                    val path = capture?.stop() ?: throw IllegalStateException("当前没有正在进行的录音。")
                    capture = null
                    AudioCaptureForegroundService.stop(context)
                    result.success(path)
                } catch (error: Exception) {
                    result.error("stop_failed", error.localizedMessage, null)
                }
            }
            "permissionStatus" -> result.success(
                mapOf(
                    "systemAudioGranted" to false,
                    "microphoneGranted" to hasMicrophonePermission(),
                ),
            )
            "openPermissionSettings" -> {
                context.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.parse("package:${context.packageName}"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun beginStart(result: MethodChannel.Result) {
        if (capture != null || pendingStart != null) {
            result.error("already_running", "录音已经开始。", null)
            return
        }
        pendingStart = result
        if (!hasMicrophonePermission()) {
            val activity = activityBinding?.activity
            if (activity == null) {
                failStart("activity_unavailable", "当前无法显示麦克风授权页面。")
                return
            }
            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_MICROPHONE)
            return
        }
        requestProjection()
    }

    private fun requestProjection() {
        val activity = activityBinding?.activity
        if (activity == null) {
            finishStart(null)
            return
        }
        val manager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        activity.startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_PROJECTION)
    }

    private fun finishStart(projectionData: Intent?) {
        val result = pendingStart ?: return
        try {
            var projection: MediaProjection? = null
            if (projectionData != null) {
                try {
                    AudioCaptureForegroundService.start(context, true)
                    val manager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    projection = manager.getMediaProjection(Activity.RESULT_OK, projectionData)
                } catch (_: Exception) {
                    AudioCaptureForegroundService.stop(context)
                }
            }
            if (projection == null) AudioCaptureForegroundService.start(context, false)
            val recorder = AndroidAudioCapture(context) { type, value -> emit(type, value) }
            val systemAvailable = recorder.start(projection)
            capture = recorder
            pendingStart = null
            result.success(
                mapOf(
                    "systemAudioAvailable" to systemAvailable,
                    "microphoneAvailable" to true,
                    "degradationReason" to if (systemAvailable) null else "未授权系统声音，本次仅记录麦克风。",
                ),
            )
        } catch (error: Exception) {
            AudioCaptureForegroundService.stop(context)
            pendingStart = null
            result.error("start_failed", error.localizedMessage, null)
        }
    }

    private fun failStart(code: String, message: String) {
        pendingStart?.error(code, message, null)
        pendingStart = null
    }

    private fun hasMicrophonePermission() =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun emit(type: String, value: Any) {
        Handler(Looper.getMainLooper()).post { eventSink?.success(mapOf("type" to type, "value" to value)) }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
    override fun onCancel(arguments: Any?) { eventSink = null }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
        binding.addRequestPermissionsResultListener(permissionResultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding?.removeRequestPermissionsResultListener(permissionResultListener)
        activityBinding = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    private companion object {
        const val REQUEST_MICROPHONE = 9101
        const val REQUEST_PROJECTION = 9102
    }
}

private class AndroidAudioCapture(
    private val context: Context,
    private val onEvent: (String, Any) -> Unit,
) {
    private val sampleRate = 16_000
    private val microphoneQueue = ArrayBlockingQueue<ShortArray>(32)
    private val systemQueue = ArrayBlockingQueue<ShortArray>(32)
    private var microphone: AudioRecord? = null
    private var system: AudioRecord? = null
    private var projection: MediaProjection? = null
    private var output: RandomAccessFile? = null
    private var outputFile: File? = null
    @Volatile private var active = false
    @Volatile private var writing = false
    private var dataBytes = 0L
    private var microphoneThread: Thread? = null
    private var systemThread: Thread? = null
    private var writerThread: Thread? = null

    fun start(mediaProjection: MediaProjection?): Boolean {
        val minBytes = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ).coerceAtLeast(4096)
        microphone = AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            .setAudioFormat(format())
            .setBufferSizeInBytes(minBytes * 2)
            .build()
        check(microphone?.state == AudioRecord.STATE_INITIALIZED) { "麦克风初始化失败。" }

        projection = mediaProjection
        system = mediaProjection?.let {
            try {
                val configuration = AudioPlaybackCaptureConfiguration.Builder(it)
                    .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                    .addMatchingUsage(AudioAttributes.USAGE_GAME)
                    .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                    .build()
                AudioRecord.Builder()
                    .setAudioFormat(format())
                    .setBufferSizeInBytes(minBytes * 2)
                    .setAudioPlaybackCaptureConfig(configuration)
                    .build()
                    .takeIf { record -> record.state == AudioRecord.STATE_INITIALIZED }
            } catch (_: Exception) {
                null
            }
        }

        val directory = File(context.cacheDir, "EasyMeetingRecordings").apply { mkdirs() }
        val file = File(directory, "${java.util.UUID.randomUUID()}.wav")
        outputFile = file
        output = RandomAccessFile(file, "rw").also { writeHeader(it, 0) }
        active = true
        writing = true
        try {
            microphone?.startRecording()
        } catch (error: Exception) {
            cleanupFailedStart(file)
            throw IllegalStateException("麦克风启动失败，请检查输入设备。", error)
        }
        try {
            system?.startRecording()
        } catch (_: Exception) {
            system?.release()
            system = null
        }
        microphoneThread = captureLoop(microphone!!, microphoneQueue, "microphone")
        systemThread = system?.let { captureLoop(it, systemQueue, "system") }
        writerThread = thread(name = "EasyMeetingAudioWriter") { writerLoop() }
        onEvent("systemSilent", system == null)
        onEvent("microphoneSilent", false)
        return system != null
    }

    private fun cleanupFailedStart(file: File) {
        active = false
        writing = false
        microphone?.release()
        system?.release()
        projection?.stop()
        output?.close()
        file.delete()
        microphone = null
        system = null
        projection = null
        output = null
        outputFile = null
    }

    fun pause() { writing = false }
    fun resume() { if (active) writing = true }

    fun stop(): String {
        check(active) { "当前没有正在进行的录音。" }
        writing = false
        active = false
        try { microphone?.stop() } catch (_: IllegalStateException) { }
        try { system?.stop() } catch (_: IllegalStateException) { }
        microphoneThread?.join(1500)
        systemThread?.join(1500)
        writerThread?.join(1500)
        microphone?.release()
        system?.release()
        projection?.stop()
        val file = output ?: throw IllegalStateException("录音文件不可用。")
        writeHeader(file, dataBytes)
        file.close()
        val path = outputFile?.absolutePath ?: throw IllegalStateException("录音文件不可用。")
        microphone = null
        system = null
        projection = null
        output = null
        outputFile = null
        return path
    }

    private fun captureLoop(record: AudioRecord, queue: ArrayBlockingQueue<ShortArray>, source: String) =
        thread(name = "EasyMeeting-${source}Capture") {
            val buffer = ShortArray(2048)
            var silentFor = 0.0
            var wasSilent = false
            while (active) {
                val count = record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
                if (count <= 0) continue
                val chunk = buffer.copyOf(count)
                if (!queue.offer(chunk)) { queue.poll(); queue.offer(chunk) }
                val level = rms(chunk)
                onEvent("${source}Level", level)
                if (level < 0.005) {
                    silentFor += count.toDouble() / sampleRate
                    if (!wasSilent && silentFor >= 2.5) {
                        wasSilent = true
                        onEvent("${source}Silent", true)
                    }
                } else {
                    silentFor = 0.0
                    if (wasSilent) { wasSilent = false; onEvent("${source}Silent", false) }
                }
            }
        }

    private fun writerLoop() {
        while (active || microphoneQueue.isNotEmpty()) {
            val mic = microphoneQueue.poll(250, TimeUnit.MILLISECONDS) ?: continue
            val playback = systemQueue.poll()
            if (!writing) continue
            val mixed = ShortArray(mic.size)
            for (index in mic.indices) {
                val systemSample = if (playback != null && index < playback.size) playback[index].toInt() else 0
                mixed[index] = ((mic[index].toInt() + systemSample) / if (playback == null) 1 else 2)
                    .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                    .toShort()
            }
            val bytes = ByteBuffer.allocate(mixed.size * 2).order(ByteOrder.LITTLE_ENDIAN)
            mixed.forEach { sample -> bytes.putShort(sample) }
            output?.write(bytes.array())
            dataBytes += bytes.capacity()
        }
    }

    private fun format() = AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setSampleRate(sampleRate)
        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
        .build()

    private fun rms(samples: ShortArray): Double {
        if (samples.isEmpty()) return 0.0
        var sum = 0.0
        samples.forEach { sample ->
            val normalized = sample / 32768.0
            sum += normalized * normalized
        }
        return sqrt(sum / samples.size).coerceIn(0.0, 1.0)
    }

    private fun writeHeader(file: RandomAccessFile, length: Long) {
        file.seek(0)
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray())
        header.putInt((36 + length).toInt())
        header.put("WAVEfmt ".toByteArray())
        header.putInt(16)
        header.putShort(1.toShort())
        header.putShort(1.toShort())
        header.putInt(sampleRate)
        header.putInt(sampleRate * 2)
        header.putShort(2.toShort())
        header.putShort(16.toShort())
        header.put("data".toByteArray())
        header.putInt(length.toInt())
        file.write(header.array())
        if (length > 0) file.seek(44 + length)
    }
}

class AudioCaptureForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "会议录音", NotificationManager.IMPORTANCE_LOW),
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = notification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            if (intent?.getBooleanExtra(EXTRA_SYSTEM_AUDIO, false) == true) {
                types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            }
            startForeground(NOTIFICATION_ID, notification, types)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    private fun notification(): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("会议纪要正在录音")
            .setContentText("轻触返回应用；结束录音后将自动生成纪要。")
            .setContentIntent(pending)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "easy_meeting_recording"
        private const val NOTIFICATION_ID = 7310
        private const val EXTRA_SYSTEM_AUDIO = "system_audio"

        fun start(context: Context, systemAudio: Boolean) {
            val intent = Intent(context, AudioCaptureForegroundService::class.java)
                .putExtra(EXTRA_SYSTEM_AUDIO, systemAudio)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AudioCaptureForegroundService::class.java))
        }
    }
}
