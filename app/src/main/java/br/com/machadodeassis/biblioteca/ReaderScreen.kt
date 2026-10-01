package br.com.machadodeassis.biblioteca

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import br.com.machadodeassis.biblioteca.db.ChapterEntity
import br.com.machadodeassis.biblioteca.db.WorkEntity
import br.com.machadodeassis.biblioteca.tts.TtsPlaybackService
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val PARAGRAPHS_PER_PAGE = 4

private data class TtsUiState(
    val chapterId: String? = null,
    val index: Int = 0,
    val total: Int = 0,
    val playing: Boolean = false,
    val paused: Boolean = false,
    val voiceName: String? = null,
    val voices: List<String> = emptyList()
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ReaderScreen(
    work: WorkEntity, chapters: List<ChapterEntity>, chapter: ChapterEntity, paragraphs: List<String>,
    progress: Int, fontSize: Float, setFontSize: (Float) -> Unit,
    onToggleFav: () -> Unit, isFav: Boolean, onQuote: (Quote) -> Unit,
    onBack: () -> Unit, onChooseChapter: (ChapterEntity) -> Unit, onProgress: (Int) -> Unit,
    onReadingTime: (Long) -> Unit
) {
    val context = LocalContext.current
    var showToc by remember { mutableStateOf(false) }
    var size by remember(chapter.id) { mutableFloatStateOf(fontSize) }
    val pages = remember(paragraphs) { paragraphs.chunked(PARAGRAPHS_PER_PAGE) }
    val pager = rememberPagerState(pageCount = { pages.size.coerceAtLeast(1) })
    val scope = rememberCoroutineScope()
    var lastReported by remember(chapter.id) { mutableIntStateOf(-1) }
    var audio by remember(chapter.id) { mutableStateOf(TtsUiState()) }
    var followAudio by remember(chapter.id) { mutableStateOf(true) }
    var showVoicePicker by remember { mutableStateOf(false) }

    DisposableEffect(chapter.id) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != TtsPlaybackService.ACTION_STATE) return
                val stateChapter = intent.getStringExtra(TtsPlaybackService.EXTRA_STATE_CHAPTER_ID)
                if (stateChapter != null && stateChapter != chapter.id) return
                audio = TtsUiState(
                    chapterId = stateChapter,
                    index = intent.getIntExtra(TtsPlaybackService.EXTRA_STATE_INDEX, 0),
                    total = intent.getIntExtra(TtsPlaybackService.EXTRA_STATE_TOTAL, 0),
                    playing = intent.getBooleanExtra(TtsPlaybackService.EXTRA_STATE_PLAYING, false),
                    paused = intent.getBooleanExtra(TtsPlaybackService.EXTRA_STATE_PAUSED, false),
                    voiceName = intent.getStringExtra(TtsPlaybackService.EXTRA_VOICE_NAME),
                    voices = intent.getStringArrayListExtra(TtsPlaybackService.EXTRA_VOICES).orEmpty()
                )
            }
        }
        ContextCompat.registerReceiver(context, receiver, IntentFilter(TtsPlaybackService.ACTION_STATE), ContextCompat.RECEIVER_NOT_EXPORTED)
        onDispose { context.unregisterReceiver(receiver) }
    }

    LaunchedEffect(audio.index, audio.chapterId, pages.size) {
        if (followAudio && audio.chapterId == chapter.id && pages.isNotEmpty()) {
            val target = (audio.index / PARAGRAPHS_PER_PAGE).coerceIn(0, pages.lastIndex)
            if (target != pager.currentPage) pager.animateScrollToPage(target)
        }
    }

    LaunchedEffect(chapter.id, pages.size) {
        if (pages.isNotEmpty() && progress in 1..99) {
            pager.scrollToPage(((progress * pages.size) / 100).coerceIn(0, pages.lastIndex))
        }
    }
    LaunchedEffect(pager.currentPage, pages.size) {
        if (pages.isNotEmpty()) {
            val pct = ((pager.currentPage + 1) * 100 / pages.size).coerceIn(0, 100)
            if (pct != lastReported) { lastReported = pct; onProgress(pct) }
        }
    }
    LaunchedEffect(chapter.id) {
        while (true) { delay(15_000); onReadingTime(15_000) }
    }

    fun goToChapter(next: ChapterEntity?) {
        if (next != null) { onProgress(((pager.currentPage + 1) * 100 / pages.size.coerceAtLeast(1)).coerceIn(0, 100)); onChooseChapter(next) }
    }

    fun audioAction(action: String, extra: String? = null, startIndex: Int? = null) {
        context.startForegroundService(Intent(context, TtsPlaybackService::class.java).apply {
            this.action = action
            putExtra(TtsPlaybackService.EXTRA_CHAPTER_ID, chapter.id)
            if (extra != null) putExtra(TtsPlaybackService.EXTRA_VOICE_NAME, extra)
            if (startIndex != null) putExtra(TtsPlaybackService.EXTRA_START_INDEX, startIndex)
        })
    }

    Scaffold(topBar = {
        TopAppBar(
            title = { Column { Text(work.title, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 19.sp, maxLines = 1); Text(chapter.title, fontSize = 12.sp, color = gold) } },
            navigationIcon = { IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Voltar") } },
            actions = {
                IconButton({
                    if (Build.VERSION.SDK_INT >= 33 && context is Activity && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) context.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 700)
                     audioAction(TtsPlaybackService.ACTION_PLAY)
                 }) { Icon(Icons.Filled.VolumeUp, "Ouvir capítulo") }
                IconButton(onToggleFav) { Icon(if (isFav) Icons.Filled.Star else Icons.Filled.StarBorder, if (isFav) "Remover favorito" else "Adicionar favorito", tint = if (isFav) gold else Color.Unspecified) }
                IconButton({ showToc = true }) { Icon(Icons.Filled.Menu, "Capítulos") }
            }
        )
    }, bottomBar = {
        Surface(tonalElevation = 3.dp) {
            Column(Modifier.padding(horizontal = 12.dp, vertical = 6.dp)) {
                if (audio.chapterId == chapter.id && audio.total > 0) {
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                        Icon(Icons.Filled.VolumeUp, null, tint = gold, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Column(Modifier.weight(1f)) {
                            Text(if (audio.playing) "Narrando agora" else if (audio.paused) "Narração pausada" else "Narração concluída", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            Text("Parágrafo ${audio.index.coerceAtMost(audio.total - 1) + 1} de ${audio.total}", fontSize = 11.sp, color = Color(0xFF5a544a))
                        }
                        IconButton({ audioAction(if (audio.playing) TtsPlaybackService.ACTION_PAUSE else TtsPlaybackService.ACTION_RESUME) }) {
                            Icon(if (audio.playing) Icons.Filled.Pause else Icons.Filled.PlayArrow, if (audio.playing) "Pausar" else "Continuar")
                        }
                        IconButton({ audioAction(TtsPlaybackService.ACTION_STOP) }) { Icon(Icons.Filled.Stop, "Parar") }
                        IconButton({ showVoicePicker = true }) { Icon(Icons.Filled.Settings, "Configurar voz") }
                    }
                    LinearProgressIndicator(
                        progress = { ((audio.index + if (audio.playing) 1 else 0).toFloat() / audio.total).coerceIn(0f, 1f) },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                        IconButton({ audioAction(TtsPlaybackService.ACTION_PREVIOUS) }) { Icon(Icons.Filled.SkipPrevious, "Parágrafo anterior") }
                        IconButton({ audioAction(TtsPlaybackService.ACTION_NEXT) }) { Icon(Icons.Filled.SkipNext, "Próximo parágrafo") }
                        Spacer(Modifier.weight(1f))
                        FilterChip(selected = followAudio, onClick = { followAudio = !followAudio }, label = { Text("Acompanhar texto", fontSize = 11.sp) })
                    }
                }
                LinearProgressIndicator(progress = { if (pages.isEmpty()) 0f else (pager.currentPage + 1).toFloat() / pages.size }, modifier = Modifier.fillMaxWidth())
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                    Text(if (pages.isEmpty()) "0 / 0" else "Página ${pager.currentPage + 1} de ${pages.size}", fontSize = 12.sp)
                    Row {
                        TextButton({ if (pager.currentPage > 0) scope.launch { pager.animateScrollToPage(pager.currentPage - 1) } }) { Text("‹") }
                        TextButton({ if (pager.currentPage < pages.lastIndex) scope.launch { pager.animateScrollToPage(pager.currentPage + 1) } }) { Text("›") }
                        IconButton({ if (size > 15f) { size -= 1f; setFontSize(size) } }) { Text("A-", fontWeight = FontWeight.Bold) }
                        IconButton({ if (size < 28f) { size += 1f; setFontSize(size) } }) { Text("A+", fontWeight = FontWeight.Bold) }
                    }
                }
            }
        }
    }) { pad ->
        if (pages.isEmpty()) {
            Box(Modifier.padding(pad).fillMaxSize(), contentAlignment = Alignment.Center) { Text("Texto indisponível.") }
        } else {
            HorizontalPager(state = pager, modifier = Modifier.padding(pad).fillMaxSize(), contentPadding = PaddingValues(horizontal = 12.dp), pageSpacing = 12.dp) { page ->
                LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 10.dp, vertical = 18.dp)) {
                    item { Text(chapter.title, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = (size * 1.15f).sp, modifier = Modifier.padding(bottom = 12.dp)) }
                    items(pages[page], key = { it.hashCode() }) { text ->
                        val index = paragraphs.indexOf(text)
                        val isNarrated = audio.chapterId == chapter.id && audio.index == index && (audio.playing || audio.paused)
                        Text(text, fontFamily = FontFamily.Serif, fontSize = size.sp, lineHeight = (size * 1.55f).sp,
                            color = if (isNarrated) green else Color.Unspecified,
                            modifier = Modifier.fillMaxWidth()
                                .then(if (isNarrated) Modifier.padding(horizontal = 8.dp).background(Color(0xFFE7D6A9), RoundedCornerShape(8.dp)) else Modifier)
                                .padding(vertical = 9.dp)
                                .combinedClickable(onClick = { if (index >= 0) audioAction(TtsPlaybackService.ACTION_PLAY, startIndex = index) }, onLongClick = { onQuote(Quote("${chapter.id}:$index", work.id, work.title, chapter.title, index, text)) }))
                    }
                    item { Row(Modifier.fillMaxWidth().padding(top = 14.dp), horizontalArrangement = Arrangement.SpaceBetween) { TextButton({ goToChapter(prevChapter(chapters, chapter)) }) { Text("‹ Capítulo anterior") }; TextButton({ goToChapter(nextChapter(chapters, chapter)) }) { Text("Próximo capítulo ›") } } }
                }
            }
        }
    }

    if (showToc) AlertDialog(onDismissRequest = { showToc = false }, title = { Text("Capítulos • ${work.title}") }, text = { LazyColumn(Modifier.heightIn(max = 420.dp)) { items(chapters) { c -> Text(c.title, fontFamily = FontFamily.Serif, modifier = Modifier.fillMaxWidth().clickable { showToc = false; onChooseChapter(c) }.padding(10.dp)) } } }, confirmButton = { TextButton({ showToc = false }) { Text("Fechar") } })

    if (showVoicePicker) AlertDialog(
        onDismissRequest = { showVoicePicker = false },
        title = { Text("Voz da narração") },
        text = {
            Column {
                Text("Apenas vozes instaladas e disponíveis offline aparecem aqui.", fontSize = 12.sp, color = Color(0xFF5a544a))
                Spacer(Modifier.height(8.dp))
                if (audio.voices.isEmpty()) Text("Nenhuma voz alternativa foi informada pelo sistema.", fontSize = 13.sp)
                audio.voices.forEach { voice ->
                    TextButton({ audioAction(TtsPlaybackService.ACTION_SET_VOICE, voice); showVoicePicker = false }, modifier = Modifier.fillMaxWidth()) {
                        Text(if (voice == audio.voiceName) "✓ $voice" else voice, modifier = Modifier.fillMaxWidth())
                    }
                }
            }
        },
        confirmButton = { TextButton({ showVoicePicker = false }) { Text("Fechar") } }
    )
}

internal fun prevChapter(chapters: List<ChapterEntity>, chapter: ChapterEntity): ChapterEntity? = chapters.firstOrNull { it.order == chapter.order - 1 }
internal fun nextChapter(chapters: List<ChapterEntity>, chapter: ChapterEntity): ChapterEntity? = chapters.firstOrNull { it.order == chapter.order + 1 }
