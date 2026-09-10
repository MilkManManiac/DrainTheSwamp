# Downloaded asset packs - licenses and coverage

All licenses below were read off the source page (and the bundled license.txt where one exists) on 2026-09-10.
Every pack here allows commercial use. Two need attribution (marked CC-BY / OGA-BY); the rest are CC0.
Original zips are kept in `_zips/`.

| Folder | Pack | Source | Author | License | Attribution required? |
|---|---|---|---|---|---|
| `ansimuz-gothicvania-swamp/` | Gotthicvania Swamp | https://opengameart.org/content/gotthicvania-swamp | Luis Zuno (ansimuz) | CC0 (page + bundled `public-license.txt`: "Public domain and free to use on whatever you want, personal or commercial. Credit is not required but appreciated.") | No |
| `ansimuz-gothicvania-town/` | Gothicvania Town | https://opengameart.org/content/gothicvania-town | Luis Zuno (ansimuz) | CC0 (page + bundled `public-license.txt`, same wording). NOTE: the bundled music (Pascal Belisle) is credit-required - do not use it. | No (art) |
| `ansimuz-gothicvania-cemetery/` | GothicVania Cemetery Pack | https://opengameart.org/content/gothicvania-cemetery-pack | Luis Zuno (ansimuz) | CC0 (page + bundled `public-license.txt`). Same music caveat. | No (art) |
| `ansimuz-parallax-forest/` | Forest Background | https://opengameart.org/content/forest-background | Luis Zuno (ansimuz) | CC0 (bundled `license.txt` links creativecommons.org/publicdomain/zero/1.0/) | No |
| `ansimuz-mountain-dusk/` | Mountain at Dusk Background | https://opengameart.org/content/mountain-at-dusk-background | Luis Zuno (ansimuz) | CC0 (page) | No |
| `ansimuz-country-side/` | Country Side Platform Tiles | https://opengameart.org/content/country-side-platform-tiles | Luis Zuno (ansimuz) | CC0 (page + bundled `license.txt`) | No |
| `craftpix-swamp-tileset/` | Swamp 2D Tileset Pixel Art | https://opengameart.org/content/swamp-2d-tileset-pixel-art | CraftPix.net | OGA-BY 3.0 (page). Commercial OK, credit "CraftPix.net" required. (Craftpix's own itch page says credit not required, but the OGA upload is OGA-BY - credit them to be safe.) | Yes: "Assets by CraftPix.net" |
| `admurin-parallax-backgrounds/` | Parallax Backgrounds (Plains / Caves / Snowy Mountains / Dead Forest / Dock) | https://opengameart.org/content/parallax-backgrounds | Admurin | CC-BY 4.0 (page links creativecommons.org/licenses/by/4.0/) | Yes: "Admurin - https://admurin.itch.io/" |
| `matepore-lamp-post/` | Lamp post | https://opengameart.org/content/lamp-post | matepore | CC0 (page: "no need for credits, but they are appreciated") | No |
| `parriah-lantern-pole/` | 2D Platformer Side Scroller Stone Fence Street Lamp | https://opengameart.org/content/2d-platformer-side-scroller-stone-fence-street-lamp | Parriah (Cagil Ozdemirag) | CC0 (page) | No |
| `knoblepersona-wooden-planks/` | Wooden Planks [Connecting Tileset] [16x16] | https://opengameart.org/content/wooden-planks-connecting-tileset-16x16 | KnoblePersona | CC-BY 3.0 (page) | Yes: "KnoblePersona" |
| `kenney-platformer-buildings/` | Platformer Art: Buildings | https://opengameart.org/content/platformer-art-buildings | Kenney | CC0 (page + bundled `license.txt`) | No |

## What each pack gives us (bayou small-town kitbash)

### Swamp / foliage
- **ansimuz-gothicvania-swamp** - the best style match (dense 16-bit, moody). `Evironment/trees.png` (288x208) = gnarled swamp trees with hanging vines; `mid-layer-01/02.png` (208x256) = loopable mid-ground swamp canopy; `background.png` (96x256) = far layer; `tileset.png` (336x112) = 16px mossy ground + water edge; `props.png` = small props (fire, roots). Also a hunter player + 3 enemies + fire sprites if wanted.
- **craftpix-swamp-tileset** - brighter/greener 32px swamp. `2 Background/Layers/1-5.png` (576x324 each) = 5-layer parallax sky/trees/water; `3 Objects/Willows/1-3.png` (up to 199x183) = weeping willows (closest thing to moss-draped cypress); `Trees/`, `Bushes/`, `Grass/` (reeds/cattail-ish), `Boxes/` (6 crates), `Fence/`, `Ladders/`, `Ridges/`, `Stones/`; `4 Animated objects/` = chest/coin/flag/key/rune. `1 Tiles/Tileset.png` (320x192) = mossy ground + animated water tiles.
- **ansimuz-parallax-forest** - 3 loopable dark forest layers (272x160) + a "lights" layer; good far-background filler behind swamp.
- **admurin-parallax-backgrounds/Parallax_Backgrounds_DeadForest** - 6 layers (384x216) of dead/misty forest; **Plains** 8 layers with sky+clouds.

