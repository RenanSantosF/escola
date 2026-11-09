# Arquitetura

## Visão geral

```
Main (scripts/main/main.gd)
├── SchoolWorld (Node3D)          ← constrói a escola em ~1 s (corrotina com tela de carregamento)
│   ├── WorldEnvironment, Sun
│   ├── Geometry/<chunk>/          ← 1–3 MeshInstance3D por área + StaticBody3D com caixas
│   ├── Trees/                     ← MultiMesh por tipo × célula de 90 m
│   ├── Seats/                     ← ~690 assentos e bebedouros interativos
│   ├── Dynamic/                   ← bolas e bolinhas de papel (RigidBody3D)
│   └── Player (CharacterBody3D)
├── CameraRig (CameraController)
└── CanvasLayer
    ├── HUD (zona, minimapa, toasts, emotes, pausa, configurações)
    │   └── MobileControls (joystick + botões, multitoque)
    └── Menu principal / carregamento
```

### Autoloads

| Nome | Responsabilidade |
|---|---|
| `Settings` | Gráficos (Baixa/Média/Alta), áudio, sensibilidade, opacidade dos botões. `user://settings.cfg`. Detecta qualidade inicial pelo aparelho. |
| `SaveManager` | Progresso em `user://save.json`. Escrita atômica (tmp → valida → backup → renomeia), recuperação pelo backup, versão de esquema e mesclagem com padrões. |
| `AudioManager` | Barramentos Music/SFX/Ambient/UI, pool de players (sem instanciar em jogo), variações de pitch, ambiente com crossfade. |
| `GameManager` | Estado (BOOT/MENU/PLAYING/PAUSED), pausa, zona atual, toasts, mapeamento de teclado/controle, salvar ao minimizar no Android, botão voltar. |

## Personagens

* **`CharacterModelBuilder`** gera um `Skeleton3D` com 24 ossos usando os nomes do
  perfil humanoide do Godot (`Hips`, `Spine`, `Chest`, `LeftUpperArm`...) — o que permite
  **retarget de animações Mixamo** no futuro sem mudar o código de jogo.
* A malha é **uma única superfície skinned com cores por vértice** → 1 draw call por
  personagem (essencial para encher o pátio de alunos na Fase 2).
* `CharacterAppearance` descreve pele, 8 penteados, roupas, mochila, boné, óculos,
  altura/porte. Serializável (save/loja) e com gerador aleatório para NPCs.
* **`CharacterAnimator`** (procedural, em camadas):
  1. idle (respiração, peso alternado, olhar, piscar);
  2. locomoção com **fase sincronizada pela distância percorrida** (passada calculada
     a partir da velocidade → sem "patinação"), IK simplificado que mantém o pé de apoio
     no chão, giro no lugar com passos, inclinação em curvas e na aceleração;
  3. pulo/queda e amortecimento de aterrissagem (mola);
  4. ações por keyframes com spline cúbica (`ActionLibrary`): sentar, levantar, chutar,
     arremessar, interagir, pegar, beber, comemorar, levar trombada, tristeza, acenar,
     espreguiçar, olhar em volta, coçar a cabeça. Ações emitem eventos
     (`impact`, `release`, `grab`, `use`) no quadro exato.
  Tudo passa por suavização exponencial — sem trocas bruscas de pose.
  `update_interval` permite atualizar NPCs distantes com menor frequência (LOD).

## Mundo

* **`SchoolBuilder`** contém o layout (em metros) e gera tudo: terreno, murada com
  pilares e murais, portão com letreiro, rua e casas, Bloco A (10 salas, biblioteca,
  diretoria, secretaria, sala dos professores, informática, artes, banheiros, depósito,
  hall e corredores), Bloco B (laboratório, salas 11–12, música, varanda), cantina,
  pátio coberto com palco, pátio central ao sol, espaço de convivência, quadra
  poliesportiva com arquibancada e alambrado, campo de queimada, parquinho, horta,
  bosque e jardins.
