#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: render a canvas's boards to PNG on this machine, headless Chrome. A report tool, never a gate.
"""render.py -- render Claude Design boards (*.dc.html) to PNG, locally.

usage: render.py PROJECT_DIR OUT_DIR --runtime PATH [--theme ID] [--scheme light|dark] [--scale N]
                 [--only Main.dc.html ...] [--props JSON] [--suffix=TEXT] [--wait MS] [--timeout S] [--chrome PATH]

  PROJECT_DIR  the canvas's project/ folder: the *.dc.html files and canvas.json (the board sizes; 390x844 when absent)
  OUT_DIR      gets <Name><suffix>.png for each board
  --runtime    THE DESIGN RUNTIME (dc-runtime.js; $DC_RUNTIME works too). Required, because this module does not ship it: it is the
               design tool's own code. A copy that matches the canvas is best (one older copy drew a newer canvas to within 0.043% of
               a real PNG, so the need for an exact match is unobserved). Routes: a copy kept earlier from the design type's folder
               (`artifact-type/dc-runtime.js`, about 188 KB), the only one seen to work; a Claude Code session with the built-in Artifact
               tool (its `read` with `paths` is documented to save the type's files, not tried here); an exported canvas (untested whether
               it contains one). On the claude-artifacts server the file is readable (`read_file` serves it) but only into the
               transcript; no tool there writes it to disk, and retyping a file that size is not a route. A copy that is truncated, empty
               or another file is not accepted: the page must report the runtime's hooks, or the board is a FAIL. Without a runtime this tool
               prints `RUNTIME-ABSENT` and exits 3, and the PNG is a person's: Copy as PNG on the canvas (2x) or Export.
  --theme      sets data-theme="ID" on <html> before the board draws: `wire` for the Gate 1 wireframe review, `dark`, or any theme id
               of the canvas's design system. The page has no theme switch, so this is how a theme is looked at. A board whose own
               CSS and linked sheets hold no [data-theme="ID"] rule draws as the brand version, and the line says so
               (`NO-THEME-RULE`); an ID that no file of the project answers is refused (`UNKNOWN-THEME`, exit 2). A board's own
               `:root` block, if it sets the same properties, still wins over a theme sheet.
  --scheme     the colour scheme Chrome is forced to (default light), so a sheet that follows prefers-color-scheme draws the same on
               every machine (Blink's preferredColorScheme: 0 is dark, 1 is light)
  --wait       virtual milliseconds the page may run before the shot (default 8000; below 50 is refused, `BAD-WAIT`: 0 and 1 hang Chrome)
  --timeout    seconds Chrome may take per board (default 90)
  --scale      device scale factor (default 1; the page's Copy as PNG is 2, and a 2x render matched a real copy to 0.043% of pixels)
  --props      JSON prop overrides for every board (what the Tweaks panel sets)
Exit codes: 0 every board rendered; 1 a board failed (Chrome failed, timed out, or the page never showed the runtime ran: RUNTIME-DID-NOT-RUN);
2 refused (NO-SUCH-BOARD, NO-SUCH-PROJECT, NO-BOARDS, UNKNOWN-THEME, BAD-PROPS, BAD-CANVAS, BAD-WAIT); 3 nothing could be rendered
(RUNTIME-ABSENT, BAD-RUNTIME, CHROME-ABSENT).
Chrome is found from --chrome, $CHROME, the usual names on PATH, or the macOS application; with none (or a --chrome, or a $CHROME,
that does not exist), `CHROME-ABSENT` and exit 3. A board whose PNG Chrome did not write (a failed run, a timeout) is `FAIL`, the old PNG removed first.
The project is COPIED to a temp dir, support.js is written there (never into PROJECT_DIR), the copy is served on 127.0.0.1, each
board is screenshotted at its size, and the temp dir is removed. Network is needed only for web fonts; offline the text falls back to
the system font (a font host that never answers holds Chrome until --timeout, and the board is a FAIL). Python 3 standard library only.
An OK line can carry notes, each from what the page did: `NOTE-404` (a file the page asked for is not in the project: a sheet or a
screen the board links, say), `NOTE-LOGIC` (the runtime logged an error: a board whose logic throws draws a red label and is still OK; the picture says it, so does this), `NO-THEME-RULE`, and a board's own `:root` that keeps its values over a theme sheet.
"""
import argparse, functools, http.server, json, os, re, shutil, subprocess, sys, tempfile, threading, urllib.parse

MAC = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

# Appended to the runtime: ?dcprops=<json> becomes the runtime's own __dcSetProps call; ?theme=<id> sets data-theme on <html> at once.
POSTLUDE = r"""
;(function(){try{
  var q=new URLSearchParams(location.search), t=q.get('theme');
  if(t) document.documentElement.setAttribute('data-theme',t);
  (function chk(n){ if(typeof window.__dcSetProps==='function'&&typeof window.__dcRootName==='function'){ new Image().src='/__kit-runtime-ran?b='+encodeURIComponent(decodeURIComponent(location.pathname).replace(/^\//,'')); } else if(n<50){ setTimeout(function(){chk(n+1)},100); } })(0);
  var p=q.get('dcprops'); if(!p) return;
  var o=JSON.parse(p);
  function go(){ if(window.__dcSetProps&&window.__dcRootName){ window.__dcSetProps(window.__dcRootName(), o); } }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',function(){setTimeout(go,0)}); else setTimeout(go,0);
}catch(e){console.error('render.py postlude',e)}})();
"""


