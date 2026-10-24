# Formato dos dados

Contrato entre `tools/` (que gera) e `app/` e `edge/` (que leem). Quem mudar um lado muda este documento e `tools/validar.mjs`.

```bash
cd tools
node snapshot.mjs   # baixa da API e do OpenStreetMap e escreve data/gerado/ (cerca de 2 min)
node validar.mjs    # confere o contrato; sai com erro se algo quebrou
```

`data/gerado/` não vai para o git. Em produção uma GitHub Action gera e publica esses arquivos 1x por dia (ainda não criada).

## Arquivos (2026-10-24)

| Arquivo | Conteúdo | Tamanho | Comprimido |
|---|---|---|---|
| `meta.json` | versão, data e totais | 0,3 KB | 0,3 KB |
| `linhas.json` | 47 linhas e seus sentidos | 9,7 KB | 1,3 KB |
| `horarios.json` | saídas por linha, sentido e tipo de dia (3.851) | 94 KB | 12 KB |
| `trajetos.json` | 106 viagens: traçado e sequência de paradas | 171 KB | 58 KB |
| `paradas.json` | 1.210 paradas com nome legível | 146 KB | 24 KB |
| `busca.json` | 2.962 itens para a busca de lugares | 207 KB | 41 KB |

## Convenções

- Coordenadas: graus decimais, WGS84 (`lat` negativa, `lng` negativa).
- Hora: texto `"HH:MM"`, horário local de Palmas (UTC−3), 24 h. Não há saídas depois de 23:59.
- Dias: lista de 7 booleanos na ordem **[dom, seg, ter, qua, qui, sex, sáb]**. Hoje só existem três padrões:
  dias úteis `[0,1,1,1,1,1,0]`, sábados `[0,0,0,0,0,0,1]`, domingos `[1,0,0,0,0,0,0]`.
- Identificadores são os da API (números). Não os reutilize entre cidades.
- `shape`: *Encoded Polyline* (precisão 5, mesmo formato do Google). Pode ser `null`.
- Cores: `#RRGGBB`.

## `meta.json`

```json
{
  "versao": 1, "geradoEm": "2026-10-24T01:10:23.440Z", "cidade": "Palmas, TO", "projetoId": 635,
  "corPrimaria": "#ffd100",
  "otpUri": "https://otp.mobilibus.com/vJJqIBsca8nqEF", "apiUri": "https://cdn.bus2.studio/api/",
  "atualizacaoAoVivoSeg": 20,
  "contagens": { "linhas": 47, "viagens": 106, "paradas": 1210, "busca": 2962 }
}
```

`versao` sobe quando o formato muda de forma incompatível. O app deve recusar uma `versao` maior do que conhece e mostrar `geradoEm` ("horários atualizados em…").

## `linhas.json`

Lista. `sentidos[].destino` é o destino mais comum das viagens daquele sentido.

```json
{ "id": 1097980, "numero": "010", "nome": "Eixão / Estação Apinajé", "cor": "#007CBA", "corTexto": "#FFFFFF",
  "sentidos": [ { "id": 0, "nome": "Ida", "destino": "Estação Apinajé" },
                { "id": 1, "nome": "Volta", "destino": "Eixão" } ] }
```

## `horarios.json`

Objeto `{ [linha.id]: [ { sentido, servicos } ] }`. Cada saída é `[partida, chegada, seq]`.

```json
{ "1097980": [ { "sentido": 0, "servicos": [
    { "id": 692907, "nome": "Dias úteis", "dias": [false,true,true,true,true,true,false],
      "saidas": [ ["04:40","05:40",1], ["05:10","06:10",1], ["05:20","06:20",1] ] } ] } ] }
```

- `chegada` é no ponto final da viagem. Nunca é menor que `partida` nos dados atuais.
- `seq` liga a saída à viagem: a viagem de `trajetos.json` com a mesma `linha`, o mesmo `sentido` e o mesmo `seq`.
  Em 3.851 saídas, essa ligação é sempre única.
- Não há feriados nem exceções de calendário. Não verificado se a API informa.

## `trajetos.json`

Objeto `{ [tripId]: viagem }`. Uma linha tem de 1 a 4 viagens por sentido (variações de percurso).

```json
{ "8494967": { "linha": 1097980, "sentido": 1, "destino": "Eixão", "seq": 3,
               "shape": "zac}@ff_fHjHAHxFN~BB~@…", "paradas": [37763548, 37763547, 37763546] } }
```

`paradas` é a ordem em que o ônibus passa; cada id existe em `paradas.json`.

## `paradas.json`

Lista ordenada por `id`.

```json
{ "id": 37763521, "nome": "Região Residencial Polinésia", "origem": "osm", "lat": -10.140934, "lng": -48.347263, "linhas": ["140"] }
```

- `linhas`: números das linhas (`linha.numero`) que passam ali.
- `origem` diz de onde veio o `nome`: `correcao` (data/paradas_nomes.json), `api` (nome da API, limpo), `osm` (montado com ruas e lugares do OpenStreetMap), `codigo` (`"Parada 37763650"`, sem nome melhor).
  Hoje: 200 `api`, 817 `osm`, 193 `codigo` (16%), nenhuma `correcao`.
- Formas do nome `osm`: `Rua A × Rua B`, `Rua A · perto de Lugar`, `Perto de Lugar`, `Região Bairro`.

## `busca.json`

Lista para a busca de lugares. A busca em si roda no app (regra em `tools/indice-busca.mjs`, função `buscar`).

```json
{ "n": "Palmas Shopping", "k": "comercio", "la": -10.18934, "lo": -48.33552 }
```

`k`: `rua`, `bairro`, `comercio`, `lugar`, `educacao`, `saude`, `culto`, `lazer`, `aeroporto`.
Siglas e nomes populares ficam em `data/apelidos.json` (`{ "uft": "Universidade Federal do Tocantins" }`) e são aplicados pelo app antes de buscar.

## Exceções conhecidas

- **14 viagens têm uma parada só** (ex.: linha 401, 21:20). Cada uma tem uma única saída, com chegada igual à partida.
  Mostrar só o horário; não há percurso para desenhar. Os dados não são descartados porque a API as lista nos horários.
- **4 viagens sem traçado** (`shape: null`): linhas 421 (sentido 1, seq 2), 091 (1, 3), 130 (1, 4) e 471 (1, 2).
- **Linhas rurais 640 e 650** vão até longitude −47,88 (cerca de 50 km de Palmas). O OpenStreetMap só é consultado entre −48,50 e −48,15,
  então as paradas além disso ficam sem nome melhor que o da API ou o código.
- Várias viagens repetem o mesmo traçado (61 traçados distintos em 106 viagens).
