#!/usr/bin/env python3
"""Changes a step's sentence in a flow file and in what was already captured, so a wording fix needs no new run.

    python3 tool/manual/retext.py <chapter> <flow> <step-id> "<new sentence>"

The old sentence is read from build/manual/<chapter>/<flow>.json and must appear once in the flow file.
"""
import json, sys, pathlib

chapter, flow, step, new = sys.argv[1:5]
root = pathlib.Path(__file__).resolve().parents[2]
captured = root / 'build' / 'manual' / chapter / f'{flow}.json'
data = json.loads(captured.read_text())
hit = [s for s in data['steps'] if s['id'] == step]
if len(hit) != 1:
    sys.exit(f'{chapter}/{flow}: no single step "{step}"')
old = hit[0]['text']
src = root / 'tool' / 'manual' / 'flows' / f'{chapter}.mjs'
text = src.read_text()
quoted_old = "'" + old.replace("'", "\\'") + "'"
if text.count(quoted_old) != 1:
    sys.exit(f'the old sentence is not in {src.name} exactly once (found {text.count(quoted_old)})')
src.write_text(text.replace(quoted_old, "'" + new.replace("'", "\\'") + "'"))
hit[0]['text'] = new
captured.write_text(json.dumps(data, indent=2, ensure_ascii=False))
print('ok')
