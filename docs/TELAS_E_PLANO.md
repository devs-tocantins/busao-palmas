# Telas e plano de desenvolvimento

## Regras

1. **O app SOU é a fonte de verdade.** Ele usa a mesma API que nós. Se um dado divergir (horário, linha, rota), vale o que o SOU mostra.
   O Moovit serve só de referência de interface. Cada marco termina com uma conferência contra o SOU.
2. **Tela só entra se a API entrega o dado.** Antes de planejar cada tela conferimos a fonte (tabela abaixo). Sem dado, sem tela.

## O que a API entrega (verificado em 2026-10-24)

| Necessidade | Fonte | Situação |
|---|---|---|
| Paradas, linhas, horários, trajetos | `mobilibus.com/api`, via snapshot | Sim; validado em [DADOS.md](DADOS.md) |
| Próximos ônibus de uma parada | `departures` | Sim, com `vehicleId`, `gpsTime` e atraso quando há ônibus ao vivo |
| Ônibus ao vivo de uma viagem | `vehicles` | Sim |
| Rota de A para B, "sair às" e "chegar às" | OTP `plan`, `arriveBy=true` | Sim |
| Buscar lugar ou endereço | OTP `/otp/geocode?address=` (o mesmo que o SOU usa) | Sim; mínimo 3 letras; devolve lugares, ruas com número e CEP, e paradas; aceita chamada do navegador |
| Nome de um ponto marcado no mapa | OTP `/otp/geocode/reverse?lat=&lon=` | Sim |
| Avisos de serviço | `alerts` e `news` | O endereço existe, mas a lista está vazia hoje. Formato com conteúdo: não verificado |
| Aviso "ônibus chegando" com o app fechado | O SOU usa push de um servidor (FCM) | **Não temos servidor.** Só dá para avisar com o app aberto |
| Favoritos | O SOU guarda no aparelho | Sim, igual |
| Foto da parada, pontos de venda | — | Não existe (`hasPointOfSale: false` em Palmas) |

## Telas necessárias (11)

Escolhidas pelo que a pessoa faz no ponto de ônibus, e só as que a tabela acima sustenta. O SOU tem cerca de 20 telas de transporte e o Moovit, 30.

Navegação: barra inferior com **Início, Linhas, Favoritos, Mais**. O planejador abre pela caixa "Para onde?" do Início.

| # | Tela | Para quê | Dados |
|---|---|---|---|
| 1 | **Início** | Mapa com paradas próximas e a caixa "Para onde?". | `paradas.json`, localização |
| 2 | **Busca** | Achar lugar, endereço, parada ou linha; recentes e favoritos. | geocodificador do Bus2 (3+ letras); `busca.json`, `apelidos.json` para 1–2 letras, sem internet e siglas; `linhas.json` |
| 3 | **Escolher no mapa** | Marcar origem ou destino com o pino. | mapa, geocodificador reverso |
| 4 | **Planejar viagem** | Origem, destino, "sair agora / sair às / chegar às" e a lista de opções. | OTP |
| 5 | **Detalhe da rota** | Linha do tempo: andar, ônibus, trocas, ônibus equivalentes; trajeto no mapa. | OTP, `trajetos.json`, `departures` |
| 6 | **Parada** | Próximos ônibus ao vivo, grade do dia, linhas que passam, favoritar. A mais usada. | `departures`, `timetable-by-stop`, `paradas.json` |
| 7 | **Linhas** | Lista das 47 linhas com busca. | `linhas.json` |
| 8 | **Linha** | Sentido, trajeto, paradas em ordem, horários do dia, ônibus ao vivo. | `trajetos.json`, `horarios.json`, `vehicles` |
| 9 | **Favoritos** | Paradas, linhas e lugares salvos (casa, trabalho) com a próxima saída. | só no aparelho, `departures` |
| 10 | **Mais** | Tema, tamanho de letra, data dos horários, sobre, sugestões (abre uma issue no GitHub), licenças. | `meta.json` |
| 11 | **Primeira abertura** | Duas telas curtas: o que o app faz e por que pedimos a localização. | — |

