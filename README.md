# GrandStrategy

Godot **4.7.2 Standard**, with Terrain3D installed under `addons/terrain_3d/`.
The project now opens the runtime Map Editor. It uses Forward+ rendering.

## Scene structure

`scenes/map_editor.tscn` contains the complete editable setup:

- `Terrain3D`, with scene-owned material and assets, region size 256, and spacing 1.
- `WorldEnvironment`, `Sun`, and `Camera3D`. The ocean clipmap is owned by
  Terrain3D, using its Ocean Enabled and Ocean Material inspector properties.
- `EditorUI`, including every settings control, preview, buttons and save dialog.

Select these nodes in the Godot scene tree to change their settings in the
Inspector. Button and save-dialog signals are connected in the scene file.
The Terrain3D editor plugin is enabled in the project settings.

The controller references these existing nodes. Generation replaces only the
Terrain3D region data and updates the preview and camera framing;
it preserves the Terrain3D node, material and assets. Terrain height data is
still generated when the scene runs, rather than stored in the starter scene.

## Generate a world

Open `project.godot` and press **F5**, or open `scenes/map_editor.tscn` and press
**F6**. An initial map is generated automatically.

- Set physical width and length independently: 256–2048 metres.
- Choose **Heightmap quality**: Standard uses one sample per metre; High uses
  two samples per metre (0.5 m vertex spacing) and is the default. For example,
  a 1024 x 512 m world gets a 2048 x 1024 float heightmap in High mode. A
  2048 x 2048 m world gets 4096 x 4096 samples. Region size remains 256 samples.
  The last vertex lies one vertex spacing short of the nominal tile footprint.
- Set **Hydraulic erosion** from 0 (off) to 2 (strong), default 1.
- Choose a seed to reproduce a world, or select **Random seed**.
- Height scale sets the full normalized elevation range in metres. Sea level
  defaults to 20%, matching Azgaar's land threshold. Sea level is subtracted
  from terrain height so the ocean surface remains at world Y=0.
- Press **Generate terrain** to apply changed settings.
- Right-drag to orbit, middle-drag to pan, use the wheel to zoom, and **F** to frame.

The heightmap is generated off the main thread. Its floating-point values are
imported directly into Terrain3D; the terrain is not a replacement mesh.
The surface uses slope, elevation, moisture and latitude to blend plains,
forest-colored areas, dry ground, stone and snow. Terrain3D uses a custom shader
for fine surface variation. The ocean uses Terrain3D's shipped ocean shader, with its clipmap rendering,
depth-based shading and a world sea level of zero.
Both shading resources are authored in the scene and editable in the Inspector.

Select the MapEditor root to adjust **Detail Strength** (0–2, default 1). This
changes real ridge/foothill geometry, not just the shading. Higher height scales
make relief more pronounced; existing saved width/length/height defaults are
preserved. Generation and color calculation both run on a worker thread.
This is a procedural terrain visual pass: it does not yet simulate erosion,
river drainage, real forest instances, or political territories.

## Save

Choose **Save heightmap + terrain…** and select an empty folder. This writes:

- `heightmap.exr`: normalized floating-point heights, before sea offset/scale.
- `map.json`: the settings used for the generated map.
- `terrain/terrain3d_*.res`: Terrain3D region resources, including height and color.
- `terrain_material.res`: the custom terrain material with its generated surface texture.
- `water_material.res`: the native Terrain3D ocean material and its settings.

An occupied folder is rejected. Editing the controls after generating does not
change the settings saved with the current map. To use the saved regions in a
separate scene, create a Terrain3D with region size 256 and vertex spacing
`1.0 / samples_per_metre` from `map.json`,
set its data directory to `terrain/`, assign `terrain_material.res`, and give
its assets at least one valid RGBA8 texture (as in MapEditor). Enable the Terrain3D ocean and assign
`water_material.res` to its Ocean Material property. No separate ocean mesh is used. Retain this project's `shaders/` directory,
which the saved materials reference. The node initializes material uniforms
when the saved material is attached. For a raw EXR import, use `height_scale` and offset
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
cells and Godot's seeded random generator for continental layout. Cubic
reconstruction, domain warping and multi-octave ridged detail then produce the
final floating-point heightmap. Generator revision 5, height sampling, erosion strength and detail strength are
recorded in `map.json`; existing seeds produce updated geometry with this revision. It preserves the Old World recipe, not Azgaar's exact
Voronoi topology, random sequence, or pixel-for-pixel results. It does not yet
create rivers, biome gameplay data, provinces, countries, or gameplay.

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

Headless tests skip the two GPU-only terrain uniform checks. To verify texture
binding and that saved materials restore their textures on Terrain3D, run:

```powershell
godot --path . --script res://tests/map_editor_test.gd
```

For a rendered screenshot check:

```powershell
godot --path . --resolution 1280x720 --script res://tests/map_editor_preview.gd
```

The screenshot is written to `tests/output/map_editor_preview.png`.

## Shader attribution

