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
        # @return [Sketchup::Group] The box group
        def build(cabinet, parent_group)
          # Don't create a sub-group, work directly in parent
          case cabinet.type
          when :corner_base, :corner_wall
            build_corner_box(cabinet, parent_group)
          when :wall_stack
            build_wall_stack_box(cabinet, parent_group)
          when :subzero_fridge
            build_subzero_box(cabinet, parent_group)
          when :miele_dishwasher
            build_dishwasher_box(cabinet, parent_group)
          when :range
            build_range_placeholder(cabinet, parent_group)
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
            
            # Create all panels
            back_thickness = (thickness * 0.5).inch
            
            # Bottom panel (full width and depth at z=0)
            pts = [[0, 0, 0], [w, 0, 0], [w, d, 0], [0, d, 0]]
            create_simple_box(entities, pts, t, @materials.box_material)
            
            # Left side panel (sits on bottom)
            pts = [[0, 0, 0], [t, 0, 0], [t, d, 0], [0, d, 0]]
            create_simple_box(entities, pts, h, @materials.box_material)
            
            # Right side panel (sits on bottom)
            pts = [[w - t, 0, 0], [w, 0, 0], [w, d, 0], [w - t, d, 0]]
            create_simple_box(entities, pts, h, @materials.box_material)
            
            # Back panel (slightly thinner, sits on bottom between sides)
            pts = [[t, d - back_thickness, 0], [w - t, d - back_thickness, 0], [w - t, d, 0], [t, d, 0]]
            create_simple_box(entities, pts, h, @materials.box_material)
            
            # Create top panel (for wall cabinets and tall cabinets)
            if cabinet.type == :wall || cabinet.type == :tall || cabinet.type == :floating
              pts = [[0, 0, h], [w, 0, h], [w, d, h], [0, d, h]]
              create_simple_box(entities, pts, t, @materials.box_material)
            end
            
            # Create interior shelves (one adjustable shelf for now)
            if height > 24.inch
              shelf_height = (height / 2.0)
              pts = [[t, 0, shelf_height], [w - t, 0, shelf_height], [w - t, d - back_thickness, shelf_height], [t, d - back_thickness, shelf_height]]
              create_simple_box(entities, pts, t, @materials.interior_material)
            end
            
            # Add toe kick for base and island cabinets
            if cabinet.type == :base || cabinet.type == :island
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
          when :blind
            build_blind_corner_box(entities, cabinet, thickness)
          when :lazy_susan
            build_lazy_susan_box(entities, cabinet, thickness)
          when :diagonal
            build_diagonal_corner_box(entities, cabinet, thickness)
          else
            build_blind_corner_box(entities, cabinet, thickness)
          end
        end
        
        # Build blind corner cabinet box (L-shaped)
        def build_blind_corner_box(entities, cabinet, thickness)
          w = cabinet.width.inch
          d = cabinet.depth.inch
          h = cabinet.interior_height.inch
          t = thickness.inch
          
          # Main section bottom
          pts = [[0, 0, 0], [w, 0, 0], [w, d, 0], [0, d, 0]]
          create_simple_box(entities, pts, t, @materials.box_material)
          
          # Return section bottom (perpendicular)
          return_width = (cabinet.width * 0.6).inch
          pts = [[w, 0, 0], [w + return_width, 0, 0], [w + return_width, d, 0], [w, d, 0]]
          create_simple_box(entities, pts, t, @materials.box_material)
          
          # Sides
          pts = [[0, 0, t], [t, 0, t], [t, d, t], [0, d, t]]
          create_simple_box(entities, pts, h, @materials.box_material)
          
          pts = [[w - t, 0, t], [w, 0, t], [w, d, t], [w - t, d, t]]
          create_simple_box(entities, pts, h, @materials.box_material)
          
          pts = [[w, 0, t], [w + return_width, 0, t], [w + return_width, t, t], [w, t, t]]
          create_simple_box(entities, pts, h, @materials.box_material)
          
          # Add toe kick
          if cabinet.type == :corner_base
            add_toe_kick(entities, cabinet.width + return_width / 12.0, cabinet.depth)
          end
        end
        
        # Build lazy susan corner cabinet box
        def build_lazy_susan_box(entities, cabinet, thickness)
          h = cabinet.interior_height.inch
          t = thickness.inch
          w = cabinet.width.inch
          d = cabinet.depth.inch
          
          # Bottom panel (simplified square)
          pts = [[0, 0, 0], [w, 0, 0], [w, d, 0], [0, d, 0]]
          create_simple_box(entities, pts, t, @materials.box_material)
          
          # Sides
          pts = [[0, 0, t], [t, 0, t], [t, d, t], [0, d, t]]
          create_simple_box(entities, pts, h, @materials.box_material)
          
          pts = [[0, 0, t], [w, 0, t], [w, t, t], [0, t, t]]
          create_simple_box(entities, pts, h, @materials.box_material)
          
          # Add center pole for lazy susan
          pole_diameter = Constants::CORNER[:lazy_susan_pole_diameter].inch
          pole_center = [w/2, d/2, t]
          add_cylinder(entities, pole_center, pole_diameter/2, h, @materials.hardware_material, "Lazy Susan Pole")
          
          # Add toe kick
          if cabinet.type == :corner_base
            add_toe_kick(entities, cabinet.width, cabinet.depth)
          end
        end
        
        # Build diagonal corner cabinet box
        def build_diagonal_corner_box(entities, cabinet, thickness)
          # Similar to blind corner but with angled front
          build_blind_corner_box(entities, cabinet, thickness)
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
            
            # Don't use pushpull - it causes SketchUp API bugs!
            # Instead, manually create the 3D box by extruding along the face normal
            
            # Create front face
            front_face = entities.add_face(pts)
            if front_face && front_face.valid?
              front_face.material = material if material
              
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
                back_pts = pts.map { |pt| pt.transform(Geom::Transformation.translation(offset)) }
                back_face = entities.add_face(back_pts.reverse) # Reverse for correct normal
                back_face.material = @materials.interior_material if back_face && @materials
                
                # Create side faces to close the box
                pts.each_with_index do |pt, i|
                  next_i = (i + 1) % pts.length
                  side_pts = [
                    pts[i],
                    pts[next_i],
                    back_pts[next_i],
                    back_pts[i]
                  ]
                  side_face = entities.add_face(side_pts)
                  side_face.material = material if side_face && material
                end
              end
            end
          rescue => e
            puts "Error creating box: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Add toe kick recess
        def add_toe_kick(entities, width, depth)
          kick_height = Constants::BASE_CABINET[:toe_kick_height].inch
          kick_depth = Constants::BASE_CABINET[:toe_kick_depth].inch
          thickness = Constants::BASE_CABINET[:panel_thickness].inch
          
          w = width.inch
          d = depth.inch
          
          # Create toe kick back panel (only the vertical panel at the recess depth)
          # This creates the "back wall" of the toe kick recess
          front_pts = [
            [0, kick_depth, 0],
            [w, kick_depth, 0],
            [w, kick_depth, kick_height],
            [0, kick_depth, kick_height]
          ]
          
          # Create front face
          front_face = entities.add_face(front_pts)
          if front_face && front_face.valid?
            front_face.material = @materials.box_material
            
            # Create back face (slightly behind for panel thickness)
            back_pts = front_pts.map { |pt| Geom::Point3d.new(pt.x, pt.y + thickness, pt.z) }
            back_face = entities.add_face(back_pts.reverse)
            back_face.material = @materials.box_material if back_face
            
            # Create side faces
            front_pts.each_with_index do |pt, i|
              next_i = (i + 1) % front_pts.length
              side_pts = [front_pts[i], front_pts[next_i], back_pts[next_i], back_pts[i]]
              side_face = entities.add_face(side_pts)
              side_face.material = @materials.box_material if side_face
            end
          end
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
            thickness = Constants::MIELE_DISHWASHER[:panel_thickness]
            
            width = cabinet.width
            depth = cabinet.depth
            height = cabinet.interior_height
            
            # Convert to SketchUp units
            w = width.inch
            d = depth.inch
            h = height.inch
            t = thickness.inch
            
            # Dishwasher opening (simple frame - no back or sides needed for built-in)
            # Just create a placeholder box to show space
            
            # Bottom panel group
            bottom_group = carcass_group.entities.add_group
            bottom_group.name = "Opening Marker"
            
            # Create simple outline showing dishwasher space
            pts = [[0, 0, 0], [w, 0, 0], [w, d, 0], [0, d, 0]]
            outline = bottom_group.entities.add_face(pts)
            outline.material = @materials.interior_material if outline
            
            # Add text note group
            note_group = carcass_group.entities.add_group
            note_group.name = "DW_Note"
            note_text_pts = [[t, d/2, h/2], [w-t, d/2, h/2], [w-t, d/2, h/2 + 6.inch], [t, d/2, h/2 + 6.inch]]
            note_face = note_group.entities.add_face(note_text_pts)
            note_face.material = @materials.interior_material if note_face
            
            # Toe kick (matches base cabinets)
            toe_group = carcass_group.entities.add_group
            toe_group.name = "Toe Kick"
            add_toe_kick(toe_group.entities, width, depth)
            
          rescue => e
            puts "Error building Miele dishwasher box: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Build range placeholder
        def build_range_placeholder(cabinet, carcass_group)
          begin
            width = cabinet.width
            depth = cabinet.depth
            height = cabinet.height
            
            # Convert to SketchUp units
            w = width.inch
            d = depth.inch
            h = height.inch
            t = 0.75.inch
            
            # Create placeholder box showing range space
            placeholder_group = carcass_group.entities.add_group
            placeholder_group.name = "Range Opening"
            
            # Base platform (cooktop surface)
            cooktop_height = (height - 2).inch  # 2" below top
            pts = [[0, 0, cooktop_height], [w, 0, cooktop_height], [w, d, cooktop_height], [0, d, cooktop_height]]
            cooktop = placeholder_group.entities.add_face(pts)
            if cooktop
              cooktop.material = @materials.interior_material
              cooktop.back_material = @materials.interior_material
            end
            
            # Add burners on cooktop (4 burners typical)
            burner_radius = 4.inch
            burner_height = 0.5.inch
            
            if width >= 30
              # Calculate burner positions based on range width
              margin = 4.inch
              spacing_x = (w - 2 * margin - 2 * burner_radius) / 1.0  # space between left and right
              spacing_y = (d - 2 * margin - 2 * burner_radius) / 1.0  # space between front and back
              
              burner_positions = [
                [margin + burner_radius, margin + burner_radius, cooktop_height + 0.1.inch],  # Front left
                [margin + burner_radius + spacing_x, margin + burner_radius, cooktop_height + 0.1.inch],  # Front right
                [margin + burner_radius, margin + burner_radius + spacing_y, cooktop_height + 0.1.inch],  # Back left
                [margin + burner_radius + spacing_x, margin + burner_radius + spacing_y, cooktop_height + 0.1.inch]   # Back right
              ]
              
              burner_positions.each_with_index do |pos, i|
                # Create burner group
                burner_group = placeholder_group.entities.add_group
                burner_group.name = "Burner_#{i+1}"
                
                # Outer ring (grate)
                circle_outer = burner_group.entities.add_circle(pos, [0, 0, 1], burner_radius, 32)
                if circle_outer && circle_outer.length > 0
                  face = burner_group.entities.add_face(circle_outer)
                  if face && face.valid?
                    face.material = [64, 64, 64]  # Dark gray
                    # Create ring by adding inner circle
                    circle_inner = burner_group.entities.add_circle(pos, [0, 0, 1], burner_radius * 0.6, 32)
                    inner_face = burner_group.entities.add_face(circle_inner) if circle_inner
                    inner_face.erase! if inner_face && inner_face.valid?  # Create hole
                  end
                end
              end
            end
            
            # Side markers to show range width
            left_marker = carcass_group.entities.add_group
            left_marker.name = "Left Marker"
            left_pts = [[0, 0, 0], [t, 0, 0], [t, d, 0], [0, d, 0]]
            create_simple_box(left_marker.entities, left_pts, h, @materials.interior_material)
            
            right_marker = carcass_group.entities.add_group
            right_marker.name = "Right Marker"
            right_pts = [[w-t, 0, 0], [w, 0, 0], [w, d, 0], [w-t, d, 0]]
            create_simple_box(right_marker.entities, right_pts, h, @materials.interior_material)
            
            # Note group
            note_group = carcass_group.entities.add_group
            note_group.name = "Range_Note"
            note_pts = [[t, d/2, h/2], [w-t, d/2, h/2], [w-t, d/2, h/2 + 12.inch], [t, d/2, h/2 + 12.inch]]
            note_face = note_group.entities.add_face(note_pts)
            note_face.material = @materials.interior_material if note_face
            
          rescue => e
            puts "Error building range placeholder: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Build wall stack (42" lower + two 12" stacked upper)
        def build_wall_stack_box(cabinet, carcass_group)
          begin
            width = cabinet.width
            depth = Constants::WALL_STACK[:depth]
            lower_height = Constants::WALL_STACK[:lower_height]
            upper_height = Constants::WALL_STACK[:upper_stack_height]
            stack_count = Constants::WALL_STACK[:upper_stack_count]
            reveal = Constants::WALL_STACK[:stack_reveal]
            thickness = Constants::WALL_STACK[:panel_thickness]
            
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
            
            current_z += lower_height.inch + r
            
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
              
              current_z += upper_height.inch + r
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
