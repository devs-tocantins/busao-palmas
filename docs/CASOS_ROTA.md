# Casos de teste da rota

A rota vem do planejador (OTP) da Mobilibus, que é de terceiros. Estes casos dizem se o resultado faz sentido para quem conhece Palmas.
Hoje são 15 trajetos em `data/casos_rota.json`; ninguém ainda confirmou as respostas. Falta a comunidade preencher `esperado`.

```bash
cd tools
node casos-rota.mjs                       # roda todos
node casos-rota.mjs uft-rodoviaria        # roda um
```

Precisa de `data/gerado/` (rode `snapshot.mjs` antes). Cada caso é consultado no próximo dia da semana e hora indicados.
Sai com erro se alguma regra abaixo falhar.

## O que o script confere sozinho

- Existe ao menos uma opção (exceto nos casos com `semRotaOk`).
- Toda linha usada existe em `linhas.json` e todo trecho de ônibus tem traçado.
- Aviso (não erro): a melhor opção manda andar mais de 2,5 km, leva mais de 150 min ou tem mais de 2 trocas.
- Se o caso tem `esperado`, confere (ver abaixo).

## Adicionar ou confirmar um caso

Cada caso é um objeto em `data/casos_rota.json`:

```json
{ "id": "uft-rodoviaria", "nome": "UFT → Rodoviária",
  "origem":  { "nome": "UFT", "lat": -10.1784, "lng": -48.35956 },
  "destino": { "nome": "Rodoviária de Palmas", "lat": -10.25684, "lng": -48.31294 },
  "quando": { "dia": "seg", "hora": "07:30" },
  "esperado": { "linhas": ["090", "410"], "maxMinutos": 60 } }
```

- `dia`: `dom`, `seg`, `ter`, `qua`, `qui`, `sex` ou `sab`.
- `esperado` (opcional, só o que você sabe com certeza):
  - `linhas`: pelo menos uma das 5 opções usa todas essas linhas;
  - `maxMinutos`: a melhor opção leva no máximo isso.
- `semRotaOk: true` e `nota`: o caso é conhecido por não ter rota. O script avisa se passar a ter.
- `referencia`: de onde vem a resposta que você conhece (ex.: "uso essa viagem todo dia").
- Coordenadas: use as do `data/gerado/busca.json` para o lugar, ou clique no mapa do openstreetmap.org.

Bons casos: viagens que você faz de verdade, com a linha e o tempo que você sabe que funcionam, e viagens que você sabe que **não** deveriam depender de muitas trocas.

## O que os 15 casos já mostram (2026-10-24)

- **Aeroporto sem rota.** Os 3 casos com o aeroporto não têm rota. O aeroporto só tem a linha 460 (Estação Xerente → Aeroporto,
  só ida, 9 saídas em dia útil). A confirmar: é o serviço real ou limite do planejador?
- **1006 Sul → 405 Norte, noite.** O Moovit mostrou 180 e depois 040 em 50 min (dados dele estão desatualizados). Nosso planejador
  deu 66 a 70 min, com 190+050, 180+050 e 410+030. A linha 040 não aparece. Quem usa esse trajeto pode dizer qual está certo.
- **Entre terminais** (Krahô → Apinajé) e **Aureny → Apinajé** dão rota direta, sem troca, em 20 a 30 min.
- **SESC → DETRAN** (~1 km) devolve só caminhada de 16 min, sem ônibus.
- **Taquaruçu** (distrito) leva cerca de 90 min e **Taquari → UFT**, 70 a 85 min.
