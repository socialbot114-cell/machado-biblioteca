package br.com.machadodeassis.biblioteca

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import br.com.machadodeassis.biblioteca.data.LibraryRepository
import br.com.machadodeassis.biblioteca.db.ChapterEntity
import br.com.machadodeassis.biblioteca.db.WorkEntity
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(state: Bundle?) { installSplashScreen(); super.onCreate(state); setContent { MachadoApp() } }
}

private sealed interface SeedState {
    data object Loading : SeedState
    data class Progress(val current: Int, val total: Int) : SeedState
    data object Ready : SeedState
    data class Error(val message: String) : SeedState
}

@Composable
fun MachadoApp() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val repo = remember { LibraryRepository(context) }
    val prefs = remember { Preferences(context) }

    var seed by remember { mutableStateOf<SeedState>(SeedState.Loading) }
    var screen by remember { mutableStateOf("home") }
    var query by remember { mutableStateOf("") }
    var theme by remember { mutableStateOf("Claro") }
    var fontSize by remember { mutableFloatStateOf(20f) }
    var seedTick by remember { mutableIntStateOf(0) }

    var works by remember { mutableStateOf<List<WorkEntity>>(emptyList()) }
    var chapters by remember { mutableStateOf<List<ChapterEntity>>(emptyList()) }
    var selWork by remember { mutableStateOf<WorkEntity?>(null) }
    var selChapter by remember { mutableStateOf<ChapterEntity?>(null) }
    var paragraphs by remember { mutableStateOf<List<String>>(emptyList()) }
    var chapterProgress by remember { mutableIntStateOf(0) }

    var favorites by remember { mutableStateOf<List<String>>(emptyList()) }
    var quotes by remember { mutableStateOf<List<Quote>>(emptyList()) }
    var characterFavorites by remember { mutableStateOf<List<String>>(emptyList()) }
    var allProgress by remember { mutableStateOf<List<br.com.machadodeassis.biblioteca.db.ChapterProgressEntity>>(emptyList()) }
    var selectedCharacter by remember { mutableStateOf<CharacterCard?>(null) }

    LaunchedEffect(seedTick) {
        seed = if (works.isNotEmpty()) SeedState.Ready else SeedState.Loading
        try {
            favorites = prefs.favorites()
            quotes = prefs.quotes()
            characterFavorites = prefs.favoriteCharacters()
            theme = prefs.theme()
            fontSize = prefs.fontSize()
            val ok = repo.seedIfNeeded { cur, total ->
                seed = SeedState.Progress(cur, total)
            }
            works = repo.worksOnce()
            allProgress = repo.allProgress()
            seed = if (ok && works.isNotEmpty()) SeedState.Ready else SeedState.Error("Importação incompleta: verifique a instalação do app.")
        } catch (e: Exception) {
            seed = SeedState.Error(e.message ?: "Falha desconhecida na importação.")
        }
    }

    val colors = when (theme) {
        "Escuro" -> darkColorScheme(background = Color(0xFF171717), surface = Color(0xFF3A2921), onBackground = Color(0xFFF7F2E8), onSurface = Color(0xFFF7F2E8), primary = Color(0xFFB39255))
        "Sépia" -> lightColorScheme(background = Color(0xFFEFE6D5), surface = Color(0xFFF7F2E8), onBackground = Color(0xFF3A2921), onSurface = Color(0xFF3A2921), primary = Color(0xFF173B32))
        else -> lightColorScheme(background = Color(0xFFF7F2E8), surface = Color(0xFFF7F2E8), onBackground = Color(0xFF171717), onSurface = Color(0xFF171717), primary = Color(0xFF173B32))
    }

    fun openWork(work: WorkEntity) {
        selWork = work
        screen = "detail"
    }

    fun openChapter(chapter: ChapterEntity) {
        scope.launch {
            val work = selWork ?: repo.work(chapter.workId) ?: return@launch
            if (chapters.isEmpty() || chapters.firstOrNull()?.workId != work.id) {
                chapters = repo.chapters(work.id)
            }
            selWork = work
            selChapter = chapter
            paragraphs = repo.paragraphs(chapter.id)
            chapterProgress = repo.progress(chapter.id)?.progress ?: 0
            screen = "reader"
        }
    }

    fun saveProgress(pct: Int) {
        val chapter = selChapter ?: return
        val work = selWork ?: return
        scope.launch { repo.saveProgress(chapter, work.id, pct); allProgress = repo.allProgress() }
    }

    MaterialTheme(colorScheme = colors) {
        Surface(Modifier.fillMaxSize()) {
            when (val s = seed) {
                is SeedState.Error -> Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Não foi possível preparar a biblioteca.", fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                        Spacer(Modifier.height(8.dp))
                        Text(s.message, fontSize = 14.sp, color = Color(0xFF5a544a))
                        Spacer(Modifier.height(16.dp))
                        Button({ seedTick++ }) { Text("Tentar novamente") }
                    }
                }
                is SeedState.Progress -> Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Preparando biblioteca…", fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                        Spacer(Modifier.height(12.dp))
                        LinearProgressIndicator(progress = if (s.total > 0) s.current.toFloat() / s.total else 0f, modifier = Modifier.fillMaxWidth())
                        Spacer(Modifier.height(8.dp))
                        Text("${s.current} de ${s.total} obras", fontSize = 13.sp, color = Color(0xFF5a544a))
                    }
                }
                SeedState.Loading -> Box(Modifier.fillMaxSize().background(Color(0xFFF7F2E8)))
                SeedState.Ready -> Scaffold(bottomBar = {
                    if (screen in listOf("home", "library", "universe", "my-library")) {
                        NavigationBar {
                            listOf(
                                "home" to (Icons.Filled.Home to "Início"),
                                "library" to (Icons.AutoMirrored.Filled.MenuBook to "Biblioteca"),
                                "universe" to (Icons.Filled.AutoAwesome to "Universo"),
                                "my-library" to (Icons.Filled.Bookmark to "Minha biblioteca")
                            ).forEach { (route, item) ->
                                NavigationBarItem(
                                    selected = screen == route,
                                    onClick = { screen = route },
                                    icon = { Icon(item.first, item.second) },
                                    label = { Text(item.second, fontSize = 11.sp) }
                                )
                            }
                        }
                    }
                }) { pad ->
                    Box(Modifier.padding(pad)) {
                        when (screen) {
                            "home" -> HomeScreen(works, allProgress, ::openWork, query, { query = it }, onSearch = { screen = "search" }, onUniverse = { screen = "universe" }, onMyLibrary = { screen = "my-library" }, onLibrary = { screen = "library" })
                            "library" -> LibraryScreen(works, query, { query = it }, ::openWork)
                            "search" -> SearchScreen(repo, ::openWork)
                            "universe" -> UniverseScreen { selectedCharacter = it; screen = "character" }
                            "my-library" -> MyLibraryScreen(works, allProgress, favorites, quotes, ::openWork, { screen = "universe" })
                            "character" -> selectedCharacter?.let { c -> CharacterDetailScreen(c, c.id in characterFavorites, { scope.launch { prefs.toggleCharacterFavorite(c.id); characterFavorites = prefs.favoriteCharacters() } }, { screen = "universe" }, { id -> works.firstOrNull { it.id == id }?.let(::openWork) }) }
                            "detail" -> selWork?.let { w ->
                                DetailScreen(w, ::openChapter, repo,
                                    onToggleFav = { scope.launch { prefs.toggleFavorite(w.id); favorites = prefs.favorites() } },
                                    isFav = favorites.contains(w.id),
                                    onBack = { screen = "home" })
                            }
                            "reader" -> {
                                val w = selWork
                                val ch = selChapter
                                if (w == null || ch == null) {
                                    Text("Selecione um capítulo.")
                                } else {
                                    ReaderScreen(w, chapters, ch, paragraphs, chapterProgress, fontSize,
                                        setFontSize = { f -> fontSize = f; scope.launch { prefs.setFontSize(f) } },
                                        onToggleFav = { scope.launch { prefs.toggleFavorite(w.id); favorites = prefs.favorites() } },
                                        isFav = favorites.contains(w.id),
                                        onQuote = { q -> scope.launch { prefs.addQuote(q); quotes = prefs.quotes() } },
                                        onBack = { screen = "detail" },
                                        onChooseChapter = { c -> openChapter(c) },
                                        onProgress = { pct -> saveProgress(pct) },
                                        onReadingTime = { ms -> scope.launch { repo.addActivity(ch, w.id, readingMs = ms); allProgress = repo.allProgress() } })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
