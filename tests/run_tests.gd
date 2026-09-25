extends SceneTree
## Runs every tests/test_*.gd file. Usage (see tests/run.sh):
##   godot --headless --path . -s res://tests/run_tests.gd -- [name-filter] [--seed=N]
## Exit code is 0 only if every check passed.

const TEST_DIR := "res://tests"
const STALL_MSEC := 90000

var _current := ""
var _test_started_msec := 0
var _errors := ErrorCatcher.new()

## Collects every engine/script error printed while a test runs. Without this a
## test that crashes half way just stops and would look like a pass.
class ErrorCatcher extends Logger:
	var messages: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == 1:  # warnings are not failures
			return
		var detail := rationale if rationale != "" else code
		messages.append("script error at %s:%d in %s(): %s" % [file.get_file(), line, function, detail])

func _init() -> void:
	var filter := ""
	var seed_value := randi()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
		else:
			filter = arg
	seed(seed_value)
	OS.add_logger(_errors)
	print("Castlelot tests (seed %d%s)" % [seed_value, ", filter '%s'" % filter if filter != "" else ""])
	_run(filter)

## A test that hits a script error stops mid-way and never returns, which would
## leave the process hanging. If one stops making progress, fail loudly instead.
func _process(_delta: float) -> bool:
	if _current != "" and Time.get_ticks_msec() - _test_started_msec > STALL_MSEC:
		print("\nSTALLED: %s made no progress for %d s - it most likely hit a script error (see SCRIPT ERROR above)." % [_current, STALL_MSEC / 1000])
		quit(1)
	return false

func _run(filter: String) -> void:
	await process_frame       # started from _init: let the tree finish starting so the first test's scenes get their _ready
	var files: Array = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd") and (filter == "" or file.contains(filter)):
			files.append(file)
	files.sort()

	var total_tests := 0
	var total_checks := 0
	var failed: Array = []

	for file in files:
		var script: GDScript = load("%s/%s" % [TEST_DIR, file])
		print("\n== %s" % file)
		if script == null or not script.can_instantiate():
			print("  ERROR  could not load %s (parse error?)" % file)
			failed.append(file)
			continue

		var names: Array = []
		for method in script.get_script_method_list():
			if method.name.begins_with("test_"):
				names.append(method.name)

		for test_name in names:
			var test = script.new()
			test.tree = self
			_current = "%s::%s" % [file, test_name]
			_test_started_msec = Time.get_ticks_msec()
			_errors.messages.clear()
			await test.call(test_name)
			await test.cleanup()
			_current = ""

			for message in _errors.messages:
				test.failures.append(message)
			if test.checks == 0 and test.failures.is_empty():
				test.failures.append("ran no checks")

			total_tests += 1
			total_checks += test.checks
			if test.failures.is_empty():
				print("  PASS  %s (%d checks)" % [test_name, test.checks])
			else:
				print("  FAIL  %s" % test_name)
				for message in test.failures:
					print("        - %s" % message)
				failed.append("%s::%s" % [file, test_name])

	print("\n%d tests, %d checks, %d failed" % [total_tests, total_checks, failed.size()])
	if not failed.is_empty():
		print("Failed: %s" % ", ".join(failed))
	quit(1 if not failed.is_empty() else 0)
