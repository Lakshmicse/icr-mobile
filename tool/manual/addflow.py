#!/usr/bin/env python3
"""Appends flows (JavaScript read from stdin) to the end of a chapter's flow file:  addflow.py <chapter>"""
import pathlib, sys
p = pathlib.Path(__file__).resolve().parent / 'flows' / f'{sys.argv[1]}.mjs'
s = p.read_text().rstrip()
assert s.endswith(']);'), 'the chapter file does not end with ]);'
p.write_text(s[:-3].rstrip() + '\n\n' + sys.stdin.read().rstrip() + '\n]);\n')
print('added to', p.name)
