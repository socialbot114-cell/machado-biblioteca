package br.com.machadodeassis.biblioteca

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import br.com.machadodeassis.biblioteca.data.LibraryRepository
import br.com.machadodeassis.biblioteca.db.SearchHit
import br.com.machadodeassis.biblioteca.db.ChapterProgressEntity
import br.com.machadodeassis.biblioteca.db.WorkEntity
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun HomeScreen(works: List<WorkEntity>, progress: List<ChapterProgressEntity>, open: (WorkEntity) -> Unit, query: String, setQuery: (String) -> Unit, onSearch: () -> Unit, onUniverse: () -> Unit, onMyLibrary: () -> Unit, onLibrary: () -> Unit) {
    val progressByWork = progress.groupBy { it.workId }.mapValues { (_, values) -> values.maxOfOrNull { it.progress } ?: 0 }
    val active = works.filter { (progressByWork[it.id] ?: 0) in 1..99 }.take(6)
    val categories = works.map { it.category }.filter { it.isNotBlank() }.distinct().take(4)
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp).verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(22.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            androidx.compose.foundation.Image(painterResource(R.drawable.logo_machado), "Machado de Assis", Modifier.size(48.dp), contentScale = ContentScale.Crop)
            Spacer(Modifier.width(12.dp))
            Column { Text("Machado de Assis", fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 29.sp, color = green); Text("Biblioteca, voz e universo", fontSize = 13.sp, color = Color(0xFF5a544a)) }
        }
        Spacer(Modifier.height(16.dp))
        HeroCarousel(works, open)
        Spacer(Modifier.height(18.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            HomeAction("Universo", "Personagens e histórias", onUniverse, Modifier.weight(1f))
            HomeAction("Minha biblioteca", "Seu percurso", onMyLibrary, Modifier.weight(1f))
        }
        Spacer(Modifier.height(20.dp))
        OutlinedTextField(query, setQuery, Modifier.fillMaxWidth(), placeholder = { Text("Buscar obra, personagem ou trecho…") }, leadingIcon = { Icon(Icons.Filled.Search, null) }, singleLine = true, trailingIcon = {
            IconButton(onSearch) { Icon(Icons.AutoMirrored.Filled.ArrowForward, "Ir para busca") }
        }, shape = RoundedCornerShape(16.dp))
        Spacer(Modifier.height(20.dp))
        if (active.isNotEmpty()) HomeBookSection("Continue lendo", active, open, showAll = onMyLibrary)
        SectionTitle("EXPLORE POR CATEGORIA")
        Text("${works.size} obras integrais para ler offline", fontSize = 13.sp, color = Color(0xFF5a544a))
        categories.forEach { category ->
            HomeBookSection(category, works.filter { it.category == category }.take(6), open, showAll = onLibrary)
        }
        Surface(Modifier.fillMaxWidth().padding(top = 16.dp).clickable { onLibrary() }, RoundedCornerShape(18.dp), color = green) {
            Row(Modifier.padding(horizontal = 18.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) { Text("Ver toda a biblioteca", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp); Text("Filtre por categoria e encontre sua próxima leitura", color = Color.White.copy(alpha = .8f), fontSize = 12.sp) }
                Icon(Icons.AutoMirrored.Filled.ArrowForward, "Abrir biblioteca", tint = Color.White)
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun HomeBookSection(title: String, works: List<WorkEntity>, open: (WorkEntity) -> Unit, showAll: () -> Unit) {
    if (works.isEmpty()) return
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 8.dp)) {
        Text(title, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 20.sp, modifier = Modifier.weight(1f))
        TextButton(showAll) { Text("Ver todos", color = green, fontSize = 12.sp) }
    }
    LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(bottom = 4.dp)) {
        items(works, key = { it.id }) { work ->
            Column(Modifier.width(126.dp).clickable { open(work) }) {
                Cover(work, Modifier.fillMaxWidth().height(176.dp))
                Spacer(Modifier.height(7.dp))
                Text(work.title, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 2)
                Text("${work.year} • ${work.category}", fontSize = 11.sp, color = Color(0xFF5a544a), maxLines = 1)
            }
        }
    }
}

@Composable
private fun HeroCarousel(works: List<WorkEntity>, open: (WorkEntity) -> Unit) {
    val heroes = listOf(
        Triple(R.drawable.hero_dom, "dom", "A dúvida que nunca termina"),
        Triple(R.drawable.hero_quincas, "quincas", "A filosofia dos vencedores"),
        Triple(R.drawable.hero_bras_cubas, "brascubas", "Memórias de além-túmulo"),
        Triple(R.drawable.hero_literatura, "", "Entre na literatura de Machado")
    )
    val pager = rememberPagerState(pageCount = { heroes.size })
    Column {
        HorizontalPager(state = pager, pageSpacing = 12.dp, contentPadding = PaddingValues(end = 28.dp), modifier = Modifier.fillMaxWidth()) { page ->
            val hero = heroes[page]
            Card(Modifier.fillMaxWidth().aspectRatio(16f / 9f).clickable { works.firstOrNull { it.id == hero.second }?.let(open) }, shape = RoundedCornerShape(22.dp)) {
                androidx.compose.foundation.Image(painterResource(hero.first), hero.third, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            }
        }
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(5.dp), modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            repeat(heroes.size) { i -> Box(Modifier.size(if (pager.currentPage == i) 20.dp else 6.dp, 6.dp).background(if (pager.currentPage == i) gold else Color(0xFFD0C6B5), RoundedCornerShape(3.dp))) }
        }
    }
}

