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

## Fase 3 — Diversão
Futebol (times, gols, placar), queimada, bolinha de gude (mira/força/colisões),
aviãozinho de papel (física de voo), convites.

## Fase 4 — Personalidade
Diretor e professores, ocorrências progressivas e leves, pais, amizades, eventos
espontâneos. A detecção de esbarrões já diferencia trombada correndo de contato leve.

## Fase 5 — Progressão
Economia, loja (a aparência já é serializável e trocável em tempo real), coleções,
missões, conquistas. O save já reserva as seções `inventory`, `collections`,
`friendships`, `missions`, `achievements`.

## Fase 6 — Acabamento
Música, mais efeitos, testes em várias resoluções, AdMob (recompensado opcional,
sem anúncios obrigatórios, respeitando as políticas para público infantil).
