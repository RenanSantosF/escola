class_name ShopCatalog
extends RefCounted
## Catálogo da loja. "look" = campos da CharacterAppearance aplicados ao equipar.
## Itens "consumable" não ficam no inventário (pacotes de figurinha/gude).

const CATEGORIES := [
	["skin", "Skins"], ["pacote", "Pacotes"], ["camiseta", "Camisetas"], ["calca", "Calças"], ["calcado", "Tênis"], ["mochila", "Mochilas"],
	["bone", "Bonés"], ["penteado", "Penteados"], ["acessorio", "Acessórios"], ["decoracao", "Decoração"],
	["gude", "Bolinhas de gude"], ["figurinha", "Figurinhas"], ["veiculo", "Skate e bike"], ["emote", "Emojis"],
	["aura", "Efeitos"], ["kart", "Karts"],
]

## Raridade: cor do cartão e da faixa.
const RARITY := {
	"comum": ["Comum", Color("7f8fa6")], "raro": ["Raro", Color("2f8be0")],
	"epico": ["Épico", Color("9b59ff")], "lendario": ["Lendário", Color("f5a623")],
}

## Skins: visual completo (substitui roupa, tênis, mochila e boné).
const SKINS := [
	{"id": "skin_nenhuma", "cat": "skin", "name": "Sem skin", "price": 0, "lvl": 1, "rarity": "comum", "look": {}},
	{"id": "skin_craque", "cat": "skin", "name": "Craque da Seleção", "price": 350, "lvl": 2, "rarity": "raro",
		"desc": "Camisa amarela, calção azul e chuteira de ouro.",
		"look": {"shirt_color": "ffd21f", "shirt_trim": "1f9e4a", "shirt_logo": true, "pants_color": "1f4fbf", "long_pants": false, "sock_color": "ffffff", "shoe_color": "f5c518", "shoe_sole": "1f1f1f", "backpack": false, "cap": false}},
	{"id": "skin_cientista", "cat": "skin", "name": "Cientista Maluco", "price": 420, "lvl": 3, "rarity": "raro",
		"desc": "Jaleco branco, óculos e tênis de laboratório.",
		"look": {"shirt_color": "fbfbfb", "shirt_trim": "36c5f0", "shirt_logo": false, "pants_color": "2c3e50", "long_pants": true, "shoe_color": "36c5f0", "backpack": true, "backpack_color": "7bd389", "glasses": true, "cap": false}},
	{"id": "skin_ninja", "cat": "skin", "name": "Ninja da Noite", "price": 600, "lvl": 4, "rarity": "epico",
		"desc": "Todo de preto com faixa vermelha. Silencioso no pega-pega!",
		"look": {"shirt_color": "1c1c24", "shirt_trim": "e0263a", "shirt_logo": false, "pants_color": "15151b", "long_pants": true, "sock_color": "15151b", "shoe_color": "15151b", "shoe_sole": "e0263a", "backpack": false, "cap": false}},
	{"id": "skin_heroi", "cat": "skin", "name": "Super-herói", "price": 750, "lvl": 5, "rarity": "epico",
		"desc": "Azul e vermelho, pronto para salvar o recreio.",
		"look": {"shirt_color": "1f5fd6", "shirt_trim": "e8202a", "shirt_logo": true, "pants_color": "e8202a", "long_pants": true, "shoe_color": "e8202a", "shoe_sole": "ffd21f", "backpack": true, "backpack_color": "e8202a", "cap": false}},
	{"id": "skin_astronauta", "cat": "skin", "name": "Astronauta", "price": 900, "lvl": 6, "rarity": "epico",
		"desc": "Macacão espacial branco com detalhes laranja.",
		"look": {"shirt_color": "f2f4f7", "shirt_trim": "ff7a1a", "shirt_logo": true, "pants_color": "e9edf2", "long_pants": true, "sock_color": "e9edf2", "shoe_color": "9aa3ad", "shoe_sole": "4a4f57", "backpack": true, "backpack_color": "dfe4ea", "cap": false}},
	{"id": "skin_explorador", "cat": "skin", "name": "Explorador da Floresta", "price": 500, "lvl": 4, "rarity": "raro",
		"desc": "Roupa cáqui, boné verde e mochila de aventura.",
		"look": {"shirt_color": "c9b27c", "shirt_trim": "6b5a2e", "shirt_logo": false, "pants_color": "7a6a3a", "long_pants": false, "sock_color": "6b5a2e", "shoe_color": "6b4423", "backpack": true, "backpack_color": "3f7a3a", "cap": true, "cap_color": "3f7a3a"}},
	{"id": "skin_galaxia", "cat": "skin", "name": "Galáxia Lendária", "price": 1600, "lvl": 8, "rarity": "lendario",
		"desc": "Roxo-galáxia com detalhes dourados. Pouquíssimos têm!",
		"look": {"shirt_color": "3b1f7a", "shirt_trim": "ffcf3f", "shirt_logo": true, "pants_color": "1d1145", "long_pants": true, "sock_color": "ffcf3f", "shoe_color": "ffcf3f", "shoe_sole": "3b1f7a", "backpack": true, "backpack_color": "7b3fe0", "cap": true, "cap_color": "ffcf3f"}},
	{"id": "skin_junina", "cat": "skin", "name": "Festa Junina", "price": 380, "lvl": 2, "rarity": "raro",
		"desc": "Camisa xadrez colorida, chapéu de palha... quase!",
		"look": {"shirt_color": "e04a3a", "shirt_trim": "ffd21f", "shirt_logo": false, "pants_color": "3f5f99", "long_pants": true, "shoe_color": "6b4423", "backpack": false, "cap": true, "cap_color": "e8c46a"}},
]