### Water / dock
- **admurin-parallax-backgrounds/Parallax_Backgrounds_Dock/Dock/0-8.png** - sky, clouds, pine treeline, lake water, shore rocks and reeds (see `_composite_Dock.png` for the flattened look). This is a lake, not a bayou, but the water + reed layers recolor well.
- **knoblepersona-wooden-planks** - 16px connecting plank tileset = boardwalk / pier decking.
- craftpix water tiles (animated) in `1 Tiles/`.

### Buildings
- **ansimuz-gothicvania-town** - `PNG/environment/props-sliced/house-a/b/c.png` (168x183, 210x244, 221x183): three timber-frame/stone houses. Style is European-gothic, not bayou, but timber framing and board walls recolor toward shacks; `layers/background.png` + `middleground.png` (384x288) = rooftop skyline parallax; `layers/tileset.png` = cobbles/stairs. See `environment-preview.png` (1536x288) for the assembled scene.
- **kenney-platformer-buildings** - CC0 fallback only: 98 clean vector-ish tiles (awnings, doors, windows, signs, wood/brick walls) as separate PNGs in `Tiles/`. Style does not match; useful for layout blocking or as a base to repaint.

### Props
- **ansimuz-gothicvania-town/props-sliced/** - `barrel.png`, `crate.png`, `crate-stack.png`, `sign.png`, `street-lamp.png` (3-headed iron), `wagon.png`, `well.png`.
- **ansimuz-gothicvania-cemetery** - `demo/assets/environment/objects.png` (624x192) = 10 decorative objects (dead trees, fences, gravestones, gate); `bg-graveyard.png`, `bg-mountains.png`, `bg-moon.png` (384x224) parallax; 16px tileset.
- **matepore-lamp-post** - single 80x80 lamp post sprite (+ PSD).
- **parriah-lantern-pole** - lantern pole at 16x64 and 32x128, plus 5 stone-fence sprites (160x32 sheet).
- craftpix `Boxes/` (6 crates) and `Fence/`.

### Sky / far distance
- **ansimuz-mountain-dusk** - 5 loopable layers (272x160 / 544x160): dusk sky, far mountains, mountains, trees, foreground trees. Warm pink-orange dusk palette.
- **ansimuz-country-side** - 384x224 back layer (blue sky, clouds, blue-green mountains), loopable pine forest layer, one big round oak, and a grass/road tileset. Daytime rural feel.

## Gaps (not found under a CC0/CC-BY license from a source we could download without a browser session)
- **Water tower** - nothing pixel-art, side-view, CC0/CC-BY on OGA. Must be painted (Kenney tiles or the Gothicvania well as a base).
- **Rural wooden storefront / general store / saloon-style facades** - closest CC-licensed candidates were on itch.io (`cursed-offerings.itch.io/yeehaw` - custom "use commercially" wording, 8-bit NES style; `waltonsimons.itch.io/16x16-wild-west-tileset` - CC-BY 4.0 but $2 minimum; `chuckiecatt.itch.io/country-town-buildings` - CC-BY 4.0 but top-down). itch.io free downloads need a browser session (the `/file/<id>` step rejects the key without a logged-in cookie), so none were fetched.
- **Spanish-moss cypress specifically** - `cokegamingstudios.itch.io/swamptree-forgottenswamppalette` has one, but states no license on the page. Skipped. Craftpix willows + Gothicvania swamp vines are the substitutes.
- **Animated lanterns** - `karsiori.itch.io/free-pixel-art-lantern-pack` is CC0 (stated on page) and would be ideal, but itch download blocked as above. Worth grabbing manually in a browser.
- **Boardwalk/dock as sprites** (posts, pilings, mooring, boats) - only the plank tileset; pilings need to be drawn.

## Checked and rejected (license)
- GandalfHardcore Sidescroller 32x32 (itch) - custom license, not CC.
- brullov Oak Woods (itch) - "commercial ok, no redistribution", not CC, $2.
- Aurusenth 8x8 swamp (itch) - custom credit-required wording, not CC, and 8px.
- AnaMayArt Side Scrolling Platformer tileset (OGA) - CC-BY-SA (share-alike), skipped.
- Mangrove (OGA, z-uo) - CC-BY 3.0 but only an .xcf; skipped for now.
