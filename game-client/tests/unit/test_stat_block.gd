extends "res://tests/unit/test_case.gd"

# StatBlock: the modifier system every temporary effect is built on.


func _block() -> StatBlock:
	var s: StatBlock = StatBlock.new()
	s.set_base(&"speed", 10.0)
	s.set_base(&"health", 100.0)
	return s


func test_base_value() -> void:
	var s: StatBlock = _block()
	near(s.value(&"speed"), 10.0, "base speed")
	near(s.value(&"missing"), 0.0, "unknown stat reads as zero")
	check(s.has(&"speed"), "has() sees a base stat")
	check(not s.has(&"missing"), "has() is false for an unknown stat")


func test_adds_apply_before_multipliers() -> void:
	var s: StatBlock = _block()
	s.set_add(&"health", &"a", 50.0)
	s.set_mul(&"health", &"b", 0.5)
	near(s.value(&"health"), 75.0, "(100 + 50) * 0.5")


func test_multipliers_compose() -> void:
	var s: StatBlock = _block()
	s.set_mul(&"speed", &"a", 1.5)
	s.set_mul(&"speed", &"b", 2.0)
	near(s.value(&"speed"), 30.0, "10 * 1.5 * 2")


func test_setting_a_key_twice_replaces_it() -> void:
	var s: StatBlock = _block()
	s.set_mul(&"speed", &"combo", 1.2)
	s.set_mul(&"speed", &"combo", 1.5)
	near(s.value(&"speed"), 15.0, "second set replaces the first")


func test_stack_multiplies_and_adds() -> void:
	var s: StatBlock = _block()
	s.stack_mul(&"speed", &"up", 1.1)
	s.stack_mul(&"speed", &"up", 1.1)
	near(s.value(&"speed"), 12.1, "two stacks of 1.1")
	s.stack_add(&"health", &"up", 25.0)
	s.stack_add(&"health", &"up", 25.0)
	near(s.value(&"health"), 150.0, "two stacks of +25")


func test_neutral_values_remove_the_modifier() -> void:
	var s: StatBlock = _block()
	s.set_mul(&"speed", &"a", 2.0)
	s.set_mul(&"speed", &"a", 1.0)
	s.set_add(&"speed", &"b", 5.0)
	s.set_add(&"speed", &"b", 0.0)
	near(s.value(&"speed"), 10.0, "back to base")
	var d: Dictionary = s.describe(&"speed")
	eq(d.mul.size(), 0, "no multipliers left")
	eq(d.add.size(), 0, "no adds left")


# the bug this system exists to prevent: a fracture event saved "the speed
# before i started", a combo buff changed speed meanwhile, the fracture wrote
# its stale value back, and the combo's later revert left the player slower
# than base for the rest of the run.
func test_overlapping_effects_revert_cleanly_in_any_order() -> void:
	var s: StatBlock = _block()
	s.set_mul(&"speed", &"fracture", 1.8)
	s.set_mul(&"speed", &"combo", 1.15)
	s.set_mul(&"speed", &"upgrade", 1.1)
	near(s.value(&"speed"), 10.0 * 1.8 * 1.15 * 1.1, "all three active")
	s.remove_key(&"fracture")
	near(s.value(&"speed"), 10.0 * 1.15 * 1.1, "fracture ended first")
	s.set_mul(&"speed", &"combo", 1.0)
	near(s.value(&"speed"), 11.0, "combo ended, upgrade survives")
	s.remove_key(&"upgrade")
	near(s.value(&"speed"), 10.0, "exactly base again")


func test_remove_key_spans_stats() -> void:
	var s: StatBlock = _block()
	s.set_mul(&"speed", &"fx", 2.0)
	s.set_add(&"health", &"fx", 10.0)
	s.set_mul(&"health", &"other", 2.0)
	s.remove_key(&"fx")
	near(s.value(&"speed"), 10.0, "speed restored")
	near(s.value(&"health"), 200.0, "only the other key remains")


func test_remove_prefix() -> void:
	var s: StatBlock = _block()
	s.set_mul(&"speed", &"up:a", 2.0)
	s.set_mul(&"speed", &"up:b", 2.0)
	s.set_mul(&"speed", &"meta:c", 1.5)
	s.remove_prefix("up:")
	near(s.value(&"speed"), 15.0, "only meta survives")


func test_clear_modifiers_keeps_bases() -> void:
	var s: StatBlock = _block()
	s.set_mul(&"speed", &"a", 3.0)
	s.set_add(&"health", &"b", 30.0)
	s.clear_modifiers()
	near(s.value(&"speed"), 10.0, "speed base")
	near(s.value(&"health"), 100.0, "health base")


func test_changed_signal_and_cache() -> void:
	var s: StatBlock = _block()
	var seen: Array = []
	s.changed.connect(func(stat: StringName) -> void: seen.append(stat))
	near(s.value(&"speed"), 10.0, "prime the cache")
	s.set_mul(&"speed", &"a", 2.0)
	near(s.value(&"speed"), 20.0, "cache invalidated by the change")
	check(seen.has(&"speed"), "changed fired for speed")
	var count: int = seen.size()
	s.set_mul(&"speed", &"a", 2.0)
	eq(seen.size(), count, "setting the same value again does not fire")
