extends RefCounted
## WorldEditor.publish_to_github() (owner 2026-10-23: "save button needs to commit and push
## straight to github all new level changes") and PlacedObjects.load_default_from_repo(). Called
## from tests/run_tests.gd.
##
## Deliberately does NOT run a real `git commit`/`git push` or touch the real tracked
## res://data/world_layout.json -- publish_to_github() has real side effects (writes a file inside
## the actual repo, runs real git commands against the real remote) that must never happen inside
## an automated test. Instead:
##   - the pure outcome-interpretation helpers (_commit_outcome/_push_outcome) are tested directly
##     with synthetic exit codes/output text, covering every branch without running git;
##   - load_default_from_repo() is tested against a scratch user:// path (its optional `path`
##     parameter), never the real DEFAULT_LAYOUT_PATH;
##   - the Web-export gate is confirmed by reading the source for the two call sites that must stay
##     unconditional (the function's own early return, and the button that only gets created when
##     `not OS.has_feature("web")`), since OS.has_feature("web") cannot be toggled at runtime in a
##     native CI test.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	_test_commit_outcome()
	_test_push_outcome()
	_test_web_gate_exists_in_source()
	_test_pr_helpers()
	await _test_load_default_from_repo(tree_root)
	await _test_publish_flow(tree_root)


func _test_commit_outcome() -> void:
	var ok := WorldEditor._commit_outcome(0, "")
	ck.call("publish: a successful commit (exit 0) is not done yet -- the caller still pushes", ok.ok and not ok.done)
	var noop := WorldEditor._commit_outcome(1, "On branch main\nnothing to commit, working tree clean")
	ck.call("publish: 'nothing to commit' is a benign no-op, not a failure, and ends the publish", noop.ok and noop.done and noop.message == "PUBLISH: no changes to publish")
	var noop2 := WorldEditor._commit_outcome(1, "nothing added to commit but untracked files present")
	ck.call("publish: 'nothing added' (untracked-only) is also treated as a benign no-op", noop2.ok and noop2.done)
	var fail := WorldEditor._commit_outcome(128, "fatal: not a git repository")
	ck.call("publish: a real commit failure is reported as failed and done (does not proceed to push)", not fail.ok and fail.done and fail.message.contains("not a git repository"))
	var long_err := WorldEditor._commit_outcome(1, "x".repeat(200))
	ck.call("publish: a long git error message is truncated so the flash banner stays readable", long_err.message.length() < 150)


func _test_push_outcome() -> void:
	var ok := WorldEditor._push_outcome(0, "", 12)
	ck.call("publish: a successful push reports the object count", ok.ok and ok.message == "PUBLISHED  12 objects -> GitHub")
	var rejected := WorldEditor._push_outcome(1, "! [remote rejected] main -> main (push declined due to repository rule violations)", 5)
	ck.call("publish: a rejected push (e.g. protected branch) is reported as a plain failure, not retried or force-pushed", not rejected.ok and rejected.message.contains("PUBLISH FAILED (push)"))


## Confirms the two Web-export gates are present as unconditional source-level guards (not just
## "currently false on this platform") -- the function's own early return, and the button creation
## only happening inside `not OS.has_feature("web")`. OS.has_feature("web") is always false in a
## native CI test run, so the gate's BEHAVIOR cannot be exercised here; this checks the gate ITSELF
## is actually in the code, so it can't silently regress.
func _test_web_gate_exists_in_source() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/editor/world_editor.gd")
	var fn_start := src.find("func publish_to_github()")
	ck.call("publish: publish_to_github() exists", fn_start != -1)
	if fn_start == -1:
		return
	var fn_body := src.substr(fn_start, 200)
	ck.call("publish: publish_to_github()'s very first check is the Web-export gate (OS.has_feature(\"web\") -> return false)",
		fn_body.find("OS.has_feature(\"web\")") != -1 and fn_body.find("return false") != -1 and fn_body.find("OS.has_feature(\"web\")") < fn_body.find("return false"))
	ck.call("publish: the PUBLISH button is only created inside a `not OS.has_feature(\"web\")` guard (never exists at all on Web, not just hidden)",
		src.contains("if not OS.has_feature(\"web\"):") and src.find("if not OS.has_feature(\"web\"):") < src.find("pub.pressed.connect(publish_to_github)"))
	ck.call("publish: git add is never called with -A or a bare '.' anywhere in this file (must stay scoped to the one layout file)",
		not src.contains("\"add\", \"-A\"") and not src.contains("\"add\", \".\""))