## Pacotes: vários itens com desconto.
const BUNDLES := [
	{"id": "pac_craque", "cat": "pacote", "name": "Kit Craque", "price": 210, "lvl": 3, "rarity": "raro", "bundle": ["cam_time", "ten_amarelo", "bon_azul"],
		"desc": "Camisa do time + tênis amarelo-ouro + boné azul"},
	{"id": "pac_estudioso", "cat": "pacote", "name": "Kit Estudioso", "price": 170, "lvl": 2, "rarity": "raro", "bundle": ["ace_oculos", "dec_planta", "dec_caneca", "dec_estojo"],
		"desc": "Óculos + plantinha + caneca + estojo para a carteira"},
	{"id": "pac_colorido", "cat": "pacote", "name": "Kit Arco-íris", "price": 190, "lvl": 3, "rarity": "raro", "bundle": ["cam_roxa", "moc_amarela", "ten_azul", "cal_verde"],
		"desc": "Roupa colorida completa"},
	{"id": "pac_colecao", "cat": "pacote", "name": "Mega pacote de coleção", "price": 70, "lvl": 1, "rarity": "comum", "consumable": true, "bundle_packs": {"figurinha": 3, "gude": 1},
		"desc": "3 pacotes de figurinha + 1 saquinho de gude"},
]

