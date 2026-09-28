#!/usr/bin/env python3
"""Compile-check the Godot project and auto-fix GDScript ':=' inference errors.

usage: python3 tools/dev/fix_inference.py [project_dir]

Godot 4.7 treats `var x := <Variant expression>` as an error ("Cannot infer the type..."). This
runs the world scene headless, finds those errors and rewrites that one ':=' to '=' (untyped),
repeating until none are left. Then it prints any other SCRIPT ERRORs so you can fix them by
hand. Errors about Game.plan being Nil are expected when the world scene runs without a campaign.
"""
import re, subprocess, sys, os
proj = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', '..'))
subprocess.run(['godot', '--headless', '--path', proj, '--import'], capture_output=True, timeout=900)
for it in range(40):
    out = subprocess.run(['timeout', '150', 'godot', '--headless', '--path', proj, 'res://scenes/world.tscn', '--quit-after', '2'],
                         capture_output=True, text=True).stdout
    errs = re.findall(r'Parse Error: (Cannot infer the type of "\w+"|The variable type is being inferred from a Variant)[^\n]*\n\s*at: GDScript::reload \((res://[^:]+):(\d+)\)', out)
    if not errs:
        other = re.findall(r'(SCRIPT ERROR: [^\n]*\n\s*at: [^\n]*)', out)
        other = [o for o in other if 'Nil' not in o and 'null value' not in o]
        print('no inference errors left')
        print('\n'.join(other[:25]) if other else 'no other script errors (Nil/null ones from running the world without a campaign are ignored)')
        break
    for _, f, l in errs:
        p = os.path.join(proj, f.replace('res://', ''))
        lines = open(p).read().split('\n')
        i = int(l) - 1
        lines[i] = lines[i].replace(':=', '=', 1)
        open(p, 'w').write('\n'.join(lines))
        print('fixed', f, l)
