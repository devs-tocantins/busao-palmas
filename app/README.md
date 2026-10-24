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
- **Paradas, linhas, horários, percursos e busca:** `assets/data/` (`paradas`, `linhas`, `horarios`, `trajetos`, `busca`),
  cópias de `data/gerado/` (gerado por `tools/snapshot.mjs`, formato em [docs/DADOS.md](../docs/DADOS.md)).
  Para atualizar: `cd tools && node snapshot.mjs`, depois copie esses cinco arquivos (e `data/apelidos.json`) para `app/assets/data/`.
- **Mapa:** estilos Positron (claro) e Dark do OpenFreeMap (gratuito, sem chave, dados do OpenStreetMap), desenhados no aparelho
  com `vector_map_tiles`. Retiramos do estilo os nomes de ruas pequenas (`lib/state/mapa.dart`). Atribuição sempre visível.
  O OpenFreeMap vive de doações: se o app crescer, apoiar ou trocar por tiles próprios (PMTiles do Tocantins).
  O CARTO foi testado e descartado: passou a exigir chave.

## Site publicado

**https://devs-tocantins.github.io/busao-palmas/** (GitHub Pages, HTTPS).

Publicado pela Action [`.github/workflows/site.yml`](../.github/workflows/site.yml):

- **Pull request com mudança em `app/`:** roda `flutter analyze`, `flutter test` e `flutter build web`. Não publica.
- **Merge na `main`** (ou "Run workflow" na aba Actions): faz o mesmo e publica. O site atualiza em poucos minutos.

O Flutter da Action é fixado em 3.47.8; ao subir de versão, mude lá e em [docs/AMBIENTE.md](../docs/AMBIENTE.md).
Configuração única do repositório: Settings → Pages → Source = **GitHub Actions**.

Para gerar o site na sua máquina, sem publicar: `flutter build web --release --base-href /busao-palmas/` (saída em `build/web/`).

## Link de parada (web)

`/parada?lat=-10.17792034&lng=-48.3340683&nome=Estação+Apinajé`

`lat` e `lng` são o ponto da parada; `nome` é o título da tela. Mostra as próximas passagens de cada linha.
Na web só aparece horário programado: a API que traz o ônibus ao vivo (`departures`) não libera o navegador. No Android
as duas fontes são usadas, e a linha com ônibus real mostra "Ao vivo". Para ter o ao vivo na web é preciso o proxy
descrito em [docs/ARQUITETURA.md](../docs/ARQUITETURA.md).

## Link de rota (web)

`/?de=-10.2491,-48.3243&para=-10.1450,-48.3420&hora=08:00`

`de` e `para` são `lat,lng`; `hora` é opcional (`HH:mm`, relógio de Palmas; se já passou hoje, vale para amanhã).
Serve para compartilhar um trajeto e para testar de dia, fora do horário.

## Navegação

Abas embaixo: **Início** (busca de destino, Casa e Trabalho, paradas a até 600 m com a próxima saída, recentes), **Mapa** (rota), **Linhas** e **Mais** (sobre).
A tela da linha (`/linha/620`) mostra o percurso, os horários por tipo de dia e as paradas; tocar numa linha na tela da parada abre ela. Na tela da linha, as paradas aparecem no mapa e a mais perto de você fica destacada, com a próxima passagem dali (precisa da localização).
A estrela na tela da linha e da parada guarda o favorito no aparelho (chave `salvos_v1`); eles aparecem no Início, em "Favoritos".
Tudo vem do snapshot embutido (sem rede); só o ônibus ao vivo vem da parada.
Escolher um destino no Início leva ao Mapa. "Perto de você" usa as paradas do snapshot, sem rede, e só pede horários das 3 mais próximas.

## Mapa e horário

Com zoom 15 ou mais o mapa mostra as paradas (até 400 na área visível); tocar abre a tela da parada. O chip de horário oferece "Sair agora", "Sair às" e "Chegar às" (o planejador recebe `arriveBy`).

## Ônibus ao vivo

O mapa mostra todos os ônibus rodando como miniaturas que giram e deslizam a cada 20 s (`CamadaOnibus`); tocar abre a linha, o atraso e o último sinal. Na tela da linha só os dela; na rota, os das linhas da viagem, e o ônibus que a pessoa vai pegar fica com um círculo amarelo. O cartão "Chega em N min" no detalhe da rota usa a passagem mais perto do horário previsto e, havendo GPS, mostra a distância do ônibus até a parada.

A API não libera o navegador, então **na web não há ônibus ao vivo** (o chip avisa). A consulta só roda enquanto a tela está à vista. Detalhes em [docs/API_MOBILIBUS.md](../docs/API_MOBILIBUS.md).

## Busca de lugar

Responde a cada letra com o que está no aparelho (`lib/data/busca_local.dart`: lugares de `busca.json`, paradas, linhas e apelidos como "uft"), sem acento e sem internet. A partir de 3 letras o geocodificador do Bus2 completa o que faltar. O texto vai ao geocodificador sem acento: ele erra com acento (verificado em 2026-10-25: `rodoviária` devolve rodovias).

## Computador

A partir de 900 px de largura: menu na lateral, painel de rota ao lado do mapa, botões de zoom e de localização, e as demais telas numa coluna de 640 px. Abaixo disso, o layout de celular.

## Estrutura

```
lib/
  core/       config, tema (docs/DESIGN.md), formatação
  domain/     modelos (Lugar, Trecho, Opcao, GrupoOpcoes)
  data/       cliente do OTP e geocodificador, dados locais
  state/      estado do planejador (Riverpod)
  features/   inicio/ (entrada), linha/ (lista e detalhe), planejar/ (mapa, busca, opções), rota/ (detalhe), parada/, mais/
  widgets/    etiqueta de linha, sequência da rota, mapa
test/         interpretação de uma resposta real do planejador, formatação e telas
```

Pacotes: `flutter_riverpod`, `go_router`, `dio`, `flutter_map`, `geolocator`, `google_fonts` (8.x: a 9 usa o `material_ui` e
não combina com o `flutter/material.dart` do Flutter 3.47), `flutter_animate`.

## Limites conhecidos

- Só "sair às" (não há "chegar às" na tela, embora o planejador aceite).
- Equivalentes são agrupados pelas paradas de embarque e desembarque. 
- A localização pode ser negada; a origem então é escolhida na busca ou no mapa.
- Sem ônibus à noite, o planejador devolve só caminhada.
