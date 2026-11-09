class_name ChatFilter
## Filtro de chat local (espelho de server/src/chat_filter.js). O servidor
## sempre filtra de novo — este evita mandar o que seria bloqueado.

const BAD_WORDS := [
	"porra", "caralho", "merda", "bosta", "puta", "puto", "foda", "foder", "fodase", "cacete", "buceta", "boceta",
	"pinto", "piroca", "rola", "cu", "cuzao", "arrombado", "viado", "veado", "bicha", "otario", "babaca", "idiota",
	"imbecil", "retardado", "mongol", "burro", "lixo", "feio", "gordo", "baleia", "macaco", "vagabundo", "vagabunda",
	"piranha", "safado", "safada", "desgracado", "desgraca", "corno", "trouxa", "escroto", "nojento", "chupa", "mamar",
	"sexo", "pelado", "pelada", "nude", "nudes", "matar", "morre", "morra", "suicidio", "droga", "maconha", "cocaina",
]
const WHOLE_ONLY := ["cu", "rola", "puto", "burro", "lixo", "feio", "gordo", "pinto", "chupa", "droga", "matar"]
const LEET := {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "@": "a", "$": "s", "!": "i", "|": "i"}
const ACCENTS := {"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "é": "e", "ê": "e", "è": "e", "í": "i", "ì": "i",
	"ó": "o", "ô": "o", "õ": "o", "ò": "o", "ú": "u", "ü": "u", "ù": "u", "ç": "c"}
const PERSONAL := [
	["(\\+?55)?\\s*\\(?\\d{2}\\)?\\s*9?\\d{4}[-.\\s]?\\d{4}", "telefone"],
	["\\d{8,}", "número"],
	["[\\w.+-]+@[\\w-]+\\.[\\w.]+", "e-mail"],
	["(https?://|www\\.|\\.com\\b|\\.net\\b|\\.br\\b|discord|whats|zap|insta|tiktok|telegram|snap)", "links"],
	["(^|\\s)@\\w{3,}", "perfis"],
	["\\b(rua|avenida|av\\.|travessa|apto|apartamento|cep)\\b", "endereço"],
	["\\b(meu|minha)\\s+(endereco|telefone|numero|senha|escola fica)\\b", "dados pessoais"],
	["\\b(onde voce mora|onde vc mora|qual (sua|tua) escola|manda foto|me passa (seu|teu))\\b", "dados pessoais"],
]


static func strip_accents(s: String) -> String:
	var out := ""
	for ch in s:
		out += ACCENTS.get(ch, ch)
	return out


static func _dedupe(s: String) -> String:
	var out := ""
	for ch in s:
		if out.is_empty() or out[out.length() - 1] != ch:
			out += ch
	return out


static func normalize(text: String) -> String:
	var s := strip_accents(text.to_lower())
	var out := ""
	for ch in s:
		out += LEET.get(ch, ch)
	return out


static func _has_bad(norm: String) -> bool:
	var re := RegEx.create_from_string("[^a-z]+")
	var words := re.sub(norm, " ", true).split(" ", false)
	for w in words:
		var wc := _dedupe(w)
		for bad in BAD_WORDS:
			var bc := _dedupe(bad)
			if bad in WHOLE_ONLY:
				if wc == bc:
					return true
			elif wc.contains(bc):
				return true
	var compact := _dedupe(re.sub(norm, "", true))
	for bad in BAD_WORDS:
		if bad in WHOLE_ONLY or bad.length() < 5:
			continue
		if compact.contains(_dedupe(bad)):
			return true
	return false


## Retorna {ok, text, reason}.
static func check(text: String, max_len := 80) -> Dictionary:
	var raw := text.strip_edges().substr(0, max_len)
	if raw == "":
		return {"ok": false, "text": "", "reason": "Mensagem vazia."}
	var plain := strip_accents(raw.to_lower())
	for p in PERSONAL:
		var re := RegEx.create_from_string("(?i)" + p[0])
		if re.search(plain) != null:
			return {"ok": false, "text": "", "reason": "Para sua segurança, não compartilhe %s." % p[1]}
	if _has_bad(normalize(raw)):
		return {"ok": false, "text": "", "reason": "Mensagem bloqueada: linguagem inadequada."}
	return {"ok": true, "text": raw}
