#!/usr/bin/env python3
"""Drive the wizard through a real pty, capturing each repaint as a frame.

    python3 scripts/wizard-shots/drive.py <script.json> <workdir> <framedir> [cli]

The wizard is a raw-mode keypress loop, so it needs a TERMINAL -- a pipe makes it
refuse and say so. `pty.fork` gives it a real one, which is also what makes these
frames worth having: they are what the program draws, not what a renderer thinks
it would draw.
"""
import os, pty, sys, time, select, re, json

CLEAR = "\x1b[2J\x1b[H"

KEYS = {
    "up": "\x1b[A", "down": "\x1b[B", "left": "\x1b[D", "right": "\x1b[C",
    "return": "\r", "space": " ", "backspace": "\x7f", "escape": "\x1b",
}

def send(fd, token):
    os.write(fd, (KEYS.get(token) or token).encode())

def drain(fd, settle=0.35, limit=6.0):
    """Read until nothing arrives for `settle` seconds."""
    chunks, last = [], time.time()
    while time.time() - last < settle and time.time() - last < limit:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            chunks.append(data)
            last = time.time()
    return b"".join(chunks)

def strip_ansi(text):
    text = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", text)
    return text.replace("\x1b", "")

def main():
    script = sys.argv[1]
    cwd = sys.argv[2]
    outdir = sys.argv[3]
    global CLI
    CLI = os.path.abspath(sys.argv[4] if len(sys.argv) > 4 else "bin/ranger-starter.js")
    steps = json.load(open(script))

    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(cwd)
        os.environ["TERM"] = "xterm-256color"
        os.environ["COLUMNS"] = "84"
        os.environ["LINES"] = "40"
        os.execvp("node", ["node", CLI, "configure"])
        os._exit(1)

    os.makedirs(outdir, exist_ok=True)
    frames = []
    written = {}
    raw = drain(fd, settle=1.2)
    frames.append(("00-open", raw.decode("utf-8", "replace")))

    for i, step in enumerate(steps):
        for token in step["keys"].split():
            send(fd, token)
            time.sleep(0.09)
        raw = drain(fd)
        if i == len(steps) - 1:
            # The last step generates the project, and how much of that output
            # has arrived when the drain gives up is a matter of timing. Holding
            # it back and joining it to the tail makes the final frame the same
            # every run, which a screenshot in the documentation has to be.
            last_chunk = raw
        else:
            frames.append((step["name"], raw.decode("utf-8", "replace")))

    time.sleep(0.6)
    tail = drain(fd, settle=2.5, limit=25.0)
    frames.append((steps[-1]["name"], (last_chunk + tail).decode("utf-8", "replace")))

    try:
        os.close(fd)
    except OSError:
        pass
    try:
        _, status = os.waitpid(pid, 0)
        code = os.waitstatus_to_exitcode(status)
    except ChildProcessError:
        code = -1

    for name, text in frames:
        # Every repaint begins by clearing the screen, so a chunk that arrived
        # while several keys were sent holds several screenfuls. The frame is the
        # LAST one: that is what the terminal is showing when the keys stop.
        parts = text.split(CLEAR)
        screen = parts[-1] if len(parts) > 1 else text
        lines = [l.rstrip() for l in strip_ansi(screen).split("\n")]
        while lines and not lines[0].strip():
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
        text = "\n".join(lines) + "\n"
        written[name] = text
        open(os.path.join(outdir, name + ".txt"), "w").write(text)
    print("exit code:", code)
    print("frames:", ", ".join(n for n, _ in frames))

    # A screenshot nobody checks is a screenshot that documents last month. Each
    # step may name the lines its frame must contain; a frame that does not is a
    # failed run, not a file quietly committed. The keypress loop hands the
    # terminal one key per poll, so which repaint a drain catches is a matter of
    # timing -- this is what turns that into a loud failure.
    bad = []
    for step in steps:
        for want in step.get("expect", []):
            if want not in written.get(step["name"], ""):
                bad.append((step["name"], want))
    for name, want in bad:
        print("MISMATCH %s: expected %r" % (name, want), file=sys.stderr)
    if bad:
        sys.exit(1)

main()
