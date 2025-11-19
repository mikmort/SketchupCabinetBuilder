# Quick Start Guide - SketchUp Cabinet Builder

## First Time Setup

1. **Restart SketchUp** - The plugin should load automatically
2. Look for **Plugins > Cabinet Builder** in the menu
3. If you don't see it, check the Ruby Console (Window > Ruby Console) for errors

## Your First Cabinet

### Method 1: Quick Create (Fastest)
1. Go to **Plugins > Cabinet Builder > Quick Create > Base Cabinet (24")**
2. A 24" base cabinet will appear at the origin with countertop

### Method 2: Using the Dialog (Full Control)
1. Go to **Plugins > Cabinet Builder > Build Cabinet...**
2. Leave default settings (Kitchen, 24" base cabinet)
3. Click **Create Cabinet**

## Common Tasks

### Create a Kitchen Base Run (10 feet)
1. **Plugins > Cabinet Builder > Build Cabinet...**
2. Select **Cabinet Run** mode
3. Enter **120** for length (10 feet = 120 inches)
4. Add appliance gap if needed:
   - Click **+ Add Appliance Gap**
   - Position: 48 (4 feet from start)
   - Width: 30 (standard range)
   - Label: Range
5. Click **Create Cabinet**

Result: Automatic layout of cabinets with optimal widths, plus filler strip info

### Create an Island with Seating
1. **Plugins > Cabinet Builder > Build Cabinet...**
2. **Cabinet Type**: Island
3. **Width**: 48" (or your preference)
4. Check **Include Seating Overhang**
5. Click **Create Cabinet**

### Create Wall Cabinets Above Base
1. Create base cabinets first
2. **Plugins > Cabinet Builder > Build Cabinet...**
3. **Cabinet Type**: Wall Cabinet
4. Match the width to your base cabinet
5. **Uncheck** Countertop and Backsplash
6. After creation, move cabinet up to proper height (54" from floor)
   - Use SketchUp's Move tool
   - Type `[0, 0, 54"]` to move precisely

## Understanding Materials

Your cabinets will have materials named like:
- `Box_Kitchen`
- `DoorFace_Kitchen`
- `Countertop_Kitchen`
- `Hardware_Kitchen`

### To View Materials
1. Window > Materials
2. Look for materials with your room name

### For TwinMotion Export
1. Create all cabinets with same room name (e.g., "Kitchen")
2. Export to TwinMotion
3. In TwinMotion, select by material name
4. Apply realistic textures to each material type
5. All cabinets update together!

## Tips for Success

### Start Simple
- Create one cabinet first
- Verify dimensions and appearance
- Then create more complex runs

### Room Naming Strategy
- Use descriptive names: "Kitchen", "Master_Bath", "GuestBed_Closet"
- Consistent naming helps in TwinMotion
- Avoid special characters (stick to letters, numbers, underscores)

### Cabinet Runs
- Measure your space first
- Plan appliance locations before creating run
- Note filler strip sizes shown after creation
- Fillers are standard in real construction

### Mixed Configurations
For "2 drawers + door" cabinets:
1. Select **Door/Drawer Configuration: Custom**
2. Type: `2 drawers + door`
3. Top section = drawers, bottom = door

## Example Projects

### Simple Kitchen (U-Shape)
1. **Left wall run**: 96" base run
2. **Back wall run**: 120" base run with 30" range gap at center
3. **Right wall run**: 60" base run
4. **Island**: 48" island with seating on one side
5. Create matching wall cabinets for each section

### Bathroom Vanity
1. Change room preset to **Bathroom**
2. Create 36" or 48" base cabinet
3. Countertop included automatically
4. Add mirror and wall sconces separately in SketchUp

### Pantry
1. **Cabinet Type**: Tall/Pantry
2. **Width**: 24" or 30"
3. **Height**: 84" (default) or 96" for ceiling height
4. Mix of shelves and drawers automatically created

## Troubleshooting

**Q: Cabinet appears but looks wrong**
- Check cabinet type matches intention (base vs wall)
- Verify dimensions are in inches
- Try different door/drawer configuration

**Q: Can't see my cabinet**
- It may be at the origin [0,0,0]
- Use Zoom Extents (Shift + Z)
- Check Outliner panel to find cabinet group

**Q: Materials are gray in SketchUp**
- This is normal - they're placeholder colors
- Check Materials panel to verify they exist
- Apply textures in TwinMotion for realistic rendering

**Q: Cabinet run doesn't fit**
- Check appliance gaps don't exceed total length
- Verify measurements in inches
- Review filler strip report - small gaps are normal

## Next Steps

Once comfortable with basics:
1. Explore corner cabinets (blind corner, lazy susan)
2. Try custom door/drawer configurations
3. Create complete room layouts
4. Export to TwinMotion for realistic rendering
5. Add hardware from 3D Warehouse (handles, pulls)

## Need Help?

- Check the full README.md for detailed documentation
- Ruby Console shows detailed error messages
- Verify all dimensions before creating
- Start with Quick Create options to test functionality

---

Happy Cabinet Building! 🔨
