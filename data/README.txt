OpenGS import images

1. Import land.png in Land Image.
2. Import boundary.png in Boundary Image. This image is intentionally all white: no country/state boundaries exist in this editor yet. You may omit it, or draw your own exact-black boundaries on this image.
3. Import density.png in Density Image. Darker means more seeds / smaller provinces; consider Exclude Ocean if you want ocean density controlled separately.
4. Import terrain.png in Terrain Image.
5. Generate territories FIRST, then provinces.

All images have the source heightmap dimensions and the same orientation: image x = world +X, image y = world +Z. Never resize these images independently or save categorical land/terrain images as JPEG.

Land: ocean RGB (5,20,18), lakes (0,255,0), land (255,255,255). Lakes are below-sea-level water not 4-connected to a map edge. Classification is relative to this map extent.
Terrain uses the OpenGS palette; urban and fjords are not auto-assigned because this editor has no settlement or fjord classification data. Other terrain classes are elevation/slope/moisture heuristics, not painted gameplay biomes.
Density is terrain suitability, not a population map. Boundary constraints are not automatically inferred from mountains.

Source: https://github.com/Thomas-Holtvedt/opengs-maptool#how-to-use-the-tool
See opengs_export.json for exact generated settings, palette, counts and heightmap hash.
