extends RefCounted

# base class for unit tests. a test file extends this and defines methods
# whose names start with "test_"; the runner calls each one on a fresh
# instance. use the checks below; a failed check records a message and the
# test carries on, so one run reports every problem in a method.

var failures: PackedStringArray = PackedStringArray()
var checks: int = 0


func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition


func eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	return check(actual == expected, "%s: expected %s, got %s" % [message, str(expected), str(actual)])


func ne(actual: Variant, unexpected: Variant, message: String = "") -> bool:
	return check(actual != unexpected, "%s: did not expect %s" % [message, str(unexpected)])


func near(actual: float, expected: float, message: String = "", epsilon: float = 0.0001) -> bool:
	return check(absf(actual - expected) <= epsilon, "%s: expected %f, got %f" % [message, expected, actual])


## override for per-test setup / cleanup.
func before_each() -> void:
	pass


func after_each() -> void:
	pass
