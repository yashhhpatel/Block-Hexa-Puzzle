"""One-off helper: drops the nearest enclosing `const` for each analyzer
const_eval error (text became a tr() call, so it can't be const)."""
import os, re, subprocess

for _ in range(12):
    out = subprocess.run('flutter analyze lib', shell=True, capture_output=True, text=True).stdout
    errs = re.findall(r"error - [^\n]*? - (lib[^:]+):(\d+):(\d+) - (const_\w+|non_constant\w*)", out)
    if not errs:
        print('clean')
        break
    done = set()
    for path, line, col, _code in errs:
        path = path.replace(os.sep, '/').replace(chr(92), '/')
        line, col = int(line) - 1, int(col) - 1
        if (path, line) in done:
            continue
        lines = open(path, encoding='utf-8').read().split('\n')
        for ln in range(line, max(-1, line - 12), -1):
            text = lines[ln] if ln != line else lines[ln][:col + 1]
            idx = text.rfind('const ')
            if idx >= 0:
                lines[ln] = lines[ln][:idx] + lines[ln][idx + 6:]
                break
        open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        done.add((path, line))
    print('fixed', len(done))
