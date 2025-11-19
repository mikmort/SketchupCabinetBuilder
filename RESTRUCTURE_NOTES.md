# Cabinet Structure Reorganization

The plugin now creates an intelligent hierarchical group structure:

## Main Structure
```
Component: CABINET_Base_610x610_Frameless
  ├─ Group: Carcass
  │   ├─ Group: Bottom
  │   ├─ Group: Left Side
  │   ├─ Group: Right Side
  │   ├─ Group: Back
  │   ├─ Group: Top (wall cabinets only)
  │   └─ Group: Toe Kick (base cabinets only)
  ├─ Group: Fronts
  │   ├─ Group: Door Left
  │   ├─ Group: Door Right
  │   └─ Group: Drawer Front 1
  ├─ Group: Hardware
  │   ├─ Group: Handle 1
  │   ├─ Group: Handle 2
  │   └─ Group: Pull 1
  ├─ Group: Countertop (if present)
  └─ Group: Backsplash (if present)
```

## Benefits
- TwinMotion friendly: Each component can have its own material
- Easy selection and editing
- Standard naming convention for automation
- Width/depth in millimeters for international compatibility
- Organized by function (structure vs. faces vs. hardware)

## Implementation Status
- ✅ Main cabinet group with descriptive name (CABINET_Type_WxD_Frame)
- ✅ Carcass group created
- ✅ Fronts group created  
- ✅ Hardware group created
- ⏳ Individual panel groups (needs box_builder update)
- ⏳ Individual door/drawer groups (needs door_drawer_builder update)
- ✅ Backsplash as separate group
