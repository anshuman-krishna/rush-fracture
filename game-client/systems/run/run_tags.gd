class_name RunTags
extends RefCounted

# short labels describing how a run was played, shown on the summary screen.


static func generate(data: RunData, combo_best: int) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()

	if data.total_enemies_killed > 0:
		var kill_rate: float = float(data.total_enemies_killed) / maxf(data.elapsed_time, 1.0)
		if kill_rate > 1.2:
			tags.append("berserker")
		elif kill_rate > 0.7:
			tags.append("aggressive")

	if combo_best >= 25:
		tags.append("unbroken")
	elif combo_best >= 15:
		tags.append("combo lord")
	elif combo_best >= 10:
		tags.append("chain killer")

	if data.rooms_cleared > 0 and data.elapsed_time / float(data.rooms_cleared) < 30.0:
		tags.append("speedrunner")

	if data.damage_taken == 0 and data.rooms_cleared >= 3:
		tags.append("untouched")

	for m: Dictionary in data.chosen_mutations:
		match m.get("type"):
			MutationDefinitions.MutationType.GLASS_CANNON: tags.append("glass cannon")
			MutationDefinitions.MutationType.BLOOD_PACT: tags.append("blood bound")
			MutationDefinitions.MutationType.VELOCITY_ADDICT: tags.append("speed demon")
			MutationDefinitions.MutationType.TEMPORAL_DISTORTION: tags.append("time bender")
			MutationDefinitions.MutationType.HOARDER: tags.append("hoarder")
	if data.chosen_mutations.size() >= 3:
		tags.append("mutant")

	var cursed: int = 0
	var weapon_ups: int = 0
	for u: Dictionary in data.chosen_upgrades:
		if u.get("rarity", &"") == UpgradeDefinitions.RARITY_CURSED:
			cursed += 1
		if u.get("weapon", &"") != &"":
			weapon_ups += 1
	if cursed >= 2:
		tags.append("risk taker")
	if weapon_ups >= 3:
		tags.append("specialist")

	if data.bosses_defeated >= 3:
		tags.append("boss slayer")
	elif data.bosses_defeated >= 1:
		tags.append("giant killer")
	if data.ascension > 0:
		tags.append("ascension %d" % data.ascension)
	if data.status == RunData.RunStatus.COMPLETED:
		tags.append("survivor")
	return tags
