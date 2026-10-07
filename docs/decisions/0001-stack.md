# 0001 — Stack e arquitetura do app mobile

**Status:** aceita
**Data:** 2026-08-22 (decisão, junto da criação da camada `core`) · registrada em 2026-10-07

## Contexto

O app começou como protótipo de interface (abril a agosto de 2026): telas do estabelecimento e do entregador desenhadas sobre listas em memória e serviços *singleton* em `lib/others/`, sem backend. Com a API do `uaiou-backend` disponível, a task A-01 introduziu a camada `lib/core/` para integrar o app ao contrato real — e, com ela, as decisões abaixo. Esta ADR registra o que foi escolhido e as consequências descobertas ao implementar; não reabre a escolha.

O repositório é **independente** do backend e do frontend web (cada stack com seu próprio ciclo de CI — ver ADR 0001 do `uaiou-backend`).

## Decisão

| Camada | Escolha | Versão |
|---|---|---|
| Framework / linguagem | Flutter (canal stable) / Dart | 3.41 / 3.11 |
| Estado | Provider + `ChangeNotifier` | 6.1.5 |
| HTTP | Dio, atrás de um único `ClienteApi` | 5.11 |
| Sessão | flutter_secure_storage (Keychain / Keystore) | 11.0 |
| Mapas 2D | flutter_map, tiles Geoapify servidos pelo backend | 8.3 |
| Mapa de rota | MapLibre GL (vetorial, inclinado) | ^0.27 |
| Localização | geolocator | 14.0 |
| Push | firebase_messaging + flutter_local_notifications | ^16.7 / ^22.3 |
| Fotos | image_picker | 1.2 |
| Datas e números | intl, locale `pt_BR` | 0.20 |
| Lints | flutter_lints | 6.0 |
| Build Android | AGP / Gradle / Kotlin / JDK | 8.11.1 / 8.14 / 2.2.20 / 17+ (CI usa 21) |
| CI | GitHub Actions — analyze, test, APK de produção | — |
| Arquitetura | `tela → controlador → repositório → ClienteApi`, agrupado por módulo de domínio em `lib/core/` | — |

## Alternativas consideradas

- **`SharedPreferences` para guardar a sessão** — rejeitado. É texto puro, legível em aparelho comprometido ou com backup ligado. A credencial vai para `flutter_secure_storage`, com `first_unlock_this_device` no iOS (não sai em backup para outro aparelho).
- **`double` para valores monetários** — proibido. `0.1 + 0.2` não dá `0.3` em ponto flutuante, e o extrato de ganhos é dinheiro que um entregador cobra de um estabelecimento. O tipo `Dinheiro` guarda centavos em `int` e recusa, na borda, string que não represente centavos exatos.
- **Pacote `uuid` para a chave de idempotência** — não adicionado. Um único uso não justificava a dependência; a chave junta o instante em microssegundos com um sufixo aleatório, suficiente para não colidir entre toques do mesmo aparelho.
- **URL da API em constante no código** — rejeitado. Vem de `--dart-define`, para o mesmo código virar build local ou de produção.
- **Sentry / Crashlytics** — fora do escopo. Há só o ponto de extensão (`_registrarFalhaNaoTratada` em `main.dart`), que registra tipo e pilha **sem** payload, token ou entrada do usuário.
- **Push no Flutter Web** — fora. Exige service worker + chave VAPID e não entrega com o navegador fechado; no web, a caixa de notificações do app segue sendo a fonte, e o push de navegador é responsabilidade do painel web.
- **Transições animadas entre telas** — removidas. O app é usado com pressa, de moto parada ou na porta do cliente; meio segundo de deslize por toque é espera sem informação.

## Consequências e descobertas empíricas

