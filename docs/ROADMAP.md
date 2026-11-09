# Roadmap

## ✅ Fase 1 — Fundação (concluída)

- [x] Projeto Godot 4.3, Android paisagem, renderer Mobile com fallback GLES3
- [x] Arquitetura em autoloads + sistemas independentes
- [x] Personagem estilizado procedural (esqueleto humanoide, 1 draw call)
- [x] Animações: idle, walk, run, turn, jump, sit, stand up, interact, pickup, kick,
      throw, celebrate, hit reaction, sad, wave, drink, idles variados
- [x] Movimentação com aceleração, giro suave, corrida, pulo (coyote time + buffer)
- [x] Câmera 3ª pessoa com SpringArm, zoom, realinhamento automático, tremor
- [x] Controles touch multitoque (joystick flutuante, botões contextuais, arrasto de câmera, pinça)
- [x] Escola grande: 2 blocos, 12 salas de aula, biblioteca, diretoria, cantina, pátios,
      quadra, queimada, parquinho, horta, bosque, murada com murais e entorno
- [x] Interações: sentar em ~690 assentos, bebedouros, chutar/conduzir bola, pegar e
      arremessar bolinha de papel, trombada cômica ao correr contra parede
- [x] HUD (local atual, minimapa/mapa completo, mensagens), menu principal, pausa,
      configurações (gráficos Baixa/Média/Alta, áudio, sensibilidade, opacidade)
- [x] Save local seguro (atômico + backup) e configurações persistentes
- [x] Sons gerados (passos por tipo de piso, chute, quique, sinal, ambiente)
- [x] 55 testes automatizados + capturas de tela

## ✅ Fase 2 — Vida escolar (concluída)

- [x] Grafo de navegação automático (3.000+ pontos validados por física, A*, ilhas removidas, suavização de caminho)
- [x] NPCs com o mesmo personagem do jogador: 8 alunos nomeados com personalidade
      (Lucas, Bia, Pedro, Ana, Júlia, Gui, Rafa, Mari) + genéricos; Professora Márcia,
      Diretor Valdir, Dona Cida (inspetora) e Tia Rosa (cantineira)
- [x] Pool de NPCs por qualidade (Baixa 22 / Média 32 / Alta 44), LOD de animação por
      distância/visão, ocultação dentro de prédios, separação entre personagens
- [x] Canal de animação superior (escrever, levantar a mão, conversar, apontar a lousa,
      bater palmas) sobreposto a sentar/andar; agachar para bolinha de gude
- [x] Ciclo do dia: chegada → aula 1 → recreio (3,5 min) → volta → aula 2 → fim, com relógio
- [x] 6 tipos de tarefa (conta, completar palavra, quiz, ordenar, ligar, achar e entregar
      objeto), dificuldade por dia, mínimo de acertos para liberar o recreio (com tarefas extras)
- [x] Sinal, faixa "RECREIO!", alunos saem correndo para atividades: futebol (chutam a bola
      para o gol), fila da cantina, pega-pega, bolinha de gude, amarelinha, balanço,
      rodas de conversa, bancos, passeios; diretor e inspetora patrulham
- [x] Conversas (diálogo com efeito de digitação), falas em balão, reação a esbarrões,
      amizades iniciais, XP/moedas/nível e resumo do fim do dia
- [x] 85 testes automatizados (save de teste separado do save real)

## ✅ Fase 3 — Diversão (concluída)

8 minijogos independentes (`scripts/minigames/`), cada um com regras, placar, interface e
recompensas próprias; estações com placa no mapa (só no recreio) e convites de amigos.

- [x] **Futebol**: 4×4 com goleiros, placar, gol pela trave, lateral, chute com mira
      assistida, passe para o colega, 2 min ou 3 gols; **torneio** (3 vitórias = campeão)
- [x] **Queimada**: times nas metades da quadra, pegar/arremessar com mira, bola "viva" até
      quicar, queimados vão ao cemitério e voltam, vitória com 6 queimados ou no tempo
- [x] **Bolinha de gude**: simulação 2D própria (atrito, colisões elásticas), mira e força,
      turnos contra a Júlia, bolinhas capturadas entram na **coleção** (7 tipos, 1 rara)
- [x] **Aviãozinho de papel**: dobrar (timing define a qualidade), mira/força, física de
      planador (sustentação, arrasto, vento), argolas, alvo de pouso, recorde
- [x] **Corrida** de 80 m contra dois colegas, **Pular corda** com ritmo crescente,
      **Pontaria** nas lixeiras de coleta seletiva, **Guerra de bolinhas de papel**
- [x] Câmera dedicada para enquadramentos de minijogo, barra de força, placar na HUD
- [x] 122 testes automatizados

## ✅ Fase 4 — Personalidade (concluída)

- [x] **Sistema disciplinar** (`systems/discipline.gd`): só conta o que um adulto vê
      (distância + linha de visão). Esbarrão andando = acidente; correndo ou repetido no
      mesmo colega = imprudência. Também: correr no corredor, jogar bolinha nos colegas,
      levantar na aula.
- [x] 1ª falta do dia: o adulto chama atenção. 2ª: **ocorrência** com cena na diretoria
      (durante a aula fica pendente para o recreio).
- [x] Ocorrência 1: advertência. Ocorrência 2: **pais chamados** (cena com mãe/pai) e
      ajudar a Dona Cida a recolher papel antes de brincar. 3ª+: conversas diferentes e
      bem-humoradas + 45 s no banco do hall. Minijogos bloqueados enquanto há castigo.
- [x] **Reputação** (0–100): cai com faltas, sobe com dias tranquilos, missões e boas
      ações; dias limpos perdoam ocorrências antigas; conquista "aluno exemplar".
- [x] **Eventos espontâneos** (variam por dia): bola nova, torneio relâmpago (recompensa
      em dobro), inspetora dando bronca, figurinha rara, diretor no pátio, lanche especial
      na cantina, recados e pedidos de ajuda.
- [x] **Missões de colegas**: achar e devolver objeto perdido, entregar bilhete.
- [x] Amizades com falas que mudam com o nível; comprar lanche com a Tia Rosa.
- [x] 144 testes automatizados

## Fase 5 — Progressão
Economia, loja (a aparência já é serializável e trocável em tempo real), coleções,
missões, conquistas. O save já reserva as seções `inventory`, `collections`,
`friendships`, `missions`, `achievements`.

## Fase 6 — Acabamento
Música, mais efeitos, testes em várias resoluções, AdMob (recompensado opcional,
sem anúncios obrigatórios, respeitando as políticas para público infantil).