const ITEMS_BASE := [
	# camisetas
	{"id": "cam_uniforme", "cat": "camiseta", "name": "Uniforme da escola", "price": 0, "lvl": 1, "look": {"shirt_color": "f4f4f0", "shirt_trim": "2f6fd0", "shirt_logo": true}},
	{"id": "cam_uniforme_v", "cat": "camiseta", "name": "Uniforme gola vermelha", "price": 40, "lvl": 1, "look": {"shirt_color": "f4f4f0", "shirt_trim": "d63c3c", "shirt_logo": true}},
	{"id": "cam_amarela", "cat": "camiseta", "name": "Camiseta amarela", "price": 60, "lvl": 2, "look": {"shirt_color": "f2b632", "shirt_trim": "c98f12", "shirt_logo": false}},
	{"id": "cam_verde", "cat": "camiseta", "name": "Camiseta verde", "price": 60, "lvl": 2, "look": {"shirt_color": "3aa45b", "shirt_trim": "2a7a43", "shirt_logo": false}},
	{"id": "cam_roxa", "cat": "camiseta", "name": "Camiseta roxa", "price": 80, "lvl": 3, "look": {"shirt_color": "8e5bd1", "shirt_trim": "6a3fa8", "shirt_logo": false}},
	{"id": "cam_laranja", "cat": "camiseta", "name": "Camiseta laranja", "price": 80, "lvl": 3, "look": {"shirt_color": "ff8a3d", "shirt_trim": "d96a20", "shirt_logo": false}},
	{"id": "cam_time", "cat": "camiseta", "name": "Camisa do time", "price": 150, "lvl": 5, "look": {"shirt_color": "2f6fd0", "shirt_trim": "f2c230", "shirt_logo": true}},
	# calças
	{"id": "cal_bermuda", "cat": "calca", "name": "Bermuda azul-marinho", "price": 0, "lvl": 1, "look": {"pants_color": "23325c", "long_pants": false}},
	{"id": "cal_jeans", "cat": "calca", "name": "Calça jeans", "price": 70, "lvl": 1, "look": {"pants_color": "3f5f99", "long_pants": true}},
	{"id": "cal_preta", "cat": "calca", "name": "Bermuda preta", "price": 50, "lvl": 2, "look": {"pants_color": "2b2b2b", "long_pants": false}},
	{"id": "cal_marrom", "cat": "calca", "name": "Calça marrom", "price": 90, "lvl": 3, "look": {"pants_color": "6b4f2b", "long_pants": true}},
	{"id": "cal_verde", "cat": "calca", "name": "Calça verde", "price": 110, "lvl": 4, "look": {"pants_color": "2d5a3b", "long_pants": true}},
	# tênis
	{"id": "ten_branco", "cat": "calcado", "name": "Tênis branco", "price": 0, "lvl": 1, "look": {"shoe_color": "f2f2f2"}},
	{"id": "ten_preto", "cat": "calcado", "name": "Tênis preto", "price": 45, "lvl": 1, "look": {"shoe_color": "1f1f1f"}},
	{"id": "ten_vermelho", "cat": "calcado", "name": "Tênis vermelho", "price": 70, "lvl": 2, "look": {"shoe_color": "d63c3c"}},
	{"id": "ten_azul", "cat": "calcado", "name": "Tênis azul", "price": 70, "lvl": 2, "look": {"shoe_color": "2f6fd0"}},
	{"id": "ten_amarelo", "cat": "calcado", "name": "Tênis amarelo-ouro", "price": 160, "lvl": 5, "look": {"shoe_color": "f2c230"}},
	# mochilas
	{"id": "moc_vermelha", "cat": "mochila", "name": "Mochila vermelha", "price": 0, "lvl": 1, "look": {"backpack": true, "backpack_color": "d63c3c"}},
	{"id": "moc_azul", "cat": "mochila", "name": "Mochila azul", "price": 50, "lvl": 1, "look": {"backpack": true, "backpack_color": "2f6fd0"}},
	{"id": "moc_amarela", "cat": "mochila", "name": "Mochila amarela", "price": 60, "lvl": 2, "look": {"backpack": true, "backpack_color": "f2c230"}},
	{"id": "moc_rosa", "cat": "mochila", "name": "Mochila rosa", "price": 60, "lvl": 2, "look": {"backpack": true, "backpack_color": "ff7eb6"}},
	{"id": "moc_roxa", "cat": "mochila", "name": "Mochila roxa galáxia", "price": 140, "lvl": 4, "look": {"backpack": true, "backpack_color": "5b3fa0"}},
	{"id": "moc_nenhuma", "cat": "mochila", "name": "Sem mochila", "price": 0, "lvl": 1, "look": {"backpack": false}},
	# bonés
	{"id": "bon_nenhum", "cat": "bone", "name": "Sem boné", "price": 0, "lvl": 1, "look": {"cap": false}},
	{"id": "bon_azul", "cat": "bone", "name": "Boné azul", "price": 55, "lvl": 1, "look": {"cap": true, "cap_color": "2f6fd0"}},
	{"id": "bon_vermelho", "cat": "bone", "name": "Boné vermelho", "price": 55, "lvl": 2, "look": {"cap": true, "cap_color": "e04a3a"}},
	{"id": "bon_verde", "cat": "bone", "name": "Boné verde", "price": 75, "lvl": 3, "look": {"cap": true, "cap_color": "3aa45b"}},
	{"id": "bon_dourado", "cat": "bone", "name": "Boné dourado", "price": 200, "lvl": 6, "look": {"cap": true, "cap_color": "e8b923"}},
	# penteados
	{"id": "pen_curto", "cat": "penteado", "name": "Cabelo curto", "price": 0, "lvl": 1, "look": {"hair_style": "curto"}},
	{"id": "pen_espetado", "cat": "penteado", "name": "Espetado", "price": 40, "lvl": 1, "look": {"hair_style": "espetado"}},
	{"id": "pen_franja", "cat": "penteado", "name": "Franja", "price": 40, "lvl": 1, "look": {"hair_style": "franja"}},
	{"id": "pen_raspado", "cat": "penteado", "name": "Raspado", "price": 30, "lvl": 1, "look": {"hair_style": "raspado"}},
	{"id": "pen_longo", "cat": "penteado", "name": "Longo", "price": 60, "lvl": 2, "look": {"hair_style": "longo"}},
	{"id": "pen_rabo", "cat": "penteado", "name": "Rabo de cavalo", "price": 60, "lvl": 2, "look": {"hair_style": "rabo"}},
	{"id": "pen_cacheado", "cat": "penteado", "name": "Cacheado", "price": 70, "lvl": 2, "look": {"hair_style": "cacheado"}},
	{"id": "pen_black", "cat": "penteado", "name": "Black power", "price": 90, "lvl": 3, "look": {"hair_style": "black_power"}},
	{"id": "tin_castanho", "cat": "penteado", "name": "Cor: castanho", "price": 0, "lvl": 1, "look": {"hair_color": "3b2417"}},
	{"id": "tin_preto", "cat": "penteado", "name": "Cor: preto", "price": 25, "lvl": 1, "look": {"hair_color": "1d1612"}},
	{"id": "tin_loiro", "cat": "penteado", "name": "Cor: loiro", "price": 50, "lvl": 2, "look": {"hair_color": "d9b25f"}},
	{"id": "tin_ruivo", "cat": "penteado", "name": "Cor: ruivo", "price": 50, "lvl": 2, "look": {"hair_color": "a32e1d"}},
	{"id": "tin_azul", "cat": "penteado", "name": "Cor: azul (ousado!)", "price": 180, "lvl": 6, "look": {"hair_color": "2f6fd0"}},
	# acessórios
	{"id": "ace_sem_oculos", "cat": "acessorio", "name": "Sem óculos", "price": 0, "lvl": 1, "look": {"glasses": false}},
	{"id": "ace_oculos", "cat": "acessorio", "name": "Óculos de grau", "price": 65, "lvl": 1, "look": {"glasses": true}},
	# decoração da carteira (aparece na sua carteira da Sala 5)
	{"id": "dec_estojo", "cat": "decoracao", "name": "Estojo colorido", "price": 35, "lvl": 1, "decor": "estojo"},
	{"id": "dec_planta", "cat": "decoracao", "name": "Plantinha na carteira", "price": 60, "lvl": 2, "decor": "planta"},
	{"id": "dec_caneca", "cat": "decoracao", "name": "Caneca de lápis", "price": 45, "lvl": 2, "decor": "caneca"},
	{"id": "dec_globo", "cat": "decoracao", "name": "Mini globo", "price": 120, "lvl": 4, "decor": "globo"},
	{"id": "dec_trofeu", "cat": "decoracao", "name": "Mini troféu", "price": 220, "lvl": 6, "decor": "trofeu"},
	# veículos (caros: exigem dias de jogo)
	{"id": "vei_skate", "cat": "veiculo", "name": "Skate", "price": 900, "lvl": 4, "vehicle": "skate"},
	{"id": "vei_patinete", "cat": "veiculo", "name": "Patinete", "price": 1300, "lvl": 5, "vehicle": "patinete"},
	{"id": "vei_bike", "cat": "veiculo", "name": "Bicicleta", "price": 2000, "lvl": 6, "vehicle": "bike"},
	# consumíveis
	{"id": "gude_saco", "cat": "gude", "name": "Saquinho com 3 bolinhas", "price": 30, "lvl": 1, "consumable": true},
	{"id": "fig_pacote", "cat": "figurinha", "name": "Pacote com 4 figurinhas", "price": 25, "lvl": 1, "consumable": true},
	# mais roupas
	{"id": "cam_azul_ceu", "cat": "camiseta", "name": "Camiseta azul-céu", "price": 70, "lvl": 2, "look": {"shirt_color": "5ec8ff", "shirt_trim": "2f8be0", "shirt_logo": false}},
	{"id": "cam_rosa", "cat": "camiseta", "name": "Camiseta rosa-chiclete", "price": 70, "lvl": 2, "look": {"shirt_color": "ff7eb6", "shirt_trim": "e0558f", "shirt_logo": false}},
	{"id": "cam_preta", "cat": "camiseta", "name": "Camiseta preta estilosa", "price": 95, "lvl": 3, "look": {"shirt_color": "23232b", "shirt_trim": "ffcf3f", "shirt_logo": true}},
	{"id": "cam_menta", "cat": "camiseta", "name": "Camiseta verde-menta", "price": 85, "lvl": 3, "look": {"shirt_color": "7bdcb5", "shirt_trim": "3aa98a", "shirt_logo": false}},
	{"id": "ten_rosa", "cat": "calcado", "name": "Tênis rosa", "price": 75, "lvl": 2, "look": {"shoe_color": "ff7eb6"}},
	{"id": "ten_verde", "cat": "calcado", "name": "Tênis verde-limão", "price": 85, "lvl": 3, "look": {"shoe_color": "9be15d"}},
	{"id": "moc_verde", "cat": "mochila", "name": "Mochila verde", "price": 60, "lvl": 2, "look": {"backpack": true, "backpack_color": "3aa45b"}},
	{"id": "moc_preta", "cat": "mochila", "name": "Mochila preta", "price": 70, "lvl": 3, "look": {"backpack": true, "backpack_color": "23232b"}},
	{"id": "bon_rosa", "cat": "bone", "name": "Boné rosa", "price": 60, "lvl": 2, "look": {"cap": true, "cap_color": "ff7eb6"}},
	{"id": "bon_preto", "cat": "bone", "name": "Boné preto", "price": 65, "lvl": 3, "look": {"cap": true, "cap_color": "23232b"}},
	{"id": "tin_rosa", "cat": "penteado", "name": "Cor: rosa", "price": 160, "lvl": 5, "look": {"hair_color": "ff7eb6"}},
	{"id": "tin_verde", "cat": "penteado", "name": "Cor: verde", "price": 160, "lvl": 5, "look": {"hair_color": "3aa45b"}},
]