`shaders/strategy_terrain.gdshader` adapts Terrain3D's shipped
`extras/shaders/minimum.gdshader`, preserving its LOD, height sampling, holes,
and terrain normal calculations. The original copyright header is retained;
the Terrain3D license remains under `addons/terrain_3d/`.

## Shoreline rendering

The scene's `TerrainFocus` node follows the orbit/pan target and drives
Terrain3D's clipmap target. High-detail terrain is therefore placed around the
visible ground, rather than underneath the elevated camera. Mesh size 96 and
one tessellation level improve close-up terrain; the native ocean uses spacing
2, mesh size 64 and one tessellation level. Four-sample MSAA smooths silhouettes.
These settings increase GPU work and are editable in the Inspector.

The custom terrain shader reconstructs heights bilinearly at every LOD, including
geomorph positions, and surface colors blend continuously across the sea level.
The generator and saved terrain dimensions are unchanged by this rendering fix.

## Realistic surface detail

Ground, rock and sand now use three seamless 512 x 512 PBR texture layers.
Albedo/height and normal/roughness arrays live in `shaders/detail/` and are
assigned to the Terrain3D material in the scene. The shader blends materials
by slope and elevation, uses triplanar rock projection to reduce stretching,
blends rotated ground samples to reduce repetition, and fades fine relief at
distance to reduce shimmering. This adds approximately 8 MB of texture data.

Select **Terrain3D > Material > Shader Uniforms > Surface Detail** to adjust
surface detail strength, ground/rock scale and bump strength. These control
surface shading independently of the MapEditor root's geometry Detail Strength.

Generation also applies six conservative thermal-weathering iterations to the
uplands. Steep cells transfer material downhill rather than simply blurring the
whole map. This thermal pass is followed by the hydraulic stage described below.
Revision 5 is recorded in saved settings; matching old seeds have updated
elevations after the new reconstruction and erosion stages. Coastline blending and the native Terrain3D
ocean remain in use.

The texture arrays are included, so rebuilding is optional. Rebuild using a
Godot executable **with graphics enabled** (GPU-backed texture arrays cannot be
serialized correctly by the headless dummy renderer):

```powershell
godot --path . --script res://tools/build_terrain_materials.gd
```

For overview and close-up screenshots:

```powershell
godot --path . --script res://tests/terrain_detail_preview.gd
```

Images are written to `tests/output/detail_overview.png` and
`tests/output/detail_closeup.png`. The full non-headless test suite checks
material layers, saved texture restoration, weathering mass conservation,
downhill transfer and lowland preservation, alongside the existing map checks.

## Heightmap landforms — shared pipeline

Old World remains the continental layout recipe. The elevation pipeline now:

1. Reconstructs the coarse recipe with a separable Gaussian kernel so the old
   cell falloff does not become tall, narrow walls.
2. Uses the selected reference preset to add domain-warped, seven-octave
   mountain ridges and secondary spurs at the actual output resolution. The
   softer preset reduces upland heights; the rugged preset retains their relief.
3. Applies conservative thermal weathering to steep uplands.
4. Runs seeded water droplets down bilinear height gradients, removing soil with
   a weighted brush and depositing sediment where their carrying capacity falls.
   Erosion and deposition have per-cell limits to avoid pits and needle peaks.
5. Applies the hydraulic elevation delta to the full-resolution float image and
   imports those actual heights into Terrain3D.

Droplet erosion runs on a grid up to 1024 samples across; its delta is interpolated
onto the output while retaining the finer ridge field. This keeps generation
practical, but it does not simulate hydraulic channels at the full 4K resolution.
Droplets still carrying sediment at their lifetime/boundary limit export that
sediment from the simulation. The sea band is protected from the erosion delta.
This is not a full river, lake, drainage-network or geological-time simulation.

Quality and erosion controls are authored into the runtime settings panel,
which scrolls to fit the window. Generation remains on a worker thread. High
mode uses four times as many elevation samples as Standard, so memory use and
processing time increase. Saved `map.json` includes physical dimensions,
heightmap dimensions, samples per metre, generator revision and erosion strength.

The visual reference was the rugged mountain/valley heightmaps at
https://www.motionforgepictures.com/height-maps/. No Motion Forge heightmaps or
assets were downloaded or incorporated; this remains an original procedural
pipeline and is not an exact recreation of those authored examples.

To inspect real geometry independently of texture detail:

```powershell
godot --path . --script res://tests/heightmap_geometry_preview.gd
```

This renders a neutral gray relief study at height scale 100, with surface detail
and bump shading disabled. It saves `tests/output/terrain_rugged_reference.png`
(or `terrain_softer_reference.png` with `-- --softer`) and an 8-bit grayscale
inspection image, `tests/output/heightmap_data_v4.png`.
The saved map's actual elevation data remains floating-point EXR.

## Province generation decision — OpenGS

Decision recorded 6 November 2026: use **OpenGS Map Tool** for province and
territory generation/authoring: https://github.com/Thomas-Holtvedt/opengs-maptool.

