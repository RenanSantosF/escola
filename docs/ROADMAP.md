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

## Fase 2 — Vida escolar (próxima)

- NPCs alunos usando o mesmo `CharacterVisual` (aparências aleatórias, rotinas
  com waypoints, LOD de animação via `update_interval`, limite de ativos)
- Professores e diretor
- Sala de aula: o jogador começa sentado; tarefas rápidas (conta, palavra, múltipla
  escolha, ordenar, achar objeto, associação), progresso da aula, pontuação
- Sinal (som já existe: `school_bell`) e transição para o recreio com alunos saindo

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