## Emojis (reações): só "Acenar" vem de graça; os outros se compram.
const EMOTES := [
	{"id": "emo_wave", "cat": "emote", "name": "Acenar", "price": 0, "lvl": 1, "emote": "wave", "desc": "Dá tchau para a turma."},
	{"id": "emo_clap", "cat": "emote", "name": "Palmas", "price": 60, "lvl": 1, "emote": "clap", "desc": "Aplausos para o colega."},
	{"id": "emo_raise_hand", "cat": "emote", "name": "Levantar a mão", "price": 50, "lvl": 1, "emote": "raise_hand", "desc": "Eu sei! Eu sei!"},
	{"id": "emo_celebrate", "cat": "emote", "name": "Comemorar", "price": 90, "lvl": 2, "emote": "celebrate", "rarity": "raro", "desc": "Pula de alegria com confete."},
	{"id": "emo_sad", "cat": "emote", "name": "Ficar triste", "price": 50, "lvl": 1, "emote": "sad", "desc": "Ah, não..."},
	{"id": "emo_stretch", "cat": "emote", "name": "Espreguiçar", "price": 70, "lvl": 2, "emote": "stretch", "desc": "Que soninho na aula..."},
	{"id": "emo_scratch", "cat": "emote", "name": "Coçar a cabeça", "price": 70, "lvl": 3, "emote": "scratch_head", "desc": "Hmm, pensando..."},
	{"id": "emo_look", "cat": "emote", "name": "Olhar em volta", "price": 60, "lvl": 3, "emote": "look_around", "desc": "Cadê todo mundo?"},
	# ANIMADOS (dancinha + figura animada em cima da cabeça). Caros na loja:
	# no Passe do Recreio saem bem mais em conta.
	{"id": "emo_dance", "cat": "emote", "name": "Dancinha", "price": 900, "lvl": 2, "emote": "dance", "rarity": "epico", "animated": true, "desc": "Rebola com notinhas musicais pulando!"},
	{"id": "emo_laugh", "cat": "emote", "name": "Gargalhada", "price": 800, "lvl": 2, "emote": "laugh", "rarity": "epico", "animated": true, "desc": "Ri até chorar (com carinha animada)."},
	{"id": "emo_heart", "cat": "emote", "name": "Coração", "price": 850, "lvl": 2, "emote": "heart_hands", "rarity": "epico", "animated": true, "desc": "Coração com as mãos e coraçõezinhos subindo."},
	{"id": "emo_robot", "cat": "emote", "name": "Dança do robô", "price": 1200, "lvl": 3, "emote": "robot", "rarity": "lendario", "animated": true, "desc": "Bip bop! Com raio elétrico piscando."},
	# só no passe
	{"id": "emo_floss", "cat": "emote", "name": "Fio dental", "price": 0, "lvl": 1, "emote": "floss", "rarity": "lendario", "animated": true, "pass": true, "desc": "A dança mais famosa do recreio, com estrela girando."},
	{"id": "emo_spin", "cat": "emote", "name": "Pirueta arco-íris", "price": 0, "lvl": 1, "emote": "spin_jump", "rarity": "lendario", "animated": true, "pass": true, "desc": "Pulo com giro e arco-íris!"},
	{"id": "emo_flex", "cat": "emote", "name": "Campeão", "price": 0, "lvl": 1, "emote": "flex", "rarity": "epico", "animated": true, "pass": true, "desc": "Mostra os músculos com uma coroa dourada."},
]

