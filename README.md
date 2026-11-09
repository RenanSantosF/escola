# Recreio — Minha Vida na Escola

Simulador casual de vida escolar em 3D, feito em **Godot 4.3** para **Android (paisagem)**.
Ambientado numa escola pública brasileira grande — com murada, pátio ao sol, quadra,
cantina, salas de aula, biblioteca, parquinho e muito mais.

> Status: **Fases 1 (Fundação) e 2 (Vida escolar) concluídas.** Veja [docs/ROADMAP.md](docs/ROADMAP.md).

## Como abrir e jogar

1. Instale o **Godot 4.3** (versão padrão, não precisa da versão .NET).
2. Abra o editor → *Importar* → selecione `project.godot`.
3. Aperte **F5**. A escola é gerada em ~1 s e o menu aparece sobre uma vista aérea.

### Controles

| Ação | Celular | Teclado/mouse | Controle |
|---|---|---|---|
| Andar | Joystick flutuante (metade esquerda da tela) | WASD / setas | Analógico esquerdo |
| Girar câmera | Arrastar na metade direita | Clique direito + arrastar, J/L | Analógico direito |
| Zoom | Pinça com dois dedos | Roda do mouse | — |
| Correr | Botão laranja (liga/desliga) | Shift (segurar) | RB |
| Pular | Botão azul | Espaço | A |
| Interagir (sentar, pegar, beber água) | Botão verde (mostra a ação) | E | X |
| Brincadeira (chutar, arremessar, comemorar) | Botão amarelo grande | F | B |
| Emotes | Botão de carinha | Q (acenar) | Y |
| Pausa | Botão ❚❚ / voltar do Android | Esc / P | Start |
| Mapa completo | Tocar no minimapa | Clicar no minimapa | — |

## Testes automatizados

```bash
# Testes de integração (save, movimento, colisões, sentar, chutar, arremessar,
# zonas, toque, câmera, navegação, NPCs, tarefas, ciclo completo do dia...)
godot --headless --path . res://tests/test_runner.tscn

# Custo de CPU por quadro com NPCs
godot --headless --path . res://tests/perf_probe.tscn -- --quality=2

# Capturas de tela de vários pontos da escola + contagem de draw calls
godot --rendering-driver opengl3 --path . res://tests/capture_world.tscn -- --out=/tmp/shots --quality=0
```

## Estrutura

```
autoloads/       GameManager, Settings, SaveManager, AudioManager
scenes/          main (entrada), character/player, school (raiz do mundo)
scripts/
  character/     aparência, construtor do modelo, animador procedural, ações
  player/        controle do jogador
  camera/        câmera em terceira pessoa
  world/         gerador da escola, decoração, props, árvores, materiais, batching
  interaction/   assentos, bebedouros, bolas, objetos arremessáveis
  npc/           NPCs, elenco, gerenciador (rotinas/atividades), grafo de navegação
  school/        ciclo do dia escolar e gerador de tarefas da aula
  systems/       amizades (e futuros sistemas de jogo)
  ui/            tema, controles de toque, HUD, minimapa, menus, aula, diálogo
  main/          fluxo carregamento → menu → jogo
assets/          texturas e sons gerados (ver tools/)
tools/           scripts Python que geram as texturas e os sons
tests/           testes automatizados e cenas de captura
docs/            arquitetura, roadmap, guia Android
```

Mais detalhes em [docs/ARQUITETURA.md](docs/ARQUITETURA.md) e [docs/ANDROID.md](docs/ANDROID.md).

## Assets e licenças

Todo o conteúdo visual e sonoro é **gerado proceduralmente** por este projeto
(modelos, animações, texturas via `tools/gen_textures.py`, sons via `tools/gen_audio.py`).
Não há assets de terceiros, então não há restrições de licença para distribuição comercial.
O Godot Engine é licenciado sob MIT.