@Composable
private fun HomeAction(title: String, subtitle: String, action: () -> Unit, modifier: Modifier) {
    Surface(modifier.clickable { action() }, RoundedCornerShape(16.dp), color = paper) {
        Column(Modifier.padding(14.dp)) { Text(title, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 17.sp, color = green); Text(subtitle, fontSize = 12.sp, color = Color(0xFF5a544a)) }
    }
}

@Composable
fun LibraryScreen(works: List<WorkEntity>, query: String, setQuery: (String) -> Unit, open: (WorkEntity) -> Unit) {
    var category by remember { mutableStateOf("Todos") }
    var visibleCount by remember { mutableIntStateOf(8) }
    val cats = listOf("Todos") + works.map { it.category }.distinct()
    val filtered = works.filter {
        (category == "Todos" || it.category == category) &&
            (query.isBlank() || it.title.contains(query, true) || it.description.contains(query, true) || it.characters.lowercase().contains(query.lowercase()))
    }
    LaunchedEffect(category, query) { visibleCount = 8 }
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp)) {
        Spacer(Modifier.height(20.dp))
        Text("Biblioteca", fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 28.sp)
        OutlinedTextField(query, setQuery, Modifier.fillMaxWidth().padding(top = 10.dp), placeholder = { Text("Filtrar obras") }, singleLine = true, shape = RoundedCornerShape(14.dp))
        Spacer(Modifier.height(8.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            items(cats) { c -> FilterChip(selected = category == c, onClick = { category = c }, label = { Text(c) }) }
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(bottom = 24.dp, top = 6.dp)) {
            items(filtered.take(visibleCount), key = { it.id }) { w ->
                Surface(Modifier.fillMaxWidth().clickable { open(w) }, RoundedCornerShape(16.dp), color = paper) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Cover(w, Modifier.size(50.dp, 72.dp))
                        Spacer(Modifier.width(12.dp))
                        Column { Text(w.title, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 18.sp); Text("${w.year} • ${w.category}"); Text(w.description, maxLines = 2, fontSize = 13.sp) }
                    }
                }
            }
            if (visibleCount < filtered.size) {
                item {
                    OutlinedButton({ visibleCount += 8 }, Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                        Text("Mostrar mais obras (${filtered.size - visibleCount} restantes)")
                    }
                }
            }
        }
    }
}