## Efeitos (auras): partículas em volta do personagem. Todos veem online.
const AURAS := [
	{"id": "aura_nenhuma", "cat": "aura", "name": "Sem efeito", "price": 0, "lvl": 1, "rarity": "comum", "look": {"aura": ""}},
	{"id": "aura_estrelas", "cat": "aura", "name": "Poeira de estrelas", "price": 1800, "lvl": 4, "rarity": "lendario", "look": {"aura": "estrelas"}, "desc": "Estrelinhas douradas sobem em volta de você."},
	{"id": "aura_coracoes", "cat": "aura", "name": "Chuva de corações", "price": 1600, "lvl": 3, "rarity": "lendario", "look": {"aura": "coracoes"}, "desc": "Coraçõezinhos flutuando o tempo todo."},
	{"id": "aura_neve", "cat": "aura", "name": "Floquinhos de neve", "price": 1500, "lvl": 3, "rarity": "epico", "look": {"aura": "neve"}, "desc": "Neve caindo só em você!"},
	{"id": "aura_fogo", "cat": "aura", "name": "Chamas de campeão", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true, "look": {"aura": "fogo"}, "desc": "Faíscas de fogo (exclusivo do passe)."},
	{"id": "aura_arco", "cat": "aura", "name": "Aura arco-íris", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true, "look": {"aura": "arco_iris"}, "desc": "Todas as cores ao seu redor (exclusivo do passe)."},
	{"id": "aura_raio", "cat": "aura", "name": "Energia elétrica", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true, "look": {"aura": "raio"}, "desc": "Raios azuis faiscando (exclusivo do passe)."},
]

## Skins exclusivas do Passe do Recreio (não se compram com moedas).
const PASS_SKINS := [
	{"id": "skin_dragao", "cat": "skin", "name": "Dragão Dourado", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true,
		"desc": "Verde-esmeralda com escamas douradas. Só no passe!",
		"look": {"shirt_color": "1e8f4e", "shirt_trim": "ffcf3f", "shirt_logo": true, "pants_color": "145c33", "long_pants": true, "sock_color": "ffcf3f", "shoe_color": "ffcf3f", "shoe_sole": "145c33", "backpack": true, "backpack_color": "ffcf3f", "cap": false, "aura": "fogo"}},
	{"id": "skin_neon", "cat": "skin", "name": "Robô Neon", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true,
		"desc": "Prata com luzes azuis e energia elétrica.",
		"look": {"shirt_color": "cfd8e3", "shirt_trim": "00e5ff", "shirt_logo": true, "pants_color": "37474f", "long_pants": true, "sock_color": "00e5ff", "shoe_color": "00e5ff", "shoe_sole": "263238", "backpack": true, "backpack_color": "90a4ae", "cap": false, "glasses": true, "aura": "raio"}},
	{"id": "skin_unicornio", "cat": "skin", "name": "Unicórnio Mágico", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true,
		"desc": "Branco, rosa e lilás com arco-íris.",
		"look": {"shirt_color": "fff4fb", "shirt_trim": "ff6fae", "shirt_logo": true, "pants_color": "c39bff", "long_pants": true, "sock_color": "ff6fae", "shoe_color": "ff6fae", "shoe_sole": "ffffff", "backpack": true, "backpack_color": "c39bff", "cap": false, "hair_color": "ff8fcf", "aura": "arco_iris"}},
	{"id": "skin_pirata", "cat": "skin", "name": "Capitão Pirata", "price": 0, "lvl": 1, "rarity": "epico", "pass": true,
		"desc": "Listras, faixa vermelha e botas.",
		"look": {"shirt_color": "f4efe6", "shirt_trim": "c62828", "shirt_logo": false, "pants_color": "263238", "long_pants": true, "sock_color": "263238", "shoe_color": "3e2723", "shoe_sole": "1b1b1b", "backpack": false, "cap": true, "cap_color": "212121"}},
]

