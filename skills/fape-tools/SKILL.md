---
name: fape-tools
description: Add custom Fape voice-action tools through local configuration and installed commands, without access to Fape source code. Use when a user wants dictation to perform a new action.
---

# Fape voice-action tools

Fape's action mode turns speech into calls to configured tools. You can add a
tool using local files; you do not need the app source or a new app build.

## Configure a tool

Find Fape with `command -v fape` and inspect `fape --help` and
`fape execution-catalog`. Verify the target command's installed help before
designing an adapter. Preserve existing tools and preferences; do not print
settings, keys, or private prompts to discover this interface.

Put one UTF-8 JSON manifest per tool in
`${XDG_CONFIG_HOME:-$HOME/.config}/fape/tools.d/`. Hold `tools.lock` in the Fape
config directory while reading/editing tools, and write atomically with mode
`0600`. Definitions reload on the next action; no restart is needed.

The manifest fields are:

- `name`: unique, 1–64 ASCII letters/digits/underscores/hyphens. Do not use
  built-in names `launch_app`, `open_url`, or `shell`.
- `description`: tell the planner when to call the tool, what arguments mean,
  and its limits. This is where natural-language routing instructions belong.
- `argv`: fixed executable and arguments. Use verified executable paths.
- `stdin_json`: set to `true` when the tool takes arguments. The executable
  receives one JSON object on stdin; ordinary CLIs usually need a small bridge.
- `parameters`: flat JSON Schema with `type: "object"`, `properties`, optional
  `required`, and `additionalProperties: false`. Property rules support only
  `type` and optional `enum`. Types are `string`, `boolean`, `number`, `integer`,
  `array`, and `object`; nested schemas and range/length keywords are unsupported.
- Optional `_comment`: local documentation, excluded from the planner.

For a command with no arguments, omit `parameters` and `stdin_json`. For example,
`{"name":"lock_screen","description":"Lock the screen when requested",
"argv":["omarchy","system","lock"]}` after checking that command exists.

Fape never substitutes model arguments into `argv`: braces, `~`, `$HOME`, pipes,
and redirects are not expanded. For input-dependent commands, parse JSON and
invoke a fixed command with a literal argument list. Validate fields, ranges,
and lengths in the bridge; never use `eval`, `shell=True`, or user-supplied
command paths. A short bridge can live in a fixed `python3 -c` argument so the
whole tool is one file; use a separate script for larger adapters.

Exit zero only on success, nonzero on failure. Plain stdout is supported; a
result card can use `{"ok":true,"feedback":{"title":"Done","message":"..."}}`.
Keep manifests below 64 KiB and each argv string below 4096 bytes. Tool runtime
is limited to 60 seconds. Tools run with the user's privileges even when the
general shell tool is disabled; keep each capability narrow.

## Example: Omarchy reminders in one file

Verify `omarchy reminder --help` supports minutes plus a message. This recipe
requires Python 3 and a working Omarchy desktop/user systemd session. It creates
relative reminders from one minute to seven days; timers do not survive reboot.
The Python below **installs the tool only**, without setting a reminder:

```python
import fcntl, json, os, shutil, tempfile
from pathlib import Path

root = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "fape"
python, omarchy = shutil.which("python3"), shutil.which("omarchy")
if not python or not omarchy:
    raise SystemExit("Install Python 3 and Omarchy before adding this tool")

bridge = '''import json, subprocess, sys
try:
    args = json.load(sys.stdin)
    if not isinstance(args, dict) or set(args) != {"minutes", "message"}:
        raise ValueError("Expected minutes and message only")
    minutes, message = args["minutes"], args["message"]
    if type(minutes) is not int or not 1 <= minutes <= 10080:
        raise ValueError("minutes must be an integer from 1 to 10080")
    if not isinstance(message, str) or not message.strip() or len(message) > 500 or any(c in message for c in "\\x00\\r\\n"):
        raise ValueError("message must be one nonempty line, at most 500 characters")
    result = subprocess.run([sys.argv[1], "reminder", str(minutes), message], capture_output=True, text=True, timeout=45)
    if result.returncode:
        raise ValueError("Omarchy reported failure; check existing reminders before retrying")
    print(json.dumps({"ok": True, "feedback": {"title": "Reminder set", "message": f"{message} — in {minutes} minute(s)"}}))
except (ValueError, OSError, subprocess.TimeoutExpired) as error:
    print(json.dumps({"ok": False, "error": str(error)}))
    sys.exit(1)
'''

manifest = {
    "name": "set_reminder",
    "description": "Set an Omarchy desktop reminder after a requested duration. Convert to whole minutes: an hour = 60, half an hour = 30. minutes must be 1–10080; message is one nonempty line, at most 500 characters. Ask if duration is missing or ambiguous. Relative durations only, no calendar times or recurrence. Timers do not survive reboot. Use this tool, rather than notes, for timed reminders. Never automatically retry an uncertain reminder.",
    "argv": [python, "-c", bridge, omarchy],
    "stdin_json": True,
    "parameters": {
        "type": "object",
        "properties": {"minutes": {"type": "integer"}, "message": {"type": "string"}},
        "required": ["minutes", "message"],
        "additionalProperties": False,
    },
}
root.mkdir(parents=True, exist_ok=True)
with (root / "tools.lock").open("a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    directory = root / "tools.d"
    directory.mkdir(exist_ok=True)
    target = directory / "omarchy-reminder.json"
    if target.exists():
        raise SystemExit("Reminder manifest already exists; inspect it before editing")
    fd, temporary = tempfile.mkstemp(prefix=".reminder-", dir=directory)
    with os.fdopen(fd, "w") as out:
        json.dump(manifest, out, indent=2)
        out.write("\n")
        out.flush()
        os.fsync(out.fileno())
    os.replace(temporary, target)
```

## Verify and hand off

Test the bridge with fake inputs and a stub command first, including invalid
arguments and command failure. Run `fape execution-catalog` and confirm the
new tool is listed. A malformed manifest can prevent catalog loading.

Configuration work does not itself request a microphone/provider/live-action
test. If the user requests one, test within that scope. For this example, a
one-minute reminder can be inspected with `omarchy reminder show --json`.
Do not clear unrelated reminders or repeat an uncertain write.

Tell the user where the manifest is, what it does, the verification performed,
and any limits. Have them use their configured **action** shortcut, for example:
“Remind me in an hour to check the oven.” Speech and tool descriptions/arguments
use Fape's configured providers; this reminder command runs locally. The skill
guides the coding agent; Fape's planner reads the tool description and schema.

Remove the manifest under `tools.lock` to disable future calls. This does not
cancel reminders already set. Leave unrelated tools, prompts, and settings intact.
