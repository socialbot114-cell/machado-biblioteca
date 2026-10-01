package br.com.machadodeassis.biblioteca.tts

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.NotificationCompat
import br.com.machadodeassis.biblioteca.MainActivity
import br.com.machadodeassis.biblioteca.R
import br.com.machadodeassis.biblioteca.db.MachadoDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.Locale

class TtsPlaybackService : Service(), TextToSpeech.OnInitListener {
    companion object {
        const val ACTION_PLAY = "machado.tts.PLAY"
        const val ACTION_RESUME = "machado.tts.RESUME"
        const val ACTION_PAUSE = "machado.tts.PAUSE"
        const val ACTION_STOP = "machado.tts.STOP"
        const val ACTION_NEXT = "machado.tts.NEXT"
        const val ACTION_PREVIOUS = "machado.tts.PREVIOUS"
        const val ACTION_SET_VOICE = "machado.tts.SET_VOICE"
        const val ACTION_STATE = "machado.tts.STATE"
        const val EXTRA_CHAPTER_ID = "chapter_id"
        const val EXTRA_START_INDEX = "start_index"
        const val EXTRA_VOICE_NAME = "voice_name"
        const val EXTRA_STATE_CHAPTER_ID = "state_chapter_id"
        const val EXTRA_STATE_INDEX = "state_index"
        const val EXTRA_STATE_TOTAL = "state_total"
        const val EXTRA_STATE_PLAYING = "state_playing"
        const val EXTRA_STATE_PAUSED = "state_paused"
        const val EXTRA_VOICES = "voices"
        private const val CHANNEL = "machado_reading"
        private const val NOTIFICATION = 71
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var tts: TextToSpeech? = null
    private var paragraphs = emptyList<String>()
    private var index = 0
    private var ready = false
    private var pendingChapter: String? = null
    private var pendingIndex = 0
    private var currentChapterId: String? = null
    private var currentWorkId: String? = null
    private var startedAt = 0L
    private var paused = false
    private var currentVoiceName: String? = null
    private val preferences by lazy { getSharedPreferences("tts", MODE_PRIVATE) }

    override fun onCreate() {
        super.onCreate()
        createChannel()
        tts = TextToSpeech(this, this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> loadAndPlay(intent.getStringExtra(EXTRA_CHAPTER_ID), intent.getIntExtra(EXTRA_START_INDEX, 0))
            ACTION_RESUME -> { paused = false; speakCurrent() }
            ACTION_PAUSE -> pausePlayback()
            ACTION_NEXT -> moveParagraph(1)
            ACTION_PREVIOUS -> moveParagraph(-1)
            ACTION_SET_VOICE -> setVoice(intent.getStringExtra(EXTRA_VOICE_NAME))
            ACTION_STOP -> { tts?.stop(); paused = false; broadcastState(false, false); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
        }
        return START_NOT_STICKY
    }

    private fun loadAndPlay(chapterId: String?, startIndex: Int = 0) {
        if (chapterId == null) return
        if (!ready) { pendingChapter = chapterId; pendingIndex = startIndex; return }
        scope.launch(Dispatchers.IO) {
            val dao = MachadoDatabase.get(this@TtsPlaybackService).dao()
            val chapter = dao.chapter(chapterId)
            val loaded = dao.paragraphs(chapterId)
            launch(Dispatchers.Main) {
                currentChapterId = chapterId
                currentWorkId = chapter?.workId
                paragraphs = loaded
                index = startIndex.coerceIn(0, (loaded.size - 1).coerceAtLeast(0))
                paused = false
                if (paragraphs.isNotEmpty()) speakCurrent()
            }
        }
    }

    private fun speakCurrent() {
        val text = paragraphs.getOrNull(index) ?: run { stopSelf(); return }
        paused = false
        startForeground(NOTIFICATION, notification("Ouvindo capítulo • ${index + 1}/${paragraphs.size}"))
        startedAt = android.os.SystemClock.elapsedRealtime()
        broadcastState(true, false)
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "paragraph_$index")
    }

    private fun pausePlayback() {
        tts?.stop()
        paused = true
        saveProgress()
        broadcastState(false, true)
        startForeground(NOTIFICATION, notification("Pausado • parágrafo ${index + 1}/${paragraphs.size}"))
    }

    private fun moveParagraph(offset: Int) {
        if (paragraphs.isEmpty()) return
        tts?.stop()
        index = (index + offset).coerceIn(0, paragraphs.lastIndex)
        paused = false
        speakCurrent()
    }

    private fun setVoice(name: String?) {
        val voice = tts?.voices?.firstOrNull { it.name == name && it.locale.language == "pt" && !it.isNetworkConnectionRequired }
            ?: return
        tts?.voice = voice
        currentVoiceName = voice.name
        preferences.edit().putString("voice_name", voice.name).apply()
        if (paragraphs.isNotEmpty() && !paused) speakCurrent()
        broadcastState(!paused, paused)
    }

    private fun saveProgress() {
        val chapterId = currentChapterId ?: return
        val workId = currentWorkId ?: return
        val percent = if (paragraphs.isEmpty()) 0 else ((index * 100) / paragraphs.size).coerceIn(0, 99)
        scope.launch(Dispatchers.IO) {
            MachadoDatabase.get(this@TtsPlaybackService).dao().let { dao ->
                if (dao.updatePosition(chapterId, percent, index, System.currentTimeMillis(), false, null) == 0) {
                    dao.upsertProgress(br.com.machadodeassis.biblioteca.db.ChapterProgressEntity(chapterId, workId, percent, System.currentTimeMillis(), index))
                }
            }
        }
    }

    private fun broadcastState(playing: Boolean, isPaused: Boolean) {
        sendBroadcast(Intent(ACTION_STATE).setPackage(packageName).apply {
            putExtra(EXTRA_STATE_CHAPTER_ID, currentChapterId)
            putExtra(EXTRA_STATE_INDEX, index)
            putExtra(EXTRA_STATE_TOTAL, paragraphs.size)
            putExtra(EXTRA_STATE_PLAYING, playing)
            putExtra(EXTRA_STATE_PAUSED, isPaused)
            putExtra(EXTRA_VOICE_NAME, currentVoiceName)
            putExtra(EXTRA_VOICES, availableVoiceNames())
        })
    }

    private fun availableVoiceNames(): ArrayList<String> = ArrayList(
        tts?.voices.orEmpty()
            .filter { it.locale.language == "pt" && it.locale.country in listOf("BR", "PT", "") && !it.isNetworkConnectionRequired }
            .map { it.name }
            .distinct()
    )

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) return
        val locale = Locale("pt", "BR")
        val offlineVoice = tts?.voices?.firstOrNull { it.locale.language == locale.language && !it.isNetworkConnectionRequired }
        if (offlineVoice == null) { stopSelf(); return }
        tts?.voice = offlineVoice
        val savedVoice = preferences.getString("voice_name", null)
        tts?.voices?.firstOrNull { it.name == savedVoice && it.locale.language == "pt" && !it.isNetworkConnectionRequired }?.let {
            tts?.voice = it
        }
        currentVoiceName = tts?.voice?.name
        ready = true
        broadcastState(false, false)
        pendingChapter?.let { pendingChapter = null; loadAndPlay(it, pendingIndex) }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit
            override fun onDone(utteranceId: String?) {
                val elapsed = android.os.SystemClock.elapsedRealtime() - startedAt
                val chapterId = currentChapterId
                val workId = currentWorkId
                if (chapterId != null && workId != null) scope.launch(Dispatchers.IO) { MachadoDatabase.get(this@TtsPlaybackService).dao().addActivity(chapterId, 0, elapsed, System.currentTimeMillis()) }
                index++
                if (index < paragraphs.size) {
                    saveProgress()
                    speakCurrent()
                } else {
                    saveProgress()
                    broadcastState(false, false)
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            }
            override fun onError(utteranceId: String?) { if (!paused) { broadcastState(false, false); stopSelf() } }
        })
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        scope.coroutineContext.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL, "Leitura em voz", NotificationManager.IMPORTANCE_LOW))
    }

    private fun notification(text: String) = NotificationCompat.Builder(this, CHANNEL)
        .setSmallIcon(R.drawable.ic_machado)
        .setContentTitle("Machado de Assis")
        .setContentText(text)
        .setContentIntent(PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        .addAction(0, if (paused) "Continuar" else "Pausar", servicePending(if (paused) ACTION_RESUME else ACTION_PAUSE))
        .addAction(0, "Parar", servicePending(ACTION_STOP))
        .addAction(0, "Próximo", servicePending(ACTION_NEXT))
        .setOngoing(true)
        .build()

    private fun servicePending(action: String): PendingIntent = PendingIntent.getService(this, action.hashCode(), Intent(this, TtsPlaybackService::class.java).setAction(action), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
}
