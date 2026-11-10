# Contextual room sources and licensing

Native room geometry and composition are adapted from the approved local studies:
`oval-3d-lab/bureau/scene/main.gd`, `vestiaire/main.gd` (enclosed human-height
perspective variant), and `terrain/main.gd`. Production adaptations remove their
command-line configuration, demonstration UI, capture automation and exit logic.
The training ground is a contextual preparation setting; the production live
match continues to use the existing `match_view.gd`.

Only the required eight furniture GLBs are redistributed in `assets/furniture/`:
bench, books, cardboardBoxClosed, chairDesk, coatRackStanding,
kitchenCoffeeMachine, plantSmall1 and trashcan. Original author: **Kenney**.
Pack: <https://kenney.nl/assets/furniture-kit>. License: **CC0 1.0 Universal**,
<https://creativecommons.org/publicdomain/zero/1.0/>. The source notice is
preserved in `assets/furniture/LICENSE.txt`; original meshes/materials remain
in the GLBs. Runtime material overrides provide the active club presentation.

The generic rigged person in `assets/athlete/athlete.glb` is the existing
**Quaternius Animated Men Pack** model, distributed under **CC0 1.0 Universal**.
Original author page: <https://quaternius.com/packs/animatedmen.html>.
Its preserved provenance notice is `assets/athlete/QUATERNIUS-CC0.md`, including
the existing conversion mirror and source blob. It is a generic stylized model,
not a likeness of a real player or a model of a measured rugby action.

Fonts reuse the production DM Sans and Barlow Condensed resources under
`res://fonts/`, with their existing OFL notices. No font copies are added here.

Club color/name and crest come from the current production presentation and
`game_skin.gd` resolver at every opening. Missing crest means blank surfaces;
missing color means neutral gray. Light/dark contrast trim is a derived neutral
presentation accent, not a claim about an authentic secondary club color.

Authoring: these scenes are generated with Godot native geometry and imported
GLB props. Authoring and source-study information is documentation only and is
not displayed in the runtime rooms.
