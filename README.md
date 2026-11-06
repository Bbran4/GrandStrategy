# GrandStrategy

Godot **4.7.2 Standard**, with Terrain3D installed under `addons/terrain_3d/`.
The project opens a main menu with **Country workshop** and **Map editor**.
It uses Forward+ rendering.

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

Open `project.godot`, press **F5** and choose **Map editor**, or open
`scenes/map_editor.tscn` and press **F6**. An initial map is generated automatically.

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
OpenGS input-image export and province/territory import are implemented in the
runtime map editor, including selection, adjacency, political views and saved ownership. No province plugin is being substituted for Terrain3D.

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

## Import OpenGS provinces into the game

The default input folder is **`data/opengs/`**. Your current exports contain
**500 provinces and 260 territories** and have been exercised in Godot 4.7.2.
The source manifest copied from `data/opengs_export.json` matches the generated
heightmap hash, resolution, sea level and physical dimensions.

Export these **raw flat-color PNGs** from OpenGS into that folder:

- `province.png` (also accepts `provinces.png`, `province_map.png`, or `province_image.png`)
- `territory.png` (also accepts `territories.png`, `territory_map.png`, or `territory_image.png`)

Keep only one filename variant for each map. These are OpenGS **output** maps,
not the input `land.png`, `terrain.png`, or a screenshot with borders and labels.
Images must be opaque, lossless PNGs at exactly the generated heightmap size;
they are never resized, filtered, flipped or recolored during import. Black is
reserved for unassigned pixels. Province/territory coverage must agree.

Optional but recommended metadata, using OpenGS's JSON exports:

- `province_definitions.json`: original province IDs, RGB values, type and terrain.
- `territory_definitions.json`: original territory IDs, RGB values and type.
- `territory_history.json`: explicit territory-to-province membership.
- `opengs_export.json`: the source manifest from our input-image export pack.

Definitions also accept `province_data.json` / `provinces.json` and
`territory_data.json` / `territories.json`; avoid duplicate variants. JSON schema
reference: https://github.com/Thomas-Holtvedt/opengs-maptool/blob/main/docs/data_export_format.md.
Without definitions, each RGB color receives a deterministic ID such as
`PRV_C80A14`, land/water is inferred from the underlying heightmap, and terrain
metadata remains unspecified. With definitions, unknown colors are rejected,
which also catches antialiased or mismatched images. There is a 65,535-region
limit per layer and a 32 MB limit on individual JSON files.

### Run and inspect

Press **F5**. After terrain generation, the editor automatically loads the
exports from `data/opengs/` if present. Auto-import and its folder are exposed on
the MapEditor root in the Inspector. **Import OpenGS provinces…** can load a
different folder. Parsing, validation, adjacency and border-distance generation
run on a worker; only the completed, valid map replaces the current province data.
A failed import keeps the previous active map. Regenerating terrain clears stale
province data before attempting to load the default folder again; a mismatched
source manifest is rejected instead of silently misaligning provinces.

The map-mode dropdown offers:

- **Terrain + borders**: retain the terrain/neutral relief beneath border lines.
- **Province view**: individual province colors.
- **Territory view**: parent-territory colors, with thicker territory boundaries.
- **Country ownership**: country colors, thin province lines and thicker ownership boundaries.

Water retains its ocean appearance. Borders and selection also render on the
existing Terrain3D ocean clipmap. `strategy_ocean.gdshader` adapts the shipped
ocean shader with the same overlay include; no separate ocean mesh is created.
Water province and territory borders are unlit surface markings: they are not
painted onto the seabed, do not produce their own reflections or shadows, and
leave the ocean shading visible beneath them. Water hover/selection highlights
only the border rather than filling the entire water province.
Province identities use nearest-sampled, non-color ID textures. Separate
bilinearly sampled distance fields smooth visible borders without changing IDs.
Each color is one logical province, including any disconnected pieces present
in the source image; the importer does not silently split or repair those shapes.

Hover highlights a province. Click it to select it and inspect its original ID,
territory, terrain type, area, ownership and shared-edge neighbours. Picking uses
world XZ coordinates and the actual sample spacing, and prefers the visible
water surface over submerged seabed. The **Show province borders** toggle hides
or shows borders; **Clear imported provinces** removes the imported layer while
retaining the generated terrain. All controls and the Provinces controller node
are authored into `scenes/map_editor.tscn`.

### Territory membership and adjacency

