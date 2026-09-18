# Machado Biblioteca - Estado do Projeto

Ultima atualizacao: 2026-09-10

## Objetivo

Publicar a versao iOS do aplicativo Biblioteca Machado de Assis no TestFlight e, depois, na App Store. O Android permanece no mesmo repositorio privado.

## Repositorio e site

- Repositorio: https://github.com/socialbot114-cell/machado-biblioteca
- Site publico: https://socialbot114-cell.github.io/machado-biblioteca-site/
- Working tree estava limpo antes desta documentacao.

## App Store Connect correto

- App correto: `Biblioteca Machado Assis`
- App ID correto: `6810760794`
- Bundle ID correto: `br.com.machadodeassis.biblioteca`
- App Store version ID: `208f4bd0-92bf-4c36-a87a-1b377e4c2446`
- Versao: `1.0`
- Estado: `PREPARE_FOR_SUBMISSION`
- Localizacao: `pt-BR`
- Localizacao ID: `50053ba3-a928-469d-932b-77cda8f7f1e4`

Existe uma segunda app incorreta, criada durante os testes:

- App ID: `6810766838`
- Bundle ID: `br.com.machadodeassis.biblioteca.ios`
- Nao usar para o envio final.

## Build iOS

- Workflow final aprovado: `34540409036`
- URL: https://github.com/socialbot114-cell/machado-biblioteca/actions/runs/34540409036
- Próxima atualização: `1.1 (22)` na app `6810760794`.
- Build ID: `12324d89-89e4-4025-9596-4c6de3b0b8da`
- O build foi associado a `App Store version 1.0`.
- O workflow gera archive assinado, exporta IPA e envia ao TestFlight.
- A versao atual e iPhone-only (`TARGETED_DEVICE_FAMILY=1`).

## Screenshots

Os tres screenshots corrigidos foram gerados em `1242 x 2688 px`:

- `refs/photo_4981107340111188027_y_1242x2688.jpg`
- `refs/photo_4981107340111188028_y_1242x2688.jpg`
- `refs/photo_4981107340111188029_y_1242x2688.jpg`

Foram enviados via App Store Connect API para a app correta, no conjunto `APP_IPHONE_65`:

- Screenshot set ID: `ec9a9089-0a01-4b47-bd1d-f6f2b6c8144a`
- Os tres estados estao `COMPLETE`.

## Assinatura Apple

- Team ID: `SRN7AW424S`
- API Key ID: `S96HVY2BYT`
- Issuer ID: `aa5a3fcd-f139-4b1f-beb2-47fd125148d9`
- Chave privada local: `/home/richard/Documentos/play store/AuthKey_S96HVY2BYT.p8`
- Certificado iOS Distribution ID: `69BADS22K3`
- Certificado valido ate 2027-09-10.
- Provisioning profile correto ID: `QM8XY8W7QZ`
- Provisioning UUID correto: `a2dc14b5-6c9b-43e2-aacd-5aafc341cc22`
- O profile correto foi criado para o bundle ID original.

Secrets configurados no GitHub:

- `APPLE_API_KEY_P8`
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_DISTRIBUTION_CERT`
- `APPLE_DISTRIBUTION_KEY`
- `APPLE_PROVISIONING_PROFILE`

Secrets obsoletos PKCS#12 foram removidos:

- `APPLE_DISTRIBUTION_CERT_P12`
- `APPLE_CERTIFICATE_PASSWORD`

## Arquivos importantes

- `.github/workflows/ios.yml`: build de simulador.
- `.github/workflows/ios-release.yml`: archive, exportacao e upload TestFlight.
- `iosApp/project.yml`: XcodeGen, bundle ID, recursos e assinatura.
- `iosApp/ExportOptions.plist`: exportacao App Store manual.
- `iosApp/Info.plist`: metadata declarada do app.
- `iosApp/Resources/Assets.xcassets/AppIcon.appiconset/`: icones do app.
- `iosApp/Resources/`: catalogo, textos, imagens e PrivacyInfo.

## Solucoes aplicadas no workflow

- Criacao de certificado iOS Distribution via App Store Connect API.
- Criacao de provisioning profile App Store via API.
- Keychain temporario no runner macOS.
- Importacao separada de certificado `.cer` e chave privada.
- Assinatura manual com `Apple Distribution`.
- Chave App Store Connect copiada para `~/private_keys/AuthKey_<KEY_ID>.p8` para o `altool`.
- Compilacao explicita do `Assets.xcassets` com `actool`.
- Script `Prepare App Store icon metadata` para garantir `CFBundleIconName`, `CFBundleIcons` e icon 120x120.
- Launch screen e orientacoes foram resolvidos para a configuracao iPhone-only.

## Pendencias antes do envio para revisao

1. Classificacao etaria ainda nao foi preenchida. O primeiro PATCH falhou porque `gambling` e `healthOrWellnessTopics` sao booleanos e `kidsAgeBand` aceita apenas faixas infantis.
2. Categoria primaria ainda nao foi definida. Categoria planejada: `BOOKS`.
3. A URL da politica de privacidade da localizacao `pt-BR` ainda aparece como nula na API; usar o site publico de privacidade.
4. Verificar export compliance e demais perguntas finais no App Store Connect.
5. Depois de corrigir essas pendencias, validar a versao e enviar para revisao.

## Atualização 1.1

- Paridade iOS com o produto Android: Home editorial, capas, busca integral, progresso, favoritos, citações, temas, leitor paginado e Universo Machado.
- Build planejado: `1.1 (22)`.
- O workflow de release executa XCTest, valida os recursos visuais no archive/IPA e envia automaticamente ao TestFlight.

## Conteudo do app

- Aplicativo offline.
- 30 obras integrais de Machado de Assis.
- Busca textual, leitor paginado, favoritos, citacoes, Universo Machado e narracao local em pt-BR.
- Sem login, anuncios, tracking ou sincronizacao.
- Fontes documentadas no app: Wikisource PT.

## Historico recente de commits

- `68711c1` Target original App Store Connect bundle
- `069f31a` Remove temporary bundle inspection step
- `33ae033` Add universal marketing icon variant
- `7db9382` Compile app icon asset catalog explicitly
- `0d1b9db` Add primary app icon plist structure
