extends Node
## Só espera a abertura FT (autoload) terminar e fecha. Usado com --write-movie
## para gerar o vídeo da abertura (para jogos que não são Godot).
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("ffe27f"))
	await get_tree().create_timer(1.85).timeout
	get_tree().quit()
