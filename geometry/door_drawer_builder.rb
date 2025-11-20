# SketchUp Cabinet Builder - Door and Drawer Builder
# Generates doors and drawers with proper spacing and hardware

module MikMort
  module CabinetBuilder
    module Geometry
      
      class DoorDrawerBuilder
        
        def initialize(model, material_manager)
          @model = model
          @materials = material_manager
        end
        
        # Build doors and/or drawers based on cabinet configuration
        # @param cabinet [Cabinet] The cabinet specification
        # @param fronts_group [Sketchup::Group] Fronts group for door/drawer faces
        # @param hardware_group [Sketchup::Group] Hardware group for handles/pulls
        # @return [Array<Sketchup::Group>] Array of door/drawer groups
        def build(cabinet, fronts_group, hardware_group)
          begin
            # Special handling for wall stack - create doors for each section
            if cabinet.type == :wall_stack || cabinet.type == :wall_stack_9ft
              build_wall_stack_doors(cabinet, fronts_group, hardware_group)
              return
            end
            
            config_sections = cabinet.parse_config
            
            # Calculate available height for doors/drawers
            available_height = cabinet.interior_height
            
            # Account for frame if framed cabinet
            frame_offset = cabinet.frame_type == :framed ? Constants::FRAME[:width] : 0

            toe_kick_offset = toe_kick_base_offset(cabinet)
            current_z = frame_offset + toe_kick_offset
            
            config_sections.each do |section|
              section_height = available_height * section[:ratio]
              
              if section[:type] == :drawer
                equal_sizing = section[:equal_sizing] || false
                build_drawers(fronts_group, hardware_group, cabinet, section[:count], current_z, section_height, equal_sizing)
              else
                door_count = door_count_for_section(cabinet, section[:count])
                build_doors(fronts_group, hardware_group, cabinet, door_count, current_z, section_height)
              end
              
              current_z += section_height
            end
          rescue => e
            puts "Error building doors/drawers: #{e.message}"
            puts e.backtrace.first(5).join("\n")
          end
        end
        
        private
        
        # Build doors for wall stack (42" lower + stacked upper)
        def build_wall_stack_doors(cabinet, fronts_group, hardware_group)
          # Get configuration based on type
          config = cabinet.type == :wall_stack_9ft ? Constants::WALL_STACK_9FT : Constants::WALL_STACK
          
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          
          lower_height = config[:lower_height]
          upper_height = config[:upper_stack_height]
          stack_count = config[:upper_stack_count]
          stack_reveal = config[:stack_reveal].inch
          
          width = cabinet.width.inch
          door_count = door_count_for_section(cabinet)
          
          current_z = 0
          
          # Lower 42" doors
          build_doors(fronts_group, hardware_group, cabinet, door_count, current_z, lower_height)
          
          current_z += lower_height + (stack_reveal / 1.inch)
          
          # Stacked 12" doors (two separate units)
          stack_count.times do |i|
            build_doors(fronts_group, hardware_group, cabinet, door_count, current_z, upper_height)
            current_z += upper_height + (stack_reveal / 1.inch)
          end
        end
        
        # Build doors
        def build_doors(fronts_group, hardware_group, cabinet, door_count, start_z, total_height)
          return if door_count.nil? || door_count <= 0
          door_count = door_count.to_i
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          frameless_overlay = cabinet.frame_type == :frameless ? Constants::DOOR_DRAWER[:frameless_overlay].inch : 0
          center_reveal = reveal
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          overlay = cabinet.frame_type == :framed ? Constants::DOOR_DRAWER[:overlay].inch : 0
          
          width = cabinet.width.inch
          depth = cabinet.depth.inch
          
          # Available width adjustments based on frame type
          if cabinet.frame_type == :frameless
            width_available = width + (2 * frameless_overlay)
            edge_start = -frameless_overlay
          else
            width_available = width - (2 * reveal)
            edge_start = reveal
          end
          total_center_spacing = center_reveal * [door_count - 1, 0].max
          door_width = (width_available - total_center_spacing) / door_count
          door_height = total_height.inch - (2 * reveal)
          
          # Position doors flush with cabinet box front
          # Door face is at y = 0 (flush with cabinet front)
          # Door thickness extends backward into cabinet (negative Y direction)
          door_z = start_z.inch + reveal
          door_y = 0  # Door face flush with cabinet front
          
          # Create each door in its own named group
          (0...door_count).each do |i|
            door_x = edge_start + (i * (door_width + center_reveal))
            
            # Create door group with descriptive name
            door_group = fronts_group.entities.add_group
            door_name = door_count == 1 ? "Door" : "Door #{i + 1}"
            door_group.name = door_name
            
            # Create door panel in door group
            create_door_panel(door_group.entities, 
                            [door_x, door_y, door_z],
                            door_width, thickness, door_height,
                            @materials.door_face_material)
            
            # Add hardware to hardware group
            handle_side = door_handle_side(i, door_count)
            add_door_handle(hardware_group.entities, door_x, door_y, door_z, 
                           door_width, door_height, thickness, handle_side)
          end
        end

        def door_handle_side(index, door_count)
          return :right if door_count == 1
          index.even? ? :right : :left
        end

        def door_count_for_section(cabinet, requested_count = nil)
          return requested_count if requested_count && requested_count > 0
          width = cabinet.width || Constants::STANDARD_WIDTHS.min
          return 1 if width < 24
          2
        end
        
        # Build drawers
        def build_drawers(fronts_group, hardware_group, cabinet, drawer_count, start_z, total_height, equal_sizing = false)
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          frameless_overlay = cabinet.frame_type == :frameless ? Constants::DOOR_DRAWER[:frameless_overlay].inch : 0
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          overlay = cabinet.frame_type == :framed ? Constants::DOOR_DRAWER[:overlay].inch : 0
          
          width = cabinet.width.inch
          depth = cabinet.depth.inch
          
          # Calculate individual drawer heights
          drawer_heights = calculate_drawer_heights(drawer_count, total_height, equal_sizing)
          
          current_z = start_z
          
          drawer_heights.each_with_index do |drawer_height, i|
            # drawer_height is already in inches (as a number)
            # start_z and current_z are also in inches (as numbers)
            
            # Create drawer front directly in parent (NO sub-group)
            if cabinet.frame_type == :frameless
              drawer_x = -frameless_overlay
              drawer_width = width + (2 * frameless_overlay)
            else
              drawer_x = reveal
              drawer_width = width - (2 * reveal)
            end
            drawer_y = 0  # Drawer face flush with cabinet front
            drawer_z = current_z.inch + reveal
            
            # Subtract reveals from height (drawer_height is in inches as a number)
            actual_drawer_height = drawer_height.inch - (2 * reveal)
            
            puts "DEBUG: Creating drawer #{i+1}: pos=[#{drawer_x}, #{drawer_y}, #{drawer_z}], size=[#{drawer_width}, #{thickness}, #{actual_drawer_height}]"
            
            # Drawer face in fronts group
            result = create_door_panel(fronts_group.entities,
                            [drawer_x, drawer_y, drawer_z],
                            drawer_width, thickness, actual_drawer_height,
                            @materials.drawer_face_material)
            
            puts "DEBUG: Drawer face created: #{result ? 'success' : 'FAILED'}"
            
            # Add drawer box to fronts group (behind the face)
            add_drawer_box(fronts_group.entities, drawer_x, drawer_y + thickness,
                          drawer_z, drawer_width, depth * 0.75, actual_drawer_height)
            
            # Add drawer pull to hardware group
            add_drawer_handle(hardware_group.entities, drawer_x, drawer_y, drawer_z,
                            drawer_width, actual_drawer_height, thickness)
            
            # Add drawer slides to fronts group
            add_drawer_slides(fronts_group.entities, drawer_x, drawer_y + thickness,
                            drawer_z, drawer_width, depth * 0.75, actual_drawer_height)
            
            # Move to next drawer position (drawer_height is in inches)
            current_z += drawer_height
          end
        end
        
        # Calculate graduated drawer heights
        def calculate_drawer_heights(count, total_height, equal_sizing = false)
          heights = []
          
          puts "DEBUG: calculate_drawer_heights - count=#{count}, total_height=#{total_height}, equal_sizing=#{equal_sizing.inspect} (class: #{equal_sizing.class})"
          
          # Check equal_sizing flag FIRST
          if equal_sizing
            # Equal distribution
            puts "DEBUG: Using EQUAL sizing"
            heights = Array.new(count, total_height / count.to_f)
          else
            # Use graduated sizing (smaller on top, larger on bottom)
            puts "DEBUG: Using GRADUATED sizing"
            case count
            when 1
              heights = [total_height]
            when 2
              heights = [total_height * 0.45, total_height * 0.55]
            when 3
              heights = [total_height * 0.25, total_height * 0.30, total_height * 0.45]
            when 4
              heights = [total_height * 0.20, total_height * 0.25, total_height * 0.25, total_height * 0.30]
            when 5
              heights = [total_height * 0.15, total_height * 0.18, total_height * 0.20, total_height * 0.22, total_height * 0.25]
            else
              # Equal distribution for 6+ drawers
              heights = Array.new(count, total_height / count.to_f)
            end
          end
          
          heights
        end
        
        # Create a door/drawer face panel
        # IMPORTANT: Don't use pushpull - it causes SketchUp to delete parent groups!
        def create_door_panel(entities, origin, width, thickness, height, material)
          x, y, z = origin
          
          # Skip if dimensions are invalid
          return nil if width.abs < 0.001 || height.abs < 0.001 || thickness.abs < 0.001
          
          begin
            # Create a 3D box manually without pushpull (to avoid SketchUp bug)
            # Front face
            front_pts = [
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x + width, y, z),
              Geom::Point3d.new(x + width, y, z + height),
              Geom::Point3d.new(x, y, z + height)
            ]
            front_face = entities.add_face(front_pts)
            front_face.material = material if front_face && material
            
            # Back face (offset by thickness)
            back_y = y - thickness
            back_pts = [
              Geom::Point3d.new(x, back_y, z),
              Geom::Point3d.new(x, back_y, z + height),
              Geom::Point3d.new(x + width, back_y, z + height),
              Geom::Point3d.new(x + width, back_y, z)
            ]
            back_face = entities.add_face(back_pts)
            back_face.material = @materials.interior_material if back_face
            
            # Side faces to close the box
            # Left side
            entities.add_face([
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x, y, z + height),
              Geom::Point3d.new(x, back_y, z + height),
              Geom::Point3d.new(x, back_y, z)
            ])
            
            # Right side
            entities.add_face([
              Geom::Point3d.new(x + width, y, z),
              Geom::Point3d.new(x + width, back_y, z),
              Geom::Point3d.new(x + width, back_y, z + height),
              Geom::Point3d.new(x + width, y, z + height)
            ])
            
            # Top edge
            entities.add_face([
              Geom::Point3d.new(x, y, z + height),
              Geom::Point3d.new(x + width, y, z + height),
              Geom::Point3d.new(x + width, back_y, z + height),
              Geom::Point3d.new(x, back_y, z + height)
            ])
            
            # Bottom edge
            entities.add_face([
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x, back_y, z),
              Geom::Point3d.new(x + width, back_y, z),
              Geom::Point3d.new(x + width, y, z)
            ])
            
            front_face
          rescue => e
            puts "Error creating door panel: #{e.message}"
            nil
          end
        end

        def toe_kick_base_offset(cabinet)
          case cabinet.type
          when :base, :island, :corner_base
            Constants::BASE_CABINET[:toe_kick_height].inch
          when :miele_dishwasher
            Constants::MIELE_DISHWASHER[:toe_kick_height].inch
          else
            0
          end
        end
        
        # Add hinges to a door
        def add_hinges(entities, door_x, door_y, door_z, door_height, side)
          hinge_width = Constants::DOOR_DRAWER[:hinge_width].inch
          hinge_height = Constants::DOOR_DRAWER[:hinge_height].inch
          
          # Place hinges at top and bottom (offset from edges)
          hinge_positions = [
            door_z + 3.inch,                    # Top hinge
            door_z + door_height - 3.inch       # Bottom hinge
          ]
          
          # Add middle hinge if door is tall
          if door_height > 36.inch
            hinge_positions.insert(1, door_z + door_height / 2)
          end
          
          hinge_positions.each_with_index do |z_pos, i|
            x_pos = side == :left ? door_x - 0.25.inch : door_x + hinge_width + 0.25.inch
            
            # Simplified hinge representation (small cylinder + plate)
            add_hinge(entities, x_pos, door_y, z_pos, side)
          end
        end
        
        # Add a single hinge
        def add_hinge(entities, x, y, z, side)
          # DISABLED: pushpull operations delete parent groups
          return
          begin
            hinge_height = Constants::DOOR_DRAWER[:hinge_height].inch
            
            # Cylinder for hinge pin
            center = Geom::Point3d.new(x, y, z + hinge_height / 2)
            circle = entities.add_circle(center, [1, 0, 0], 0.25.inch, 12)
            if circle && circle.length > 0
              face = entities.add_face(circle)
              if face && face.valid?
                face.material = @materials.hardware_material
                face.pushpull(1.inch)
              end
            end
          rescue => e
            puts "Error creating hinge: #{e.message}"
          end
        end
        
        # Add door handle
        def add_door_handle(entities, door_x, door_y, door_z, door_width, door_height, door_thickness, side)
          begin
            # Create small marker cube for hardware placement
            marker_size = 0.5.inch
            
            # Position marker
            handle_z = door_z + door_height / 2 - marker_size / 2
            handle_x = side == :left ? door_x + 2.inch : door_x + door_width - 2.inch - marker_size
            handle_y = door_y - marker_size
            
            # Create marker cube
            pts = [
              Geom::Point3d.new(handle_x, handle_y, handle_z),
              Geom::Point3d.new(handle_x + marker_size, handle_y, handle_z),
              Geom::Point3d.new(handle_x + marker_size, handle_y, handle_z + marker_size),
              Geom::Point3d.new(handle_x, handle_y, handle_z + marker_size)
            ]
            
            front_face = entities.add_face(pts)
            if front_face && front_face.valid?
              front_face.material = @materials.hardware_material
              
              # Create back face
              back_y = handle_y - marker_size
              back_pts = [
                Geom::Point3d.new(handle_x, back_y, handle_z),
                Geom::Point3d.new(handle_x, back_y, handle_z + marker_size),
                Geom::Point3d.new(handle_x + marker_size, back_y, handle_z + marker_size),
                Geom::Point3d.new(handle_x + marker_size, back_y, handle_z)
              ]
              entities.add_face(back_pts)
              
              # Create side faces
              entities.add_face([pts[0], pts[1], back_pts[3], back_pts[0]])
              entities.add_face([pts[1], pts[2], back_pts[2], back_pts[3]])
              entities.add_face([pts[2], pts[3], back_pts[1], back_pts[2]])
              entities.add_face([pts[3], pts[0], back_pts[0], back_pts[1]])
            end
          rescue => e
            puts "Error creating door handle marker: #{e.message}"
          end
        end
        
        # Add drawer handle
        def add_drawer_handle(entities, drawer_x, drawer_y, drawer_z, drawer_width, drawer_height, drawer_thickness)
          begin
            # Create small marker cube for hardware placement
            marker_size = 0.5.inch
            
            # Position marker at center top of drawer
            handle_x = drawer_x + drawer_width / 2 - marker_size / 2
            handle_y = drawer_y - marker_size
            handle_z = drawer_z + drawer_height - 2.inch - marker_size / 2
            
            # Create marker cube
            pts = [
              Geom::Point3d.new(handle_x, handle_y, handle_z),
              Geom::Point3d.new(handle_x + marker_size, handle_y, handle_z),
              Geom::Point3d.new(handle_x + marker_size, handle_y, handle_z + marker_size),
              Geom::Point3d.new(handle_x, handle_y, handle_z + marker_size)
            ]
            
            front_face = entities.add_face(pts)
            if front_face && front_face.valid?
              front_face.material = @materials.hardware_material
              
              # Create back face
              back_y = handle_y - marker_size
              back_pts = [
                Geom::Point3d.new(handle_x, back_y, handle_z),
                Geom::Point3d.new(handle_x, back_y, handle_z + marker_size),
                Geom::Point3d.new(handle_x + marker_size, back_y, handle_z + marker_size),
                Geom::Point3d.new(handle_x + marker_size, back_y, handle_z)
              ]
              entities.add_face(back_pts)
              
              # Create side faces
              entities.add_face([pts[0], pts[1], back_pts[3], back_pts[0]])
              entities.add_face([pts[1], pts[2], back_pts[2], back_pts[3]])
              entities.add_face([pts[2], pts[3], back_pts[1], back_pts[2]])
              entities.add_face([pts[3], pts[0], back_pts[0], back_pts[1]])
            end
          rescue => e
            puts "Error creating drawer handle marker: #{e.message}"
          end
        end
        
        # Add simplified drawer box (DISABLED - uses pushpull)
        def add_drawer_box(entities, x, y, z, width, depth, height)
          # DISABLED: pushpull operations delete parent groups
          return
          begin
            box_thickness = 0.5.inch
            
            # Bottom
            pts = [
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x + width, y, z),
              Geom::Point3d.new(x + width, y + depth, z),
              Geom::Point3d.new(x, y + depth, z)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.interior_material
              face.pushpull(box_thickness)
            end
            
            # Sides (simplified)
            # Left side
            pts = [
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x, y + depth, z),
              Geom::Point3d.new(x, y + depth, z + height),
              Geom::Point3d.new(x, y, z + height)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.interior_material
              face.pushpull(box_thickness)
            end
            
            # Right side
            pts = [
              Geom::Point3d.new(x + width - box_thickness, y, z),
              Geom::Point3d.new(x + width - box_thickness, y + depth, z),
              Geom::Point3d.new(x + width - box_thickness, y + depth, z + height),
              Geom::Point3d.new(x + width - box_thickness, y, z + height)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.interior_material
              face.pushpull(box_thickness)
            end
          rescue => e
            puts "Error creating drawer box: #{e.message}"
          end
        end
        
        # Add simplified drawer slides
        def add_drawer_slides(entities, x, y, z, width, depth, height)
          begin
            slide_height = 0.5.inch
            slide_thickness = 0.125.inch
            
            # Left slide
            pts = [
              Geom::Point3d.new(x, y, z + height/2 - slide_height/2),
              Geom::Point3d.new(x, y + depth, z + height/2 - slide_height/2),
              Geom::Point3d.new(x, y + depth, z + height/2 + slide_height/2),
              Geom::Point3d.new(x, y, z + height/2 + slide_height/2)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.hardware_material
              face.pushpull(-slide_thickness)
            end
            
            # Right slide
            pts = [
              Geom::Point3d.new(x + width, y, z + height/2 - slide_height/2),
              Geom::Point3d.new(x + width, y + depth, z + height/2 - slide_height/2),
              Geom::Point3d.new(x + width, y + depth, z + height/2 + slide_height/2),
              Geom::Point3d.new(x + width, y, z + height/2 + slide_height/2)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.hardware_material
              face.pushpull(-slide_thickness)
            end
          rescue => e
            puts "Error creating drawer slides: #{e.message}"
          end
        end
        
      end
      
    end
  end
end
