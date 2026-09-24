class_name OnlineMatchmaker
extends Node
## Pede uma partida online ao matchmaker (projeto separado `nephelia-server`, Node.js):
##   POST <SERVICE_URL>/v1/matchmake  {"version":1,"name":"Alex","platform":"ios"}
##   200 {"host":"1.2.3.4","port":24700,"match":"m1","ticket":"..."}                (ENet, VPS)
##   200 {"url":"wss://nephelia.onrender.com/play/m1","match":"m1","ticket":"..."}  (WebSocket, Render)
## e devolve onde conectar (`found`) ou por que não deu (`failed`, texto em inglês para a tela).
## Quem conecta depois é a sala (Lobby), pelo mesmo caminho da partida no Wi-Fi.

## `host` é o endereço (ENet) ou a URL "wss://..." (WebSocket; aí `port` = 0).
signal found(host: String, port: int)
signal failed(reason: String)

## Endereço do matchmaker no ar (vazio = o botão PLAY ONLINE não aparece). Preencher quando o
## servidor estiver na nuvem (ex.: "http://<ip-da-oracle>:8080").
const SERVICE_URL := ""
## Espera no máximo isto pela resposta (abrir uma partida nova leva alguns segundos).
const TIMEOUT_SECONDS: float = 40.0

var _http: HTTPRequest


## Endereço usado agora: `--matchmaker=<url>` na linha de comando (testes, servidor de teste) ou
## `SERVICE_URL`.
static func service_url() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--matchmaker="):
			return arg.substr("--matchmaker=".length())
	return SERVICE_URL


static func is_available() -> bool:
	return not service_url().is_empty()


## Plataforma para as estatísticas do matchmaker.
static func platform() -> String:
	match OS.get_name():
		"iOS":
			return "ios"
		"Android":
			return "android"
		"Windows":
			return "windows"
		"macOS":
			return "macos"
		"Linux", "FreeBSD":
			return "linux"
	return "other"


## Pede a partida (a resposta chega por `found` ou `failed`).
func request_match(player_name: String) -> void:
	request_match_at(service_url(), player_name)


## Pede a partida a um matchmaker em `url` (testes).
func request_match_at(url: String, player_name: String) -> void:
	cancel()
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	var body: String = JSON.stringify({"version": NetMessage.VERSION, "name": player_name,
			"platform": platform()})
	var err: Error = _http.request(url + "/v1/matchmake", ["Content-Type: application/json"],
			HTTPClient.METHOD_POST, body)
	if err != OK:
		_finish_failed("Could not reach the online service.")


## Desiste do pedido (a pessoa voltou).
func cancel() -> void:
	if _http != null:
		_http.cancel_request()
		_http.queue_free()
		_http = null


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	_http = null
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Could not reach the online service. Check your internet.")
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if code == 200 and data is Dictionary:
		var answer: Dictionary = data
		var url: String = str(answer.get("url", ""))
		if url.begins_with("wss://") or url.begins_with("ws://"):
			found.emit(url, 0)
			return
		if answer.get("host") is String and answer.get("port") is float:
			found.emit(answer["host"], int(answer["port"]))
			return
	failed.emit(message_for(code))


## Texto na tela para cada resposta de erro do matchmaker.
static func message_for(code: int) -> String:
	match code:
		426:
			return "A new version of Nephelia is out. Update the game to play online."
		429:
			return "Too many tries. Wait a moment and try again."
		503:
			return "All online matches are full right now. Try again soon."
		502:
			return "The match could not start. Try again."
	return "The online service is not answering (%d). Try again later." % code


func _finish_failed(reason: String) -> void:
	if _http != null:
		_http.queue_free()
		_http = null
	failed.emit.call_deferred(reason)
