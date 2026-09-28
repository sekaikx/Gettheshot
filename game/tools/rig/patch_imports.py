#!/usr/bin/env python3
"""Writes the retargeting settings into the .import files of the Quaternius characters and the
animation sources (run once after copying new files in, then `godot --headless --import`).

Every rig is mapped to Godot's SkeletonProfileHumanoid (bones renamed to "Hips", "LeftUpperArm",
..., rests overwritten to the profile axes and the T-pose silhouette, position tracks normalised
by Skeleton3D.motion_scale, unique %Skeleton3D) so tools/rig/build_library.gd can move clips
between them in world space.

    python3 tools/rig/patch_imports.py game
"""
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")

SUB = """_subresources={
"nodes": {
"PATH:%(skel)s": {
"retarget/bone_map": Resource("res://assets/animations/%(map)s"),
"retarget/bone_renamer/rename_bones": true,
"retarget/bone_renamer/unique_node/make_unique": true,
"retarget/bone_renamer/unique_node/skeleton_name": "Skeleton3D",
"retarget/remove_tracks/except_bone_transform": false,
"retarget/remove_tracks/unimportant_positions": false,
"retarget/remove_tracks/unmapped_bones": false,
"retarget/rest_fixer/apply_node_transforms": true,
"retarget/rest_fixer/fix_silhouette/base_height_adjustment": 0.0,
"retarget/rest_fixer/fix_silhouette/enable": true,
"retarget/rest_fixer/fix_silhouette/threshold": 15.0,
"retarget/rest_fixer/keep_global_rest_on_leftovers": true,
"retarget/rest_fixer/normalize_position_tracks": true,
"retarget/rest_fixer/reset_all_bone_poses_after_import": true,
"retarget/rest_fixer/retarget_method": 1,
"retarget/rest_fixer/use_global_pose": true
}
}
}"""

JOBS = []
for d, m in [("assets/models/characters/quaternius/men", "bone_map_quat_men.tres"),
             ("assets/models/characters/quaternius/women", "bone_map_quat_women.tres")]:
    for f in sorted(os.listdir(os.path.join(ROOT, d))):
        if f.endswith(".fbx"):
            JOBS.append((d + "/" + f, "CharacterArmature/Skeleton3D", m, False))
for f in ["UAL1_Standard.glb", "UAL2_Standard.glb"]:
    JOBS.append(("tools/rig/ual_src/" + f, "Armature/Skeleton3D", "bone_map_ual.tres", True))
JOBS.append(("tools/rig/ual_src/QuatWoman_Anims.fbx", "CharacterArmature/Skeleton3D", "bone_map_quat_anim.tres", True))

for path, skel, bmap, is_anim in JOBS:
    imp = os.path.join(ROOT, path + ".import")
    if not os.path.exists(imp):
        print("missing (run godot --import first):", imp)
        continue
    s = open(imp).read()
    s = re.sub(r"_subresources=\{.*?\n\}\n(?=[a-z])|_subresources=\{\}", lambda _: SUB % {"skel": skel, "map": bmap}, s, flags=re.S)
    opts = {
        "animation/import": "true" if is_anim else "false",
        "animation/remove_immutable_tracks": "false",
        "animation/trimming": "false",
        "meshes/generate_lods": "false" if is_anim else "true",
        "meshes/create_shadow_meshes": "false" if is_anim else "true",
        "meshes/ensure_tangents": "false",
        "meshes/light_baking": "0",
    }
    for k, v in opts.items():
        s = re.sub(r"^%s=.*$" % re.escape(k), "%s=%s" % (k, v), s, flags=re.M)
    open(imp, "w").write(s)
    print("patched", path)