Land/ocean provinces crossing territory boundaries are rejected. OpenGS can,
however, make one province for an entire lake even when its territory raster
splits that water body. For these water provinces we choose the parent from
territory history if supplied, otherwise the province's source center, otherwise
the largest overlap. The in-game territory ID raster is normalized so the whole
province has one parent. Original PNGs are retained, and a notice reports this
normalization. Your current lake province exercises this case.

Province adjacency is derived from shared horizontal/vertical pixel edges;
corner contact alone does not create a neighbour. Shared-border lengths and
areas use actual world spacing. This graph includes land/water interfaces;
army/naval movement and passability rules are not implemented yet.

### Country ownership and saving

Select a province, enter a country ID, choose a color, and press
**Assign country / clear ownership**. New countries use the chosen color. Joining
an existing country keeps its color. To recolor that country, select a province
already owned by it and apply a new color without changing its country ID.
Leaving the ID blank clears ownership of the selected province. Ownership is
separate from province/territory identity and does not modify terrain or province
geometry. Territories are administrative groups, not automatically generated nations.

**Save heightmap + terrain…** now includes a `provinces/` package when a province
map is loaded. It stores original PNGs, definitions, canonical territory history,
exact ID rasters, source manifest and `province_state.json` containing records,
adjacency, areas and ownership. `map.json` points to that package. Re-import the
saved `provinces/` folder over its matching source terrain to restore it, including
country ownership. Full saved-world loading, country simulation, armies, economy,
province labels and OpenGS CSV/YAML/XML metadata import are not part of this pass.

### Province verification

```powershell
godot --headless --path . --script res://tests/province_import_test.gd
godot --path . --script res://tests/province_scene_test.gd
godot --path . --script res://tests/province_preview.gd
```

The first uses documented-schema synthetic fixtures for identities, hierarchy,
shared-border adjacency, world coordinates, malformed imports, lake normalization
and save/re-import. The second exercises the actual scene, terrain preservation,
selection, political shader bindings on land/ocean, far-camera picking, ownership,
saving, failed-import recovery and regeneration. The third auto-loads the actual
files in `data/opengs/` and writes territory/province screenshots under
`tests/output/`. Existing map-editor and OpenGS-export tests remain available.


## Tribe library

Press **F5 → Country workshop**, or run `scenes/country_creator.tscn` with **F6**.
The standalone creator now asks for **only a permanent ID and name**. Every nation
begins as a tribe. Laws, taxation, technology, national skills and other development
choices belong to the running game, not to these reusable tribe definitions.

Six fictional starter tribes are included under `data/countries/`:

| ID | Name |
| --- | --- |
| FJORD | Fjord Clans |
| RAVENFELL | Ravenfell |
| ASHEN_WOLF | Ashen Wolves |
| IRON_PINE | Ironpine |
| STORM_COAST | Stormcoast |
| ELKWOOD | Elkwood |

Each starter JSON file contains exactly `id` and `name`. Create, rename, search,
duplicate and save tribes in the tool. Saved IDs remain read-only so province
references survive name changes. Unsaved changes require confirmation before
switching records or leaving. Archive/restore remains a library-management feature;
archived records carry an optional `archived` flag, not gameplay state.

Development saves go to `data/countries/<ID>.json`; the previous version is kept
as `<ID>.json.bak`. Old full country records are read as identity only. Resaving
through the creator strips old pregame choices; their previous file is retained
in the backup. Exported-build custom saves use `user://countries`. Export packaging
and shipping the bundled tribes remain to be verified.

In the map editor, choose a saved tribe in the province country dropdown and
press **Assign country / clear ownership**. A stable display color is generated
from the ID; it is presentation, not an authored tribe attribute. Existing province
ownership and manually entered IDs remain supported.

The technology/national-skill planner remains as a separate development prototype
in `scenes/progression_planner.tscn` and its rules remain available for future
in-game progression. It is disconnected from tribe creation; no build plan, law,
technology, skill, faith, culture or AI preference is assigned by this tool.
There is not yet a playable simulation or an in-game research/law screen.

```powershell
godot --headless --path . --script res://tests/country_creator_test.gd
godot --path . --script res://tests/country_creator_preview.gd
godot --path . --script res://tests/province_scene_test.gd
godot --headless --path . --script res://tests/nation_progression_test.gd
```

Checks cover minimal records, duplicate IDs, backups, invalid files, legacy
identity loading, discard protection, archive/restore, starter tribes and province
assignment. Tests write only isolated fixtures under `tests/output/`.
