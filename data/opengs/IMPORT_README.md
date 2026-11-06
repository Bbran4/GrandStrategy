# OpenGS game import

Keep your raw `province.png`, `territory.png`, `province_definitions.json` and
`territory_definitions.json` here. Optional `territory_history.json` preserves
explicit parent groups. `opengs_export.json` is the matching source-heightmap
manifest from our export pack; retain it for alignment checks.

Run the map editor with the matching terrain settings. This folder loads
automatically after generation. The runtime Import OpenGS provinces button can
load other folders. See the project README for selection, map modes, ownership,
saving and the special handling of whole-lake provinces.

Your PNG and definition files are inputs: the importer reads them and does not
rewrite them. Game packages and ownership changes are saved separately via
Save heightmap + terrain.
