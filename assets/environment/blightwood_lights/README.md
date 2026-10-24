# Blightwood Forest lights

Five transparent PixelLab fixtures matching the owner concept: wooden lantern post, stone pagoda lantern, flowering branch lantern, stone brazier and root-wrapped spirit totem. Palette combines the concept's forest/blue swatches with live grass colors. Source job IDs and raw PNGs live in source/ and are excluded from Godot import.

blightwood-lights.art.json records native sizes, individual ground anchors, source light anchors, collision footprints, glass masks, pendant pivots and sprite atlas metadata. Hanging lanterns are losslessly extracted from the original prop and sway independently; roots and structural wood stay fixed. Animated pendants are runtime transforms, not additional painted body frames.

Separate12-frame spirit flame at12FPS and8-frame firefly wingbeat at18FPS. Each fixture uses12bounded insects with independent flight and glow pulses. The Forest Fireflies card creates a separate32-insect emitter with no collider or navigation footprint. All six cards are under the Blightwood lights builder filter and can be moved/deleted/saved. No existing map layout is repainted.

BlightwoodLight adds independent floor illumination, light on the fixture, emissive glass and source halos. Two spirit-flame props reuse the original quiet fire ambience from the Ashen pack; other fixtures are silent. ForestFireflies can be reused without a fixture. Review controls expose fireflies, lighting, pendulum sway and sound separately; normal/half-speed GIFs contain actual Godot Web captures.