func _test_load_default_from_repo(tree_root: Node) -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	tree_root.add_child(main)
	for i in 6:
		await main.get_tree().physics_frame
	var arena := main.get_node_or_null("TrainingArena") as TrainingArena
	var placed := arena.placed if arena != null else null
	ck.call("publish: main scene has a usable PlacedObjects", placed != null)
	if placed == null:
		main.queue_free()
		return
	var scratch_path := "user://test_default_layout.json"
	if FileAccess.file_exists(scratch_path):
		DirAccess.remove_absolute(scratch_path)

	ck.call("publish: load_default_from_repo() on a missing file returns 0 (normal case: nothing published yet)", placed.load_default_from_repo(scratch_path) == 0)

	var f := FileAccess.open(scratch_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 4, "items": [{"id": "tree_1", "x": -500.0, "y": 300.0}]}))
	f.close()
	var made := placed.load_default_from_repo(scratch_path)
	ck.call("publish: load_default_from_repo() loads a valid published layout from the given path", made == 1, str(made))
	# Syntactically VALID JSON of the wrong shape (a plain string, not a Dictionary) -- exercises the
	# same `typeof(parsed) != TYPE_DICTIONARY` branch without feeding genuinely malformed JSON syntax
	# into JSON.parse_string(), which logs an engine-level ERROR line regardless of how gracefully
	# the caller handles the null/wrong-type result -- exactly the kind of "real engine error, not
	# just a return value" the CI test harness correctly treats as a hard failure.
	f = FileAccess.open(scratch_path, FileAccess.WRITE)
	f.store_string("\"just a string, not an object\"")
	f.close()
	ck.call("publish: load_default_from_repo() on well-formed JSON of the wrong shape (not a Dictionary) returns 0 instead of crashing", placed.load_default_from_repo(scratch_path) == 0)

	f = FileAccess.open(scratch_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 4, "items": []}))
	f.close()
	ck.call("publish: load_default_from_repo() on an empty-items published layout returns 0 (keeps defaults, same rule as load_saved())", placed.load_default_from_repo(scratch_path) == 0)

	DirAccess.remove_absolute(scratch_path)
	main.queue_free()
	await main.get_tree().process_frame


func _test_pr_helpers() -> void:
	ck.call("publish: repo slug from an https origin", WorldEditor._repo_slug("https://github.com/kiotdstudios/shinobi-rush.git\n") == "kiotdstudios/shinobi-rush")
	ck.call("publish: repo slug from an ssh origin", WorldEditor._repo_slug("git@github.com:kiotdstudios/shinobi-rush.git") == "kiotdstudios/shinobi-rush")
	ck.call("publish: a non-GitHub origin has no slug", WorldEditor._repo_slug("https://gitlab.com/a/b.git") == "" and WorldEditor._repo_slug("") == "")
	var b := WorldEditor._publish_branch(0)
	ck.call("publish: each publish gets its own builder/layout-<timestamp> branch, never main", b == "builder/layout-19700101-000000", b)
	ck.call("publish: the PR url is the last https /pull/ line gh prints",
		WorldEditor._pr_url(0, "Warning: 1 uncommitted change\nhttps://github.com/o/r/pull/7\n") == "https://github.com/o/r/pull/7")
	ck.call("publish: a failed gh pr create yields no url", WorldEditor._pr_url(1, "https://github.com/o/r/pull/7") == "")
	var am := WorldEditor._automerge_outcome(0, "https://github.com/o/r/pull/7", 9)
	ck.call("publish: auto-merge on reports the PR and that it merges itself after CI", am.ok and am.message.contains("pull/7") and am.message.contains("CI"))
	var off := WorldEditor._automerge_outcome(1, "https://github.com/o/r/pull/7", 9)
	ck.call("publish: auto-merge refused still counts (the PR is open) and says to merge it by hand", off.ok and off.message.contains("merge it on GitHub") and off.message.contains("pull/7"))


