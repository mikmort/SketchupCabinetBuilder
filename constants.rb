# SketchUp Cabinet Builder - Constants
# Standard US cabinet dimensions and configurations

module MikMort
  module CabinetBuilder
    
    # All dimensions in inches (SketchUp will convert to model units)
    module Constants
      
      # Standard widths available for all cabinet types
      STANDARD_WIDTHS = [9, 12, 15, 18, 24, 30, 36, 42, 48].freeze
      
      # Base Cabinet Standards (Lower Cabinets)
      BASE_CABINET = {
        depth: 24.0,          # Standard base depth
        height: 34.5,         # Height to top of cabinet (before countertop)
        toe_kick_height: 4.0, # Toe kick height
        toe_kick_depth: 3.0,  # Toe kick setback
        panel_thickness: 0.75 # 3/4" plywood standard
      }.freeze
      
      # Wall Cabinet Standards (Upper Cabinets)
      WALL_CABINET = {
        depth: 12.0,          # Standard wall cabinet depth
        height_short: 30.0,   # Short wall cabinet
        height_standard: 36.0, # Standard wall cabinet
        height_tall: 42.0,    # Tall wall cabinet
        panel_thickness: 0.75,
        mounting_height: 54.0 # Bottom of cabinet from floor (18" above 36" counter)
      }.freeze
      
      # Wall Stack Configuration (10-foot stack)
      WALL_STACK = {
        depth: 12.0,          # Same as wall cabinet
        lower_height: 42.0,   # Main upper cabinet (42")
        upper_stack_count: 2, # Two stacked cabinets
        upper_stack_height: 12.0, # Each stack is 12"
        total_height: 66.0,   # 42" + (2 × 12") = 66" total
        panel_thickness: 0.75,
        mounting_height: 54.0, # Same as standard wall
        stack_reveal: 0.125   # Small reveal between sections
      }.freeze
      
      # Wall Stack 9-foot Configuration (9-foot ceiling)
      WALL_STACK_9FT = {
        depth: 12.0,          # Same as wall cabinet
        lower_height: 42.0,   # Main upper cabinet (42")
        upper_stack_count: 1, # One stacked cabinet
        upper_stack_height: 12.0, # Stack is 12"
        total_height: 54.0,   # 42" + 12" = 54" total
        panel_thickness: 0.75,
        mounting_height: 54.0, # Same as standard wall
        stack_reveal: 0.125   # Small reveal between sections
      }.freeze
      
      # Island Cabinet Standards
      ISLAND_CABINET = {
        depth: 36.0,          # Deeper for overhang
        height: 34.5,         # Same as base
        toe_kick_height: 4.0,
        toe_kick_depth: 3.0,
        panel_thickness: 0.75,
        seating_overhang: 15.0, # Overhang for seating side
        min_knee_space: 9.0   # Minimum knee clearance depth
      }.freeze
      
      # Tall/Pantry Cabinet Standards
      TALL_CABINET = {
        depth: 24.0,
        height: 84.0,         # 7 feet tall
        height_pantry: 96.0,  # 8 feet tall pantry
        panel_thickness: 0.75
      }.freeze
      
      # SubZero Panel-Ready Refrigerator Standards
      # Standard built-in dimensions (cabinet opening required)
      SUBZERO_FRIDGE = {
        # 30" Built-In models (BI-30U, BI-30UG)
        width_30: 30.0,
        depth_30: 24.0,
        height_30: 84.0,
        
        # 36" Built-In models (BI-36U, BI-36UG, BI-36UFD)
        width_36: 36.0,
        depth_36: 24.0,
        height_36: 84.0,
        
        # 42" Built-In models (BI-42U, BI-42UG, BI-42SD)
        width_42: 42.0,
        depth_42: 24.0,
        height_42: 84.0,
        
        # 48" Built-In models (BI-48SD, BI-48SID)
        width_48: 48.0,
        depth_48: 24.0,
        height_48: 84.0,
        
        panel_thickness: 0.75,
        toe_kick_height: 0.0,  # No toe kick for built-in fridges
        clearance_top: 1.0,    # Top clearance for ventilation
        clearance_back: 2.0    # Back clearance for compressor/coils
      }.freeze
      
      # Miele Panel-Ready Dishwasher Standards
      # Standard 24" fully integrated dishwasher
      MIELE_DISHWASHER = {
        width: 24.0,          # Standard dishwasher width
        depth: 24.0,          # Standard depth (matches base cabinets)
        height: 34.5,         # Standard height (matches base cabinets)
        panel_thickness: 0.75,
        toe_kick_height: 4.0, # Matches base cabinet toe kick
        clearance_back: 1.0   # Back clearance for hoses/connections
      }.freeze
      
      # Generic Range/Cooktop Placeholder
      # Standard range sizes for space planning
      RANGE = {
        # 30" Range (most common)
        width_30: 30.0,
        depth_30: 26.0,       # Slightly deeper than countertop
        height_30: 36.0,      # Cooking surface height
        
        # 36" Range
        width_36: 36.0,
        depth_36: 26.0,
        height_36: 36.0,
        
        # 48" Range (pro-style)
        width_48: 48.0,
        depth_48: 27.0,       # Pro ranges are deeper
        height_48: 36.0,
        
        clearance_back: 3.0,  # Back clearance for gas line/electrical
        clearance_side: 0.0   # Side clearance (varies by model)
      }.freeze
      
      # Countertop Standards
      COUNTERTOP = {
        depth: 25.5,          # 1.5" overhang beyond base cabinet
        thickness: 1.5,       # Standard countertop thickness
        backsplash_height: 4.0, # Standard backsplash
        overhang_front: 1.5,  # Front overhang
        overhang_side: 0.75   # Side overhang (end caps)
      }.freeze
      
      # Door and Drawer Standards
      DOOR_DRAWER = {
        reveal: 0.125,        # 1/8" spacing between doors/drawers
        overlay: 0.375,       # 3/8" overlay for framed cabinets
        thickness: 0.75,      # Door/drawer front thickness
        hinge_width: 1.5,     # European hinge width
        hinge_height: 3.0,    # Hinge plate height
        pull_diameter: 0.5,   # Handle/knob diameter (simplified)
        pull_projection: 1.25 # How far pull extends from door
      }.freeze
      
      # Frame Standards (for framed cabinets)
      FRAME = {
        width: 1.5,           # Face frame stile/rail width
        thickness: 0.75       # Face frame thickness
      }.freeze
      
      # Corner Cabinet Standards
      CORNER = {
        diagonal_width: 36.0, # Diagonal corner cabinet
        blind_width: 42.0,    # Blind corner cabinet width
        blind_overlap: 3.0,   # How much blind cabinet overlaps adjacent
        lazy_susan_diameter: 28.0, # Rotating shelf diameter
        lazy_susan_pole_diameter: 1.5 # Center pole
      }.freeze
      
      # Drawer Configuration Presets
      DRAWER_CONFIGS = {
        single: [1.0],        # One drawer (full height)
        double: [0.5, 0.5],   # Two equal drawers
        triple: [0.33, 0.33, 0.34], # Three equal drawers
        graduated_3: [0.25, 0.30, 0.45], # Small top, larger bottom
        graduated_4: [0.20, 0.25, 0.25, 0.30], # Four graduated
        bank_3: [0.2, 0.2, 0.6], # Two small drawers over one deep
        bank_4: [0.15, 0.15, 0.15, 0.55] # Three small over one deep
      }.freeze
      
      # Cabinet Types
      CABINET_TYPES = [
        :base,
        :wall,
        :wall_stack,
        :wall_stack_9ft,
        :island,
        :tall,
        :corner_base,
        :corner_wall,
        :floating,
        :subzero_fridge,
        :miele_dishwasher,
        :range
      ].freeze
      
      # Frame Types
      FRAME_TYPES = [:framed, :frameless].freeze
      
      # Corner Types
      CORNER_TYPES = [:blind, :lazy_susan, :diagonal].freeze
      
      # Room Presets with default configurations
      ROOM_PRESETS = {
        kitchen: {
          base_depth: BASE_CABINET[:depth],
          wall_depth: WALL_CABINET[:depth],
          wall_height: WALL_CABINET[:height_standard],
          countertop: true,
          backsplash: true
        },
        bathroom: {
          base_depth: 21.0,    # Shallower for bathrooms
          wall_depth: 12.0,
          wall_height: WALL_CABINET[:height_short],
          countertop: true,
          backsplash: true
        },
        closet: {
          base_depth: 24.0,
          wall_depth: 14.0,    # Deeper shelving
          wall_height: WALL_CABINET[:height_tall],
          countertop: false,
          backsplash: false
        }
      }.freeze
      
      # Material color defaults (for visualization before TwinMotion)
      MATERIAL_COLORS = {
        box_wood: [139, 90, 43],        # Brown wood tone
        door_face: [160, 120, 80],      # Lighter wood tone
        countertop: [240, 240, 235],    # Off-white marble
        hardware: [180, 180, 180],      # Brushed metal gray
        interior: [245, 235, 220]       # Light interior
      }.freeze
      
    end
  end
end