* **Prédios genéricos**: cada prédio é uma lista de salas retangulares; as paredes
  compartilhadas são unificadas por linha, e portas/janelas/balcões são recortados
  automaticamente. Cada sala recebe pintura interna própria (barra + parede).
* **`InteriorDecorator`** mobilia cada tipo de ambiente.
* **`WorldBatcher`** agrupa a geometria de cada área em poucas malhas e cria as
  colisões (caixas/cilindros), oclusores e alcance de visibilidade.
* **Material único do cenário** (`SchoolMaterials.world_material`): um shader com
  `Texture2DArray` (atlas de 10 camadas comprimido em ETC2/ASTC); a camada e a
  rugosidade/metal vêm por vértice (UV2). Assim quase todo o cenário usa **um só
  material** → cerca de 1 draw call por área.
* **Telhados e interiores**: ao entrar num prédio, o telhado some e a mobília interna
  aparece; ao sair, o inverso. Fora dos prédios nada da mobília é desenhado.
* Zonas nomeadas alimentam a HUD, o minimapa e o som dos passos (piso duro/grama/terra).

## Sistemas de jogo (Fases 2–6)

| Nó / classe | Papel |
|---|---|
| `NavGraph` | Grafo de navegação gerado da física (grade 3 m + portas), A*, sem ilhas |
| `NPCManager` / `NPC` | Pool de alunos e adultos, rotinas por fase, atividades do recreio, LOD |
| `SchoolDay` | Ciclo do dia (chegada → aula → recreio → volta → aula → fim), tarefas, sinal |
| `ClassroomTasks` / `ClassroomUI` | Gerador de 6 tipos de tarefa e painel em forma de lousa |
| `MinigameManager` / `Minigame` | 8 minijogos independentes, estações e convites |
| `DisciplineSystem` | Testemunhas, faltas, ocorrências com cena na diretoria, reputação |
| `SchoolEvents` | Eventos espontâneos e missões de colegas |
| `Progression` / `ShopCatalog` | Loja, guarda-roupa, decoração, missões diárias, conquistas |
| `Friendship`, `Stickers` | Amizades e álbum de figurinhas (estáticos, dados no save) |
| `ProfileMenu`, `DialogueUI`, `HUD` | Interfaces (mochila, diálogos, objetivo, placar, minimapa) |
| `Effects`, `AudioManager` | Partículas e áudio com pool |
| `AdsManager` | Monetização preparada e desativada |

## Interação

Duck typing via grupo `interactable`: `interact_point()`, `interact_radius`,
`get_prompt()`, `can_interact()`, `interact()`. O jogador varre os próximos a cada
0,1 s e a HUD mostra a ação contextual no botão verde (Sentar, Pegar, Beber água...).

## Otimização (resumo)

| Técnica | Onde |
|---|---|
| Malha única por personagem | `CharacterModelBuilder` |
| Batching por área + material único com Texture2DArray | `WorldBatcher`, `SchoolMaterials` |
| MultiMesh em células para árvores | `TreeFactory` |
| Interiores e rótulos só dentro do prédio | `SchoolWorld._set_roof_hidden` |
| Alcance de visibilidade por área / objeto (ajustado pela qualidade) | `SchoolBuilder.AREA_RANGE`, `SchoolWorld._apply_quality` |
| Oclusores na murada | `SchoolBuilder._murada_segment` |
| Pool de sons, nada instanciado durante o jogo | `AudioManager` |
| Varreduras periódicas (0,1–0,2 s) em vez de por quadro | jogador, zonas, minimapa |
| Qualidade Baixa: sem sombras, 75 % de resolução 3D, sem névoa | `SchoolWorld._apply_quality` |

Medições (renderer de compatibilidade, qualidade Baixa): 50–110 mil triângulos e
~120–160 draw calls totais (incluindo a HUD) nos pontos mais carregados.
