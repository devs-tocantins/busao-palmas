---
name: documentar
description: Escrever ou revisar documentação do Busão Palmas (docs/, README, ADRs). Usar sempre que for criar ou editar um .md do projeto. Regra central: só entra o que o leitor precisa para decidir ou agir.
---

# Documentar o Busão Palmas

Quem lê: dev voluntário da comunidade que chega sem contexto e quer saber **o que foi decidido, por quê e o que fazer**.

## Antes de escrever
1. Diga em uma frase para que o documento serve. Se não couber em uma frase, são dois documentos.
2. Veja se o assunto já está em outro arquivo. Se estiver, aponte para ele; nunca copie.

## Entra
- Decisões e o motivo.
- Fatos verificados, com data e como foram testados.
- Passos exatos, comandos que funcionam, valores reais.
- Riscos que mudam uma decisão.
- Perguntas em aberto que bloqueiam algo.

## Não entra
- Introdução, resumo do que o texto vai dizer, conclusão que repete o corpo.
- Explicação de coisa óbvia para quem programa ou de conceito já definido em outro documento.
- Lista de "boas práticas" genéricas, roadmap sem dono ou data, promessas.
- Seção só para parecer completo. Documento curto é sinal de que está bom.
- Tabela quando bastam duas linhas; tabela só para comparar itens com os mesmos atributos.
- Adjetivos e hesitação ("robusto", "talvez seja interessante"). Afirme, ou diga que não foi verificado.

## Forma
- Português do dia a dia, frases curtas, termo técnico só quando não há palavra comum.
- Título diz o conteúdo. Primeira linha já entrega o essencial.
- Mesmo termo para a mesma coisa em todos os arquivos.
- Marque o que não foi testado como "não verificado".
- Data (AAAA-MM-DD) em fatos que podem envelhecer.

## Depois de escrever
Releia cortando: cada parágrafo precisa responder "se eu tirar isso, alguém erra ou perde tempo?". Se não, tire.
