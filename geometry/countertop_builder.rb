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
        # @param parent_group [Sketchup::Group] Parent group
        # @param options [Hash] Additional options (seating_side, etc.)
        # @return [Sketchup::Group] The countertop group
        def build(cabinet, parent_group, options = {})
          entities = parent_group.entities
          countertop_group = entities.add_group
          countertop_group.name = "Countertop"
          
          if cabinet.is_a?(Array)
            build_continuous_countertop(cabinet, countertop_group, options)
          else
            build_single_countertop(cabinet, countertop_group, options)
          end
          
          countertop_group
        end
        
        private
        
        # Build countertop for a single cabinet
        def build_single_countertop(cabinet, countertop_group, options)
          entities = countertop_group.entities
          
          # Calculate dimensions
          width = cabinet.width + (2 * Constants::COUNTERTOP[:overhang_side])
          depth = Constants::COUNTERTOP[:depth]
          thickness = Constants::COUNTERTOP[:thickness]
          cabinet_height = cabinet.height  # Total height, not interior
          
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
          start_x = -Constants::COUNTERTOP[:overhang_side].inch
          start_y = -Constants::COUNTERTOP[:overhang_front].inch
          # For base cabinets, box top is at interior_height, but total height includes toe kick
          start_z = cabinet.interior_height.inch  # Sit on top of box (not including toe kick in z)
          
          # Create countertop slab
          create_countertop_slab(entities, start_x, start_y, start_z, w, d, t)
          
          # Add backsplash if needed (as separate group)
          if cabinet.has_backsplash
            backsplash_height = Constants::COUNTERTOP[:backsplash_height].inch
            
            # Backsplash position (at back edge of countertop)
            backsplash_y = start_y + d  # Full depth to back edge
            backsplash_z = start_z + t
            
            # Create separate backsplash group at countertop level
            backsplash_group = entities.add_group
            backsplash_group.name = "Backsplash"
            create_backsplash(backsplash_group.entities, start_x, backsplash_y, backsplash_z, 
                            w, backsplash_height, t)
          end
        end
        
        # Build continuous countertop spanning multiple cabinets
        def build_continuous_countertop(cabinets, countertop_group, options)
          return if cabinets.empty?
          
          entities = countertop_group.entities
          
          # Find the span of all cabinets
          min_x = cabinets.map { |c| c.position[0] }.min
          max_x = cabinets.map { |c| c.position[0] + c.width }.max
          
          # Use first cabinet as reference for height and depth
          ref_cabinet = cabinets.first
          height = ref_cabinet.height
          depth = Constants::COUNTERTOP[:depth]
          thickness = Constants::COUNTERTOP[:thickness]
          
          # Calculate total width
          total_width = max_x - min_x + (2 * Constants::COUNTERTOP[:overhang_side])
          
          # Convert to inches
          w = total_width.inch
          d = depth.inch
          t = thickness.inch
          h = height.inch
          
          # Starting position
          start_x = (min_x - Constants::COUNTERTOP[:overhang_side]).inch
          start_y = -Constants::COUNTERTOP[:overhang_front].inch
          start_z = h
          
          # Create countertop slab
          create_countertop_slab(entities, start_x, start_y, start_z, w, d, t)
          
          # Add backsplash if any cabinet has one
          if cabinets.any? { |c| c.has_backsplash }
            backsplash_height = Constants::COUNTERTOP[:backsplash_height].inch
            backsplash_y = start_y + d - t
            backsplash_z = start_z + t
            
            create_backsplash(entities, start_x, backsplash_y, backsplash_z,
                            w, backsplash_height, t)
          end
        end
        
        # Create the main countertop slab
        def create_countertop_slab(entities, x, y, z, width, depth, thickness)
          begin
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
              bottom_face.material = @materials.countertop_material
              
              # Create top face (manual extrusion)
              top_pts = pts.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + thickness) }
              top_face = entities.add_face(top_pts.reverse)
              top_face.material = @materials.countertop_material if top_face
              
              # Create side faces
              pts.each_with_index do |pt, i|
                next_i = (i + 1) % pts.length
                side_pts = [pts[i], pts[next_i], top_pts[next_i], top_pts[i]]
                side_face = entities.add_face(side_pts)
                side_face.material = @materials.countertop_material if side_face
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
