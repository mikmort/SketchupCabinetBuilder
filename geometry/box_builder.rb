# SketchUp Cabinet Builder - Box Builder
# Generates cabinet box geometry (case/carcass)

module MikMort
  module CabinetBuilder
    module Geometry
      
      class BoxBuilder
        
        def initialize(model, material_manager)
          @model = model
          @materials = material_manager
        end
        
        # Build a cabinet box
        # @param cabinet [Cabinet] The cabinet specification
        # @param parent_group [Sketchup::Group] Parent group to add box to
        # @param position [Array, nil] Optional [x, y, z] position for range placeholders
        # @return [Sketchup::Group] The box group
        def build(cabinet, parent_group, position = nil)
          # Don't create a sub-group, work directly in parent
          case cabinet.type
          when :corner_base, :corner_wall
            build_corner_box(cabinet, parent_group)
          when :wall_stack
            build_wall_stack_box(cabinet, parent_group, :wall_stack)
          when :wall_stack_9ft
            build_wall_stack_box(cabinet, parent_group, :wall_stack_9ft)
          when :subzero_fridge
            build_subzero_box(cabinet, parent_group)
          when :miele_dishwasher
            build_dishwasher_box(cabinet, parent_group)
          
          when :wall_oven
            build_wall_oven_box(cabinet, parent_group)
          when :range
            build_range_placeholder(cabinet, parent_group, position)
          else
            build_standard_box(cabinet, parent_group)
          end
          
          parent_group
        end
        
        private
        
        # Build a standard rectangular cabinet box
        def build_standard_box(cabinet, box_group)
          begin
            entities = box_group.entities
            thickness = Constants::BASE_CABINET[:panel_thickness]
            
            width = cabinet.width
            depth = cabinet.depth
            height = cabinet.interior_height
            
            # Convert to SketchUp units (inches)
            w = width.inch
            d = depth.inch
            h = height.inch
            t = thickness.inch
            
            # Determine if this cabinet needs toe kick elevation
            has_toe_kick = (cabinet.type == :base || cabinet.type == :island || cabinet.type == :display_base)
            kick_height = has_toe_kick ? Constants::BASE_CABINET[:toe_kick_height].inch : 0
            kick_depth = has_toe_kick ? Constants::BASE_CABINET[:toe_kick_depth].inch : 0
            total_height = kick_height + h
            
            # Create all panels
            back_thickness = (thickness * 0.5).inch
            
            # Bottom panel (elevated by kick_height, full depth from front to back)
            pts = [[0, 0, kick_height], [w, 0, kick_height], [w, d, kick_height], [0, d, kick_height]]
            create_simple_box(entities, pts, t, @materials.box_material)
            
            # Left/right side panels (with toe kick notch when needed)
            if has_toe_kick
              create_toe_kick_side_panel(entities, :left, w, d, t, total_height, kick_height, kick_depth, @materials.box_material)
              create_toe_kick_side_panel(entities, :right, w, d, t, total_height, kick_height, kick_depth, @materials.box_material)
            else
              # For cabinets with top panels (wall, tall, floating, display), reduce side height by panel thickness
              has_top_panel = (cabinet.type == :wall || cabinet.type == :tall || cabinet.type == :floating || cabinet.type == :display_wall)
              side_height = has_top_panel ? h - t : h
              
              pts = [[0, 0, 0], [t, 0, 0], [t, d, 0], [0, d, 0]]
              create_simple_box(entities, pts, side_height, @materials.box_material)
              pts = [[w - t, 0, 0], [w, 0, 0], [w, d, 0], [w - t, d, 0]]
              create_simple_box(entities, pts, side_height, @materials.box_material)
            end
            
            # Back panel (slightly thinner, elevated by kick_height, full width for frameless)
            # For cabinets with top panels, reduce back height by panel thickness
            has_top_panel = (cabinet.type == :wall || cabinet.type == :tall || cabinet.type == :floating || cabinet.type == :display_base || cabinet.type == :display_wall)
            back_height = has_top_panel ? h - t : h
            pts = [[0, d - back_thickness, kick_height], [w, d - back_thickness, kick_height], [w, d, kick_height], [0, d, kick_height]]
            create_simple_box(entities, pts, back_height, @materials.box_material)
            
            # Create top panel (for wall cabinets, tall cabinets, and display cabinets)
            if cabinet.type == :wall || cabinet.type == :tall || cabinet.type == :floating || cabinet.type == :display_base || cabinet.type == :display_wall
              top_z = kick_height + h - t
              pts = [[0, 0, top_z], [w, 0, top_z], [w, d, top_z], [0, d, top_z]]
              create_simple_box(entities, pts, t, @materials.box_material)
            end
            
            # Create interior shelves
            if cabinet.type == :display_base || cabinet.type == :display_wall
              # Display cabinet: multiple shelves spaced 14-18" apart
              create_display_cabinet_shelves(entities, cabinet, w, d, h, t, back_thickness, kick_height)
            elsif height > 24.inch
              # Standard cabinet: one adjustable shelf in the middle
              shelf_height = kick_height + (height / 2.0)
              pts = [[t, 0, shelf_height], [w - t, 0, shelf_height], [w - t, d - back_thickness, shelf_height], [t, d - back_thickness, shelf_height]]
              create_simple_box(entities, pts, t, @materials.interior_material)
            end
            
            # Add toe kick for base, island, and display_base cabinets
            if cabinet.type == :base || cabinet.type == :island || cabinet.type == :display_base
              add_toe_kick(entities, width, depth)
            end
          rescue => e
            puts "Error building standard box: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Build a corner cabinet box (L-shaped or diagonal)
        def build_corner_box(cabinet, box_group)
          entities = box_group.entities
          thickness = Constants::BASE_CABINET[:panel_thickness]
          
          case cabinet.corner_type
          when :inside_36
            build_inside_corner_box(entities, cabinet, thickness, 36)
          when :inside_24
            build_inside_corner_box(entities, cabinet, thickness, 24)
          when :outside_36
            build_outside_corner_box(entities, cabinet, thickness, 36)
          when :outside_24
            build_outside_corner_box(entities, cabinet, thickness, 24)
          else
            build_inside_corner_box(entities, cabinet, thickness, 36)
          end
        end
        
        # Build inside corner cabinet box (TRUE L-SHAPED corner cabinet)
        # 36" x 36" footprint with 24" x 24" cutout at front-right corner
        def build_inside_corner_box(entities, cabinet, thickness, corner_size)
          begin
            t = thickness.inch
            h = cabinet.interior_height.inch
            
            # TRUE L-SHAPED corner cabinet
            # 36" x 36" outer footprint with 24" x 24" cutout at FRONT-RIGHT corner
            #
            # TOP VIEW (looking down, origin at front-left):
            #
            #     Y (back)
            #     ^
            #     |
            # 36" ┌──────────────────────────────┐
            #     │                              │
            #     │      BACK SECTION            │
            #     │      (36" wide x 24" deep)   │
            #     │                              │
            # 12" │              ┌───────────────┘  <- Inside corner
            #     │              │
            #     │  LEFT LEG    │    CUTOUT
            #     │  (12" wide   │    (24" x 12")
            #     │   x 12" deep)│    (OPEN)
            #     │              │
            #   0 └──────────────┘─────────────────> X (right)
            #     0             12"               36"
            #
            # The L-shape consists of:
            # - Left leg: X = 0 to 12", Y = 0 to 12" (front section)
            # - Back section: X = 0 to 36", Y = 12" to 36" (full width back)
            # - Cutout: X = 12" to 36", Y = 0 to 12" (OPEN - no cabinet here)
            
            size = corner_size.inch           # 36" total footprint
            cutout = 12.inch                  # 12" x 12" cutout at Front-Left
            
            # SHIFT GEOMETRY FORWARD BY 12" (along Y axis)
            # The cabinet needs to align with the front of the adjacent runs
            # Adjacent runs are at Y=0 (front face)
            # Currently, the cutout is at Y=0..12, so the back leg starts at Y=12
            # If we shift everything by -12" in Y? No, user said "move 12" forward".
            # Forward usually means -Y (towards the user) in SketchUp if Y is depth.
            # But here Y is depth going back.
            # If the cabinet is "too far back", we need to move it -Y.
            # If the cabinet is "too far forward", we need to move it +Y.
            # User says "move 12" forward".
            # Let's assume "forward" means towards the front of the room (negative Y).
            # Wait, the picture shows the corner cabinet is BEHIND the left cabinet.
            # The left cabinet front is at Y=0?
            # The corner cabinet front (of the back leg) is at Y=12.
            # So there is a 12" gap.
            # To align them, we need to move the corner cabinet -12" in Y.
            # BUT, the corner cabinet has a depth of 36".
            # If we move it -12", the back will be at Y=24.
            # The left cabinet has depth 24". Its back is at Y=24.
            # So aligning the backs makes sense.
            
            # Let's apply a transformation to shift all points by -12" in Y.
            shift_y = -12.inch
            
            # Determine if this is a base cabinet (has toe kick)
            is_base_cabinet = cabinet.type == :base || cabinet.type == :corner_base || cabinet.type == :island
            
            kick_height = is_base_cabinet ? Constants::BASE_CABINET[:toe_kick_height].inch : 0.inch
            kick_depth = is_base_cabinet ? Constants::BASE_CABINET[:toe_kick_depth].inch : 0.inch
            
            top_z = kick_height + h
            panel_bottom = kick_height + t
            panel_height = h - t
            
            # ============ L-SHAPED BOTTOM PANEL (Cutout at Front-Left) ============
            # 6-point L-shape
            # Left Leg: X=0..12, Y=0..24 (Recessed)
            # Right Leg: X=12..36, Y=-12..24 (Standard Depth)
            
            bottom_pts = [
              Geom::Point3d.new(0, cutout + shift_y, kick_height),         # 1. Front-Left (0, 0)
              Geom::Point3d.new(cutout, cutout + shift_y, kick_height),    # 2. Inner Corner (12, 0)
              Geom::Point3d.new(cutout, 0 + shift_y, kick_height),         # 3. Front-Inner-Right (12, -12)
              Geom::Point3d.new(size, 0 + shift_y, kick_height),           # 4. Front-Right (36, -12)
              Geom::Point3d.new(size, size + shift_y, kick_height),        # 5. Back-Right (36, 24)
              Geom::Point3d.new(0, size + shift_y, kick_height)            # 6. Back-Left (0, 24)
            ]
            face = entities.add_face(bottom_pts)
            if face && face.valid?
              face.reverse! if face.normal.z < 0
              face.material = @materials.box_material
              face.pushpull(t)
            end
            
            # ============ L-SHAPED TOP PANEL ============
            top_pts = [
              Geom::Point3d.new(0, cutout + shift_y, top_z),
              Geom::Point3d.new(cutout, cutout + shift_y, top_z),
              Geom::Point3d.new(cutout, 0 + shift_y, top_z),
              Geom::Point3d.new(size, 0 + shift_y, top_z),
              Geom::Point3d.new(size, size + shift_y, top_z),
              Geom::Point3d.new(0, size + shift_y, top_z)
            ]
            face = entities.add_face(top_pts)
            if face && face.valid?
              face.reverse! if face.normal.z > 0
              face.material = @materials.box_material
              face.pushpull(t)
            end
            
            # ============ LEFT SIDE PANEL (at X=0, Y=0 to 24") ============
            pts = [[0, cutout + shift_y, kick_height], [t, cutout + shift_y, kick_height], 
                   [t, size + shift_y, kick_height], [0, size + shift_y, kick_height]]
            create_simple_box(entities, pts, h, @materials.drawer_face_material)
            
            # ============ RIGHT SIDE PANEL (at X=36", Y=-12 to 24") ============
            pts = [[size - t, 0 + shift_y, kick_height], [size, 0 + shift_y, kick_height], 
                   [size, size + shift_y, kick_height], [size - t, size + shift_y, kick_height]]
            create_simple_box(entities, pts, h, @materials.drawer_face_material)
            
            # ============ BACK PANEL (at Y=24", full width) ============
            back_t = (t * 0.5)
            pts = [[0, size - back_t + shift_y, panel_bottom], [size, size - back_t + shift_y, panel_bottom], 
                   [size, size + shift_y, panel_bottom], [0, size + shift_y, panel_bottom]]
            create_simple_box(entities, pts, panel_height, @materials.box_material)
            
            # ============ RIGHT LEG FRONT PANEL (at Y=-12, X=12" to 36") ============
            # Starts at X=12 (Standard 24" width)
            pts = [[cutout, 0 + shift_y, panel_bottom], [size, 0 + shift_y, panel_bottom], 
                   [size, t + shift_y, panel_bottom], [cutout, t + shift_y, panel_bottom]]
            create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
            
            # ============ LEFT LEG FRONT PANEL (at Y=0, X=0 to 12) ============
            # This is the front face of the Left Leg
            pts = [[0, cutout + shift_y, panel_bottom], [cutout, cutout + shift_y, panel_bottom], 
                   [cutout, cutout + t + shift_y, panel_bottom], [0, cutout + t + shift_y, panel_bottom]]
            create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
            
            # ============ INNER FACE 2 (Facing Left, at X=12, Y=-12 to 0) ============
            # Encloses the Right Leg from the cutout
            # At X=12 (Standard position)
            pts = [[cutout, 0 + shift_y, panel_bottom], [cutout + t, 0 + shift_y, panel_bottom], 
                   [cutout + t, cutout + shift_y, panel_bottom], [cutout, cutout + shift_y, panel_bottom]]
            create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
            
            # Add toe kick for L-shape
            if cabinet.type == :corner_base
              add_corner_toe_kick(entities, corner_size, cabinet.depth, :inside)
            end
          rescue => e
            puts "    ERROR in build_inside_corner_box: #{e.message}"
            puts "    #{e.backtrace.first(5).join("\n    ")}"
          end
        end
        
        # Build outside corner cabinet box (L-shaped, wraps around an outside corner)
        # Creates an L-shaped cabinet that wraps around an outside corner/peninsula
        def build_outside_corner_box(entities, cabinet, thickness, corner_size)
          t = thickness.inch
          h = cabinet.interior_height.inch
          size = corner_size.inch
          depth = cabinet.depth.inch
          
          # Determine if this is a base cabinet (has toe kick)
          is_base_cabinet = cabinet.type == :base || cabinet.type == :corner_base || cabinet.type == :island
          kick_height = is_base_cabinet ? Constants::BASE_CABINET[:toe_kick_height].inch : 0.inch
          
          # Calculate panel height
          # If we have a top panel (wall cabinet or base without countertop), reduce side height by thickness
          # Base cabinets without countertop should have a top panel
          needs_top_panel = !cabinet.has_countertop || cabinet.type == :corner_wall
          panel_height = needs_top_panel ? h - t : h
          
          # Handle case where size == depth (24x24 corner)
          # In this case, there's no "back" section - it's just an L-shape
          return_depth = size - depth  # This will be 0 for 24x24
          
          # Outside corner L-shape:
          # The cabinet wraps around an outside corner
          # Has an open corner area in the back where the corner column would be
          
          # Bottom panel - Main section along X (always created)
          pts1 = [[0, 0, kick_height], [size, 0, kick_height], [size, depth, kick_height], [0, depth, kick_height]]
          create_simple_box(entities, pts1, t, @materials.drawer_face_material)
          
          # Bottom panel - Return section along Y (only if there's a return depth)
          if return_depth > 0.inch
            pts2 = [[return_depth, depth, kick_height], [size, depth, kick_height], [size, size, kick_height], [return_depth, size, kick_height]]
            create_simple_box(entities, pts2, t, @materials.drawer_face_material)
          end
          
          # Left side panel (exposed - use door_face_material)
          pts = [[0, 0, kick_height + t], [t, 0, kick_height + t], [t, depth, kick_height + t], [0, depth, kick_height + t]]
          create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
          
          # Front panel of X wing (along the front edge)
          pts = [[0, 0, kick_height + t], [size, 0, kick_height + t], [size, t, kick_height + t], [0, t, kick_height + t]]
          create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
          
          # Right side of X wing (transitions to Y wing)
          # This covers the entire right side (X=size) from Y=0 to Y=size
          pts = [[size - t, 0, kick_height + t], [size, 0, kick_height + t], [size, size, kick_height + t], [size - t, size, kick_height + t]]
          create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
          
          # Back panel of X wing (only if there's a return depth)
          if return_depth > 0.inch
            pts = [[0, depth - t, kick_height + t], [return_depth, depth - t, kick_height + t], [return_depth, depth, kick_height + t], [0, depth, kick_height + t]]
            create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
          else
            # For 24x24 (no return), back panel spans full width
            pts = [[0, depth - t, kick_height + t], [size - t, depth - t, kick_height + t], [size - t, depth, kick_height + t], [0, depth, kick_height + t]]
            create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
          end
          
          # Left side of Y wing (inner corner side) - only if there's a return depth
          if return_depth > 0.inch
            pts = [[return_depth, depth, kick_height + t], [return_depth + t, depth, kick_height + t], [return_depth + t, size, kick_height + t], [return_depth, size, kick_height + t]]
            create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
          end
          
          # Far end of Y wing - only if there's a return depth
          if return_depth > 0.inch
            pts = [[return_depth, size - t, kick_height + t], [size, size - t, kick_height + t], [size, size, kick_height + t], [return_depth, size, kick_height + t]]
            create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
          else
            # For 24x24, back panel at Y=size
            pts = [[0, size - t, kick_height + t], [size - t, size - t, kick_height + t], [size - t, size, kick_height + t], [0, size, kick_height + t]]
            create_simple_box(entities, pts, panel_height, @materials.drawer_face_material)
          end
          
          # Add top panel if needed
          if needs_top_panel
            top_z = kick_height + h - t
            # Top panel - Main section along X (use door_face_material to match exposed faces)
            pts1 = [[0, 0, top_z], [size, 0, top_z], [size, depth, top_z], [0, depth, top_z]]
            create_simple_box(entities, pts1, t, @materials.drawer_face_material)
            
            # Top panel - Return section along Y (only if there's a return depth)
            if return_depth > 0.inch
              pts2 = [[return_depth, depth, top_z], [size, depth, top_z], [size, size, top_z], [return_depth, size, top_z]]
              create_simple_box(entities, pts2, t, @materials.drawer_face_material)
            end
          end
          
          # Add toe kick
          if cabinet.type == :corner_base
            add_corner_toe_kick(entities, corner_size, cabinet.depth, :outside)
          end
        end
        
        # Add toe kick for corner cabinets
        def add_corner_toe_kick(entities, corner_size, depth, corner_type)
          toe_height = Constants::BASE_CABINET[:toe_kick_height].inch
          toe_depth = Constants::BASE_CABINET[:toe_kick_depth].inch
          t = Constants::BASE_CABINET[:panel_thickness].inch
          size = corner_size.inch
          d = depth.inch
          cutout = 12.inch
          shift_y = -12.inch
          
          if corner_type == :inside
            # TRUE L-SHAPED corner toe kick (Recessed 3" from faces)
            # Faces are at:
            # - Left Leg Front: Y = 0 (X=0..12) -> Toe Kick Y = 3
            # - Right Leg Side: X = 12 (Y=-12..0) -> Toe Kick X = 15
            # - Right Leg Front: Y = -12 (X=12..36) -> Toe Kick Y = -9
            
            toe_y_front = cutout + shift_y + toe_depth # 12 - 12 + 3 = 3
            toe_x_side = cutout + toe_depth            # 12 + 3 = 15
            toe_y_right = 0 + shift_y + toe_depth      # 0 - 12 + 3 = -9
            toe_x_end = size - toe_depth               # 36 - 3 = 33
            
            # 1. Left Leg Front Segment (X=0 to 15, Y=3)
            pts = [
              [0, toe_y_front, 0], 
              [toe_x_side, toe_y_front, 0], 
              [toe_x_side, toe_y_front + t, 0], 
              [0, toe_y_front + t, 0]
            ]
            create_simple_box(entities, pts, toe_height, @materials.drawer_face_material)
            
            # 2. Right Leg Side Segment (X=15, Y=-9 to 3)
            pts = [
              [toe_x_side, toe_y_right, 0], 
              [toe_x_side + t, toe_y_right, 0], 
              [toe_x_side + t, toe_y_front, 0], 
              [toe_x_side, toe_y_front, 0]
            ]
            create_simple_box(entities, pts, toe_height, @materials.drawer_face_material)
            
            # 3. Right Leg Front Segment (X=15 to 36, Y=-9)
            # Note: Extending to 36 (full width) as requested
            pts = [
              [toe_x_side, toe_y_right, 0], 
              [size, toe_y_right, 0], 
              [size, toe_y_right + t, 0], 
              [toe_x_side, toe_y_right + t, 0]
            ]
            create_simple_box(entities, pts, toe_height, @materials.drawer_face_material)
          else
            # L-shaped toe kick for outside corner
            # Recessed 3" from Front (Y=0) and Right (X=36)
            # Match standard toe kick: visible face at Y = toe_depth - t (so box extends from toe_depth-t to toe_depth)
            
            toe_y_back = toe_depth             # 3" (back edge of toe kick panel)
            toe_y_front = toe_depth - t        # 2.25" (visible front face, matches standard toe kick)
            toe_x_right = size - toe_depth     # 33"
            toe_x_left = toe_x_right - t       # 32.25" (visible right face)
            
            # 1. Front Segment (X=0 to toe_x_left, visible face at Y=toe_y_front)
            pts = [
              [0, toe_y_front, 0], 
              [toe_x_left, toe_y_front, 0], 
              [toe_x_left, toe_y_back, 0], 
              [0, toe_y_back, 0]
            ]
            create_simple_box(entities, pts, toe_height, @materials.drawer_face_material)
            
            # 2. Right Side Segment (visible face at X=toe_x_left, Y from toe_y_front to size)
            pts = [
              [toe_x_left, toe_y_front, 0], 
              [toe_x_right, toe_y_front, 0], 
              [toe_x_right, size, 0], 
              [toe_x_left, size, 0]
            ]
            create_simple_box(entities, pts, toe_height, @materials.drawer_face_material)
          end
        end
        

        
        # Add a panel with specified corners and extrusion direction
        # @param entities [Sketchup::Entities] The entities collection to add to
        # @param name [String] Name for the panel
        # @param corners [Array<Array>] Four corner points [[x,y,z], ...]
        # @param thickness [Float] Panel thickness in inches
        # @param extrude_direction [Symbol] Direction to extrude (:up, :down, :left, :right, :forward, :backward)
        def add_panel(entities, name, corners, thickness, extrude_direction)
          # Convert corners to Point3d
          pts = corners.map { |c| Geom::Point3d.new(*c) }
          
          # Calculate extrusion vector based on direction
          t = thickness
          extrude_vector = case extrude_direction
          when :up then Geom::Vector3d.new(0, 0, t)
          when :down then Geom::Vector3d.new(0, 0, -t)
          when :left then Geom::Vector3d.new(-t, 0, 0)
          when :right then Geom::Vector3d.new(t, 0, 0)
          when :forward then Geom::Vector3d.new(0, -t, 0)
          when :backward then Geom::Vector3d.new(0, t, 0)
          else Geom::Vector3d.new(0, 0, t)  # default to up
          end
          
          # Create back face points by transforming front face points
          back_pts = pts.map { |pt| pt.offset(extrude_vector) }
          
          # Create front face
          front_face = entities.add_face(pts)
          if front_face && front_face.valid?
            front_face.material = @materials.carcass_material
          end
          
          # Create back face
          back_face = entities.add_face(back_pts.reverse)  # Reverse for correct normal
          if back_face && back_face.valid?
            back_face.material = @materials.carcass_material
          end
          
          # Create side faces connecting front to back
          4.times do |i|
            next_i = (i + 1) % 4
            side_pts = [
              pts[i],
              pts[next_i],
              back_pts[next_i],
              back_pts[i]
            ]
            side_face = entities.add_face(side_pts)
            if side_face && side_face.valid?
              side_face.material = @materials.carcass_material
            end
          end
        end
        
        # Create a rectangular panel
        def create_panel(entities, origin, dimensions, material, name = nil)
          x, y, z = origin
          w, d, h = dimensions
          
          # Skip if dimensions are too small
          return if w.abs < 0.001 || d.abs < 0.001
          
          pts = [
            [x, y, z],
            [x + w, y, z],
            [x + w, y + d, z],
            [x, y + d, z]
          ]
          
          create_simple_box(entities, pts, h, material)
        end
        
        # Create a simple extruded box from points
        def create_simple_box(entities, points, extrude_height, material)
          begin
            # Convert points to Point3d objects
            pts = points.map { |p| p.is_a?(Array) ? Geom::Point3d.new(*p) : p }
            
            # Check for duplicate points (would cause "Duplicate points in array" error)
            unique_pts = pts.uniq { |p| [p.x.round(6), p.y.round(6), p.z.round(6)] }
            if unique_pts.length < 3
              puts "Warning: Skipping box with degenerate geometry (#{unique_pts.length} unique points)"
              return
            end
            
            # Don't use pushpull - it causes SketchUp API bugs!
            # Instead, manually create the 3D box by extruding along the face normal
            
            # Create front face
            front_face = entities.add_face(unique_pts)
            if front_face && front_face.valid?
              front_face.material = material if material
              front_face.back_material = material if material
              
              # Create back face (offset by extrude_height along normal)
              if extrude_height && extrude_height.abs > 0.001
                # For horizontal faces (bottom/top panels), always extrude upward in +Z
                # For vertical faces (sides), extrude along the normal
                normal = front_face.normal
                
                # Check if this is a horizontal face (normal mostly in Z direction)
                if normal.z.abs > 0.9
                  # Horizontal face - always extrude upward
                  offset = Geom::Vector3d.new(0, 0, extrude_height.abs)
                else
                  # Vertical face - extrude along normal
                  offset = Geom::Vector3d.new(normal.x * extrude_height, 
                                              normal.y * extrude_height, 
                                              normal.z * extrude_height)
                end
                
                # Create back face points by translating along normal
                back_pts = unique_pts.map { |pt| pt.transform(Geom::Transformation.translation(offset)) }
                back_face = entities.add_face(back_pts.reverse) # Reverse for correct normal
                if back_face && back_face.valid?
                  back_face.material = material if material
                  back_face.back_material = material if material
                end
                
                # Create side faces to close the box
                unique_pts.each_with_index do |pt, i|
                  next_i = (i + 1) % unique_pts.length
                  side_pts = [
                    unique_pts[i],
                    unique_pts[next_i],
                    back_pts[next_i],
                    back_pts[i]
                  ]
                  side_face = entities.add_face(side_pts)
                  if side_face && side_face.valid?
                    side_face.material = material if material
                    side_face.back_material = material if material
                  end
                end
              end
            end
          rescue => e
            puts "Error creating box: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Create a side panel with a toe kick notch removed at the front bottom
        def create_toe_kick_side_panel(entities, side, width, depth, thickness, total_height, kick_height, kick_depth, material)
          plane_x = side == :left ? 0 : (width - thickness)
          extrude = side == :left ? thickness : thickness
          top_z = total_height
          
          puts "DEBUG create_toe_kick_side_panel: side=#{side}, width=#{width}, thickness=#{thickness}, plane_x=#{plane_x}, extrude=#{extrude}"
          
          pts = [
            [plane_x, kick_depth, 0],
            [plane_x, depth, 0],
            [plane_x, depth, top_z],
            [plane_x, 0, top_z],
            [plane_x, 0, kick_height],
            [plane_x, kick_depth, kick_height]
          ]
          
          create_simple_box(entities, pts, extrude, material)
        end
        
        # Create shelves for display cabinet (spaced 14-18" apart)
        def create_display_cabinet_shelves(entities, cabinet, w, d, h, t, back_thickness, kick_height)
          # Calculate available interior height (excluding bottom and top panels)
          interior_height = h - (2 * t)  # Height minus top and bottom panels
          bottom_z = kick_height + t  # Start above bottom panel
          
          # Target shelf spacing of 14-18" (use 16" as ideal)
          ideal_spacing = 16.0.inch
          min_spacing = 14.0.inch
          max_spacing = 18.0.inch
          
          # Calculate number of shelves that fit
          # We need at least one shelf for display purposes
          num_shelves = (interior_height / ideal_spacing).floor
          num_shelves = [num_shelves, 1].max  # At least 1 shelf
          
          # Calculate actual spacing
          if num_shelves > 0
            spacing = interior_height / (num_shelves + 1)  # +1 for top/bottom gaps
            
            # Clamp spacing to min/max
            if spacing < min_spacing
              num_shelves = (interior_height / max_spacing).floor
              num_shelves = [num_shelves, 1].max
              spacing = interior_height / (num_shelves + 1)
            elsif spacing > max_spacing
              num_shelves = (interior_height / min_spacing).floor
              spacing = interior_height / (num_shelves + 1)
            end
          else
            spacing = interior_height / 2.0
            num_shelves = 1
          end
          
          puts "DEBUG Display Cabinet: interior_height=#{interior_height}, num_shelves=#{num_shelves}, spacing=#{spacing}"
          
          # Get or create display shelf material
          display_shelf_material = get_or_create_display_shelf_material
          
          # Create each shelf
          num_shelves.times do |i|
            shelf_z = bottom_z + spacing * (i + 1)
            
            # Shelf spans from left panel to right panel, front to back (minus back panel)
            pts = [
              [t, 0, shelf_z],
              [w - t, 0, shelf_z],
              [w - t, d - back_thickness, shelf_z],
              [t, d - back_thickness, shelf_z]
            ]
            
            shelf_group = entities.add_group
            shelf_group.name = "Shelf #{i + 1}"
            create_simple_box(shelf_group.entities, pts, t, display_shelf_material)
          end
        end
        
        # Get or create the display shelf material
        def get_or_create_display_shelf_material
          material_name = "Display_Shelf_Face"
          material = @model.materials[material_name]
          
          unless material
            material = @model.materials.add(material_name)
            # Light wood color for display shelves
            material.color = Sketchup::Color.new(220, 200, 170)
          end
          
          material
        end
        
        # Add toe kick components (recessed face only)
        def add_toe_kick(entities, width, depth)
          kick_height = Constants::BASE_CABINET[:toe_kick_height].inch
          kick_depth = Constants::BASE_CABINET[:toe_kick_depth].inch
          thickness = Constants::BASE_CABINET[:panel_thickness].inch
          w = width.inch
          d = depth.inch
          
          # Front plate recessed by kick_depth
          front_pts = [
            [0, kick_depth, 0],
            [w, kick_depth, 0],
            [w, kick_depth, kick_height],
            [0, kick_depth, kick_height]
          ]
          create_simple_box(entities, front_pts, -thickness, @materials.drawer_face_material)
        end
        
        # Build SubZero refrigerator enclosure
        def build_subzero_box(cabinet, carcass_group)
          begin
            thickness = Constants::SUBZERO_FRIDGE[:panel_thickness]
            clearance_back = Constants::SUBZERO_FRIDGE[:clearance_back]
            
            width = cabinet.width
            depth = cabinet.depth
            height = cabinet.height
            
            # Convert to SketchUp units
            w = width.inch
            d = depth.inch
            h = height.inch
            t = thickness.inch
            clear_back = clearance_back.inch
            
            # Appliance opening (reduced by clearances)
            appliance_depth = d - clear_back
            
            # Create enclosure panels as named groups
            # Left side panel
            left_group = carcass_group.entities.add_group
            left_group.name = "Left Side"
            pts = [[0, 0, 0], [t, 0, 0], [t, appliance_depth, 0], [0, appliance_depth, 0]]
            create_simple_box(left_group.entities, pts, h, @materials.box_material)
            
            # Right side panel
            right_group = carcass_group.entities.add_group
            right_group.name = "Right Side"
            pts = [[w - t, 0, 0], [w, 0, 0], [w, appliance_depth, 0], [w - t, appliance_depth, 0]]
            create_simple_box(right_group.entities, pts, h, @materials.box_material)
            
            # Top panel (with ventilation clearance)
            top_group = carcass_group.entities.add_group
            top_group.name = "Top"
            pts = [[0, 0, h], [w, 0, h], [w, appliance_depth, h], [0, appliance_depth, h]]
            create_simple_box(top_group.entities, pts, t, @materials.box_material)
            
            # Optional back panel (decorative, with opening for utilities)
            back_group = carcass_group.entities.add_group
            back_group.name = "Back"
            back_thickness = (thickness * 0.5).inch
            pts = [[t, d - back_thickness, 0], [w - t, d - back_thickness, 0], 
                   [w - t, d, 0], [t, d, 0]]
            create_simple_box(back_group.entities, pts, h, @materials.interior_material)
            
          rescue => e
            puts "Error building SubZero box: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Build Miele dishwasher enclosure
        def build_dishwasher_box(cabinet, carcass_group)
          begin
            entities = carcass_group.entities
            thickness = Constants::BASE_CABINET[:panel_thickness]
            
            width = cabinet.width
            depth = cabinet.depth
            height = cabinet.interior_height
            
            # Convert to SketchUp units (inches)
            w = width.inch
            d = depth.inch
            h = height.inch
            t = thickness.inch
            
            # Dishwasher has toe kick like base cabinet
            kick_height = Constants::BASE_CABINET[:toe_kick_height].inch
            kick_depth = Constants::BASE_CABINET[:toe_kick_depth].inch
            total_height = kick_height + h
            
            # Create all panels (same as base cabinet)
            back_thickness = (thickness * 0.5).inch
            
            # Bottom panel (elevated by kick_height, full depth from front to back)
            pts = [[0, 0, kick_height], [w, 0, kick_height], [w, d, kick_height], [0, d, kick_height]]
            create_simple_box(entities, pts, t, @materials.box_material)
            
            # Left/right side panels (with toe kick notch)
            create_toe_kick_side_panel(entities, :left, w, d, t, total_height, kick_height, kick_depth, @materials.box_material)
            create_toe_kick_side_panel(entities, :right, w, d, t, total_height, kick_height, kick_depth, @materials.box_material)
            
            # Back panel (slightly thinner, elevated by kick_height, full width for frameless)
            pts = [[0, d - back_thickness, kick_height], [w, d - back_thickness, kick_height], [w, d, kick_height], [0, d, kick_height]]
            create_simple_box(entities, pts, h, @materials.box_material)
            
            # Add toe kick
            add_toe_kick(entities, width, depth)
            
          rescue => e
            puts "Error building Miele dishwasher box: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Build wall oven cabinet with opening for appliance
        def build_wall_oven_box(cabinet, carcass_group)
          begin
            entities = carcass_group.entities
            thickness = Constants::TALL_CABINET[:panel_thickness]
            
            width = cabinet.width
            depth = cabinet.depth
            height = cabinet.height
            
            # Convert to SketchUp units (inches)
            w = width.inch
            d = depth.inch
            h = height.inch
            t = thickness.inch
            
            # Get oven configuration from options
            oven_type = cabinet.options[:oven_type] || :single
            oven_height = case oven_type
                         when :single
                           Constants::WALL_OVEN[:height_single]
                         when :double
                           Constants::WALL_OVEN[:height_double]
                         when :microwave
                           Constants::WALL_OVEN[:height_micro]
                         else
                           Constants::WALL_OVEN[:height_single]
                         end
            
            # Get oven position (from bottom of cabinet)
            oven_bottom = cabinet.options[:oven_bottom] || 12.0  # Default 12" from bottom
            oven_bottom_inch = oven_bottom.inch
            oven_height_inch = oven_height.inch
            oven_top = oven_bottom_inch + oven_height_inch
            
            # Create all panels for tall cabinet
            back_thickness = (thickness * 0.5).inch
            
            # Bottom panel (full depth from front to back)
            pts = [[0, 0, 0], [w, 0, 0], [w, d, 0], [0, d, 0]]
            create_simple_box(entities, pts, t, @materials.box_material)
            
            # Top panel
            pts = [[0, 0, h], [w, 0, h], [w, d, h], [0, d, h]]
            create_simple_box(entities, pts, t, @materials.box_material)
            
            # Left side panel (full height)
            pts = [[0, 0, 0], [0, d, 0], [0, d, h], [0, 0, h]]
            create_simple_box(entities, pts, t, @materials.box_material)
            
            # Right side panel (full height)
            pts = [[w, 0, 0], [w, 0, h], [w, d, h], [w, d, 0]]
            create_simple_box(entities, pts, t, @materials.box_material)
            
            # Back panel (full height, slightly thinner)
            pts = [[0, d - back_thickness, 0], [w, d - back_thickness, 0], [w, d, 0], [0, d, 0]]
            create_simple_box(entities, pts, h, @materials.box_material)
            
            # Create horizontal dividers (above and below oven opening)
            # Bottom divider (below oven opening)
            pts = [[0, 0, oven_bottom_inch], [w, 0, oven_bottom_inch], [w, d, oven_bottom_inch], [0, d, oven_bottom_inch]]
            create_simple_box(entities, pts, t, @materials.box_material)
            
            # Top divider (above oven opening)
            pts = [[0, 0, oven_top], [w, 0, oven_top], [w, d, oven_top], [0, d, oven_top]]
            create_simple_box(entities, pts, t, @materials.box_material)
            
            # Create oven placeholder group (visible opening area)
            oven_group = entities.add_group
            oven_group.name = "Oven Placeholder (#{oven_type})"
            oven_entities = oven_group.entities
            
            # Clearances
            clearance_sides = Constants::WALL_OVEN[:clearance_sides].inch
            clearance_back = Constants::WALL_OVEN[:clearance_back].inch
            
            # Oven opening dimensions (with clearances)
            oven_width = w - (2 * clearance_sides)
            oven_depth = d - clearance_back - t  # From front to back panel minus clearance
            
            # Create a simple box to represent the oven opening
            oven_x = clearance_sides
            oven_y = 0
            oven_z = oven_bottom_inch + t
            
            pts = [
              [oven_x, oven_y, oven_z],
              [oven_x + oven_width, oven_y, oven_z],
              [oven_x + oven_width, oven_y + oven_depth, oven_z],
              [oven_x, oven_y + oven_depth, oven_z]
            ]
            
            # Create a face to represent the oven opening (semi-transparent)
            face = oven_entities.add_face(pts)
            face.pushpull(oven_height_inch - (2 * t))
            
            # Apply a distinct material to the oven placeholder
            oven_material = @model.materials['Oven_Placeholder'] || @model.materials.add('Oven_Placeholder')
            oven_material.color = Sketchup::Color.new(60, 60, 60)  # Dark gray
            oven_material.alpha = 0.3  # Semi-transparent
            face.material = oven_material
            
          rescue => e
            puts "Error building wall oven box: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Build range placeholder
        # Builds directly into parent entities collection (no sub-grouping to avoid invalidation)
        def build_range_placeholder(cabinet, parent_entities, position = nil)
          begin
            width = cabinet.width
            depth = cabinet.depth
            height = cabinet.height
            
            puts "DEBUG build_range_placeholder: position=#{position.inspect}"
            
            # Convert to SketchUp units
            w = width.inch
            d = depth.inch
            h = height.inch
            t = 0.75.inch
            kick_height = Constants::BASE_CABINET[:toe_kick_height].inch
            cooktop_height = kick_height + (height - 2).inch  # 2" below top, above kick
            
            # Get position offset
            offset_x = position.is_a?(Geom::Point3d) ? position.x : 0
            offset_y = position.is_a?(Geom::Point3d) ? position.y : 0
            offset_z = position.is_a?(Geom::Point3d) ? position.z : 0
            
            # Use entities directly (could be model.active_entities or group.entities)
            ents = parent_entities.is_a?(Sketchup::Entities) ? parent_entities : parent_entities.entities
            
            # Create cooktop surface
            pts = [
              [offset_x + 0, offset_y + 0, offset_z + cooktop_height],
              [offset_x + w, offset_y + 0, offset_z + cooktop_height],
              [offset_x + w, offset_y + d, offset_z + cooktop_height],
              [offset_x + 0, offset_y + d, offset_z + cooktop_height]
            ]
            cooktop = ents.add_face(pts)
            if cooktop
              cooktop.material = @materials.interior_material rescue nil
              cooktop.back_material = @materials.interior_material rescue nil
            end
            
            # Add burners on cooktop (4 burners typical for 30"+ ranges)
            if width >= 30
              burner_radius = 4.inch
              margin = 4.inch
              spacing_x = (w - 2 * margin - 2 * burner_radius) / 1.0
              spacing_y = (d - 2 * margin - 2 * burner_radius) / 1.0
              
              # Burner 1 (front-left)
              pos1 = [offset_x + margin + burner_radius, offset_y + margin + burner_radius, offset_z + cooktop_height + 0.1.inch]
              circle1 = ents.add_circle(pos1, [0, 0, 1], burner_radius, 32)
              face1 = ents.add_face(circle1) if circle1.length > 0
              if face1 && face1.valid?
                face1.material = [64, 64, 64]
                inner1 = ents.add_circle(pos1, [0, 0, 1], burner_radius * 0.6, 32)
                if inner1.length > 0
                  inner_face1 = ents.add_face(inner1)
                  inner_face1.erase! if inner_face1
                end
              end
              
              # Burner 2 (front-right)
              pos2 = [offset_x + margin + burner_radius + spacing_x, offset_y + margin + burner_radius, offset_z + cooktop_height + 0.1.inch]
              circle2 = ents.add_circle(pos2, [0, 0, 1], burner_radius, 32)
              face2 = ents.add_face(circle2) if circle2.length > 0
              if face2 && face2.valid?
                face2.material = [64, 64, 64]
                inner2 = ents.add_circle(pos2, [0, 0, 1], burner_radius * 0.6, 32)
                if inner2.length > 0
                  inner_face2 = ents.add_face(inner2)
                  inner_face2.erase! if inner_face2
                end
              end
              
              # Burner 3 (back-left)
              pos3 = [offset_x + margin + burner_radius, offset_y + margin + burner_radius + spacing_y, offset_z + cooktop_height + 0.1.inch]
              circle3 = ents.add_circle(pos3, [0, 0, 1], burner_radius, 32)
              face3 = ents.add_face(circle3) if circle3.length > 0
              if face3 && face3.valid?
                face3.material = [64, 64, 64]
                inner3 = ents.add_circle(pos3, [0, 0, 1], burner_radius * 0.6, 32)
                if inner3.length > 0
                  inner_face3 = ents.add_face(inner3)
                  inner_face3.erase! if inner_face3
                end
              end
              
              # Burner 4 (back-right)
              pos4 = [offset_x + margin + burner_radius + spacing_x, offset_y + margin + burner_radius + spacing_y, offset_z + cooktop_height + 0.1.inch]
              circle4 = ents.add_circle(pos4, [0, 0, 1], burner_radius, 32)
              face4 = ents.add_face(circle4) if circle4.length > 0
              if face4 && face4.valid?
                face4.material = [64, 64, 64]
                inner4 = ents.add_circle(pos4, [0, 0, 1], burner_radius * 0.6, 32)
                if inner4.length > 0
                  inner_face4 = ents.add_face(inner4)
                  inner_face4.erase! if inner_face4
                end
              end
            end
            
            # Side markers to show range opening width
            # Start at kick height and go up to full cabinet height
            left_pts = [
              [offset_x + 0, offset_y + 0, offset_z + kick_height],
              [offset_x + t, offset_y + 0, offset_z + kick_height],
              [offset_x + t, offset_y + d, offset_z + kick_height],
              [offset_x + 0, offset_y + d, offset_z + kick_height]
            ]
            left_face = ents.add_face(left_pts)
            left_face.pushpull(h) if left_face
            
            right_pts = [
              [offset_x + w - t, offset_y + 0, offset_z + kick_height],
              [offset_x + w, offset_y + 0, offset_z + kick_height],
              [offset_x + w, offset_y + d, offset_z + kick_height],
              [offset_x + w - t, offset_y + d, offset_z + kick_height]
            ]
            right_face = ents.add_face(right_pts)
            right_face.pushpull(h) if right_face
            
          rescue => e
            puts "Error building range placeholder: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Build wall stack (42" lower + stacked upper)
        def build_wall_stack_box(cabinet, carcass_group, config_type = :wall_stack)
          begin
            # Get configuration based on type
            config = config_type == :wall_stack_9ft ? Constants::WALL_STACK_9FT : Constants::WALL_STACK
            
            width = cabinet.width
            depth = cabinet.depth  # Use cabinet's actual depth, not constant
            lower_height = config[:lower_height]
            upper_height = config[:upper_stack_height]
            stack_count = config[:upper_stack_count]
            reveal = config[:stack_reveal]
            thickness = config[:panel_thickness]
            
            # Convert to SketchUp units
            w = width.inch
            d = depth.inch
            t = thickness.inch
            r = reveal.inch
            
            current_z = 0
            
            # Build lower 42" cabinet
            lower_group = carcass_group.entities.add_group
            lower_group.name = "Lower_42in"
            
            add_panel(lower_group.entities, "Bottom", 
                     [[0, 0, current_z], [w, 0, current_z], [w, d, current_z], [0, d, current_z]], 
                     t, :up)
            
            add_panel(lower_group.entities, "Left Side",
                     [[0, 0, current_z], [0, d, current_z], [0, d, current_z + lower_height.inch], [0, 0, current_z + lower_height.inch]],
                     t, :right)
            
            add_panel(lower_group.entities, "Right Side",
                     [[w, 0, current_z], [w, 0, current_z + lower_height.inch], [w, d, current_z + lower_height.inch], [w, d, current_z]],
                     t, :left)
            
            add_panel(lower_group.entities, "Back",
                     [[0, d, current_z], [w, d, current_z], [w, d, current_z + lower_height.inch], [0, d, current_z + lower_height.inch]],
                     t, :forward)
            
            add_panel(lower_group.entities, "Top",
                     [[0, 0, current_z + lower_height.inch], [w, 0, current_z + lower_height.inch], 
                      [w, d, current_z + lower_height.inch], [0, d, current_z + lower_height.inch]],
                     t, :down)
            
            current_z += lower_height.inch
            
            # Build stacked upper cabinets (two 12" units)
            stack_count.times do |i|
              stack_group = carcass_group.entities.add_group
              stack_group.name = "Stack_#{i+1}_12in"
              
              z_start = current_z
              
              add_panel(stack_group.entities, "Bottom",
                       [[0, 0, z_start], [w, 0, z_start], [w, d, z_start], [0, d, z_start]],
                       t, :up)
              
              add_panel(stack_group.entities, "Left Side",
                       [[0, 0, z_start], [0, d, z_start], [0, d, z_start + upper_height.inch], [0, 0, z_start + upper_height.inch]],
                       t, :right)
              
              add_panel(stack_group.entities, "Right Side",
                       [[w, 0, z_start], [w, 0, z_start + upper_height.inch], [w, d, z_start + upper_height.inch], [w, d, z_start]],
                       t, :left)
              
              add_panel(stack_group.entities, "Back",
                       [[0, d, z_start], [w, d, z_start], [w, d, z_start + upper_height.inch], [0, d, z_start + upper_height.inch]],
                       t, :forward)
              
              add_panel(stack_group.entities, "Top",
                       [[0, 0, z_start + upper_height.inch], [w, 0, z_start + upper_height.inch],
                        [w, d, z_start + upper_height.inch], [0, d, z_start + upper_height.inch]],
                       t, :down)
              
              current_z += upper_height.inch
            end
            
          rescue => e
            puts "Error building wall stack: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Add a cylinder (for poles, hinges, etc.)
        def add_cylinder(entities, center, radius, height, material, name = nil)
          return if radius <= 0 || height.abs < 0.001
          
          begin
            circle = entities.add_circle(center, [0, 0, 1], radius, 24)
            if circle && circle.length > 0
              face = entities.add_face(circle)
              if face && face.valid?
                face.material = material if material
                face.pushpull(height)
              end
            end
          rescue => e
            puts "Error creating cylinder #{name}: #{e.message}"
          end
        end
        
      end
      
    end
  end
end
