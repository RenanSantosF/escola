extends RefCounted
## Provedor de anúncios FALSO usado apenas nos testes automatizados.

var shown_rewarded := 0
var shown_interstitial := 0


func is_rewarded_ready() -> bool:
	return true


func show_rewarded(_unit: String, ok: Callable, _fail: Callable) -> void:
	shown_rewarded += 1
	ok.call()


func is_interstitial_ready() -> bool:
	return true


func show_interstitial(_unit: String) -> void:
	shown_interstitial += 1