@Composable
fun SearchScreen(repo: LibraryRepository, open: (WorkEntity) -> Unit) {
    var q by remember { mutableStateOf("") }
    var hits by remember { mutableStateOf<List<SearchHit>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(q) {
        val term = q.trim()
        if (term.length >= 3) {
            searching = true
            delay(300)
            hits = repo.search(term)
            searching = false
        } else {
            hits = emptyList()
            searching = false
        }
    }
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp)) {
        Spacer(Modifier.height(20.dp))
        Text("Busca no texto integral", fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 26.sp)
        OutlinedTextField(q, { q = it }, Modifier.fillMaxWidth().padding(top = 10.dp), placeholder = { Text("Buscar palavra ou trecho…") }, singleLine = true, shape = RoundedCornerShape(14.dp))
        Spacer(Modifier.height(8.dp))
        when {
            q.trim().length < 3 -> Text("Digite ao menos 3 letras para pesquisar em toda a obra.", color = Color(0xFF5a544a))
            searching -> LinearProgressIndicator(Modifier.fillMaxWidth())
            hits.isEmpty() -> Text("Nenhum trecho encontrado.")
            else -> {
                Text("${hits.size} ocorrências")
                LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 24.dp)) {
                    items(hits) { h ->
                        Surface(Modifier.fillMaxWidth().clickable { scope.launch { repo.work(h.workId)?.let(open) } }, RoundedCornerShape(12.dp), color = paper) {
                            Column(Modifier.padding(12.dp)) {
                                Text(h.workTitle, fontWeight = FontWeight.Bold)
                                Text(h.chapterTitle, color = green, fontSize = 13.sp)
                                Text(h.snippet, fontSize = 14.sp, maxLines = 3)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun FavoritesScreen(works: List<WorkEntity>, favorites: List<String>, open: (WorkEntity) -> Unit) {
    val fav = works.filter { it.id in favorites }
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp)) {
        Spacer(Modifier.height(20.dp))
        Text("Favoritos", fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 28.sp)
        if (fav.isEmpty()) Text("Marque obras como favoritas na leitura.", color = Color(0xFF5a544a))
        LazyColumn { items(fav) { w -> Surface(Modifier.fillMaxWidth().padding(vertical = 4.dp).clickable { open(w) }, RoundedCornerShape(14.dp), color = paper) { Row(Modifier.padding(12.dp)) { Cover(w, Modifier.size(46.dp, 66.dp)); Spacer(Modifier.width(12.dp)); Column { Text(w.title, fontWeight = FontWeight.Bold, fontSize = 18.sp); Text(w.category) } } } } }
    }
}

@Composable
fun ProfileScreen(quotes: List<Quote>, favoriteCount: Int, theme: String, setTheme: (String) -> Unit, onRemoveQuote: (String) -> Unit) {
    Column(Modifier.fillMaxSize().padding(22.dp).verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(20.dp))
        Text("Seu perfil", fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 28.sp)
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) { StatCard("$favoriteCount", "favoritos"); StatCard("${quotes.size}", "citações"); StatCard("3", "temas") }
        Spacer(Modifier.height(24.dp))
        Text("Tema do leitor", fontWeight = FontWeight.Bold)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("Claro", "Sépia", "Escuro").forEach { t -> FilterChip(selected = theme == t, onClick = { setTheme(t) }, label = { Text(t) }) }
        }
        Spacer(Modifier.height(24.dp))
        Text("Citações", fontWeight = FontWeight.Bold)
        if (quotes.isEmpty()) {
            Text("Toque e segure um parágrafo no leitor para salvar uma citação.", fontSize = 13.sp, color = Color(0xFF5a544a))
        } else {
            quotes.forEach { quote ->
                Surface(Modifier.fillMaxWidth().padding(vertical = 5.dp), RoundedCornerShape(12.dp), color = paper) {
                    Column(Modifier.padding(12.dp)) {
                        Text("“${quote.text}”", fontFamily = FontFamily.Serif, fontSize = 15.sp, lineHeight = 21.sp)
                        Spacer(Modifier.height(6.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(quote.workTitle.ifBlank { "Origem não registrada" }, fontSize = 12.sp, color = green, fontWeight = FontWeight.Bold)
                                if (quote.chapterTitle.isNotBlank()) Text(quote.chapterTitle, fontSize = 11.sp, color = Color(0xFF5a544a))
                            }
                            IconButton({ onRemoveQuote(quote.id) }) {
                                Icon(Icons.Filled.Delete, "Remover citação", tint = Color(0xFF5a544a))
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(24.dp))
        Text("Sobre", fontWeight = FontWeight.Bold)
        Text("Obras integrais de Machado de Assis (1839–1908), em domínio público. Transcrições do Wikisource com adaptação ortográfica. App offline, sem anúncios.", fontSize = 14.sp, color = Color(0xFF5a544a))
        Spacer(Modifier.height(16.dp))
        Text("Licenças e fontes: ver tela de detalhe da obra e documentação do projeto.", fontSize = 12.sp, color = Color(0xFF5a544a))
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun StatCard(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) { Text(value, fontSize = 28.sp, fontWeight = FontWeight.Bold, color = green); Text(label, fontSize = 12.sp) }
}

@Composable
internal fun SectionTitle(title: String) {
    Text(title, color = gold, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 20.dp, bottom = 6.dp), letterSpacing = 1.sp)
}

val gold = Color(0xFFB39255)
val green = Color(0xFF173B32)
val paper = Color(0xFFEFE6D5)
val ivory = Color(0xFFF7F2E8)

@Composable
fun Cover(work: WorkEntity, modifier: Modifier) {
    val palette = when (kotlin.math.abs(work.id.hashCode()) % 4) {
        0 -> listOf(Color(0xFF173B32), Color(0xFF315E50))
        1 -> listOf(Color(0xFF3A2921), Color(0xFF704B37))
        2 -> listOf(Color(0xFF5B3C56), Color(0xFF8A5D78))
        else -> listOf(Color(0xFF8A642E), Color(0xFFB39255))
    }
    Box(modifier.background(Brush.verticalGradient(palette), RoundedCornerShape(8.dp)).padding(10.dp), contentAlignment = Alignment.BottomStart) {
        Column {
            Text("MACHADO DE ASSIS", color = Color(0xFFDCC79A), fontSize = 7.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            Spacer(Modifier.height(4.dp))
            Text(work.title, color = Color(0xFFF7F2E8), fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 16.sp, lineHeight = 18.sp, maxLines = 4)
            Spacer(Modifier.height(4.dp))
            Text(work.category.uppercase(), color = Color(0xFFF7F2E8).copy(alpha = .75f), fontSize = 8.sp, maxLines = 1)
        }
    }
}
