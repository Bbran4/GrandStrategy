# GrandStrategy

Godot **4.7.2 Standard**, with Terrain3D installed under `addons/terrain_3d/`.
The project now opens the runtime Map Editor. It uses Forward+ rendering.

## Scene structure

`scenes/map_editor.tscn` contains the complete editable setup:

- `Terrain3D`, with scene-owned material and assets, region size 256, and spacing 1.
- `WorldEnvironment`, `Sun`, `Camera3D`, and `Ocean` with its mesh and material.
- `EditorUI`, including every settings control, preview, buttons and save dialog.

Select these nodes in the Godot scene tree to change their settings in the
Inspector. Button and save-dialog signals are connected in the scene file.
The Terrain3D editor plugin is enabled in the project settings.

The controller references these existing nodes. Generation replaces only the
Terrain3D region data and updates the preview, ocean bounds and camera framing;
it preserves the Terrain3D node, material and assets. Terrain height data is
still generated when the scene runs, rather than stored in the starter scene.

## Generate a world

Open `project.godot` and press **F5**, or open `scenes/map_editor.tscn` and press
**F6**. An initial map is generated automatically.

- Set width and length independently: 256–2048 samples, in 256-sample regions.
  At one metre between vertices, a 1024-sample map spans 1023 metres between
  its first and last vertices. These are local world dimensions, not real-world
  geographic distances; strategy-game kilometre scaling can be added later.
- Choose a seed to reproduce a world, or select **Random seed**.
- Height scale sets the full normalized elevation range in metres. Sea level
  defaults to 20%, matching Azgaar's land threshold. Sea level is subtracted
  from terrain height so the ocean surface remains at world Y=0.
- Press **Generate terrain** to apply changed settings.
- Right-drag to orbit, middle-drag to pan, use the wheel to zoom, and **F** to frame.

The heightmap is generated off the main thread. Its floating-point values are
imported directly into Terrain3D; the terrain is not a replacement mesh.
A simple elevation colormap and ocean plane provide an initial visualization.

## Save

Choose **Save heightmap + terrain…** and select an empty folder. This writes:

- `heightmap.exr`: normalized floating-point heights, before sea offset/scale.
- `map.json`: the settings used for the generated map.
- `terrain/terrain3d_*.res`: Terrain3D region resources, including height and color.

An occupied folder is rejected. Editing the controls after generating does not
change the settings saved with the current map. To use the saved regions in a
separate scene, create a Terrain3D with region size 256 and vertex spacing 1,
set its data directory to `terrain/`, and use a material showing its colormap
with background disabled. For a raw EXR import, use `height_scale` and offset
`-sea_level * height_scale` from `map.json`. There is no saved-map browser or
load button yet.

## Old World source and adaptation

The recipe and height operations are adapted from Azgaar's MIT-licensed
[Fantasy Map Generator](https://github.com/Azgaar/Fantasy-Map-Generator), pinned
for this implementation at commit `83838f14f1fb0523aed0b5fbb252f4595443c7f9`:

- `src/data/heightmap-templates.ts`: the complete Old World operation sequence.
- `src/model/physical/heightmap-generator.ts`: hill, pit, range, trough, strait,
  land multiplication and smoothing operations.

License and attribution are in `third_party/azgaar/LICENSE.txt`.
This implementation uses approximately 10,000 staggered, six-neighbour raster
cells, Godot's seeded random generator, and bilinear interpolation to the chosen
output dimensions. It preserves the Old World recipe, not Azgaar's exact
Voronoi topology, random sequence, or pixel-for-pixel results. It does not yet
create rivers, biomes, provinces, countries, or gameplay.

## Verification

Run with a Godot 4.7.2 executable:

```powershell
godot --headless --path . --script res://tests/map_editor_test.gd
```

Checks reproducible and different seeds, normalized float data, rectangular
maps, land and water, Terrain3D height correspondence, region replacement,
EXR/settings/region saving, overwrite protection, scene-authored nodes and
signals, and preservation of the Terrain3D node/material/assets on regeneration. Test outputs are ignored
by Git under `tests/output/`.

For a rendered screenshot check:

```powershell
godot --path . --resolution 1280x720 --script res://tests/map_editor_preview.gd
```

The screenshot is written to `tests/output/map_editor_preview.png`.