1. **`1 << 32` vale `0` no Flutter Web.** Em Dart compilado para JavaScript o deslocamento é de 32 bits; na VM nativa vale 4294967296. `Random().nextInt(0)` lança `RangeError`, e como o erro estourava antes de qualquer requisição, publicar pedido e aceitar corrida falhavam **só no navegador**. A suíte de testes não pegou porque roda na VM. Resolvido com teto `1 << 30` em `idempotencia.dart`.
2. **`DateFormat` com `pt_BR` exige `initializeDateFormatting('pt_BR')` antes do primeiro uso.** Sem isso, a primeira data formatada lança em runtime — e nenhum teste de unidade pega, porque o erro é de dados de locale, não de lógica.
3. **O emulador Android não enxerga o `localhost` da máquina.** Para ele, a máquina anfitriã é `10.0.2.2` — por isso o padrão local muda por plataforma em `ambiente.dart`.
4. **Android 9+ bloqueia HTTP sem TLS por padrão.** Sem exceção em `network_security_config.xml`, toda requisição ao backend local morre antes de sair do aparelho e o app parece "não fazer nada". A exceção cobre só hosts locais, e precisa ser host a host — o Android não aceita faixa de IP por curinga.
5. **Dois hífens seguidos num comentário XML derrubam o build release.** O XML proíbe `--` dentro de comentário e o `aapt2` falha ao compilar o recurso, quebrando o APK inteiro.
6. **`flutter_secure_storage` no web cai em `localStorage`**, que qualquer script da página lê. Aceitável só em desenvolvimento.
7. **CORS decide se o app web conversa com a API.** A porta do `flutter run -d chrome` precisa estar em `CORS_ALLOWED_ORIGINS` do backend; fora dela, o navegador bloqueia a resposta e o Dio relata **falha de conexão** — o app mostra "sem conexão com o servidor" com a API no ar e saudável. Observado ao rodar na porta 5050; resolvido usando a 5500, já liberada.
8. **Modo debug no navegador pode travar no handshake do DWDS.** `flutter run --release -d chrome` contorna, e é como o app é testado no navegador nesta fase. Por isso a checagem de HTTPS em release abre exceção para host local.
9. **No Windows, build com plugins exige o Modo de Desenvolvedor** (suporte a symlinks) — o `flutter pub get` avisa, mas o alvo web roda sem ele.

## Decisões de implementação tomadas dentro deste escopo

- **`ClienteApi` é o único ponto de HTTP.** Concentra URL base, tempo limite, injeção de token e tradução de erro; todo método lança `ErroApi`, nunca `DioException`. Um `401` dispara **uma** tentativa de renovar a sessão e repetir — exceto em `/auth/*`, onde renovar reentraria na própria renovação. Um `426` acende uma tela de atualização obrigatória por cima de qualquer outra.
- **A raiz do app reage à sessão.** `_Raiz` escolhe a tela inicial a partir de `ControladorSessao.fase`; nenhuma tela chama `Navigator` depois de login ou logout.
- **Guarda de rota.** Rotas de operação (`_rotasDeOperacao` em `main.dart`) exigem sessão ativa; sem ela, vão para o login, e conta que não pode operar (pendente, suspensa) vai para a tela de status. Admin não tem área no app.
- **`Carregavel` selado** (`Carregando`, `Pronto`, `Vazio`, `Falhou`): esquecer um caso vira erro de compilação, não tela em branco. Recarga não volta para `Carregando`, para a lista não piscar a cada puxão.
- **`_links` decide o que aparece.** Botão que o servidor não ofereceu para aquele estado e papel não é renderizado.
- **Logout limpa as lojas.** Todo `ChangeNotifierProxyProvider` dependente da sessão chama `limpar()` quando ela deixa de estar autenticada — dado de um usuário não sobrevive à troca de conta.
- **Release recusa HTTP fora da rede local.** Build de distribuição apontando para texto puro abre numa tela de bloqueio, nunca na interface normal.
- **Tiles do mapa passam pelo backend**, que guarda a chave do Geoapify e faz cache; o app guarda estilo e camada pelo dia (UTC) e cai no OpenStreetMap se o recurso estiver fora.
- **Rota fica fora do controlador de entrega**: é dado estável e não deve pegar carona no polling de 10 s da execução.

## Pontos em aberto

- **`pubspec.lock` não é versionado** (está no `.gitignore`). O CI resolve as dependências a cada build, então duas builds do mesmo commit podem sair com versões diferentes. Para apps, a recomendação do Dart é versionar o lock.
- **`lib/others/`** ainda guarda código em uso — o modelo `Pedido` e o estado por papel (`EstadoEntregador`, `EstadoEstabelecimento`). O nome é herança do protótipo; candidato a migrar para `lib/core/`.
- **O backend ainda não emite `426`.** A tela de atualização obrigatória existe e está testada, mas só acende quando o servidor passar a exigir versão mínima.
- **Falha não tratada só vai para o log local** — sem relatório remoto de crash.

## Verificação

O workflow `android-apk.yml` roda `flutter analyze` e `flutter test` a cada push em `main` que toque `uaiou_app/`, antes de gerar o APK — build com lint ou teste quebrado não produz artefato. A suíte cobre a camada `core` (`test/core/`, testes de unidade) e os fluxos de cadastro e publicação de pedido (`test/telas/`, testes de widget).

Verificação local em 2026-10-07 (Flutter 3.41.4, Windows): `flutter analyze` — **nenhum problema** — e `flutter test` — **246/246 testes verdes**. A execução expõe um aviso do `flutter_map` sobre a política de uso dos servidores públicos de tiles do OpenStreetMap, usados pelo app só como reserva quando os tiles do backend falham; revisar antes de escalar o uso em produção.
