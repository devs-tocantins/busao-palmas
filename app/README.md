# App Busão Palmas

Flutter, Android e web. Hoje tem a primeira funcionalidade: escolher origem e destino e ver a rota
(ver [docs/UX_ROTA.md](../docs/UX_ROTA.md) e [docs/TELAS_E_PLANO.md](../docs/TELAS_E_PLANO.md)).

## Rodar

Ambiente: [docs/AMBIENTE.md](../docs/AMBIENTE.md).

```bash
cd app
flutter pub get
flutter run -d <id-do-celular>      # flutter devices lista os aparelhos
flutter run -d chrome               # navegador
flutter test                        # testes
flutter build apk --release         # APK em build/app/outputs/flutter-apk/
flutter build web --release         # site em build/web/
```

## De onde vêm os dados

- **Rota, busca de lugar e nome do ponto no mapa:** planejador (OTP) e geocodificador do Bus2, os mesmos do app SOU
  ([docs/API_MOBILIBUS.md](../docs/API_MOBILIBUS.md)). Aceitam chamada do navegador, então a web não precisa de proxy nesta fase.
- **Nome legível das paradas e cor das linhas:** `assets/data/paradas.json` e `assets/data/linhas.json`,
  cópias de `data/gerado/` (gerado por `tools/snapshot.mjs`, formato em [docs/DADOS.md](../docs/DADOS.md)).
  Para atualizar: `cd tools && node snapshot.mjs`, depois copie os dois arquivos para `app/assets/data/`.
- **Mapa:** estilos Positron (claro) e Dark do OpenFreeMap (gratuito, sem chave, dados do OpenStreetMap), desenhados no aparelho com `vector_map_tiles`.
  Uso gratuito com atribuição, pensado para volume baixo. Antes do lançamento público, trocar por tiles próprios
  (PMTiles do Tocantins ou OpenFreeMap) e conferir os termos: https://carto.com/basemaps.

## Link de rota (web)

`/?de=-10.2491,-48.3243&para=-10.1450,-48.3420&hora=08:00`

`de` e `para` são `lat,lng`; `hora` é opcional (`HH:mm`, relógio de Palmas; se já passou hoje, vale para amanhã).
Serve para compartilhar um trajeto e para testar de dia, fora do horário.

## Estrutura

```
lib/
  core/       config, tema (docs/DESIGN.md), formatação
  domain/     modelos (Lugar, Trecho, Opcao, GrupoOpcoes)
  data/       cliente do OTP e geocodificador, dados locais
  state/      estado do planejador (Riverpod)
  features/   planejar/ (mapa, busca, opções) e rota/ (detalhe)
  widgets/    etiqueta de linha, sequência da rota, mapa
test/         interpretação de uma resposta real do planejador, formatação e telas
```

Pacotes: `flutter_riverpod`, `go_router`, `dio`, `flutter_map`, `geolocator`, `google_fonts` (8.x: a 9 usa o `material_ui` e
não combina com o `flutter/material.dart` do Flutter 3.47), `flutter_animate`.

## Limites conhecidos

- Só "sair às" (não há "chegar às" na tela, embora o planejador aceite).
- Equivalentes são agrupados pelas paradas de embarque e desembarque; não há ainda tela de linha nem de parada.
- A localização pode ser negada; a origem então é escolhida na busca ou no mapa.
- Sem ônibus à noite, o planejador devolve só caminhada.
