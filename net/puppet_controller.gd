class_name PuppetController
extends CharacterController
## Cliente: personagem de outro jogador (ou bot do anfitrião) visto neste aparelho. Não simula
## nada: mostra o personagem onde as fotos do anfitrião dizem, um pouco no passado
## (`NetClient.render_tick`), passeando suave entre duas fotos em vez de pular 30 vezes por
## segundo. Se a próxima foto atrasar, segue na mesma velocidade por um instante.

## Fotos guardadas por personagem (as mais velhas saem).
const MAX_SAMPLES: int = 32
## Se as fotos pararem de chegar, segue em frente no máximo este tempo (passos de física).
const MAX_EXTRAPOLATE_TICKS: float = 6.0

var client: NetClient

## Fotos recebidas, da mais velha à mais nova: {"tick", "position", "velocity", "yaw", "pitch",
## "flags"}.
var _samples: Array[Dictionary] = []
var _was_reloading: bool = false
var _was_protected: bool = false


func is_puppet() -> bool:
	return true


## Guarda uma foto (fora de ordem ou repetida é ignorada).
func push_sample(tick: int, entry: Dictionary) -> void:
	if not _samples.is_empty() and tick <= int(_samples[_samples.size() - 1]["tick"]):
		return
	_samples.append({"tick": tick, "position": entry["position"], "velocity": entry["velocity"],
			"yaw": entry["yaw"], "pitch": entry["pitch"], "flags": entry["flags"]})
	if _samples.size() > MAX_SAMPLES:
		_samples.pop_front()


## Esquece as fotos (renasceu: não pode "deslizar" do lugar da morte até o ponto novo).
func clear() -> void:
	_samples.clear()


func has_samples() -> bool:
	return not _samples.is_empty()


func drive_puppet(_delta: float) -> void:
	if _samples.is_empty() or client == null:
		return
	var state: Dictionary = _sample_at(client.render_tick)
	var flags: int = state["flags"]
	var on_rail: SkylineRail = null
	if flags & NetSnapshot.ON_RAIL != 0:
		on_rail = character.rail if character.rail != null else client.nearest_rail(state["position"])
	character.apply_puppet_state(state["position"], state["velocity"], state["yaw"], state["pitch"],
			flags & NetSnapshot.AIRBORNE != 0, on_rail, flags & NetSnapshot.RAIL_PULLING != 0)
	character.visible = true
	# Recarga dos outros: só o som (e o que mais escutar o sinal).
	var reloading: bool = flags & NetSnapshot.RELOADING != 0
	if reloading and not _was_reloading and character.weapon != null:
		character.weapon.reload_started.emit()
	_was_reloading = reloading
	# A proteção de nascimento acabou antes da hora (atirou): o brilho some.
	var protected: bool = flags & NetSnapshot.PROTECTED != 0
	if _was_protected and not protected and character.is_spawn_protected:
		character.end_spawn_protection()
	_was_protected = protected


# Estado no passo `tick` (fracionário): entre as duas fotos em volta, ou seguindo a última.
func _sample_at(tick: float) -> Dictionary:
	var first: Dictionary = _samples[0]
	if tick <= float(first["tick"]):
		return first
	for i: int in range(_samples.size() - 1, 0, -1):
		var before: Dictionary = _samples[i - 1]
		var after: Dictionary = _samples[i]
		if tick >= float(before["tick"]) and tick <= float(after["tick"]):
			var span: float = maxf(float(after["tick"]) - float(before["tick"]), 1.0)
			var weight: float = (tick - float(before["tick"])) / span
			return {
				"position": (before["position"] as Vector3).lerp(after["position"], weight),
				"velocity": (before["velocity"] as Vector3).lerp(after["velocity"], weight),
				"yaw": lerp_angle(before["yaw"], after["yaw"], weight),
				"pitch": lerpf(before["pitch"], after["pitch"], weight),
				"flags": after["flags"] if weight > 0.5 else before["flags"],
			}
	# Depois da última foto: segue na mesma velocidade por um instante (a próxima atrasou).
	var last: Dictionary = _samples[_samples.size() - 1]
	var ahead: float = minf(tick - float(last["tick"]), MAX_EXTRAPOLATE_TICKS)
	var step: float = 1.0 / Engine.physics_ticks_per_second
	var velocity: Vector3 = last["velocity"]
	# Pendurado ou no chão segue reto; caindo, a gravidade já está na velocidade.
	return {"position": (last["position"] as Vector3) + velocity * ahead * step, "velocity": velocity,
			"yaw": last["yaw"], "pitch": last["pitch"], "flags": last["flags"]}
