#!/usr/bin/env python3
"""Writes the role chapters' "what your menu shows" tables into docs/manual/src/NN-*.json.

    python3 tool/manual/words.py

The tables come from build/manual/menus.json, which `node tool/manual/menus.mjs` reads from the
app itself, so a chapter never lists a menu row the app does not draw. Everything else in a
chapter's JSON (overview, rules, website-instead) is written by hand and left as it is.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'docs' / 'manual' / 'src'
menus = json.loads((ROOT / 'build' / 'manual' / 'menus.json').read_text())

# chapter → (the person whose menu it shows, the rows worth showing, the table's heading)
CHAPTERS = {
    '15-mentors': ('mentor', {'Mentorship'}, "What a mentor's menu adds"),
    '16-company-admins': ('companyAdmin', {'Jobs', 'Company', 'Marketplace'}, None),
    '17-hiring': ('recruiter', {'Jobs', 'Company'}, None),
    '18-hiring-managers': ('hiringManager', {'Jobs'}, "What a hiring manager's menu shows"),
    '19-sellers': ('seller', {'Company', 'Marketplace'}, None),
    '20-buyers': ('buyer', {'Company', 'Marketplace'}, None),
    '21-partner-institutes': ('instituteAdmin', {'Partner Institute'}, 'What the institute adds to your menu'),
}


def rows(who, only):
    return [
        {'row': f"**{w['label']}**", 'pages': ' · '.join(i['label'] for s in w['sections'] for i in s['items'])}
        for w in menus[who]['workspaces']
        if w['label'] in only
    ]


for chapter, (who, only, title) in CHAPTERS.items():
    path = SRC / f'{chapter}.json'
    data = json.loads(path.read_text()) if path.exists() else {}
    data['menu'] = rows(who, only)
    if title:
        data['menuTitle'] = title
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    print(chapter, len(data['menu']), 'rows')
