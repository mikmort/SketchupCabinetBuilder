# SketchUp Cabinet Builder - LED Recess Builder
# Creates LED strip recesses in cabinet carcasses

module MikMort
  module CabinetBuilder
    module Geometry
      
      class LEDRecessBuilder
        
        # Simplified dimensions in mm (will convert to inches for SketchUp)
        EDGE_OFFSET = 19.05     # 3/4" from edge
        RECESS_WIDTH = 15.0     # 15mm wide recess
        RECESS_DEPTH = 25.0     # 25mm deep push
        SIDE_INSET = 2.0        # 2mm inset from each end
        BLOCKER_HEIGHT = 10.0   # 10mm tall light blocker
        PLACEHOLDER_SIZE = 2.0  # 2mm x 2mm light placeholder
        
        def initialize(model)
          @model = model
          @placeholder_counter = 0
          @run_name = ""
        end
        
        # Create LED recess on all cabinets in a carcass group
        # @param group [Sketchup::Group] The carcass group containing cabinet sub-groups
        # @param edge [Symbol] Which edge to add recess: :front, :back, :left, :right
        # @param run_name [String] The name of the run (for naming placeholders)
        # @return [Array<Sketchup::Group>] Array of LED recess groups created
        def create_recess(group, edge = :front, run_name = "Run")
          return nil unless group.is_a?(Sketchup::Group)
          
          @run_name = run_name
          @placeholder_counter = 0
          
          # Find all cabinet sub-groups (exclude LED Recess groups and Light groups)
          sub_groups = group.entities.grep(Sketchup::Group).reject { |g| 
            g.name.start_with?("LED Recess") || g.name.start_with?("Light")
          }
          
          carcass_entities = group.entities
          recess_groups = []
          
          if sub_groups.empty?
            # No sub-groups - the group itself contains the geometry
            puts "DEBUG: No sub-groups found, processing group directly"
            recess_group = create_recess_for_cabinet(group, group, carcass_entities, edge)
            recess_groups << recess_group if recess_group
          else
            # Process each cabinet sub-group
            puts "DEBUG: Found #{sub_groups.length} cabinet sub-groups"
            sub_groups.each_with_index do |cabinet_group, index|
              puts "DEBUG: Processing cabinet #{index + 1}: #{cabinet_group.name}"
              recess_group = create_recess_for_cabinet(cabinet_group, group, carcass_entities, edge)
              recess_groups << recess_group if recess_group
            end
          end
          
          recess_groups.first  # Return first group for compatibility
        end
        
        # Create LED recess for a single cabinet
        # @param cabinet_group [Sketchup::Group] The cabinet's geometry group
        # @param parent_group [Sketchup::Group] The parent carcass group
        # @param carcass_entities [Sketchup::Entities] Entities collection to add recess to
        # @param edge [Symbol] Which edge to add recess
        # @return [Sketchup::Group] The LED recess group
        def create_recess_for_cabinet(cabinet_group, parent_group, carcass_entities, edge)
          # Get the local bounding box of the geometry within the cabinet group
          local_bounds = get_local_bounds(cabinet_group)
          
          # Get cabinet dimensions (in local coordinates)
          local_min_z = local_bounds.min.z
          cab_width = local_bounds.max.x - local_bounds.min.x
          cab_depth = local_bounds.max.y - local_bounds.min.y
          
          # Get the cabinet's X offset (for positioning accessories)
          tr = cabinet_group.transformation
          cabinet_x_offset = tr.origin.x
          cabinet_y_offset = tr.origin.y
          world_min_z = (tr * Geom::Point3d.new(0, 0, local_min_z)).z
          
          puts "DEBUG LED Recess Cabinet: width=#{cab_width}, depth=#{cab_depth}, min_z=#{world_min_z}, x_offset=#{cabinet_x_offset}"
          
          # Convert mm to inches
          edge_offset = mm_to_inch(EDGE_OFFSET)
          recess_width = mm_to_inch(RECESS_WIDTH)
          recess_depth = mm_to_inch(RECESS_DEPTH)
          side_inset = mm_to_inch(SIDE_INSET)
          blocker_height = mm_to_inch(BLOCKER_HEIGHT)
          placeholder_size = mm_to_inch(PLACEHOLDER_SIZE)
          
          # Increment placeholder counter
          @placeholder_counter += 1
          
          # Create a group for the LED Recess components (blocker and placeholder)
          recess_group = carcass_entities.add_group
          recess_group.name = "LED Recess #{@placeholder_counter}"
          recess_entities = recess_group.entities
          
          # Create recess based on edge - pass cabinet group for finding the correct bottom face
          case edge
          when :front
            create_front_recess(cabinet_group, recess_entities, cab_width, cab_depth, world_min_z,
                               edge_offset, recess_width, recess_depth, side_inset,
                               blocker_height, placeholder_size, cabinet_x_offset, cabinet_y_offset)
          when :back
            create_back_recess(cabinet_group, recess_entities, cab_width, cab_depth, world_min_z,
                              edge_offset, recess_width, recess_depth, side_inset,
                              blocker_height, placeholder_size, cabinet_x_offset, cabinet_y_offset)
          when :left
            create_left_recess(cabinet_group, recess_entities, cab_width, cab_depth, world_min_z,
                              edge_offset, recess_width, recess_depth, side_inset,
                              blocker_height, placeholder_size, cabinet_x_offset, cabinet_y_offset)
          when :right
            create_right_recess(cabinet_group, recess_entities, cab_width, cab_depth, world_min_z,
                               edge_offset, recess_width, recess_depth, side_inset,
                               blocker_height, placeholder_size, cabinet_x_offset, cabinet_y_offset)
          end
          
          recess_group
        end
        
        private
        
        def mm_to_inch(mm)
          mm / 25.4
        end
        
        # Get the local bounding box of geometry within a group
        def get_local_bounds(group)
          bounds = Geom::BoundingBox.new
          group.entities.each do |entity|
            if entity.respond_to?(:bounds)
              bounds.add(entity.bounds)
            end
          end
          bounds
        end
        
        # Helper to split a face with a rectangle and pushpull the inner face
        # Creates a cutting box in a temp group, then explodes it to merge geometry
        def split_and_pushpull(face_entities, local_x_start, local_x_end, local_y_start, local_y_end, local_z, recess_depth, debug_name="")
          # Define rectangle points at the exact face level
          pt1 = Geom::Point3d.new(local_x_start, local_y_start, local_z)
          pt2 = Geom::Point3d.new(local_x_end, local_y_start, local_z)
          pt3 = Geom::Point3d.new(local_x_end, local_y_end, local_z)
          pt4 = Geom::Point3d.new(local_x_start, local_y_end, local_z)
          
          # Calculate expected area of our inner rectangle
          expected_area = (local_x_end - local_x_start).abs * (local_y_end - local_y_start).abs
          puts "DEBUG #{debug_name}: Expected inner face area = #{expected_area}"
          
          # Create a temporary group with just edges (not a full face)
          # When exploded, these edges will split the existing face
          temp_group = face_entities.add_group
          temp_ents = temp_group.entities
          
          # Add just the edges to the temp group
          temp_ents.add_line(pt1, pt2)
          temp_ents.add_line(pt2, pt3)
          temp_ents.add_line(pt3, pt4)
          temp_ents.add_line(pt4, pt1)
          
          puts "DEBUG #{debug_name}: Created edge rectangle in temp group"
          
          # Explode the group - this merges the edges with the existing geometry
          # and should split the coplanar face
          temp_group.explode
          
          puts "DEBUG #{debug_name}: Exploded temp group"
          
          # Now find the inner face and pushpull it
          center = Geom::Point3d.new(
            (local_x_start + local_x_end) / 2.0,
            (local_y_start + local_y_end) / 2.0,
            local_z
          )
          
          # Find the face closest to expected area that contains center
          best_face = nil
          best_area_diff = Float::INFINITY
          
          face_entities.grep(Sketchup::Face).each do |f|
            # Check if face is horizontal and at the right Z
            next unless f.normal.z.abs > 0.9
            face_z_values = f.vertices.map { |v| v.position.z }
            next unless face_z_values.all? { |z| (z - local_z).abs < 0.1 }
            
            # Check if center is inside this face
            result = f.classify_point(center)
            next if result == Sketchup::Face::PointOutside
            
            # Find face closest to expected area
            area_diff = (f.area - expected_area).abs
            if area_diff < best_area_diff
              best_area_diff = area_diff
              best_face = f
            end
          end
          
          if best_face && best_face.valid?
            puts "DEBUG #{debug_name}: Found best face, area=#{best_face.area} (expected=#{expected_area}), normal.z=#{best_face.normal.z}"
            
            # Only pushpull if area is close to expected (within 20%)
            if best_face.area < expected_area * 1.2 && best_face.area > expected_area * 0.8
              # Make sure normal points down (we want to push up into the panel)
              if best_face.normal.z > 0
                best_face.reverse!
              end
              # Push up into the panel (negative because normal points down)
              best_face.pushpull(-recess_depth)
              puts "DEBUG #{debug_name}: Pushpull completed"
              return true
            else
              puts "DEBUG #{debug_name}: Face area #{best_face.area} too different from expected #{expected_area}, skipping pushpull"
            end
          else
            puts "DEBUG #{debug_name}: Could not find face containing center after explode"
          end
          
          false
        end
        
        # Create recess along the front edge
        def create_front_recess(cabinet_group, recess_entities, cab_width, cab_depth, min_z,
                                edge_offset, recess_width, recess_depth, side_inset,
                                blocker_height, placeholder_size, cabinet_x_offset = 0, cabinet_y_offset = 0)
          
          # Recess spans cabinet width minus 2mm on each side
          recess_length = cab_width - (2 * side_inset)
          
          # LOCAL X position within the cabinet: starts 2mm (side_inset) from left edge
          local_x_start = side_inset
          local_x_end = cab_width - side_inset
          
          # LOCAL Y position within the cabinet: 3/4" from front edge
          local_y_start = edge_offset
          local_y_end = local_y_start + recess_width
          
          # World positions for accessories (blocker, placeholder)
          x_start = cabinet_x_offset + side_inset
          y_start = cabinet_y_offset + edge_offset
          
          puts "DEBUG front recess: local x=#{local_x_start}..#{local_x_end}, local y=#{local_y_start}..#{local_y_end}, world x_offset=#{cabinet_x_offset}"
          
          # Find the bottom face within this specific cabinet group
          bottom_face_result = find_bottom_face_in_group(cabinet_group)
          
          if bottom_face_result
            face, face_entities = bottom_face_result
            
            # Use local coordinates (z=0 in local space for the bottom)
            local_z = 0
            
            puts "DEBUG: Local coords for split: x=#{local_x_start}..#{local_x_end}, y=#{local_y_start}..#{local_y_end}, z=#{local_z}"
            
            split_and_pushpull(face_entities, local_x_start, local_x_end, local_y_start, local_y_end, local_z, recess_depth, "front")
          else
            puts "DEBUG: Could not find bottom face in cabinet group"
          end
          
          # Create light blocker (15mm x length x 10mm)
          # Position at top of recess (using world coordinates)
          # blocker_z is the bottom of the blocker, it extends upward into the recess
          blocker_z = min_z + recess_depth - blocker_height
          create_light_blocker(recess_entities, recess_length, blocker_height, recess_width,
                              x_start, y_start, blocker_z)
          
          # Create light placeholder (2mm x 2mm x length)
          # Position centered in recess (7.5mm in from front of recess), attached to bottom of blocker
          # Placeholder is shorter than blocker by 2mm on each side
          placeholder_length = recess_length - (2 * side_inset)
          placeholder_x_start = x_start + side_inset
          placeholder_y = y_start + (recess_width / 2.0) - (placeholder_size / 2.0)
          placeholder_z = blocker_z - placeholder_size  # Attached to bottom of light blocker
          placeholder_name = "#{@run_name} - Light Placeholder #{@placeholder_counter}"
          create_light_placeholder(recess_entities, placeholder_length, placeholder_size,
                                  placeholder_x_start, placeholder_y, placeholder_z, placeholder_name)
        end
        
        # Create recess along the back edge
        def create_back_recess(cabinet_group, recess_entities, cab_width, cab_depth, min_z,
                               edge_offset, recess_width, recess_depth, side_inset,
                               blocker_height, placeholder_size, cabinet_x_offset = 0, cabinet_y_offset = 0)
          
          recess_length = cab_width - (2 * side_inset)
          
          # LOCAL coordinates within the cabinet
          local_x_start = side_inset
          local_x_end = cab_width - side_inset
          local_y_end = cab_depth - edge_offset
          local_y_start = local_y_end - recess_width
          
          # World positions for accessories
          x_start = cabinet_x_offset + side_inset
          y_start = cabinet_y_offset + cab_depth - edge_offset - recess_width
          
          puts "DEBUG back recess: local x=#{local_x_start}..#{local_x_end}, local y=#{local_y_start}..#{local_y_end}, x_offset=#{cabinet_x_offset}"
          
          bottom_face_result = find_bottom_face_in_group(cabinet_group)
          
          if bottom_face_result
            face, face_entities = bottom_face_result
            local_z = 0
            
            split_and_pushpull(face_entities, local_x_start, local_x_end, local_y_start, local_y_end, local_z, recess_depth, "back")
          else
            puts "DEBUG: Could not find bottom face in cabinet group"
          end
          
          # Position at top of recess (using world coordinates)
          blocker_z = min_z + recess_depth - blocker_height
          create_light_blocker(recess_entities, recess_length, blocker_height, recess_width,
                              x_start, y_start, blocker_z)
          
          # Placeholder is shorter than blocker by 2mm on each side
          placeholder_length = recess_length - (2 * side_inset)
          placeholder_x_start = x_start + side_inset
          placeholder_y = y_start + (recess_width / 2.0) - (placeholder_size / 2.0)
          placeholder_z = blocker_z - placeholder_size  # Attached to bottom of light blocker
          placeholder_name = "#{@run_name} - Light Placeholder #{@placeholder_counter}"
          create_light_placeholder(recess_entities, placeholder_length, placeholder_size,
                                  placeholder_x_start, placeholder_y, placeholder_z, placeholder_name)
        end
        
        # Create recess along the left edge
        def create_left_recess(cabinet_group, recess_entities, cab_width, cab_depth, min_z,
                               edge_offset, recess_width, recess_depth, side_inset,
                               blocker_height, placeholder_size, cabinet_x_offset = 0, cabinet_y_offset = 0)
          
          recess_length = cab_depth - (2 * side_inset)
          
          # LOCAL coordinates within the cabinet
          local_y_start = side_inset
          local_y_end = cab_depth - side_inset
          local_x_start = edge_offset
          local_x_end = local_x_start + recess_width
          
          # World positions for accessories
          x_start = cabinet_x_offset + edge_offset
          y_start = cabinet_y_offset + side_inset
          
          puts "DEBUG left recess: local x=#{local_x_start}..#{local_x_end}, local y=#{local_y_start}..#{local_y_end}, x_offset=#{cabinet_x_offset}"
          
          bottom_face_result = find_bottom_face_in_group(cabinet_group)
          
          if bottom_face_result
            face, face_entities = bottom_face_result
            local_z = 0
            
            split_and_pushpull(face_entities, local_x_start, local_x_end, local_y_start, local_y_end, local_z, recess_depth, "left")
          else
            puts "DEBUG: Could not find bottom face in cabinet group"
          end
          
          # Position at top of recess (using world coordinates)
          blocker_z = min_z + recess_depth - blocker_height
          create_light_blocker_vertical(recess_entities, recess_length, blocker_height, recess_width,
                                        x_start, y_start, blocker_z)
          
          # Placeholder is shorter than blocker by 2mm on each side
          placeholder_length = recess_length - (2 * side_inset)
          placeholder_x = x_start + (recess_width / 2.0) - (placeholder_size / 2.0)
          placeholder_y_start = y_start + side_inset
          placeholder_z = blocker_z - placeholder_size  # Attached to bottom of light blocker
          placeholder_name = "#{@run_name} - Light Placeholder #{@placeholder_counter}"
          create_light_placeholder_vertical(recess_entities, placeholder_length, placeholder_size,
                                            placeholder_x, placeholder_y_start, placeholder_z, placeholder_name)
        end
        
        # Create recess along the right edge
        def create_right_recess(cabinet_group, recess_entities, cab_width, cab_depth, min_z,
                                edge_offset, recess_width, recess_depth, side_inset,
                                blocker_height, placeholder_size, cabinet_x_offset = 0, cabinet_y_offset = 0)
          
          recess_length = cab_depth - (2 * side_inset)
          
          # LOCAL coordinates within the cabinet
          local_y_start = side_inset
          local_y_end = cab_depth - side_inset
          local_x_end = cab_width - edge_offset
          local_x_start = local_x_end - recess_width
          
          # World positions for accessories
          x_start = cabinet_x_offset + cab_width - edge_offset - recess_width
          y_start = cabinet_y_offset + side_inset
          
          puts "DEBUG right recess: local x=#{local_x_start}..#{local_x_end}, local y=#{local_y_start}..#{local_y_end}, x_offset=#{cabinet_x_offset}"
          
          bottom_face_result = find_bottom_face_in_group(cabinet_group)
          
          if bottom_face_result
            face, face_entities = bottom_face_result
            local_z = 0
            
            split_and_pushpull(face_entities, local_x_start, local_x_end, local_y_start, local_y_end, local_z, recess_depth, "right")
          else
            puts "DEBUG: Could not find bottom face in cabinet group"
          end
          
          # Position at top of recess (using world coordinates)
          blocker_z = min_z + recess_depth - blocker_height
          create_light_blocker_vertical(recess_entities, recess_length, blocker_height, recess_width,
                                        x_start, y_start, blocker_z)
          
          # Placeholder is shorter than blocker by 2mm on each side
          placeholder_length = recess_length - (2 * side_inset)
          placeholder_x = x_start + (recess_width / 2.0) - (placeholder_size / 2.0)
          placeholder_y_start = y_start + side_inset
          placeholder_z = blocker_z - placeholder_size  # Attached to bottom of light blocker
          placeholder_name = "#{@run_name} - Light Placeholder #{@placeholder_counter}"
          create_light_placeholder_vertical(recess_entities, placeholder_length, placeholder_size,
                                            placeholder_x, placeholder_y_start, placeholder_z, placeholder_name)
        end
        
        # Find the bottom face within a specific cabinet group
        # Returns [face, entities] or nil
        def find_bottom_face_in_group(cabinet_group)
          puts "DEBUG find_bottom_face_in_group: searching in #{cabinet_group.name}"
          
          # Search for a downward-facing face at z=0 (local coordinates)
          cabinet_group.entities.grep(Sketchup::Face).each do |face|
            if face.normal.z < -0.9  # Normal pointing down
              # Check if any vertex is at z=0 (or very close)
              if face.vertices.any? { |v| v.position.z.abs < 0.1 }
                puts "DEBUG: Found bottom face at z=0, normal.z=#{face.normal.z}"
                return [face, cabinet_group.entities]
              end
            end
          end
          
          puts "DEBUG: No bottom face found at z=0"
          nil
        end
        
        # Find a face that is bounded by the given rectangle points
        # This finds the NEW face created by drawing edges, not the original large face
        def find_face_at_points(entities, pts, target_z)
          center = Geom::Point3d.new(
            pts.map(&:x).sum / pts.length,
            pts.map(&:y).sum / pts.length,
            target_z
          )
          
          # Calculate the expected area of our rectangle
          width = (pts[1].x - pts[0].x).abs
          depth = (pts[2].y - pts[1].y).abs
          expected_area = width * depth
          
          puts "DEBUG find_face: looking for face with area ~#{expected_area} at center (#{center.x}, #{center.y})"
          
          # Find faces at the correct Z that contain our center point
          candidates = entities.grep(Sketchup::Face).select do |face|
            at_z = face.vertices.any? { |v| (v.position.z - target_z).abs < 0.1 }
            contains_center = face.classify_point(center) != Sketchup::Face::PointOutside
            at_z && contains_center
          end
          
          puts "DEBUG find_face: found #{candidates.length} candidates"
          
          # Find the face with area closest to our expected rectangle area
          # This ensures we get the new inner face, not the large outer face
          best_face = candidates.min_by do |face|
            (face.area - expected_area).abs
          end
          
          if best_face
            puts "DEBUG find_face: selected face with area #{best_face.area} (expected #{expected_area})"
          end
          
          best_face
        end
        
        # Create the light blocker (horizontal orientation - along X axis)
        def create_light_blocker(entities, length, height, depth, x, y, z)
          blocker_group = entities.add_group
          blocker_group.name = "Light Blocker"
          blocker_entities = blocker_group.entities
          
          # Create black material
          model = Sketchup.active_model
          materials = model.materials
          black_material = materials['LED_Blocker_Black']
          unless black_material
            black_material = materials.add('LED_Blocker_Black')
            black_material.color = Sketchup::Color.new(20, 20, 20)
          end
          
          # Create box: length along X, depth along Y, height along Z
          pts = [
            Geom::Point3d.new(x, y, z),
            Geom::Point3d.new(x + length, y, z),
            Geom::Point3d.new(x + length, y + depth, z),
            Geom::Point3d.new(x, y + depth, z)
          ]
          
          face = blocker_entities.add_face(pts)
          if face && face.valid?
            face.reverse! if face.normal.z < 0
            face.pushpull(height)
          end
          
          blocker_entities.grep(Sketchup::Face).each do |f|
            f.material = black_material
            f.back_material = black_material
          end
          
          blocker_group
        end
        
        # Create the light blocker (vertical orientation - along Y axis)
        def create_light_blocker_vertical(entities, length, height, depth, x, y, z)
          blocker_group = entities.add_group
          blocker_group.name = "Light Blocker"
          blocker_entities = blocker_group.entities
          
          model = Sketchup.active_model
          materials = model.materials
          black_material = materials['LED_Blocker_Black']
          unless black_material
            black_material = materials.add('LED_Blocker_Black')
            black_material.color = Sketchup::Color.new(20, 20, 20)
          end
          
          # Create box: depth along X, length along Y, height along Z
          pts = [
            Geom::Point3d.new(x, y, z),
            Geom::Point3d.new(x + depth, y, z),
            Geom::Point3d.new(x + depth, y + length, z),
            Geom::Point3d.new(x, y + length, z)
          ]
          
          face = blocker_entities.add_face(pts)
          if face && face.valid?
            face.reverse! if face.normal.z < 0
            face.pushpull(height)
          end
          
          blocker_entities.grep(Sketchup::Face).each do |f|
            f.material = black_material
            f.back_material = black_material
          end
          
          blocker_group
        end
        
        # Create the light placeholder (horizontal - along X axis)
        def create_light_placeholder(entities, length, size, x, y, z, name = "Light Placeholder")
          placeholder_group = entities.add_group
          placeholder_group.name = name
          placeholder_entities = placeholder_group.entities
          
          # Create white material
          model = Sketchup.active_model
          materials = model.materials
          white_material = materials['LED_Light_Placeholder']
          unless white_material
            white_material = materials.add('LED_Light_Placeholder')
            white_material.color = Sketchup::Color.new(255, 255, 240)
          end
          
          # Create box: length along X, size along Y, size along Z
          pts = [
            Geom::Point3d.new(x, y, z),
            Geom::Point3d.new(x + length, y, z),
            Geom::Point3d.new(x + length, y + size, z),
            Geom::Point3d.new(x, y + size, z)
          ]
          
          face = placeholder_entities.add_face(pts)
          if face && face.valid?
            face.reverse! if face.normal.z < 0
            face.pushpull(size)
          end
          
          placeholder_entities.grep(Sketchup::Face).each do |f|
            f.material = white_material
            f.back_material = white_material
          end
          
          placeholder_group
        end
        
        # Create the light placeholder (vertical - along Y axis)
        def create_light_placeholder_vertical(entities, length, size, x, y, z, name = "Light Placeholder")
          placeholder_group = entities.add_group
          placeholder_group.name = name
          placeholder_entities = placeholder_group.entities
          
          model = Sketchup.active_model
          materials = model.materials
          white_material = materials['LED_Light_Placeholder']
          unless white_material
            white_material = materials.add('LED_Light_Placeholder')
            white_material.color = Sketchup::Color.new(255, 255, 240)
          end
          
          # Create box: size along X, length along Y, size along Z
          pts = [
            Geom::Point3d.new(x, y, z),
            Geom::Point3d.new(x + size, y, z),
            Geom::Point3d.new(x + size, y + length, z),
            Geom::Point3d.new(x, y + length, z)
          ]
          
          face = placeholder_entities.add_face(pts)
          if face && face.valid?
            face.reverse! if face.normal.z < 0
            face.pushpull(size)
          end
          
          placeholder_entities.grep(Sketchup::Face).each do |f|
            f.material = white_material
            f.back_material = white_material
          end
          
          placeholder_group
        end
        
      end
      
    end
  end
end
