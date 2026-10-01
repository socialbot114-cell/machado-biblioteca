# Machado de Assis | Biblioteca

Aplicativo Android nativo offline-first em Kotlin + Jetpack Compose. `applicationId`: `br.com.machadodeassis.biblioteca`. Target SDK: API 36. Versão 1.4.0 (versionCode 9).

## O que há nesta versão

- **30 obras integrais** (10 romances + 20 contos) para leitura offline, geradas do Wikisource PT e embutidas como assets gzipados (`.json.gzdata`, extensão preservada no AAB).
- Armazenamento local em **Room** com **FTS4** para busca integral por palavra ou trecho, em todas as obras.
- Leitor com **LazyColumn** (virtualização de parágrafos), progresso por capítulo persistido em Room (scroll, troca de capítulo e saída da tela), retomada automática da posição, navegação entre capítulos (anterior/próximo/índice), tamanho de fonte ajustável e três temas (Claro, Sépia, Escuro).
- **Citações estruturadas** (toque longo no parágrafo) com origem: obra, capítulo e índice do parágrafo; migração automática de citações antigas (v1.1) que guardavam apenas texto.
- Importação inicial transacional e idempotente (Seeder), com validação de cada asset contra os metadados do índice, retomada se interrompida e **estados visíveis de progresso/erro com retry**.
- Busca integral com **debounce de 300 ms** e indicador de progresso.
- Orientação livre (sem trava de retrato); estado de navegação preservado em rotação via `configChanges`.
- Home editorial com carrossel hero, Universo Machado com personagens e linha do tempo, e Minha Biblioteca com progresso, favoritos, citações e tempo acumulado.
- Leitura em voz local por foreground service, com notificação e continuidade em segundo plano.

## Build local

```bash
./gradlew testDebugUnitTest lintDebug assembleDebug bundleRelease
jarsigner -verify -verbose -certs app/build/outputs/bundle/release/app-release.aab
```

O release usa `machado-release.keystore`, criado exclusivamente para este projeto. `keystore.properties` e a chave real são ignorados pelo Git e nunca devem ser publicados. Para configurar uma máquina nova, copie `keystore.properties.example` para `keystore.properties` e preencha os valores localmente.

Consulte `SECURITY.md` para o fluxo de rotação de credenciais. Builds (`.aab`, `.apk`, `.ipa`) ficam fora do repositório e devem ser distribuídos por releases ou artefatos do CI.

## Conteúdo

Pipeline reproduzível:

```bash
python3 tools/fetch_machado.py      # baixa do Wikisource e gera app/src/main/assets/texts/*.json.gzdata
python3 tools/validate_assets.py    # valida integridade (exatamente 30 obras) e gera RELATORIO_CONTEUDO.md
python3 tools/refix.py <id>...      # refaz obras específicas e atualiza o índice
```

Fontes, licença (CC BY-SA das transcrições) e política de modernização ortográfica: ver `DATA_SOURCES.md`. Relatório com contagens por obra: `RELATORIO_CONTEUDO.md`.

## Arquitetura

- `db/` — entidades Room (`works`, `chapters`, `paragraphs`, `paragraphs_fts`, `chapter_progress`), DAO único, Seeder transacional com validação por obra.
- `data/LibraryRepository.kt` — única camada de acesso da UI (obras, capítulos, parágrafos, busca FTS com escape de operadores, progresso).
- `MainActivity.kt` — máquina de estados de seed (`Loading/Progress/Ready/Error` com retry) e navegação por telas (home, biblioteca, busca, favoritos, perfil, detalhe, leitor).
- `Preferences.kt` — tema, fonte, favoritos e citações estruturadas em DataStore (com migração do formato antigo).
- `shared/` — núcleo KMP inicial com modelos de obras, capítulos, parágrafos, progresso, citações e personagens; a integração gradual com as implementações de plataforma começa nesta base.
- `iosApp/` — shell SwiftUI reproduzível por XcodeGen, com as quatro abas do produto e narração local inicial.

## iOS

O bundle identifier planejado é `br.com.machadodeassis.biblioteca`. O projeto Xcode é gerado em macOS a partir de `iosApp/project.yml`. O build local Linux não valida Xcode, SwiftUI ou assinatura Apple; o workflow manual `.github/workflows/ios.yml` faz essa validação em um runner macOS quando o XcodeGen e as credenciais estiverem disponíveis.

## Testes

- `CatalogTest` — integridade dos assets (estrutura, contagens, ausência de HTML).
- `DatabaseTest` (Robolectric) — Room end-to-end: inserção, ordem de parágrafos, busca FTS, progresso, reimportação sem duplicatas.
- `PreferencesTest` (Robolectric) — favoritos, citações estruturadas (roundtrip, dedup), tema e fonte.

## Escopo e limitações

O catálogo cobre as principais obras em prosa do autor; não é a obra completa (não inclui poesia, teatro, crítica e crônicas). A tela de cada obra indica a fonte. A busca indexa parágrafos com limite de 40 resultados por consulta.

“Narração local” usa TextToSpeech do Android e depende de uma voz `pt-BR` instalada. Vozes que exigem rede são recusadas para preservar o funcionamento offline do conteúdo.

O banco Room usa `fallbackToDestructiveMigration()` enquanto o schema está em v1 e ainda sem base instalada de usuários; antes de qualquer atualização publicada com mudança de schema, migrar para migrations explícitas.

### Verificação

```bash
./gradlew testDebugUnitTest lintDebug assembleDebug bundleRelease
jarsigner -verify -verbose -certs app/build/outputs/bundle/release/app-release.aab
```

O release assinado usa o `machado-release.keystore` existente. Senhas ficam somente em `keystore.properties`; não são documentadas, impressas ou alteradas.
