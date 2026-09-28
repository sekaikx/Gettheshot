# Character rig and animation pipeline

The street cast (`scripts/world/person.gd`) is built from Quaternius' **Ultimate Modular Men /
Women** (CC0, the "Humanoid Rig" FBX files in `assets/models/characters/quaternius/`). A person is
one outfit's skeleton with four parts hung on it (body, legs, feet, head), each part taken from
any outfit of the same rig and dyed per material, plus procedural hats, a shopkeeper's apron, a
patrolman's belt, the family ring. Hats sit on the `Head` bone, the pistol on `RightHand`.

The clips live in `assets/animations/quat_men.res` and `quat_women.res` (library `q`), built by
`build_library.gd` from

| source | from | clips |
|---|---|---|
| `ual_src/UAL1_Standard.glb` | Universal Animation Library (Standard), `Unreal-Godot/` | Idle, Walk, Walk_Formal, Jog, Sprint, Idle_Talking, Sitting_Idle, Pistol_Idle / Shoot, Punch_Jab / Cross, Hit_Chest / Head, PickUp, Interact, Death |
| `ual_src/UAL2_Standard.glb` | Universal Animation Library 2 (Standard), `Unreal-Godot/` | Walk_Carry, Idle_FoldArms, Idle_Rail, Melee_Hook, Hit_Knockback, Yes, No, Consume, LayToIdle |
| `ual_src/QuatWoman_Anims.fbx` | Ultimate Modular Women, `Individual Characters/FBX/Casual.fbx` | Kick (Kick_Right), Wave, Fall (Death) |
| synthesised | | Cheer (fists up over the idle), Lie_Down / Lie_Dead (last frames of Fall / Death) |

All CC0 (quaternius.com, quaternius.itch.io). The sources are not committed (`ual_src/.gitignore`);
their `.import` files are, and carry the retargeting settings.

## How the retarget works

1. `patch_imports.py` writes the import settings: every rig (UAL mannequin, both Quaternius rigs,
   the animated Quaternius rig) gets a `BoneMap` to `SkeletonProfileHumanoid`
   (`assets/animations/bone_map_ual.tres`, `bone_map_quat_men.tres`, `bone_map_quat_women.tres`,
   `bone_map_quat_anim.tres`), bone renaming, the rest fixer (overwrite axis, fix silhouette,
   normalised position tracks via `Skeleton3D.motion_scale`) and a unique `%Skeleton3D`.
2. `build_library.gd` re-solves each clip in world space: a target bone takes the world rotation
   delta (pose x rest^-1) of the same-named source bone, applied to its own rest after swinging that
   rest onto the source bone's rest direction (the mannequin's spine leans back, its forearms are
   straighter). That survives different bone rolls and hierarchies: the Women rig hangs its legs
   from Root (they get position tracks that keep them on the hips), the animated rig moves a Body
   bone and IK feet. Hips follow the source hips' world position relative to rest, in normalised
   units. Part of the mannequin's hunched idle stance (spine, chest, neck, head) is taken out of
   every UAL clip (`POSTURE`).

## Rebuild

```
# unzip the two UAL "Standard" zips from quaternius.itch.io and the Modular Women pack, then
cp UAL1_Standard.glb UAL2_Standard.glb game/tools/rig/ual_src/
cp "Ultimate Modular Women - April 2022/Individual Characters/FBX/Casual.fbx" game/tools/rig/ual_src/QuatWoman_Anims.fbx
godot --headless --path game --import
python3 game/tools/rig/patch_imports.py game      # only for newly added files
godot --headless --path game --import
godot --headless --path game --script res://tools/rig/build_library.gd
```

## Looking at it

```
# every kind side by side (rows are clip@time; --view=game uses the street camera, pitch 56 deg)
xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --path game res://tools/rig/lineup.tscn -- \
    --out=/tmp/lineup.png --view=game --dist=20 --rows=Idle@0.4,Walk@0.3,Punch_Cross@0.3
# one row per kind, one clip per column
... res://tools/rig/lineup.tscn -- --out=/tmp/g.png --view=close --dist=9 --lift=0 --kinds=crew,ped:woman \
    --gallery=Idle@0.4,Walk@0.3,Kick@0.45,Cheer@0.5,Lie_Down@0
# a crowd in the real street at the game camera
DIST=17 OUT=/tmp/street.png xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --path game res://tools/rig/street.tscn
# source mannequin next to the retargeted people / which material is which
... res://tools/rig/compare.tscn -- --out=/tmp/c.png --clip=Idle --src=Idle --t=0.5 --yaw=35
... res://tools/rig/mats.tscn -- --out=/tmp/m.png --files=men/Farmer,women/Formal
```