Não são telas: aviso de chegada (folha que sobe, só com o app aberto), compartilhar, faixa de aviso de serviço (aparece em Parada, Linha e Detalhe
quando `alerts` tiver conteúdo) e estados de erro e sem internet ([DESIGN.md](DESIGN.md)).

### Ficou de fora, e por quê

- **Tela de Avisos** (o SOU tem "Notícias e alertas"): `alerts` e `news` estão vazios em Palmas. Volta a entrar se `news` passar a ter conteúdo.
- **Aviso de chegada com o app fechado:** exige servidor de push. É a maior diferença para o SOU; pode melhorar no Android com serviço em primeiro plano (marco M6).
- **Acompanhar a viagem e avisar para descer** (o SOU e o Moovit têm): dá para fazer só com GPS e as paradas da rota, mas exige localização em segundo plano. Fica para depois do M6, só no Android.
- Recarga, clube de pontos, carteira, pagamento, passagens, assinatura, login: não são informação de ônibus e exigem cadastro.
- Fretado, carona, bicicleta, patinete, anúncios, busca por IA: fora do escopo.
- Foto da parada e visão da rua: sem fonte.
- "Contra o assédio" (existe no SOU): conteúdo não visto; perguntar à prefeitura.

## Plano

Cada marco entrega algo usável. Tela só vira código depois de protótipo aprovado.

| Marco | Entrega | Pronto quando |
|---|---|---|
| **P. Protótipo** | Telas 1 a 6 navegáveis no celular, com dados reais | 5 moradores concluem "ver quando passa o ônibus da minha parada" e "ir de A para B" sem ajuda |
| **M0. Fundação** | Projeto Flutter em `app/`, tema, navegação com as 4 abas, leitura de `data/gerado/`, proxy para a web | `flutter run` abre no Android e no navegador mostrando "atualizado em [data]" |
| **M1. Início, busca e mapa** (1, 2, 3) | Mapa com paradas próximas; busca de lugar, parada e linha; pino no mapa | "uft", "104 sul" e "palmas shopping" acham o lugar; busca de 1–2 letras e sem internet funciona pelo índice local |
| **M2. Rota de A para B** (4, 5) | Planejador com "sair/chegar às", trocas, ônibus equivalentes e linha do tempo | Os 15 casos de [CASOS_ROTA.md](CASOS_ROTA.md) dão no app o mesmo resultado do script; 5 trajetos conferem com o SOU |
| **M3. Parada ao vivo** (6) | Próximos ônibus com atualização a cada 20 s, grade do dia, favoritar | 10 paradas conferem com o SOU (mesmas linhas, horários até 1 min de diferença) |
| **M4. Linhas** (7, 8) | Lista, trajeto, paradas em ordem, horários, ônibus ao vivo | As 47 linhas abrem; trajeto e horários de 5 linhas conferem com o SOU |
| **M5. Favoritos, mais e primeira abertura** (9, 10, 11) | Telas restantes e aviso de chegada com o app aberto | Favoritos sobrevivem a fechar o app; a localização só é pedida depois da explicação |
| **M6. Qualidade** | Acessibilidade, offline, desempenho em celular simples, testes | Leitor de tela lê as 11 telas; 3 s para abrir com dados salvos; beta fechado com a comunidade |

Ordem: P → M0 → M1 → M2 → M3 → M4 → M5 → M6. M3 e M4 são independentes e podem andar em paralelo.

### Cada tela, antes de virar código

1. Protótipo aprovado; componente novo registrado em [DESIGN.md](DESIGN.md).
2. Quatro estados desenhados: carregando, vazio, sem internet, erro.
3. Fonte dos dados confirmada na tabela acima; se faltar campo, a mudança entra primeiro em `snapshot.mjs` e `validar.mjs`.
4. Conferência contra o SOU anotada no PR: qual consulta, o que cada app mostrou.

## Em aberto

- Quem faz o protótipo e onde ele fica.
- Conferir no SOU o trajeto 1006 Sul → 405 Norte e uma viagem ao aeroporto ([CASOS_ROTA.md](CASOS_ROTA.md)).
- Formato dos avisos quando houver um real.
- Termos de uso do geocodificador e da API: antes de publicar.