## Itens especiais pagos com DIAMANTES (campo "diamonds" = preço em diamantes).
const DIAMOND_ITEMS := [
	{"id": "skin_cavaleiro", "cat": "skin", "name": "Cavaleiro Dourado", "price": 0, "diamonds": 250, "lvl": 1, "rarity": "lendario",
		"desc": "Armadura prateada com faixa dourada e brilho de ouro. Vem também no Pacote de Boas-vindas!",
		"look": {"shirt_color": "c9d1db", "shirt_trim": "ffcf3f", "shirt_logo": true, "shirt_pattern": "faixa", "pants_color": "7b8794", "long_pants": true, "sock_color": "ffcf3f", "shoe_color": "ffcf3f", "shoe_sole": "5d6670", "backpack": true, "backpack_color": "b0bac5", "cap": false, "aura": "dourada"}},
	{"id": "skin_princesa", "cat": "skin", "name": "Princesa Estelar", "price": 0, "diamonds": 280, "lvl": 1, "rarity": "lendario",
		"desc": "Lilás com estrela no peito, cabelo rosa e estrelinhas em volta.",
		"look": {"shirt_color": "b98cff", "shirt_trim": "ffcf3f", "shirt_logo": false, "shirt_pattern": "estrela", "pants_color": "8e5bd1", "long_pants": true, "sock_color": "ffffff", "shoe_color": "ff8fcf", "shoe_sole": "ffffff", "backpack": true, "backpack_color": "ff8fcf", "cap": false, "hair_color": "ff8fcf", "aura": "estrelas"}},
	{"id": "skin_craque_neon", "cat": "skin", "name": "Craque Neon", "price": 0, "diamonds": 200, "lvl": 1, "rarity": "lendario",
		"desc": "Camisa listrada preta e verde-neon com raios elétricos.",
		"look": {"shirt_color": "1c1c24", "shirt_trim": "39ff88", "shirt_logo": true, "shirt_pattern": "listras", "pants_color": "1c1c24", "long_pants": false, "sock_color": "39ff88", "shoe_color": "39ff88", "shoe_sole": "1c1c24", "backpack": false, "cap": false, "aura": "raio"}},
	{"id": "skin_bombeiro", "cat": "skin", "name": "Bombeiro Herói", "price": 0, "diamonds": 160, "lvl": 1, "rarity": "epico",
		"desc": "Vermelho com faixa refletiva amarela. Pronto para salvar o dia!",
		"look": {"shirt_color": "d32f2f", "shirt_trim": "ffd23f", "shirt_logo": false, "shirt_pattern": "faixa", "pants_color": "263238", "long_pants": true, "sock_color": "263238", "shoe_color": "212121", "shoe_sole": "ffd23f", "backpack": true, "backpack_color": "b71c1c", "cap": true, "cap_color": "d32f2f"}},
	{"id": "skin_chef", "cat": "skin", "name": "Chef Confeiteiro", "price": 0, "diamonds": 140, "lvl": 1, "rarity": "epico",
		"desc": "Dólmã branco xadrez e boné de cozinheiro. Hummm, bolo!",
		"look": {"shirt_color": "fbfbfb", "shirt_trim": "e0e0e0", "shirt_logo": false, "shirt_pattern": "xadrez", "pants_color": "37474f", "long_pants": true, "shoe_color": "fbfbfb", "shoe_sole": "9e9e9e", "backpack": false, "cap": true, "cap_color": "fbfbfb", "aura": "coracoes"}},
	{"id": "aura_dourada", "cat": "aura", "name": "Brilho de ouro", "price": 0, "diamonds": 150, "lvl": 1, "rarity": "lendario", "look": {"aura": "dourada"}, "desc": "Faíscas douradas o tempo todo. Todo mundo vai ver!"},
	{"id": "aura_bolhas", "cat": "aura", "name": "Bolhas de sabão", "price": 0, "diamonds": 120, "lvl": 1, "rarity": "epico", "look": {"aura": "bolhas"}, "desc": "Bolhinhas subindo em volta de você."},
	{"id": "aura_notas", "cat": "aura", "name": "Música no ar", "price": 0, "diamonds": 130, "lvl": 1, "rarity": "epico", "look": {"aura": "notas"}, "desc": "Notinhas musicais dançando ao seu redor."},
	{"id": "emo_backflip", "cat": "emote", "name": "Mortal para trás", "price": 0, "diamonds": 90, "lvl": 1, "emote": "backflip", "rarity": "lendario", "animated": true, "desc": "Um mortal de verdade com estrela girando!"},
	{"id": "emo_guitar", "cat": "emote", "name": "Guitarra imaginária", "price": 0, "diamonds": 80, "lvl": 1, "emote": "air_guitar", "rarity": "epico", "animated": true, "desc": "Solo de guitarra com notas musicais."},
]

