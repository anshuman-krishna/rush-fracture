class_name StatBlock
extends RefCounted

# a set of named stats, each computed as (base + adds) * muls.
#
# every modifier is stored under a key ("combo", "fracture", "upgrade:brutal
# rounds"...), so whoever applied it can change or remove exactly their own
# contribution later. nothing ever has to remember "the value before i touched
# it" and write it back, which is what used to make speed and damage drift
# when two temporary effects overlapped.

signal changed(stat: StringName)

var _base: Dictionary = {}
var _mul: Dictionary = {}
var _add: Dictionary = {}
var _cache: Dictionary = {}


func set_base(stat: StringName, value: float) -> void:
	_base[stat] = value
	_invalidate(stat)


func get_base(stat: StringName) -> float:
	return _base.get(stat, 0.0)


func has(stat: StringName) -> bool:
	return _base.has(stat)


func value(stat: StringName) -> float:
	if _cache.has(stat):
		return _cache[stat]
	var v: float = _base.get(stat, 0.0)
	var adds: Dictionary = _add.get(stat, {})
	for k: Variant in adds:
		v += adds[k]
	var muls: Dictionary = _mul.get(stat, {})
	for k: Variant in muls:
		v *= muls[k]
	_cache[stat] = v
	return v


## sets (replaces) this key's multiplier on a stat. 1.0 removes it.
func set_mul(stat: StringName, key: StringName, factor: float) -> void:
	var muls: Dictionary = _mul.get(stat, {})
	if is_equal_approx(factor, 1.0):
		if not muls.has(key):
			return
		muls.erase(key)
	else:
		if muls.has(key) and is_equal_approx(muls[key], factor):
			return
		muls[key] = factor
	_mul[stat] = muls
	_invalidate(stat)


## multiplies this key's existing multiplier — for upgrades that stack.
func stack_mul(stat: StringName, key: StringName, factor: float) -> void:
	set_mul(stat, key, get_mul(stat, key) * factor)


func get_mul(stat: StringName, key: StringName) -> float:
	return _mul.get(stat, {}).get(key, 1.0)


## sets (replaces) this key's flat bonus on a stat. 0.0 removes it.
func set_add(stat: StringName, key: StringName, amount: float) -> void:
	var adds: Dictionary = _add.get(stat, {})
	if is_zero_approx(amount):
		if not adds.has(key):
			return
		adds.erase(key)
	else:
		if adds.has(key) and is_equal_approx(adds[key], amount):
			return
		adds[key] = amount
	_add[stat] = adds
	_invalidate(stat)


## adds to this key's existing flat bonus — for upgrades that stack.
func stack_add(stat: StringName, key: StringName, amount: float) -> void:
	set_add(stat, key, get_add(stat, key) + amount)


func get_add(stat: StringName, key: StringName) -> float:
	return _add.get(stat, {}).get(key, 0.0)


## removes every modifier stored under this key, on every stat.
func remove_key(key: StringName) -> void:
	for stat: Variant in _mul.keys():
		if _mul[stat].has(key):
			_mul[stat].erase(key)
			_invalidate(stat)
	for stat: Variant in _add.keys():
		if _add[stat].has(key):
			_add[stat].erase(key)
			_invalidate(stat)


## removes every modifier whose key starts with the prefix.
func remove_prefix(prefix: String) -> void:
	for table: Dictionary in [_mul, _add]:
		for stat: Variant in table.keys():
			var mods: Dictionary = table[stat]
			var dirty: bool = false
			for k: Variant in mods.keys():
				if String(k).begins_with(prefix):
					mods.erase(k)
					dirty = true
			if dirty:
				_invalidate(stat)


func clear_modifiers() -> void:
	var touched: Dictionary = {}
	for stat: Variant in _mul:
		touched[stat] = true
	for stat: Variant in _add:
		touched[stat] = true
	_mul.clear()
	_add.clear()
	for stat: Variant in touched:
		_invalidate(stat)


## every active modifier on a stat, for debug overlays and tests.
func describe(stat: StringName) -> Dictionary:
	return {
		"base": get_base(stat),
		"add": _add.get(stat, {}).duplicate(),
		"mul": _mul.get(stat, {}).duplicate(),
		"value": value(stat),
	}


func _invalidate(stat: Variant) -> void:
	_cache.erase(stat)
	changed.emit(stat)