def find_chrome(given):
    for c in (given, os.environ.get('CHROME')):
        if c and shutil.which(c):
            return shutil.which(c)
    for n in ('google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser', 'chrome'):
        if shutil.which(n):
            return shutil.which(n)
    return MAC if os.path.exists(MAC) else None


def theme_rule(root, board, theme):
    """True when the board's own text or a stylesheet it links (a relative path inside the project, @import followed one level)
    holds a [data-theme="<theme>"] rule."""
    rx = re.compile(r'\[data-theme\s*=\s*["\']?' + re.escape(theme) + r'["\']?\s*\]')
    seen, todo = set(), [board]
    while todo:
        name = todo.pop()
        path = os.path.normpath(os.path.join(root, name))
        if name in seen or not path.startswith(root) or not os.path.isfile(path):
            continue
        seen.add(name)
        text = open(path, encoding='utf-8', errors='replace').read()
        if rx.search(text):
            return True
        base = os.path.dirname(name)
        for ref in re.findall(r'(?:href=["\']?|@import\s+(?:url\()?["\']?)([^"\'\s)>]+\.css)', text):
            if re.match(r'^([a-z]+:|//)', ref):
                continue
            todo.append(os.path.normpath(ref.lstrip('/') if ref.startswith('/') else os.path.join(base, ref)))
    return False


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('project')
    ap.add_argument('out')
    ap.add_argument('--runtime')
    ap.add_argument('--theme')
    ap.add_argument('--scheme', choices=('light', 'dark'), default='light')
    ap.add_argument('--scale', type=float, default=1)
    ap.add_argument('--only', nargs='*')
    ap.add_argument('--props')
    ap.add_argument('--suffix', default='')
    ap.add_argument('--wait', type=int, default=8000)
    ap.add_argument('--timeout', type=int, default=90)
    ap.add_argument('--chrome')
    a = ap.parse_args(argv[1:])
    rt = a.runtime or os.environ.get('DC_RUNTIME')
    if not rt or not os.path.isfile(rt):
        print('RUNTIME-ABSENT: no design runtime (dc-runtime.js) given or found' + (f' at {rt}' if rt else '') + '. This module does not ship it; '
              'see `render.py --help`. The PNG is then a person\'s: Copy as PNG on the canvas (2x), or Export.', file=sys.stderr)
        return 3
    if a.chrome and not shutil.which(a.chrome):
        print('CHROME-ABSENT: --chrome %s does not exist or is not executable. Nothing was rendered.' % a.chrome, file=sys.stderr)
        return 3
    env = os.environ.get('CHROME')
    if not a.chrome and env and not shutil.which(env):
        print('CHROME-ABSENT: $CHROME is %s, which does not exist or is not executable. Nothing was rendered.' % env, file=sys.stderr)
        return 3
    chrome = find_chrome(a.chrome)
    if not chrome:
        print('CHROME-ABSENT: no Chrome or Chromium found (--chrome, $CHROME, PATH, the macOS application). Nothing was rendered.', file=sys.stderr)
        return 3
    if a.wait < 50:
        print('BAD-WAIT: --wait %d is below 50 (0 and 1 hang Chrome until --timeout). Nothing was rendered.' % a.wait, file=sys.stderr)
        return 2
    if not os.path.isdir(a.project):
        print('NO-SUCH-PROJECT: %s is not a folder. Nothing was rendered.' % a.project, file=sys.stderr)
        return 2
    os.makedirs(a.out, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix='dcrender-')
    srv = None
    try:
        root = os.path.join(tmp, 'site')
        shutil.copytree(a.project, root)
        try:
            with open(rt, encoding='utf-8') as f:
                runtime = f.read()
        except (UnicodeDecodeError, OSError) as e:
            print('BAD-RUNTIME: %s cannot be read as text (%s); it is not the design runtime. Nothing was rendered.' % (rt, e), file=sys.stderr)
            return 3
        with open(os.path.join(root, 'support.js'), 'w', encoding='utf-8') as f:
            f.write(runtime + POSTLUDE)
        if a.props:
            try:
                json.loads(a.props)
            except ValueError as e:
                print('BAD-PROPS: --props is not JSON (%s). Nothing was rendered.' % e, file=sys.stderr)
                return 2
        boards = {}
        cj = os.path.join(root, 'canvas.json')
        if os.path.exists(cj):
            try:
                boards = json.load(open(cj, encoding='utf-8')).get('boards', {})
                if not isinstance(boards, dict):
                    raise ValueError('"boards" is not an object')
            except (ValueError, AttributeError, UnicodeDecodeError) as e:
                print('BAD-CANVAS: %s is not a canvas.json (%s). Nothing was rendered.' % (cj, e), file=sys.stderr)
                return 2
        files = sorted(n for n in os.listdir(root) if n.endswith('.dc.html'))
        if not files:
            print('NO-BOARDS: no *.dc.html file in %s (give the canvas\'s project/ folder). Nothing was rendered.' % a.project, file=sys.stderr)
            return 2
        if a.only:
            missing = [n for n in a.only if n not in files]
            if missing:
                print('NO-SUCH-BOARD: %s is not a *.dc.html file of %s' % (', '.join(missing), a.project), file=sys.stderr)
                return 2
            files = [n for n in files if n in a.only]
        if a.theme and files and not any(theme_rule(root, os.path.relpath(os.path.join(dp, f), root), a.theme) for dp, _, fs in os.walk(root) for f in fs if f.endswith(('.css', '.html'))):
            print('UNKNOWN-THEME: no file of %s holds a [data-theme="%s"] rule. Nothing was rendered.' % (a.project, a.theme), file=sys.stderr)
            return 2

        ran, missing = set(), []

        class Q(http.server.SimpleHTTPRequestHandler):
            def log_message(self, *x):
                pass

            def send_error(self, code, *args, **kw):
                if code == 404 and not self.path.startswith('/favicon'):
                    missing.append(urllib.parse.unquote(urllib.parse.urlparse(self.path).path))
                super().send_error(code, *args, **kw)

            def do_GET(self):
                if self.path.startswith('/__kit-runtime-ran'):
                    ran.add(urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get('b', [''])[0])
                    self.send_response(204)
                    self.end_headers()
                    return
                super().do_GET()
        srv = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Q, directory=root))
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        port = srv.server_address[1]
        rc = 0
        for n in files:
            b = boards.get(n, {})
            w, h = int(b.get('w', 390)), int(b.get('h', 844))
            qs = []
            if a.theme:
                qs.append('theme=' + urllib.parse.quote(a.theme))
            if a.props:
                qs.append('dcprops=' + urllib.parse.quote(a.props))
            url = 'http://127.0.0.1:%d/%s' % (port, urllib.parse.quote(n)) + ('?' + '&'.join(qs) if qs else '')
            out = os.path.abspath(os.path.join(a.out, n.replace('.dc.html', '') + a.suffix + '.png'))
            cmd = [chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--user-data-dir=' + os.path.join(tmp, 'profile'),
                   '--blink-settings=preferredColorScheme=%d' % (0 if a.scheme == 'dark' else 1),
                   '--force-device-scale-factor=%g' % a.scale, '--virtual-time-budget=%d' % a.wait,
                   '--enable-logging=stderr', '--v=0', '--screenshot=' + out, '--window-size=%d,%d' % (w, h), url]
            if os.path.exists(out):
                os.remove(out)      # a failed run must not leave the last render to pass for this one
            del missing[:]
            try:
                r = subprocess.run(cmd, capture_output=True, text=True, timeout=a.timeout)
                ok = r.returncode == 0 and os.path.exists(out) and os.path.getsize(out) > 0
                err = r.stderr[-500:]
            except subprocess.TimeoutExpired:
                ok, err = False, 'Chrome did not finish in %d s' % a.timeout
            if ok and n not in ran:
                ok, err = False, 'RUNTIME-DID-NOT-RUN: the page never reported the runtime\'s hooks (__dcSetProps, __dcRootName), so %s is not a working design runtime (truncated, empty, or another file?); the PNG was not kept\n' % rt
            note = ''
            if ok and missing:
                note += ' NOTE-404: the page asked for %s, which the project does not hold' % ', '.join(sorted(set(missing))[:4])
            logged = [m.group(1) for m in (re.search(r'CONSOLE:\d+\]\s*"(.*)", source: \S*/support\.js', ln) for ln in r.stderr.splitlines()) if m] if ok else []
            logged = [m for m in logged if 'returned 404' not in m]       # a missing file is said by NOTE-404
            if logged:
                note += ' NOTE-LOGIC: the runtime logged: %s' % logged[0][:160]
            if ok and a.theme and not theme_rule(root, n, a.theme):
                note += ' NO-THEME-RULE: this board and its linked sheets hold no [data-theme="%s"] rule, so it is drawn as the brand version' % a.theme
            elif ok and a.theme and re.search(r':root\s*\{[^}]*--[\w-]+\s*:', open(os.path.join(root, n), encoding='utf-8', errors='replace').read()):
                note += ' NOTE: the board has its own :root block of custom properties, which wins over a theme sheet for the properties it sets'
            print(('OK   ' if ok else 'FAIL ') + '%s %dx%d%s -> %s%s' % (n, w, h, ' @%gx' % a.scale if a.scale != 1 else '', out, note))
            if not ok:
                rc = 1
                if os.path.exists(out):
                    os.remove(out)
                sys.stderr.write(err)
        return rc
    finally:
        if srv:
            srv.shutdown()
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
