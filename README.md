# uaiou — app mobile

App **Flutter** do **UaiOu**, marketplace que conecta estabelecimentos a entregadores para redirecionamento de entregas.

Este repositório é só o app mobile, que atende **dois papéis**: **estabelecimento** (publica pedidos, acompanha entregas, paga fretes) e **entregador** (fica disponível, aceita corridas, executa a entrega, recebe). O painel **admin** não existe no app — fica no frontend web. A API vive no repositório `uaiou-backend`, e a documentação de negócio, os casos de uso e o contrato da API vivem no vault de documentação do projeto (`system-documentation/`, em repositório à parte).

## Stack

Flutter 3.41 · Dart 3.11 · Provider · Dio · flutter_secure_storage · flutter_map + MapLibre · Firebase Cloud Messaging. Decisão e descobertas registradas em [docs/decisions/0001-stack.md](docs/decisions/0001-stack.md).

## Estrutura

```
uaiou_app/
├── lib/
│   ├── main.dart        # providers, rotas, guarda de sessão
│   ├── core/            # lógica sem UI, um módulo por domínio
│   │   ├── rede/        # ClienteApi (único ponto de HTTP), erros, idempotência
│   │   ├── sessao/      # login, refresh de token, cofre seguro
│   │   ├── pedidos/     # vitrine, publicação, detalhe, contraoferta
│   │   ├── entregas/    # retirada, código de entrega, contestável
│   │   └── ...          # presenca, rotas, mapa, ganhos, pagar, avaliacoes,
│   │                    # gamificacao, notificacoes, perfil, cadastro, tema
│   ├── screens/         # telas e widgets
│   └── others/          # modelos/estado legados (pedido, estado por papel)
├── test/
│   ├── core/            # testes de unidade da camada core
│   └── telas/           # testes de widget
└── android/ ios/ web/ windows/ linux/ macos/
.github/workflows/android-apk.yml   # CI: analyze + test + APK de produção
```

## Arquitetura em uma linha

**tela → controlador (`ChangeNotifier` via Provider) → repositório → `ClienteApi`**. Nenhuma tela faz requisição direta. As regras que valem para o código todo:

- **Dinheiro nunca é `double`.** O contrato manda valores como string decimal (`"6.00"`); o app representa com `Dinheiro`, que guarda centavos em `int`.
- **Botão que a API não ofereceu não é renderizado.** Toda resposta traz `_links` (HATEOAS) com as transições permitidas para aquele papel naquele estado — o app não reimplementa geofence, prazo ou elegibilidade.
- **Toda tela trata quatro estados**: `Carregando`, `Pronto`, `Vazio` e `Falhou` (tipo selado `Carregavel`, com `switch` exaustivo).
- **Credencial só em armazenamento cifrado** (Keychain / Keystore via `flutter_secure_storage`). `SharedPreferences` é proibido para sessão.
- **Ações que não podem duplicar** (aceitar corrida, publicar pedido) mandam `Idempotency-Key`.
- **Trocar de conta limpa o estado**: toda loja dependente de sessão é zerada no logout.

## Rodar localmente

Pré-requisitos: Flutter 3.41+ e o **backend rodando** (ver README do `uaiou-backend` — `docker compose up --build` sobe a API em `http://localhost:8080/api/v1`).

```bash
cd uaiou_app
flutter pub get
```

A URL da API vem de `--dart-define=UAIOU_API_BASE_URL=...`. Sem ela, o app usa o padrão local de cada plataforma ([lib/core/config/ambiente.dart](uaiou_app/lib/core/config/ambiente.dart)):

| Onde roda | Comando | URL padrão |
|---|---|---|
| Emulador Android | `flutter run` | `http://10.0.2.2:8080/api/v1` |
| Chrome | `flutter run -d chrome --release --web-port=5500` | `http://localhost:8080/api/v1` |
| Windows desktop | `flutter run -d windows` | `http://localhost:8080/api/v1` |
| Aparelho físico (mesma rede) | `flutter run --dart-define=UAIOU_API_BASE_URL=http://<IP-da-máquina>:8080/api/v1` | — |

Pegadinhas conhecidas:

- **Chrome:** a porta precisa estar na lista de CORS do backend (`CORS_ALLOWED_ORIGINS`, padrão `5500`, `8123` e `3000`). Fora dela, o navegador bloqueia a resposta e o app mostra **"sem conexão com o servidor"**, mesmo com a API no ar.
- **Chrome em modo debug** pode travar no handshake do DWDS; `--release` contorna.
- **Aparelho físico:** além do `dart-define`, o IP da máquina precisa entrar em [network_security_config.xml](uaiou_app/android/app/src/main/res/xml/network_security_config.xml) — o Android bloqueia HTTP sem TLS para qualquer host fora da lista.
- **Windows:** builds com plugins exigem o **Modo de Desenvolvedor** ligado (suporte a symlinks).
- **Usuários do seed** do backend têm hash de senha *placeholder* e não conseguem logar — nem o admin. Para testar, insira usuários com hash bcrypt real e status `ativo` direto no Postgres (admin não tem autorregistro). Contas criadas pelo cadastro do app nascem `pendente` e só operam depois de aprovadas no painel admin.

## Testes e análise estática

```bash
cd uaiou_app
flutter analyze   # lints do flutter_lints
flutter test      # unidade (test/core) + widget (test/telas)
```

A suíte roda na VM do Dart, **não no navegador** — bug que só aparece no Flutter Web (ver ADR, item sobre `1 << 32`) passa despercebido nela.

## Build de distribuição

O workflow [android-apk.yml](.github/workflows/android-apk.yml) roda a cada push em `main` que toque `uaiou_app/`: `flutter analyze` → `flutter test` → `flutter build apk --release` apontando para o backend de produção (Railway, HTTPS). O APK sai como artefato do workflow (`uaiou-apk`).

Build de release **recusa HTTP** fora da rede local: se a URL não for HTTPS e não for host local, o app abre numa tela de bloqueio em vez da interface normal.

## Documentação

- [Decisões técnicas do app](docs/decisions/)
- Contrato da API, casos de uso e backlog de tasks (`A-01`…`A-14`, `RF-Axx`): vault `system-documentation/`, em repositório à parte. Os comentários do código citam esses identificadores.

## Autores

- **Luis Pedro Costa** — criou as telas do app: login, cadastro, principais, pedidos, entregas, atividades e perfis do estabelecimento e do entregador.
- **João ([jvpereira07](https://github.com/jvpereira07))** — integrou o backend: camada `core`, adaptação das telas à API e telas novas da integração (detalhe e publicação de pedido, entrega em andamento, ganhos, notificações, avaliações), testes, CI, notificações push, mapas e rotas.
