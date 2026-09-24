# Summit Valley — Godot rebuild

Summit Valley is being rebuilt as a proper 3D ski-resort tycoon in Godot 4.

The target is the level of interaction and system depth of modern ski-resort tycoon games such as Ski-E-O!: freeform piste construction, connected lifts, simulated skiers, resort facilities, economy, reputation, snow/weather, grooming, snowmaking, patrol, research and sandbox play.

The game uses original code, procedural geometry and eventually original/appropriately licensed Blender assets. It does not copy proprietary Ski-E-O! assets, code or UI.

## Current Godot foundation

- Large procedural alpine mountain
- Snow surface and forest
- Hotels/restaurants/rental buildings
- Chairlift and gondola construction
- Freehand piste painting
- Individual 3D skier entities following pistes
- Ticket/economy loop
- Reputation
- Snow depth and day/night cycle
- Godot scene structure ready for Blender GLB assets

## Production architecture

Blender:
- mountain art
- cliffs, bowls and snow shelves
- alpine buildings
- lifts and stations
- groomers and snow cannons
- rigged skiers/snowboarders
- vegetation and props

Godot:
- runtime terrain/piste carving
- lift routing and queues
- guest AI
- snow/weather simulation
- grooming and snowmaking
- patrol and safety
- economy/research/scenarios
- save/load
- touch controls
- iOS build

## Next production milestones

1. Replace temporary geometry with detailed Blender-authored mountain and assets.
2. Make pistes deform/sculpt the terrain rather than simply drawing a ribbon.
3. Build proper lift stations, cable sag, chairs/cabins and boarding queues.
4. Replace procedural skiers with rigged animated skiers/snowboarders.
5. Give guests needs, destinations, lift queues, skill levels and route choice.
6. Add grooming, snowmaking, snowfall accumulation and weather impacts.
7. Expand buildings, shops, hotels, restaurants and après-ski facilities.
8. Add staff, ski patrol, incidents, research and upgrades.
9. Add scenarios and a full sandbox.
10. Optimise and export to iOS.

Open GodotProject/project.godot with Godot 4.x to run the current build.