## Mais roupas e skins com estampa (moedas).
const MORE_ITEMS := [
	{"id": "cam_listrada", "cat": "camiseta", "name": "Camiseta listrada", "price": 120, "lvl": 2, "rarity": "raro", "look": {"shirt_color": "f4f4f0", "shirt_trim": "2f80ed", "shirt_logo": false, "shirt_pattern": "listras"}},
	{"id": "cam_xadrez", "cat": "camiseta", "name": "Camisa xadrez", "price": 130, "lvl": 2, "rarity": "raro", "look": {"shirt_color": "e04a3a", "shirt_trim": "1d1d1d", "shirt_logo": false, "shirt_pattern": "xadrez"}},
	{"id": "cam_degrade", "cat": "camiseta", "name": "Camiseta pôr do sol", "price": 160, "lvl": 3, "rarity": "raro", "look": {"shirt_color": "ff8a1f", "shirt_trim": "8e44ad", "shirt_logo": false, "shirt_pattern": "degrade"}},
	{"id": "cam_raio", "cat": "camiseta", "name": "Camiseta do raio", "price": 180, "lvl": 3, "rarity": "raro", "look": {"shirt_color": "2f80ed", "shirt_trim": "ffd23f", "shirt_logo": false, "shirt_pattern": "raio"}},
	{"id": "cam_estrela", "cat": "camiseta", "name": "Camiseta estrela", "price": 200, "lvl": 4, "rarity": "raro", "look": {"shirt_color": "1c1c24", "shirt_trim": "ffd23f", "shirt_logo": false, "shirt_pattern": "estrela"}},
	{"id": "cam_time_faixa", "cat": "camiseta", "name": "Camisa de time com faixa", "price": 240, "lvl": 5, "rarity": "epico", "look": {"shirt_color": "f4f4f0", "shirt_trim": "1f9e4a", "shirt_logo": true, "shirt_pattern": "faixa"}},
	{"id": "skin_surfista", "cat": "skin", "name": "Surfista", "price": 650, "lvl": 4, "rarity": "epico", "desc": "Camiseta degradê do mar, bermuda e boné virado.",
		"look": {"shirt_color": "3ec1d3", "shirt_trim": "1f5fd6", "shirt_logo": false, "shirt_pattern": "degrade", "pants_color": "ff8a1f", "long_pants": false, "sock_color": "ffffff", "shoe_color": "ffd23f", "backpack": false, "cap": true, "cap_color": "ffd23f"}},
	{"id": "skin_rock", "cat": "skin", "name": "Estrela do Rock", "price": 700, "lvl": 4, "rarity": "epico", "desc": "Preto com raio vermelho. Rock no recreio!",
		"look": {"shirt_color": "1c1c24", "shirt_trim": "e0263a", "shirt_logo": false, "shirt_pattern": "raio", "pants_color": "2b2b2b", "long_pants": true, "shoe_color": "1c1c24", "shoe_sole": "e0263a", "backpack": false, "cap": false, "glasses": true}},
	{"id": "skin_tigre", "cat": "skin", "name": "Tigre", "price": 800, "lvl": 5, "rarity": "epico", "desc": "Laranja com listras pretas. Rawr!",
		"look": {"shirt_color": "ff8a1f", "shirt_trim": "1d1d1d", "shirt_logo": false, "shirt_pattern": "listras", "pants_color": "ff8a1f", "long_pants": true, "sock_color": "1d1d1d", "shoe_color": "1d1d1d", "backpack": false, "cap": false}},
	{"id": "kart_padrao", "cat": "kart", "name": "Kart da Escola", "price": 0, "lvl": 1, "rarity": "comum", "kart": {"color": "", "accent": "ffffff", "style": ""}, "desc": "O kart de todo mundo: na corrida ele ganha a cor do seu lugar no grid."},
	# Karts com DESIGN só no Passe do Recreio (todos andam igual: é só beleza!)
	{"id": "kart_turbo", "cat": "kart", "name": "Kart Turbo V8", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true, "kart": {"color": "e0263a", "accent": "ffd23f", "style": "listras", "body": "turbo"}, "desc": "Aerofólio gigante e carburadores cromados. Exclusivo do passe!"},
	{"id": "kart_neon", "cat": "kart", "name": "Kart Neon", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true, "kart": {"color": "263238", "accent": "00e5ff", "style": "listras", "body": "neon"}, "desc": "Luz neon embaixo do kart e aerofólio iluminado. Exclusivo do passe!"},
	{"id": "kart_foguete", "cat": "kart", "name": "Kart Foguete", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true, "kart": {"color": "eceff1", "accent": "e53935", "style": "", "body": "foguete"}, "desc": "Bico de foguete, aletas e turbina com fogo. Exclusivo do passe!"},
	{"id": "kart_arco", "cat": "kart", "name": "Kart Arco-íris", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true, "kart": {"color": "ffffff", "accent": "ff6fae", "style": "arco", "body": "esportivo"}, "desc": "Exclusivo do passe!"},
	{"id": "kart_campeao", "cat": "kart", "name": "Kart Campeão", "price": 0, "lvl": 1, "rarity": "lendario", "pass": true, "kart": {"color": "1d1d1d", "accent": "ffcf3f", "style": "xadrez", "body": "campeao"}, "desc": "Bico comprido, asa dupla e detalhes de ouro. Exclusivo do passe!"},
	{"id": "kart_esportivo", "cat": "kart", "name": "Kart Esportivo", "price": 0, "lvl": 1, "rarity": "epico", "pass": true, "kart": {"color": "2f80ed", "accent": "ffffff", "style": "listras", "body": "esportivo"}, "desc": "Prêmio do último nível do passe (grátis)!"},
	# karts antigos (quem já tinha continua com eles; não aparecem mais na loja)
	{"id": "kart_azul", "cat": "kart", "name": "Kart Azul Turbo", "price": 0, "lvl": 1, "rarity": "raro", "legacy": true, "kart": {"color": "2f80ed", "accent": "ffffff", "style": "listras"}},
	{"id": "kart_verde", "cat": "kart", "name": "Kart Verde Limão", "price": 0, "lvl": 1, "rarity": "raro", "legacy": true, "kart": {"color": "9be15d", "accent": "1d1d1d", "style": "xadrez"}},
	{"id": "kart_chamas", "cat": "kart", "name": "Kart Chamas", "price": 0, "lvl": 1, "rarity": "epico", "legacy": true, "kart": {"color": "1d1d1d", "accent": "ff7a1a", "style": "chamas"}},
	{"id": "kart_dourado", "cat": "kart", "name": "Kart Dourado", "price": 0, "lvl": 1, "rarity": "lendario", "legacy": true, "kart": {"color": "ffcf3f", "accent": "ffffff", "style": "listras"}},
	{"id": "kart_galaxia", "cat": "kart", "name": "Kart Galáxia", "price": 0, "lvl": 1, "rarity": "lendario", "legacy": true, "kart": {"color": "3b1f7a", "accent": "ffcf3f", "style": "estrelas"}},
]

static var ITEMS: Array = SKINS + PASS_SKINS + DIAMOND_ITEMS + MORE_ITEMS + BUNDLES + ITEMS_BASE + EMOTES + AURAS


## Emojis que o jogador tem: [[nome, emote], ...].
static func owned_emotes() -> Array:
	var inv: Dictionary = SaveManager.section("inventory")
	var owned: Array = inv.get("owned", [])
	var out: Array = []
	# todos os itens com emoji (inclusive os de diamante, como o mortal e a guitarra)
	for e in ITEMS:
		if e.has("emote") and (e.id == "emo_wave" or e.id in owned):
			out.append([e.name, e.emote])
	return out

