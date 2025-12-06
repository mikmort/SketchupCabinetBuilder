# SketchUp Cabinet Builder

Professional cabinet builder plugin for SketchUp 2026+ with US standard dimensions, room presets, and TwinMotion material support.

## Features

- **Multiple Cabinet Types**: Base, wall, island, tall/pantry, corner (blind & lazy susan), and floating cabinets
- **US Standard Dimensions**: Pre-configured with standard widths (9" to 48") and depths
- **Room Presets**: Kitchen, bathroom, and closet configurations with appropriate dimensions
- **Frame Options**: Both framed and frameless cabinet construction
- **Flexible Configurations**: Mix doors and drawers (e.g., "2 drawers + door")
- **Auto-Layout**: Automatically fill cabinet runs with optimal standard widths
- **Appliance Gaps**: Define spaces for ranges, dishwashers, and other appliances
- **Countertops & Backsplashes**: Automatic generation with proper overhangs
- **Island Seating**: Optional 15" overhang for bar seating
- **Realistic Hardware**: Simplified but accurate hinges, pulls, and drawer slides
- **TwinMotion Ready**: Materials named by room for easy texture application

## Installation

### Option 1: Direct Installation (Recommended)

The plugin is already installed in your SketchUp Plugins folder:
```
C:\Users\[Username]\AppData\Roaming\SketchUp\SketchUp 2026\SketchUp\Plugins\
```

1. Restart SketchUp 2026
2. The plugin will load automatically
3. Access via **Plugins > Cabinet Builder** menu

### Option 2: Manual Installation

If moving to a different SketchUp installation:

1. Copy the entire `SketchupCabinetBuilder` folder to your Plugins directory
2. Copy `sketchup_cabinet_builder.rb` to the same Plugins directory
3. Restart SketchUp

## Usage

### Using the Dialog Interface

1. Go to **Plugins > Cabinet Builder > Build Cabinet...**
2. Configure your cabinet:
   - **Room Name**: Enter a name (e.g., "Kitchen", "Master Bath") for material naming
   - **Room Preset**: Select Kitchen, Bathroom, or Closet for default dimensions
   - **Build Mode**: Choose "Single Cabinet" or "Cabinet Run"
   - **Cabinet Type**: Select from 7 cabinet types
   - **Dimensions**: Use standard widths or enter custom sizes
   - **Configuration**: Choose door/drawer combinations
   - **Options**: Add countertops, backsplashes, seating overhangs

3. Click **Create Cabinet**

### Quick Create Options

For rapid prototyping, use the quick create menu:

- **Plugins > Cabinet Builder > Quick Create**
  - Base Cabinet (24")
  - Base Cabinet (36")
  - Wall Cabinet (30")
  - Island (48" with seating)
  - 10 ft Base Run

### Cabinet Runs

Cabinet runs automatically:
- Fill the specified length with optimal standard widths
- Calculate and display required filler strips
- Create continuous countertops across all cabinets
- Leave gaps for appliances at specified positions

Example: 10-foot kitchen run with 30" range gap
- Total length: 120"
- Appliance gap at 60" position, 30" wide (for range)
- Plugin auto-fills remaining space with standard cabinet widths

## Standard Dimensions (US)

### Base Cabinets
- **Depth**: 24"
- **Height**: 34.5" (before countertop)
- **Toe Kick**: 4" high, 3" deep
- **Panel Thickness**: 3/4"

### Wall Cabinets
- **Depth**: 12"
- **Heights**: 30" (short), 36" (standard), 42" (tall)
- **Mounting Height**: 54" from floor (18" above counter)

### Islands
- **Depth**: 36" (allows for seating overhang)
- **Height**: 34.5"
- **Seating Overhang**: 15" (when enabled)

### Countertops
- **Depth**: 25.5" (1.5" overhang beyond base)
- **Thickness**: 1.5"
- **Backsplash**: 4" high
- **Side Overhang**: 0.75"

### Door & Drawer Spacing
- **Reveal**: 1/8" between all doors and drawers
- **Overlay**: 3/8" for framed cabinets
- **Thickness**: 3/4"

### Standard Widths Available
9", 12", 15", 18", 24", 30", 36", 42", 48"

## Material Naming for TwinMotion

Materials are automatically named with the room name for easy identification in TwinMotion:

- `Box_[RoomName]` - Cabinet box/carcass (brown wood)
- `DoorFace_[RoomName]` - Door fronts (lighter wood)
- `DrawerFace_[RoomName]` - Drawer fronts (lighter wood)
- `Interior_[RoomName]` - Interior surfaces (light color)
- `Countertop_[RoomName]` - Countertop surface (off-white/marble)
- `Hardware_[RoomName]` - Hinges, pulls, slides (metallic gray)
- `EdgeBand_[RoomName]` - Edge banding (matches box)

### TwinMotion Workflow

1. Create cabinets in SketchUp with appropriate room names
2. Export to TwinMotion
3. In TwinMotion, select objects by material name
4. Apply your desired textures/materials to each category
5. All cabinets in the same room will update together

Example:
- "Kitchen" cabinets use `Box_Kitchen`, `DoorFace_Kitchen`, etc.
- "Master_Bath" uses `Box_Master_Bath`, `DoorFace_Master_Bath`, etc.

## Cabinet Types Explained

### Base Cabinet
Standard lower cabinets with toe kick. Default 24" deep × 34.5" high. Includes countertop support.

### Wall Cabinet
Upper cabinets mounted 54" from floor (18" above standard 36" counter height). Default 12" deep.

### Island
Deeper cabinets (36") with optional seating overhang. Can be accessed from multiple sides.

### Tall/Pantry
Floor-to-ceiling storage. Default 84" high (7 feet). Use for pantries, broom closets, etc.

### Corner Base
Corner cabinet with blind corner or lazy susan options. 42" × 42" L-shaped configuration.

### Corner Wall
Upper corner cabinet with blind or lazy susan. Matches corner base configuration.

### Floating
Wall-mounted cabinets at custom heights. No floor support or toe kick.

## Door/Drawer Configurations

### Pre-defined Configurations
- **Doors Only**: Two doors (default)
- **Drawers Only**: Three graduated drawers
- **2 Drawers + Door**: Two small drawers on top, one door below
- **3 Drawers + Door**: Three small drawers on top, one door below

### Custom Configurations
Use natural language in the dialog:
- "2 drawers + door"
- "drawer + 2 doors"
- "3 drawers + door"

Drawers are automatically graduated (smaller on top, larger on bottom) when multiple drawers are used.

## Tips & Best Practices

### For Kitchens
1. Use **Kitchen** preset for proper depths (24" base, 12" wall)
2. Plan appliance gaps before creating runs (30" for ranges, 24" for dishwashers)
3. Create base run first, then wall cabinets above
4. Use islands with seating overhang for breakfast bars

### For Bathrooms
1. Use **Bathroom** preset for shallower cabinets (21" depth)
2. Wall cabinets are shorter (30") by default
3. Consider floating vanities for modern look

### For Closets
1. Use **Closet** preset for appropriate shelving depth (14")
2. Tall cabinets work well for full-height storage
3. Mix cabinet types at different heights for varied storage

### Material Application
1. Name rooms descriptively ("Kitchen", "Master_Bath") not generically
2. Create all cabinets for one room before moving to another
3. In TwinMotion, apply materials by searching for the room name
4. Use realistic wood grains for boxes, smooth finish for painted doors

### Performance
- For large projects, create runs instead of individual cabinets
- Group related cabinets (like an entire kitchen) in SketchUp layers
- Use components for repeated cabinet configurations

## Scripting API

Advanced users can script cabinet creation via Ruby Console:

### Create Single Cabinets
```ruby
# Base cabinet
MikMort::CabinetBuilder.create_base_cabinet(36, {
  room_name: "Kitchen",
  frame_type: :frameless,
  config: :drawer_bank_3,
  countertop: true,
  backsplash: true
})

# Island with seating
MikMort::CabinetBuilder.create_island(48, {
  room_name: "Kitchen",
  seating: true
})
```

### Create Cabinet Runs
```ruby
# 10-foot run with range gap
MikMort::CabinetBuilder.create_cabinet_run(120, {
  room_name: "Kitchen",
  cabinet_type: :base,
  appliance_gaps: [
    {position: 48, width: 30, label: "Range"}
  ]
})
```

## Troubleshooting

### Plugin doesn't appear in menu
- Verify files are in correct location
- Check Ruby Console (Window > Ruby Console) for error messages
- Restart SketchUp completely

### Cabinets don't generate
- Check that all dimensions are positive numbers
- Ensure custom widths are reasonable (9" - 60")
- Verify room name contains only letters, numbers, underscores

### Materials don't show in TwinMotion
- Ensure room name was entered before creating cabinets
- Check SketchUp's Materials panel to verify materials exist
- Re-apply materials in SketchUp if needed before exporting

### Cabinet runs have unexpected gaps
- Check appliance gap positions don't overlap
- Verify total run length accommodates gaps
- Review filler strip summary after creation

## Technical Details

### File Structure
```
Plugins/
├── sketchup_cabinet_builder.rb          # Main loader
└── SketchupCabinetBuilder/
    ├── main.rb                          # Entry point
    ├── constants.rb                     # Dimensions & standards
    ├── models/
    │   ├── cabinet.rb                   # Cabinet model
    │   └── cabinet_run.rb               # Run layout logic
    ├── materials/
    │   └── material_manager.rb          # Material creation
    ├── geometry/
    │   ├── box_builder.rb               # Cabinet boxes
    │   ├── door_drawer_builder.rb       # Doors & drawers
    │   ├── countertop_builder.rb        # Countertops
    │   └── cabinet_generator.rb         # Orchestrator
    ├── ui/
    │   └── dialog.rb                    # Dialog manager
    └── resources/
        └── dialog.html                  # UI interface
```

### Requirements
- SketchUp 2017 or later (uses HtmlDialog API)
- Tested on SketchUp 2026

### Performance Notes
- Single cabinet: <1 second
- Cabinet run (10 cabinets): 2-5 seconds
- Materials are reused across cabinets in same room

## Future Enhancements

Potential additions for future versions:
- Crown molding and decorative trim
- Glass door panels
- Open shelving sections
- Cabinet lighting
- More hardware styles
- Imperial/Metric unit toggle
- Custom material presets
- Import/export cabinet configurations

## Support & Feedback

For issues, feature requests, or questions:
- GitHub: https://github.com/mikmort/SketchupCabinetBuilder
- Check Ruby Console for detailed error messages
- Include SketchUp version and cabinet configuration when reporting issues

## Development Notes

### SketchUp API Limitations & Workarounds

**Problem: Nested Group Invalidation**

SketchUp has a critical limitation with deeply nested groups during entity creation:
- When iterating over model entities and creating geometry in nested groups (A → B → C), parent group B becomes invalid
- This causes "reference to deleted Group" errors
- The invalidation happens during the operation, even within the same transaction

**Failed Approaches:**
1. ❌ Building directly into nested groups (Run → Appliances → entities) - parent invalidates
2. ❌ Building at model level, converting to component with `to_component` - invalidates parent groups
3. ❌ Building at model level, exploding and regrouping - entities get lost or positioned incorrectly
4. ❌ Using `transform_entities` to move geometry between collections - doesn't preserve entities
5. ❌ Keeping Ruby object references to groups across operations - references become stale

**Working Solution:**

For special elements like range placeholders that need to be in subgroups:

1. **Build directly into the target group's entities collection**
   ```ruby
   @box_builder.build(cabinet, @current_run.appliances_group.entities, position)
   ```
   - Avoids all nested group creation during iteration
   - Entities are created at correct position relative to parent group
   - No transformation complexity

2. **Reload group references between operations**
   ```ruby
   def next_position
     load_subgroups  # Finds groups by attributes, not by stale Ruby references
     # ... calculate bounds
   end
   ```
   - Each cabinet creation is a separate operation/transaction
   - Group object references become invalid between operations
   - Must re-find groups in the model by their attributes, not by stored Ruby variables

**Key Lessons:**
- Don't nest group creation beyond 2 levels during entity iteration
- Don't store SketchUp group references across operation boundaries
- Build geometry directly into final destination, not at model level then move
- Use attributes to relocate groups, not Ruby object references
- `to_component` and `explode` cause unexpected group invalidations

### Cabinet Run Structure

Each cabinet run uses this group hierarchy:
```
Kitchen - Run Name (main group)
├── Carcass (subgroup) - cabinet boxes
├── Faces (subgroup) - doors and drawer fronts  
├── Countertops (subgroup) - countertop surfaces
├── Backsplash (subgroup) - backsplash panels
├── Hardware (subgroup) - hinges, pulls, slides
└── Appliances (subgroup) - ranges, dishwashers, etc.
```

Subgroups are identified by `CabinetBuilder.subgroup_type` attribute, not by name or position.

## License

Copyright (c) 2025 MikMort

---

**Version**: 1.0.0  
**Last Updated**: November 22, 2025  
**Compatible With**: SketchUp 2017+
