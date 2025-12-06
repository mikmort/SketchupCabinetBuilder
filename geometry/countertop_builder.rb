# SketchUp Cabinet Builder - Countertop Builder
# Generates countertops and backsplashes

module MikMort
  module CabinetBuilder
    module Geometry
      
      class CountertopBuilder
        
        def initialize(model, material_manager)
          @model = model
          @materials = material_manager
        end
        
        # Build countertop for a single cabinet or cabinet run
        # @param cabinet [Cabinet, Array<Cabinet>] Single cabinet or array of cabinets
        # @param parent_group [Sketchup::Group] Parent group (the Countertop group)
        # @param options [Hash] Additional options (seating_side, etc.)
        # @return [Sketchup::Group] The countertop group
        def build(cabinet, parent_group, options = {})
          # parent_group is already the "Countertop" group
          # Build directly in it and create backsplash subgroup if needed
          
          if cabinet.is_a?(Array)
            build_continuous_countertop(cabinet, parent_group, options)
          else
            build_single_countertop(cabinet, parent_group, options)
          end
          
          parent_group
        end
        
        # Build countertop and backsplash into separate groups
        # Used by the new run-based system
        def build_separate(cabinet, countertop_group, backsplash_group, options = {})
          if cabinet.is_a?(Array)
            build_continuous_separate(cabinet, countertop_group, backsplash_group, options)
          else
            build_single_separate(cabinet, countertop_group, backsplash_group, options)
          end
        end
        
        private
        
        # Build single cabinet countertop into separate groups
        def build_single_separate(cabinet, countertop_group, backsplash_group, options)
          # Handle corner cabinets specially
          if cabinet.type == :corner_base || cabinet.type == :corner_wall
            build_corner_countertop_separate(cabinet, countertop_group, backsplash_group, options)
            return
          end
          
          front_overhang = countertop_overhang(:overhang_front)
          side_overhang = options[:add_side_overhang] ? countertop_overhang(:overhang_side) : 0
          back_overhang = countertop_overhang(:overhang_back)
          base_depth = cabinet_depth_value(cabinet)

          width = cabinet.width + (2 * side_overhang)
          depth = base_depth + front_overhang + back_overhang
          thickness = Constants::COUNTERTOP[:thickness]
          cabinet_height = cabinet.height || Constants::BASE_CABINET[:height]
          
          if cabinet.type == :island && cabinet.has_seating_side
            depth += Constants::ISLAND_CABINET[:seating_overhang]
          end
          
          w = width.inch
          d = depth.inch
          t = thickness.inch
          
          start_x = -side_overhang.inch
          start_y = -front_overhang.inch
          start_z = cabinet_height.inch
          
          # Create countertop slab
          create_countertop_slab(countertop_group.entities, start_x, start_y, start_z, w, d, t)
          
          # Create backsplash if needed
          if cabinet.has_backsplash
            backsplash_height = Constants::COUNTERTOP[:backsplash_height].inch
            backsplash_y = start_y + d - back_overhang.inch
            backsplash_z = start_z + t
            create_backsplash(backsplash_group.entities, start_x, backsplash_y, backsplash_z, 
                            w, backsplash_height, t)
          end
        end
        
        # Build L-shaped countertop for corner cabinets
        def build_corner_countertop_separate(cabinet, countertop_group, backsplash_group, options)
          front_overhang = countertop_overhang(:overhang_front)
          thickness = Constants::COUNTERTOP[:thickness]
          cabinet_height = cabinet.height || Constants::BASE_CABINET[:height]
          
          # Get corner size from corner_type
          corner_size = case cabinet.corner_type
          when :inside_36, :outside_36 then 36.0
          when :inside_24, :outside_24 then 24.0
          else 36.0
          end
          
          t = thickness.inch
          start_z = cabinet_height.inch
          fo = front_overhang.inch
          
          # Shift Y is only for INSIDE corners to align with the recessed back
          # Outside corners are aligned at Y=0
          shift_y = cabinet.corner_type.to_s.include?('outside') ? 0.inch : -12.inch
          
          entities = countertop_group.entities
          material = @materials.countertop_material
          size = corner_size.inch
          cutout = 12.inch

          if cabinet.corner_type.to_s.include?('outside')
            # OUTSIDE CORNER COUNTERTOP (L-shape wrapping around a wall)
            # Matches the carcass footprint:
            # - Main Run: X=0..36, Y=0..24
            # - Return Run: X=12..36, Y=24..36
            # - Empty Space (Wall): X=0..12, Y=24..36
            
            l_pts = [
              Geom::Point3d.new(0, 0 + shift_y - fo, start_z),                   # 1. Front-Left (Overhang)
              Geom::Point3d.new(0, 24.inch + shift_y, start_z),                  # 2. Left-Back (Connects to Left Run)
              Geom::Point3d.new(12.inch, 24.inch + shift_y, start_z),            # 3. Inner Corner (Wall Corner)
              Geom::Point3d.new(12.inch, size + shift_y, start_z),               # 4. Back-Inner (Connects to Back Run)
              Geom::Point3d.new(size + fo, size + shift_y, start_z),             # 5. Back-Right (Overhang)
              Geom::Point3d.new(size + fo, 0 + shift_y - fo, start_z)            # 6. Front-Right (Overhang)
            ]
            
            face = entities.add_face(l_pts)
            if face && face.valid?
              face.reverse! if face.normal.z < 0
              face.material = material
              face.pushpull(t)
            end
            
            # Apply countertop material to all faces (front and back)
            entities.grep(Sketchup::Face).each do |f|
              if f.valid?
                f.material = material
                f.back_material = material
              end
            end
            
            if cabinet.has_backsplash
              bs_height = Constants::COUNTERTOP[:backsplash_height].inch
              bs_z = start_z + t
              bs_thick = 1.5.inch
              
              # Backsplash 1: Along Y=24 wall (from X=0 to 12)
              pts_bs1 = [
                Geom::Point3d.new(0, 24.inch + shift_y, bs_z),
                Geom::Point3d.new(12.inch, 24.inch + shift_y, bs_z),
                Geom::Point3d.new(12.inch, 24.inch + shift_y, bs_z + bs_height),
                Geom::Point3d.new(0, 24.inch + shift_y, bs_z + bs_height)
              ]
              f_bs1 = entities.add_face(pts_bs1)
              if f_bs1 && f_bs1.valid?
                f_bs1.material = material
                f_bs1.back_material = material
                f_bs1.pushpull(-bs_thick) # Pull towards front (-Y)
              end
              
              # Backsplash 2: Along X=12 wall (from Y=24 to 36)
              # Ensure points are ordered to create a face with normal pointing towards +X (into the room)
              pts_bs2 = [
                Geom::Point3d.new(12.inch, 24.inch + shift_y, bs_z),
                Geom::Point3d.new(12.inch, size + shift_y, bs_z),
                Geom::Point3d.new(12.inch, size + shift_y, bs_z + bs_height),
                Geom::Point3d.new(12.inch, 24.inch + shift_y, bs_z + bs_height)
              ]
              f_bs2 = entities.add_face(pts_bs2)
              if f_bs2 && f_bs2.valid?
                # Ensure normal points to +X
                f_bs2.reverse! if f_bs2.normal.x < 0
                
                f_bs2.material = material
                f_bs2.back_material = material # Apply to both sides to be safe
                f_bs2.pushpull(bs_thick) # Pull towards right (+X)
              end
            end
            
            return # Done with outside corner
          end

          # TRUE L-SHAPED corner countertop
          # 36" x 36" footprint with 24" x 24" cutout at front-right corner
          # Same shape as the cabinet box
          
          # L-shaped countertop with overhangs on exposed edges
          # Cutout at Front-Left (X=0..12, Y=0..12)
          # No overhang on sides connecting to neighbors (X=0, Y=12..36) and (X=36, Y=0..36)?
          # Wait, if connecting to neighbors:
          # - Left side (X=0, Y=12..36) connects to Left Run. No overhang.
          # - Right side (X=36, Y=0..36) connects to Right Run? Or Wall?
          # If Right Run is along Right Wall, then X=36 is against wall? No, X=36 is Right side of cabinet.
          # If Right Run is along Right Wall, it connects to the FRONT of the Right Leg? No.
          # Usually corner cabinet connects to runs on both sides.
          # So X=0 (Back Leg Left Side) connects to Left Run.
          # Y=0 (Right Leg Front Side) connects to Right Run? No, Right Run is along Right Wall.
          # So Right Run connects to X=36? No.
          # Right Run is perpendicular. It runs along X=something.
          # If Right Run is along Right Wall (X=36+24?), then it connects to X=36 side of corner cabinet.
          # So X=36 side connects to Right Run. No overhang.
          
          # Overhangs needed at:
          # - Inner Face 1 (Y=0, X=0..12)
          # - Inner Face 2 (X=12, Y=-12..0)
          
          # Add 0.75" overhang to the Right Leg Front (Y=-12)
          # This makes the countertop edge at Y = -12.75
          # Carcass is at Y = -12.
          # Overhang = 0.75".
          
          # Also add overhang to the Right Leg Side (X=12)
          # Door is at X=11.25.
          # Overhang should be 0.75" from door face?
          # X = 11.25 - 0.75 = 10.5.
          
          l_pts = [
            Geom::Point3d.new(0, cutout + shift_y - fo, start_z),              # 1. Left edge, front (overhang)
            Geom::Point3d.new(cutout - fo, cutout + shift_y - fo, start_z),    # 2. Inner corner (overhang intersection)
            Geom::Point3d.new(cutout - 1.5.inch, 0 + shift_y - 0.75.inch, start_z),  # 3. Front edge, left (Overhang 1.5" from X=12)
            Geom::Point3d.new(size, 0 + shift_y - 0.75.inch, start_z),         # 4. Front-Right (Overhang 0.75")
            Geom::Point3d.new(size, size + shift_y, start_z),                  # 5. Back-Right
            Geom::Point3d.new(0, size + shift_y, start_z)                      # 6. Back-Left
          ]
          
          face = entities.add_face(l_pts)
          if face && face.valid?
            face.reverse! if face.normal.z < 0
            face.material = material
            face.pushpull(t)
          end
          
          # Apply countertop material to all faces (front and back)
          entities.grep(Sketchup::Face).each do |f|
            if f.valid?
              f.material = material
              f.back_material = material
            end
          end
          
          # Create L-shaped backsplash along both back walls
          if cabinet.has_backsplash
            backsplash_height = Constants::COUNTERTOP[:backsplash_height].inch
            backsplash_z = start_z + t
            bs_entities = backsplash_group.entities
            bs_thickness = 1.5.inch
            
            # Backsplash along back wall (at Y=36", full width)
            # Starts at X=0 (connecting to left run)
            pts1 = [
              Geom::Point3d.new(0, size + shift_y, backsplash_z),
              Geom::Point3d.new(size, size + shift_y, backsplash_z),
              Geom::Point3d.new(size, size + shift_y, backsplash_z + backsplash_height),
              Geom::Point3d.new(0, size + shift_y, backsplash_z + backsplash_height)
            ]
            bs_face1 = bs_entities.add_face(pts1)
            if bs_face1 && bs_face1.valid?
              bs_face1.material = material
              # Normal is -Y (Front). Pushpull positive to go Front (onto the countertop).
              bs_face1.pushpull(bs_thickness)
            end
            
            # Backsplash along right wall (at X=36", full depth)
            # Should extend to front edge of countertop (Flush, no overhang)
            bs_start_y = 0 + shift_y - 0.75.inch
            
            pts2 = [
              Geom::Point3d.new(size, bs_start_y, backsplash_z),
              Geom::Point3d.new(size, size + shift_y, backsplash_z),
              Geom::Point3d.new(size, size + shift_y, backsplash_z + backsplash_height),
              Geom::Point3d.new(size, bs_start_y, backsplash_z + backsplash_height)
            ]
            bs_face2 = bs_entities.add_face(pts2)
            if bs_face2 && bs_face2.valid?
              bs_face2.material = material
              # Normal is +X (Right). Pushpull negative to go Left (onto the countertop).
              bs_face2.pushpull(-bs_thickness)
            end
            
            # Apply countertop material to all backsplash faces (front and back)
            bs_entities.grep(Sketchup::Face).each do |f|
              if f.valid?
                f.material = material
                f.back_material = material
              end
            end
          end
        end
        
        # Build continuous countertop for multiple cabinets into separate groups
        def build_continuous_separate(cabinets, countertop_group, backsplash_group, options)
          return if cabinets.empty?
          
          # For now, build each cabinet separately
          # TODO: Create actual continuous countertop
          cabinets.each do |cabinet|
            build_single_separate(cabinet, countertop_group, backsplash_group, options)
          end
        end
        
        # Build countertop for a single cabinet
        def build_single_countertop(cabinet, countertop_group, options)
          entities = countertop_group.entities
          
          front_overhang = countertop_overhang(:overhang_front)
          side_overhang = options[:add_side_overhang] ? countertop_overhang(:overhang_side) : 0
          back_overhang = countertop_overhang(:overhang_back)
          base_depth = cabinet_depth_value(cabinet)

          # Calculate dimensions
          width = cabinet.width + (2 * side_overhang)
          depth = base_depth + front_overhang + back_overhang
          thickness = Constants::COUNTERTOP[:thickness]
          cabinet_height = cabinet.height || Constants::BASE_CABINET[:height]  # Total height, not interior
          
          # Adjust for island with seating
          if cabinet.type == :island && cabinet.has_seating_side
            # Add extra overhang on one side
            depth += Constants::ISLAND_CABINET[:seating_overhang]
          end
          
          # Convert to inches
          w = width.inch
          d = depth.inch
          t = thickness.inch
          h = cabinet_height.inch
          
          # Starting position (account for side overhang)
          start_x = -side_overhang.inch
          start_y = -front_overhang.inch
          # Place countertop on top of full cabinet height (toe kick included)
          start_z = cabinet_height.inch
          
          # Create countertop slab directly in countertop group
          create_countertop_slab(entities, start_x, start_y, start_z, w, d, t)
          
          # Add backsplash as subgroup if needed
          if cabinet.has_backsplash
            backsplash_height = Constants::COUNTERTOP[:backsplash_height].inch
            
            # Backsplash position (at back edge of countertop)
            backsplash_y = start_y + d - back_overhang.inch
            backsplash_z = start_z + t
            
            # Create backsplash subgroup within countertop group
            backsplash_group = countertop_group.entities.add_group
            backsplash_group.name = "Backsplash"
            create_backsplash(backsplash_group.entities, start_x, backsplash_y, backsplash_z, 
                            w, backsplash_height, t)
          end
        end
        
        # Build continuous countertop spanning multiple cabinets
        def build_continuous_countertop(cabinets, countertop_group, options)
          return if cabinets.empty?
          
          entities = countertop_group.entities
          
          front_overhang = countertop_overhang(:overhang_front)
          side_overhang = countertop_overhang(:overhang_side)
          back_overhang = countertop_overhang(:overhang_back)

          # Find the span of all cabinets
          min_x = cabinets.map { |c| c.position[0] }.min
          max_x = cabinets.map { |c| c.position[0] + c.width }.max
          
          # Use first cabinet as reference for height and depth
          ref_cabinet = cabinets.first
          height = cabinets.map(&:height).compact.max || ref_cabinet.height || Constants::BASE_CABINET[:height]
          depth = cabinets_max_depth(cabinets) + front_overhang + back_overhang
          thickness = Constants::COUNTERTOP[:thickness]
          
          # Calculate total width
          total_width = max_x - min_x + (2 * side_overhang)
          
          # Convert to inches
          w = total_width.inch
          d = depth.inch
          t = thickness.inch
          h = height.inch
          
          # Starting position
          start_x = (min_x - side_overhang).inch
          start_y = -front_overhang.inch
          start_z = h
          
          # Create countertop slab directly in countertop group
          create_countertop_slab(entities, start_x, start_y, start_z, w, d, t)
          
          # Add backsplash as subgroup if any cabinet has one
          if cabinets.any? { |c| c.has_backsplash }
            backsplash_height = Constants::COUNTERTOP[:backsplash_height].inch
            backsplash_y = start_y + d - back_overhang.inch
            backsplash_z = start_z + t
            
            # Create backsplash subgroup within countertop group
            backsplash_group = countertop_group.entities.add_group
            backsplash_group.name = "Backsplash"
            create_backsplash(backsplash_group.entities, start_x, backsplash_y, backsplash_z,
                            w, backsplash_height, t)
          end
        end

        def countertop_overhang(key)
          Constants::COUNTERTOP[key] || 0.0
        end

        def cabinet_depth_value(cabinet)
          cabinet.depth || Constants::COUNTERTOP[:depth] || Constants::BASE_CABINET[:depth]
        end

        def cabinets_max_depth(cabinets)
          depths = cabinets.map { |cab| cabinet_depth_value(cab) }
          depths.compact.max || (Constants::COUNTERTOP[:depth] || Constants::BASE_CABINET[:depth])
        end
        
        # Create the main countertop slab
        def create_countertop_slab(entities, x, y, z, width, depth, thickness)
          begin
            material = @materials.countertop_material
            
            # Create rectangle for countertop
            pts = [
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x + width, y, z),
              Geom::Point3d.new(x + width, y + depth, z),
              Geom::Point3d.new(x, y + depth, z)
            ]
            
            # Create bottom face
            bottom_face = entities.add_face(pts)
            if bottom_face && bottom_face.valid?
              bottom_face.material = material
              bottom_face.back_material = material
              
              # Create top face (manual extrusion)
              top_pts = pts.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + thickness) }
              top_face = entities.add_face(top_pts.reverse)
              if top_face
                top_face.material = material
                top_face.back_material = material
              end
              
              # Create side faces
              pts.each_with_index do |pt, i|
                next_i = (i + 1) % pts.length
                side_pts = [pts[i], pts[next_i], top_pts[next_i], top_pts[i]]
                side_face = entities.add_face(side_pts)
                if side_face
                  side_face.material = material
                  side_face.back_material = material
                end
              end
            end
            
            # Add edge profile (simplified bullnose on front edge)
            # This is a visual detail - just round the front edge slightly
            add_edge_profile(entities, x, y, z, width, thickness)
          rescue => e
            puts "Error creating countertop slab: #{e.message}"
          end
        end
        
        # Create backsplash
        def create_backsplash(entities, x, y, z, width, height, thickness)
          begin
            # Create rectangle for backsplash
            pts = [
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x + width, y, z),
              Geom::Point3d.new(x + width, y, z + height),
              Geom::Point3d.new(x, y, z + height)
            ]
            
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.countertop_material
              face.back_material = @materials.countertop_material
              
              # Extrude backwards to create thickness
              face.pushpull(thickness)
            end
          rescue => e
            puts "Error creating backsplash: #{e.message}"
          end
        end
        
        # Add simple edge profile to front of countertop
        def add_edge_profile(entities, x, y, z, width, thickness)
          # For now, just a visual marker - actual edge profiles would be more complex
          # In a full implementation, you might use follow-me for curved edges
          
          # Add a small chamfer or bevel to front edge (optional enhancement)
          # This is a simplified version
        end
        
      end
      
    end
  end
end
