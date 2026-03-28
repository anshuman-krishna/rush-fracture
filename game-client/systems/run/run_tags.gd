class_name RunTags
extends RefCounted

# analyzes run state to assign identity tags.
# tags reflect playstyle, choices, and achievements.


static func generate(data: RunData, combo_best: int) -> PackedStringArray:
	var tags := PackedStringArray()

	# playstyle tags
	if data.total_enemies_killed > 0:
		var kill_rate := float(data.total_enemies_killed) / max(data.elapsed_time, 1.0)
		if kill_rate > 1.5:
			tags.append("berserker")
		elif kill_rate > 0.8:
			tags.append("aggressive")

	if combo_best >= 15:
		tags.append("combo lord")
	elif combo_best >= 10:
		tags.append("chain killer")
	elif combo_best >= 6:
		tags.append("combo adept")

	# speed tag
	if data.elapsed_time > 0 and data.rooms_cleared > 0:
		var avg_room_time := data.elapsed_time / float(data.rooms_cleared)
		if avg_room_time < 15.0:
			tags.append("speedrunner")

	# mutation tags
	_check_mutation_tags(data, tags)

	# upgrade tags
	_check_upgrade_tags(data, tags)

	# survival tags
	if data.status == RunData.RunStatus.COMPLETED:
		tags.append("survivor")

	if data.chosen_mutations.size() >= 3:
		tags.append("mutant")

	# cursed upgrade count
	var cursed_count := 0
	for u in data.chosen_upgrades:
		if u.get("cursed", false):
			cursed_count += 1
	if cursed_count >= 2:
		tags.append("risk taker")

	return tags


static func _check_mutation_tags(data: RunData, tags: PackedStringArray) -> void:
	for m in data.chosen_mutations:
		match m.type:
			MutationDefinitions.MutationType.GLASS_CANNON:
				tags.append("glass cannon")
			MutationDefinitions.MutationType.BLOOD_PACT:
				tags.append("blood bound")
			MutationDefinitions.MutationType.VELOCITY_ADDICT:
				tags.append("speed demon")
			MutationDefinitions.MutationType.TEMPORAL_DISTORTION:
				tags.append("time bender")


static func _check_upgrade_tags(data: RunData, tags: PackedStringArray) -> void:
	var damage_count := 0
	var heal_count := 0
	var speed_count := 0

	for u in data.chosen_upgrades:
		var stat: String = u.get("stat", "")
		match stat:
			"damage", "power_surge", "berserker_pact":
				damage_count += 1
			"kill_heal":
				heal_count += 1
			"move_speed", "fragile_speed", "dash_cooldown":
				speed_count += 1

	if damage_count >= 3:
		tags.append("damage stacker")
	if heal_count >= 2:
		tags.append("lifedrinker")
	if speed_count >= 3:
		tags.append("velocity freak")
