# Telas e plano de desenvolvimento

## Decisão: o app SOU é a fonte de verdade

O app oficial da SOU Palmas usa a mesma API que nós. Quando um dado divergir (horário, linha, rota), vale o que o SOU mostra.
O Moovit serve só de referência de interface. Cada marco abaixo termina com uma conferência contra o SOU.

## Telas necessárias (12)

Escolhidas pelo que a pessoa precisa fazer no ponto de ônibus. Origem: o que o SOU e o Moovit têm para transporte
(cerca de 20 telas no SOU, 30 no Moovit). Ficou de fora o que não é ver ônibus (lista no fim).

Navegação: barra inferior com **Início, Linhas, Favoritos, Mais**. O planejador abre pela caixa "Para onde?" do Início.

| # | Tela | Para quê | Dados |
|---|---|---|---|
| 1 | **Início** | Mapa com paradas próximas e a caixa "Para onde?". Ponto de partida de tudo. | `paradas.json`, localização |
| 2 | **Busca** | Achar lugar, parada ou linha digitando; mostra recentes e favoritos. | `busca.json`, `apelidos.json`, `paradas.json`, `linhas.json` |
| 3 | **Escolher no mapa** | Marcar origem ou destino com o pino, para quando não se sabe o nome. | mapa, `busca.json` (nome do ponto) |
| 4 | **Planejar viagem** | Origem, destino, "sair agora / sair às / chegar às" e a lista de opções de rota. | OTP |
| 5 | **Detalhe da rota** | Linha do tempo: andar, ônibus, trocas, ônibus equivalentes, aviso de chegada; trajeto no mapa. | OTP, `trajetos.json`, `departures` |
| 6 | **Parada** | Próximos ônibus ao vivo, grade do dia, linhas que passam, favoritar. É a tela mais usada. | `departures`, `timetable-by-stop`, `paradas.json` |
| 7 | **Linhas** | Lista das 47 linhas com busca por número ou nome. | `linhas.json` |
| 8 | **Linha** | Sentido, trajeto no mapa, paradas em ordem, horários do dia, ônibus ao vivo. | `trajetos.json`, `horarios.json`, `vehicles` |
| 9 | **Favoritos** | Paradas, linhas e lugares salvos (casa, trabalho) com próxima saída. | só no aparelho |
| 10 | **Avisos** | Alertas de serviço da operadora. Hoje a lista está vazia; a tela existe para quando houver. | `alerts` |
| 11 | **Mais** | Tema claro/escuro, tamanho de letra, data dos horários, sobre o projeto, enviar sugestão, licenças. | `meta.json` |
| 12 | **Primeira abertura** | Duas telas curtas: o que o app faz e por que pedimos a localização. | — |

Componentes que aparecem em várias telas, não são telas: aviso de chegada (folha que sobe), compartilhar, estados de erro e sem internet
([DESIGN.md](DESIGN.md)).

### Ficou de fora, e por quê

- Recarga, clube de pontos, carteira, pagamento, passagens, assinatura, login e conta: não são informação de ônibus e exigem cadastro.
- Fretado, carona, bicicleta e patinete: fora do serviço de Palmas que mapeamos.
- Anúncios e busca por IA: fora do escopo.
- Foto da parada e visão da rua: não temos fonte de dados.
- "Contra o assédio" (existe no SOU): conteúdo não visto; perguntar à prefeitura antes de decidir.

## Plano

Cada marco entrega algo que uma pessoa já consegue usar. Telas só entram em código depois de ter protótipo aprovado.

| Marco | Entrega | Pronto quando |
|---|---|---|
| **P. Protótipo** | Telas 1 a 6 navegáveis no celular, com dados reais de exemplo | 5 moradores concluem "ver quando passa o ônibus da minha parada" e "ir de A para B" sem ajuda |
| **M0. Fundação** | Projeto Flutter em `app/`, tema, navegação com as 4 abas, leitura dos arquivos de `data/gerado/`, proxy mínimo para a web | `flutter run` abre o app no Android e no navegador mostrando "atualizado em [data]" |
| **M1. Início, busca e mapa** (telas 1, 2, 3) | Mapa com paradas próximas; busca de lugar, parada e linha; escolher ponto no mapa | Digitar "uft" e "104 sul" acha o lugar; paradas só carregam as visíveis; funciona sem internet |
| **M2. Rota de A para B** (telas 4, 5) | Planejador completo: opções, trocas, ônibus equivalentes, detalhe em linha do tempo | Os 15 casos de [CASOS_ROTA.md](CASOS_ROTA.md) rodam no app com o mesmo resultado do script, e 5 trajetos conferem com o SOU |
| **M3. Parada ao vivo** (tela 6) | Próximos ônibus com atualização a cada 20 s, grade do dia, favoritar | 10 paradas conferem com o SOU (mesmas linhas e horários, até 1 min de diferença) |
| **M4. Linhas** (telas 7, 8) | Lista, trajeto, paradas em ordem, horários, ônibus ao vivo no mapa | As 47 linhas abrem; trajeto e horários de 5 linhas conferem com o SOU |
| **M5. Favoritos, avisos, mais, primeira abertura** (telas 9, 10, 11, 12) | Telas restantes e aviso de chegada | Favoritos sobrevivem a fechar o app; permissão de localização só é pedida após a explicação |
| **M6. Qualidade** | Acessibilidade, offline, desempenho em celular simples, testes | Leitor de tela lê as 12 telas; 3 s para abrir com dados salvos; beta fechado com a comunidade |

Ordem: P → M0 → M1 → M2 → M3 → M4 → M5 → M6. M2 vem antes de M3 porque a rota foi a prioridade; M3 e M4 são independentes e
podem andar em paralelo se houver mais gente.

### Cada tela, antes de ir para código

1. Protótipo aprovado e registrado em [DESIGN.md](DESIGN.md) se criar componente novo.
2. Os quatro estados (carregando, vazio, sem internet, erro) desenhados.
3. Dados que ela lê descritos em [DADOS.md](DADOS.md); se faltar campo, a mudança entra no `snapshot.mjs` e no `validar.mjs` primeiro.
4. Conferência contra o SOU anotada no PR (qual consulta, qual resultado nos dois).

## Em aberto

- Quem faz o protótipo e onde ele fica.
- Conferir o caso 1006 Sul → 405 Norte e o aeroporto no SOU: resolvem as dúvidas de [CASOS_ROTA.md](CASOS_ROTA.md).
- O que é a tela "Contra o assédio" do SOU.