Planned workflow: derive a coastline/land mask from the finished terrain, author
provinces in OpenGS, then import its province image and JSON data into Godot.
Terrain3D remains the terrain renderer. Province IDs, adjacency, selection,
ownership and political overlays belong to the game's province system.
OpenGS input-image export is implemented in the runtime map editor. Importing
generated OpenGS province images and province data back into Godot is still planned. No province plugin is being substituted for Terrain3D.

## Accepted terrain references — revision 5

The default is now **Rugged reference**, using the earlier additive mountain
ridge/spur formula, High 2x height sampling, erosion 1.0, detail strength 1.0,
height scale 100, sea level 20%, and seed 12345. The second **Softer reference**
preset applies the earlier 0.72 upland height multiplier before the additive
ridge stage. These correspond to the rugged and softer gray relief previews
selected by the user. Later multiplicative ridge reshaping is no longer used.

**Neutral relief view** is enabled by default: a gray material with surface
texture detail and bump strength disabled, so the actual terrain shape remains
visible. Turn this off to return to terrain colors and material detail. This
view switch does not regenerate or change elevation data.

Preset and view controls are scene-authored and available in the running map
editor. Generation settings record revision 5, relief_profile (0 rugged / 1
softer), and neutral_relief along with the existing settings. Reference previews
are reproducible with `tests/heightmap_geometry_preview.gd`; pass `-- --softer`
to capture the softer variant. The preview camera differs between references,
while both use the same physical dimensions, seed, sampling and height scale.

The user-selected visual targets are preserved in [rugged-target.png](docs/terrain-references/rugged-target.png) and [softer-target.png](docs/terrain-references/softer-target.png). Compare future terrain changes against these before replacing the defaults.

## Export images for OpenGS

Generate a map, click **Export OpenGS images…**, and choose an empty folder.
The exporter uses the last generated heightmap and its settings; editing the
controls without generating does not change the exported world. Image building
and writing run on a worker thread, and generation/saving are locked until the
export finishes. Occupied folders are rejected.

The pack contains four opaque, lossless RGB PNGs at the heightmap resolution:

| File | Contents |
| --- | --- |
| `land.png` | White land; ocean `(5,20,18)`; lakes `(0,255,0)` |
| `boundary.png` | White everywhere: no predefined country/state constraints |
| `density.png` | Grayscale suitability: darker lowlands attract more seeds; lighter rugged/arid terrain attracts fewer |
| `terrain.png` | Exact OpenGS terrain labels, without interpolation or anti-aliasing |

Water below the generated sea level is ocean if connected to a map edge using
four-neighbour connectivity; other water bodies become lakes. Classification is
relative to the exported map extent. Pixels exactly at sea level are land.

**Boundary limitations:** there are no authored country/state borders in this
editor yet, so the boundary file intentionally imposes no constraints. It may
be omitted in OpenGS, or edited externally to add exact-black `(0,0,0)` borders
on the same white image. Mountains are not automatically treated as mandatory
political boundaries. OpenGS still generates territories and provinces from the
land image without predefined administrative borders.

Terrain labels use these RGB codes from the
[OpenGS usage instructions](https://github.com/Thomas-Holtvedt/opengs-maptool#how-to-use-the-tool):

| Terrain | RGB |
| --- | --- |
| forest | 89, 199, 85 |
| hills | 248, 255, 153 |
| mountain | 157, 192, 208 |
| plains | 255, 129, 66 |
| urban | 120, 120, 120 |
| jungle | 127, 191, 0 |
| marsh | 76, 96, 35 |
| desert | 255, 127, 0 |
| deep_ocean | 2, 38, 150 |
| shallow_sea | 56, 118, 217 |
| fjords | 75, 162, 198 |
| lakes | 58, 91, 255 |

Land classification is a deterministic elevation/slope/moisture/latitude
heuristic using the generated seed, physical height scale and vertex spacing.
Mountain/hill classifications take precedence over vegetation. Urban and fjord
labels are reserved for future authoring; they are not inferred from noise.
Density is a suitability estimate, not population or a simulated economy.
Ocean density is uniform (175); lake density is white (255), since OpenGS makes
individual lake provinces. OpenGS exposes an **Exclude Ocean** density option.

Load the images into their matching OpenGS tabs, generate **territories first**,
then **provinces**. All four share orientation: image x maps to world +X, image y
to world +Z, with no flip. Do not resize the images independently, recolor the
label maps, or convert them to JPEG. High 2x sampling exports twice the physical
map dimensions per image axis, and does not enlarge the world.

The exporter also writes `README.txt` with import instructions and
`opengs_export.json` with source settings, resolution, water counts, palette,
orientation and a SHA-256 of the source height data. The neutral/color terrain
view toggle has no effect on these data maps.

Verify the raster exporter with:

```powershell
godot --headless --path . --script res://tests/opengs_export_test.gd
```

This checks exact colors, rectangular dimensions, four-neighbour lake detection,
density direction, PNG byte round-trips, all-land/all-ocean inputs and overwrite
protection. The full map-editor suite also verifies scene-authored export
controls, background-worker locking and use of generated rather than edited
settings. Files are validated against the documented image contract; an actual
OpenGS application import has not been exercised by these tests.
