# API de dados (Mobilibus/Bus2) — Palmas

API pública, só GET, sem login e sem documentação oficial. Tudo abaixo foi testado em 2026-10-23/24.
Palmas-TO é `project_id=635` (não confundir com Palmas-PR, `857`). Chaves de API do app oficial não são necessárias nem usadas.

Bases: `https://mobilibus.com/api` ou o `apiUri` de Palmas, `https://cdn.bus2.studio/api` (mesmos dados).
Nenhuma envia CORS; o OTP envia.

## Endpoints

| Endpoint | Parâmetros | Devolve | Cache da origem |
|---|---|---|---|
| `/projects` | — | 801 cidades | — |
| `/project-details` | `project_id` | cor da marca (`#ffd100`), `otpUri`, `apiUri`, agência, `realtimeUpdateFreqSec` (20) | — |
| `/routes` | `project_id` (`q` opcional) | 47 linhas: `routeId`, `shortName`, `longName`, `color` | 1 h |
| `/timetable` | `project_id`, `route_id` | horários por sentido e dia; lista de `trips` (`tripId`, `directionId`) | 1 h |
| `/trip-details` | `project_id`, `trip_id` | paradas, traçado (`shape`, *Encoded Polyline*), horários, ônibus ao vivo | — |
| `/stops` | `project_id`, `tile=x,y,zoom` | paradas do quadrante (zoom ≥ 14) | — |
| `/departures` | `project_id`, `stop_id` | próximos ônibus da parada; com `vehicleId`, `gpsTime`, `delay` quando há ônibus ao vivo | 30 s |
| `/timetable-by-stop` | `project_id`, `stop_id` | grade de horários da parada | — |
| `/vehicles` | `trip_id` | ônibus ao vivo da viagem: `vehicleId`, `lat`, `lng`, `heading` (graus do norte), `positionTime` (HH:mm:ss de Palmas), `percTravelled`, `delay` (s; negativo = adiantado), `startTime`, `seq`. Resposta fica 15 s no cache da CDN | 15 s |
| `/alerts` | `project_id` | avisos (vazio em 2026-10-23) | — |
| OTP `{otpUri}/otp/routers/default/plan` | `fromPlace`, `toPlace`, `date=MM-DD-YYYY`, `time=HH:mm`, `mode=TRANSIT,WALK`, `numItineraries` | itinerários com trechos a pé e de ônibus, traçado e passos | — |

**Todos os ônibus de uma vez:** não existe endpoint para isso. Pergunta-se pelas 106 viagens do snapshot (`trajetos.json`), em lotes de 30. Medido em 2026-10-24 (sábado, 16:53): 106 respostas em 1,6 s, 34 ônibus; o mesmo ônibus nunca apareceu em duas viagens. Sem CORS: só no app.

`otpUri` de Palmas: `https://otp.mobilibus.com/vJJqIBsca8nqEF`.

## Como encadear

`/routes` → `routeId` → `/timetable` → `tripId` → `/trip-details` (paradas, traçado) e `/vehicles`.
Para uma parada: `/stops` → `stopId` → `/departures` e `/timetable-by-stop`.

## Quadrante de `/stops`

```
z = zoom - 2
x = floor((lng + 180) / 360 * 2^z)
y = floor((1 - ln(tan(lat) + 1/cos(lat)) / π) / 2 * 2^z)     (lat em radianos)
tile = "x,y,zoom"                                             (zoom original, não z)
```
Exemplo: centro de Palmas, zoom 16 → `5992,8657,16` (59 paradas).

## Particularidades

- 83% das paradas (886 de 1064 vistas no primeiro levantamento) têm só o código no `name` (ex.: `450134721`) e `address` vazio. Ver [nomes-paradas.mjs](../tools/nomes-paradas.mjs).
- Nomes que não são código vêm com sujeira: `"Avenida Tocantins Palmas - Tocantins 77060-150 Brasil"`.
- `stops` sem `tile` devolve erro 500 (`Cannot read properties of undefined (reading 'x')`).
- `/vehicles-by-trip` devolve texto cifrado; não usado.
- Não existem `/shape`, `/trip`, `/search`, nem swagger/openapi (testados 25 caminhos comuns).
- Formato de `days` em `timetable`: `[dom, seg, ter, qua, qui, sex, sáb]` (visto em `[false,true,true,true,true,true,false]` = dias úteis).

## Fontes

Endpoints que o app oficial não expõe na tela foram confirmados com a pesquisa de
[lucasbrisolla/onibus-bh](https://github.com/lucasbrisolla/onibus-bh/blob/main/docs/mobilibus-otimo-api-research.md) (MIT) e testados em Palmas.

## Geocodificador e avisos (verificado 2026-10-24)

Mesma base do OTP (`otpUri`). É o que o app SOU usa para buscar lugares. Aceita chamada do navegador (CORS aberto).

| Endpoint | Parâmetros | Devolve |
|---|---|---|
| `{otpUri}/otp/geocode` | `address` (mínimo 3 letras; com 1 ou 2 não devolve nada) | `{ count, results: [{ id, provider, lat, lng, description, street, number, postalCode, city, importance, ... }] }`. `provider` é `Bus2` (OpenStreetMap: lugares, ruas, endereços) ou `GTFS` (paradas de ônibus) |
| `{otpUri}/otp/geocode/reverse` | `lat`, `lon` | mesma estrutura, lugares próximos do ponto |
| `/news` | `project_id` | lista; vazia hoje |
| `/alerts` | `project_id` | lista; vazia hoje |

O OTP também aceita `arriveBy=true` no `plan` ("chegar às"). O campo `stops` do GraphQL não existe nessa versão do OTP.