const DEFAULT_OWNED := ["skin_nenhuma", "cam_uniforme", "cal_bermuda", "ten_branco", "moc_vermelha", "moc_nenhuma", "bon_nenhum",
	"pen_curto", "tin_castanho", "ace_sem_oculos", "emo_wave", "aura_nenhuma", "kart_padrao"]


## Itens que também dá para ganhar assistindo vídeos premiados (id -> quantos vídeos).
const AD_ITEMS := {
	"cam_amarela": 1, "moc_amarela": 1, "bon_vermelho": 1, "ten_vermelho": 1, "dec_estojo": 1,
	"pen_cacheado": 2, "tin_ruivo": 2, "emo_celebrate": 2, "cam_roxa": 2, "moc_rosa": 2,
	"cam_time": 3, "dec_globo": 3, "ten_amarelo": 3,
	"bon_dourado": 4, "tin_azul": 4, "skin_junina": 5,
}


static func ad_cost(id: String) -> int:
	return int(AD_ITEMS.get(id, 0))


## Itens que saíram da loja (menos coisas, mas bem feitas): quem já comprou
## continua usando; para os outros eles não aparecem mais.
const RETIRED := ["cam_uniforme_v", "cam_verde", "cam_azul_ceu", "cam_menta", "cam_xadrez", "cam_degrade",
	"pen_raspado", "pen_franja", "tin_preto", "tin_verde",
	"skin_explorador", "skin_chef", "skin_craque_neon",
	"emo_scratch", "emo_look", "emo_stretch", "emo_sad",
	"moc_verde", "moc_preta", "bon_verde", "bon_preto", "ten_verde", "ten_rosa",
	"aura_notas", "cal_marrom"]


static func is_retired(i: Dictionary) -> bool:
	return i.get("legacy", false) or str(i.get("id", "")) in RETIRED


static func by_cat(cat: String) -> Array:
	# itens antigos/aposentados só aparecem para quem já tem
	return ITEMS.filter(func(i): return i.cat == cat and (not is_retired(i) or Progression.owns(i.id)))


static func get_item(id: String) -> Dictionary:
	for i in ITEMS:
		if i.id == id:
			return i
	return {}


## Preço em diamantes (0 = não é item de diamante).
static func diamonds_of(item: Dictionary) -> int:
	return int(item.get("diamonds", 0))


static func rarity_of(item: Dictionary) -> String:
	if item.has("rarity"):
		return item.rarity
	var p := int(item.get("price", 0))
	if p >= 900:
		return "lendario" if p >= 1500 else "epico"
	if p >= 140:
		return "raro"
	return "comum"


# ------------------------------------------------------------- promoções

## Ofertas do dia (mudam todo dia, no calendário real): 3 itens com
## 20–40% de desconto + 1 oferta relâmpago com 50%.
static func deals(date_key := "") -> Dictionary:
	if date_key == "":
		date_key = Time.get_date_string_from_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ofertas-" + date_key)
	var pool := ITEMS.filter(func(i): return int(i.get("price", 0)) >= 50 and not i.get("consumable", false) and i.cat != "veiculo" and not is_retired(i))
	var out := {}
	var tries := 0
	while out.size() < 4 and tries < 60:
		tries += 1
		var it: Dictionary = pool[rng.randi() % pool.size()]
		if out.has(it.id):
			continue
		out[it.id] = 50 if out.is_empty() else [20, 25, 30, 40][rng.randi() % 4]
	return out


static func flash_deal_id(date_key := "") -> String:
	var d := deals(date_key)
	for k in d.keys():
		if int(d[k]) == 50:
			return k
	return ""


## Preço com desconto do dia (o que a criança paga de verdade).
static func price_of(item: Dictionary, date_key := "") -> int:
	var base := int(item.get("price", 0))
	var off := int(deals(date_key).get(item.get("id", ""), 0))
	return int(round(base * (100 - off) / 100.0)) if off > 0 else base


static func discount_of(id: String, date_key := "") -> int:
	return int(deals(date_key).get(id, 0))


## Segundos até a meia-noite (fim das ofertas do dia).
static func seconds_to_midnight() -> int:
	var t := Time.get_time_dict_from_system()
	return 86400 - (int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second))


## Valor somado dos itens de um pacote (para mostrar a economia).
static func bundle_value(item: Dictionary) -> int:
	var v := 0
	for id in item.get("bundle", []):
		v += int(get_item(id).get("price", 0))
	for k in item.get("bundle_packs", {}).keys():
		v += int(item.bundle_packs[k]) * (25 if k == "figurinha" else 30)
	return v


## Cor representativa para o cartão da loja.
static func swatch(item: Dictionary) -> Color:
	var look: Dictionary = item.get("look", {})
	for k in ["shirt_color", "pants_color", "shoe_color", "backpack_color", "cap_color", "hair_color"]:
		if look.has(k):
			return Color(look[k])
	match item.cat:
		"skin": return Color(item.get("look", {}).get("shirt_color", "9b59ff"))
		"pacote": return Color("ff8a3d")
		"decoracao": return Color("a0663a")
		"gude": return Color("3fa7d6")
		"figurinha": return Color("f2b632")
		"veiculo": return Color("e74c3c")
		"penteado": return Color("3b2417")
		"acessorio": return Color("1c1c1c")
	return Color("cccccc")
