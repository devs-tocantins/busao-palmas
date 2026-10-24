# Arquitetura

App gratuito, sem login, para ver ônibus de Palmas-TO, feito pela comunidade Devs Tocantins.
Independente da SOU Palmas e da Mobilibus. Primeira funcionalidade: [rota de A para B](UX_ROTA.md).
Contrato da API de dados: [API_MOBILIBUS.md](API_MOBILIBUS.md).

## Decisões

| Tema | Decisão |
|---|---|
| Código | Flutter, um projeto para Android e Web (PWA). iOS depois. |
| Nome | Busão Palmas, provisório. Texto exibido em um só lugar (`app_config`). |
| `applicationId` | `br.com.devstocantins.busaopalmas` |
| Dados lentos (linhas, paradas, horários, traçados) | Snapshot nosso, gerado 1x por dia. |
| Dados ao vivo (previsão, ônibus, rota) | Chamados na hora, pelo proxy. |
| Web | Exige proxy: a API de dados não envia CORS. |
| Hospedagem | Em aberto. |
| Licença | MIT. |
| Contato com SOU Palmas / prefeitura | Só depois de ter uma demonstração. |

## Fatos que moldam o desenho (verificado 2026-10-23/24)

- `routes`, `stops`, `departures` etc. não enviam `Access-Control-Allow-Origin`: o navegador bloqueia chamada direta.
  O OTP (planejador) e os tiles do OSM enviam.
- `routes`/`timetable` vêm com `max-age=3600`; `departures` com `max-age=30`.
- Palmas é `project_id=635`. O `apiUri` dele é `https://cdn.bus2.studio/api/` (Cloudflare). Atualização ao vivo sugerida: 20 s.
- Não existe documentação oficial da API.
- Os tiles públicos do OSM não permitem uso pesado.

## Peças

```
 Android / Web (Flutter)
        │
        ├── snapshot (JSON comprimido, na CDN) ── linhas, paradas, horários, traçados
        │
        └── proxy de borda ─┬── API Mobilibus (Palmas)
                            └── OTP de Palmas
```

```
busao-palmas/
  app/    Flutter
  edge/   proxy (TypeScript)
  tools/  gerador do snapshot e teste de contrato
  docs/
```

### Snapshot
GitHub Action diária. Baixa linhas, horários, `trip-details` (sem a parte `vehicles`) e varre os tiles de Palmas em `stops`.
Guarda `version` e `generatedAt`; o app mostra a data.

**Nome das paradas** (`tools/paradas.mjs`). A API devolve só o código em 83% das paradas. Ordem de prioridade do nome:
correção da comunidade (`data/paradas_nomes.json`) → nome da API, limpo → OpenStreetMap (`Rua × rua que cruza`, ou `Rua · perto de <lugar>`,
ou `Região <bairro>`) → `Parada <código>`. Resultado em 2026-10-24: 1064 paradas; 178 pelo nome da API, 729 pelo OSM, 157 só código (15%).
As quadras de Palmas quase não têm nome no OSM, por isso usamos rua e cruzamento.

**Busca de lugares** (`tools/indice-busca.mjs`). Índice próprio, sem servidor: 2962 itens (2113 ruas, 34 bairros, ~800 lugares),
207 KB (41 KB comprimido). A busca roda no aparelho: todos os termos digitados devem iniciar uma palavra do nome, sem acento e sem
diferença entre "Av." e "Avenida". Siglas e nomes populares vêm de `data/apelidos.json`. Nominatim e Photon foram descartados:
dependem de servidor público com limite de uso.

### Proxy
Cloudflare Worker, ou equivalente (hospedagem em aberto). Regras:
- aceita só os caminhos que usamos e só `project_id=635`;
- libera CORS para os nossos domínios;
- cache de borda: 1 h em linhas e horários, 15–30 s em `departures` e `vehicles`; se a origem cair, devolve o último bom;
- limite por IP; `User-Agent` identificável com contato.
O Android usa o proxy e cai para a API direta se ele falhar.

### App
Camadas: `presentation` → `application` (Riverpod) → `domain` (modelos puros) → `data` (cliente HTTP, cache, snapshot).

| Necessidade | Pacote |
|---|---|
| Estado | `flutter_riverpod` |
| Rotas e URLs na web | `go_router` |
| HTTP | `dio` |
| Modelos | `freezed`, `json_serializable` |
| Cache offline (Android e Web) | `hive_ce` |
| Mapa | `flutter_map`, `latlong2` |
| Localização | `geolocator` |
| Alertas | `flutter_local_notifications` |
| Favoritos e ajustes | `shared_preferences` |

O `shape` dos trajetos vem em *Encoded Polyline*; decodificador próprio.

### Mapas
Desenvolvimento: tiles do OSM com `User-Agent` e atribuição. Produção: tiles próprios (PMTiles do Tocantins) ou provedor com plano
gratuito; decidir antes de abrir ao público. Atribuição "© OpenStreetMap contributors" sempre visível.

## Limites por plataforma

- **Web:** primeira carga mais pesada; localização exige HTTPS; notificação em segundo plano não é confiável (pior no iPhone).
  Alertas completos só no Android.
- **Android:** permissão de localização em uso, pedida na hora. Distribuição: Play Store e APK no GitHub Releases.

## Privacidade

Sem conta. Localização e favoritos ficam no aparelho. Sem analytics de terceiros.

## Riscos

| Risco | Resposta |
|---|---|
| A API muda ou bloqueia | Proxy único; teste de contrato diário contra a API real que abre issue se o formato mudar; snapshot de reserva. |
| Termos de uso da Mobilibus | Ler antes de publicar. Não verificado. |
| Muito acesso se o app viralizar | Cache de borda e limite no proxy; só dado ao vivo passa. |
| Custo dos tiles | Ver Mapas. |

## Ordem de construção

1. Estrutura do repositório, tema, proxy mínimo, snapshot de linhas.
2. Rota de A para B (ver `UX_ROTA.md`), com mapa e paradas.
3. Tela da parada com previsão ao vivo.
4. Linhas e viagem com ônibus ao vivo.
5. Favoritos, alertas e offline.
