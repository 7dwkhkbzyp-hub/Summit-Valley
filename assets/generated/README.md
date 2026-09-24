# Summit Valley 3D assets

This folder is the runtime asset target for the Blender pipeline.

Expected GLBs:

- alpine_hotel.glb
- alpine_chalet.glb
- alpine_pine.glb
- skier.glb
- chairlift.glb
- gondola.glb
- snowmaker.glb

PlayCanvas recommends GLB for web 3D assets because it preserves model hierarchy, materials, textures and animated skeletons efficiently. The runtime is wired to use this folder as the asset boundary; the procedural versions remain as a fallback until the GLBs are present.

Run `tools/blender_generate_assets.py` from Blender 4.x to generate the starter asset set. These starter models are intentionally a base production pack; the next art pass can replace individual GLBs with higher-detail Blender models without changing the tycoon code.