## Drives the whole publish with a fake runner: no real git/gh process runs and the real
## res://data/world_layout.json is never written.
func _test_publish_flow(tree_root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 6:
		await main.get_tree().physics_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var ed: WorldEditor = arena.editor
	ed.void_check = false
	var repo_file := ProjectSettings.globalize_path(WorldEditor.REPO_LAYOUT_PATH)
	var repo_before := FileAccess.get_file_as_string(repo_file) if FileAccess.file_exists(repo_file) else "<absent>"
	var calls: Array = []
	var fail_on := {"step": ""}
	var shipped := {"json": ""}
	var wt := ed._publish_worktree()
	ed.publish_runner = func(tool: String, args: Array) -> Dictionary:
		calls.append([tool, args])
		var joined := " ".join(args)
		if fail_on.step != "" and joined.contains(fail_on.step):
			return {"code": 1, "out": "nothing to commit, working tree clean" if fail_on.step == "commit" else "boom"}
		if tool == "git" and args.has("get-url"):
			return {"code": 0, "out": "https://github.com/kiotdstudios/shinobi-rush.git"}
		if tool == "git" and args.has("commit"):
			shipped.json = FileAccess.get_file_as_string(wt.path_join("data/world_layout.json"))
		if tool == "gh" and args.has("create"):
			return {"code": 0, "out": "https://github.com/kiotdstudios/shinobi-rush/pull/999"}
		return {"code": 0, "out": ""}

	var ok := ed.publish_to_github()
	ck.call("publish flow: a clean run succeeds", ok)
	var add_wt := _find(calls, "worktree add")
	ck.call("publish flow: the layout is built in a throwaway worktree cut from a fresh origin/main",
		_find(calls, "fetch origin main") != -1 and add_wt != -1 and _find(calls, "fetch origin main") < add_wt and (calls[add_wt][1] as Array).has("origin/main") and (calls[add_wt][1] as Array).has(wt))
	ck.call("publish flow: the committed file is the current layout", shipped.json == ed.placed.to_json_string())
	var commit_i := _find(calls, "commit -m")
	ck.call("publish flow: the commit runs inside the worktree, scoped to the one layout file",
		commit_i != -1 and (calls[commit_i][1] as Array)[1] == wt and (calls[commit_i][1] as Array).slice(-2) == ["--", "data/world_layout.json"])
	var push_i := _find(calls, "push")
	var push_args: Array = calls[push_i][1] if push_i != -1 else []
	ck.call("publish flow: pushes only its own builder/layout-* branch, never main, never forced",
		push_i != -1 and str(push_args[-1]).contains("refs/heads/builder/layout-") and not " ".join(push_args).contains(":main") and not push_args.has("--force") and not push_args.has("-f"))
	var pr_i := _find(calls, "pr create")
	ck.call("publish flow: opens a PR into main after the push", pr_i > push_i and (calls[pr_i][1] as Array).has("main"))
	var am_i := _find(calls, "pr merge")
	ck.call("publish flow: turns on auto-merge for that PR", am_i > pr_i and (calls[am_i][1] as Array).has("--auto") and (calls[am_i][1] as Array).has("https://github.com/kiotdstudios/shinobi-rush/pull/999"))
	ck.call("publish flow: cleans up the worktree after", _find(calls, "worktree remove", am_i) != -1)
	ck.call("publish flow: the status note names the PR and stays up long enough to read", ed._note.contains("pull/999") and ed._note_until - Time.get_ticks_msec() > 10000, ed._note)
	var repo_after := FileAccess.get_file_as_string(repo_file) if FileAccess.file_exists(repo_file) else "<absent>"
	ck.call("publish flow: the builder's own checkout is never written to", repo_after == repo_before)

	calls.clear()
	fail_on.step = "commit"
	ck.call("publish flow: an unchanged layout is a clean no-op (no push, no PR)", ed.publish_to_github() and _find(calls, "push") == -1 and _find(calls, "pr create") == -1)
	for step in ["fetch", "worktree add", "push -u", "pr create"]:
		calls.clear()
		fail_on.step = step
		var r := ed.publish_to_github()
		ck.call("publish flow: a failed '%s' reports failure and goes no further" % step,
			not r and (ed._note.contains("FAIL") or ed._note.contains("failed")) and _find(calls, "pr merge") == -1, ed._note)
		if step in ["push -u", "pr create"]:
			ck.call("publish flow: a failed '%s' still removes the worktree" % step, _find(calls, "worktree remove", _find(calls, step)) != -1)
	ed.publish_runner = Callable()
	main.queue_free()
	await main.get_tree().process_frame


func _find(calls: Array, needle: String, after := -1) -> int:
	for i in range(after + 1, calls.size()):
		if " ".join(calls[i][1]).contains(needle):
			return i
	return -1
