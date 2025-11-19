# SketchUp Cabinet Builder - Cabinet Connection Manager
# Automatically connects new cabinets to existing ones

module MikMort
  module CabinetBuilder
    
    class CabinetConnectionManager
      
      def initialize(model)
        @model = model
      end
      
      # Find cabinets near a proposed position
      # @param position [Array] [x, y, z] position in inches
      # @param cabinet_type [Symbol] Type of cabinet to connect
      # @return [Hash] Connection info {:side, :cabinet_group, :run_group}
      def find_nearby_cabinet(position, cabinet_type)
        x, y, z = position
        search_distance = 48.inch  # Search within 48" (4 feet)
        
        # Find all cabinet groups in the model
        cabinet_groups = find_all_cabinets
        
        return nil if cabinet_groups.empty?
        
        # Look for cabinets at similar height (same type)
        nearby = cabinet_groups.select do |group|
          bounds = group.bounds
          cabinet_z = bounds.min.z
          cabinet_y = bounds.min.y
          
          # Check if at similar height (within 1")
          height_match = (cabinet_z - z.inch).abs < 1.inch
          depth_match = (cabinet_y - y.inch).abs < 1.inch
          
          height_match && depth_match
        end
        
        # Find closest cabinet on left or right
        closest = nil
        closest_distance = search_distance
        connection_side = nil
        
        nearby.each do |group|
          bounds = group.bounds
          right_edge = bounds.max.x
          left_edge = bounds.min.x
          
          # Check distance to left side (new cabinet to the right)
          dist_to_left = (x.inch - right_edge).abs
          if dist_to_left < closest_distance && x.inch >= right_edge
            closest = group
            closest_distance = dist_to_left
            connection_side = :right
          end
          
          # Check distance to right side (new cabinet to the left)
          dist_to_right = (left_edge - x.inch).abs
          if dist_to_right < closest_distance && x.inch <= left_edge
            closest = group
            closest_distance = dist_to_right
            connection_side = :left
          end
        end
        
        return nil unless closest
        
        # Find if this cabinet is part of a run
        run_group = find_parent_run(closest)
        
        {
          cabinet_group: closest,
          run_group: run_group,
          side: connection_side,
          distance: closest_distance / 1.inch
        }
      end
      
      # Connect a new cabinet to an existing one
      # @param new_cabinet_group [Sketchup::Group] New cabinet group
      # @param connection [Hash] Connection info from find_nearby_cabinet
      # @return [Sketchup::Group] The run group containing both cabinets
      def connect_cabinets(new_cabinet_group, connection)
        @model.start_operation('Connect Cabinets', true)
        
        begin
          existing_cabinet = connection[:cabinet_group]
          run_group = connection[:run_group]
          
          # Create new run group if needed
          if run_group.nil?
            run_group = create_run_group([existing_cabinet, new_cabinet_group])
            
            # Move existing cabinet into run
            move_to_group(existing_cabinet, run_group)
          end
          
          # Move new cabinet into run
          move_to_group(new_cabinet_group, run_group)
          
          # Create or update continuous countertop
          update_run_countertop(run_group)
          
          @model.commit_operation
          run_group
        rescue => e
          @model.abort_operation
          puts "Error connecting cabinets: #{e.message}"
          puts e.backtrace.first(5).join("\n")
          nil
        end
      end
      
      # Auto-position a new cabinet next to existing ones
      # @param cabinet [Cabinet] Cabinet model
      # @return [Array] Adjusted [x, y, z] position
      def auto_position_cabinet(cabinet)
        # Find all existing cabinets
        existing_cabinets = find_all_cabinets
        
        puts "DEBUG auto_position: Found #{existing_cabinets.length} existing cabinets"
        
        if existing_cabinets.empty?
          # No existing cabinets, use original position
          puts "DEBUG auto_position: No existing cabinets, using [0, 0, 0]"
          return cabinet.position
        end
        
        # Find the rightmost cabinet at similar height/depth
        rightmost = nil
        rightmost_x = -Float::INFINITY
        
        existing_cabinets.each do |group|
          bounds = group.bounds
          cabinet_z = bounds.min.z / 1.inch
          cabinet_y = bounds.min.y / 1.inch
          right_edge_x = bounds.max.x / 1.inch
          
          puts "DEBUG auto_position: Checking cabinet at x=#{right_edge_x.round(4)}, y=#{cabinet_y.round(4)}, z=#{cabinet_z.round(4)}"
          puts "DEBUG auto_position: Cabinet bounds width: #{(bounds.width / 1.inch).round(4)}\""
          
          # Check if at similar height and depth (within 3" tolerance)
          # For first cabinet, position is [0,0,0] so we need looser matching
          height_match = (cabinet_z - cabinet.position[2]).abs < 3
          depth_match = true  # Accept any depth for now to get cabinets positioned
          
          if height_match && depth_match
            if right_edge_x > rightmost_x
              rightmost_x = right_edge_x
              rightmost = group
              puts "DEBUG auto_position: Found new rightmost at x=#{rightmost_x.round(4)}\""
            end
          end
        end
        
        if rightmost
          # Place to the right of rightmost cabinet with no gap
          x = rightmost_x  # This is already the right edge in inches
          # Use the original cabinet's Y position (depth), not the previous cabinet's
          # This prevents forward drift from countertop overhang
          y = cabinet.position[1]
          z = rightmost.bounds.min.z / 1.inch
          puts "DEBUG auto_position: Positioning next cabinet at: [#{x.round(4)}, #{y}, #{z}]\""
          [x, y, z]
        else
          # No matching cabinet found, use original position
          puts "DEBUG auto_position: No matching cabinet, using original position"
          cabinet.position
        end
      end
      
      # Get all existing cabinet runs in the model
      # @return [Array<Hash>] Array of run info: {:group, :name, :cabinet_count, :bounds}
      def get_all_runs
        runs = []
        
        @model.active_entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group)
          
          if entity.name.start_with?('Cabinet_Run_')
            cabinet_count = entity.entities.grep(Sketchup::Group).select { |g|
              g.name.start_with?('CABINET_') || g.name.start_with?('Cabinet_')
            }.count
            
            runs << {
              group: entity,
              name: entity.name,
              cabinet_count: cabinet_count,
              bounds: entity.bounds
            }
          end
        end
        
        runs
      end
      
      # Connect cabinet to a specific run
      # @param cabinet_group [Sketchup::Group] Cabinet to add
      # @param run_group [Sketchup::Group] Target run
      # @param side [Symbol] :left or :right - which side to add to
      # @return [Sketchup::Group] The run group
      def connect_to_run(cabinet_group, run_group, side = :right)
        @model.start_operation('Connect to Run', true)
        
        begin
          # Get run bounds
          run_bounds = run_group.bounds
          
          # Position cabinet at appropriate side
          if side == :right
            # Add to right side
            new_x = run_bounds.max.x
            new_y = run_bounds.min.y
            new_z = run_bounds.min.z
          else
            # Add to left side
            cabinet_width = cabinet_group.bounds.width
            new_x = run_bounds.min.x - cabinet_width
            new_y = run_bounds.min.y
            new_z = run_bounds.min.z
          end
          
          # Move cabinet to position
          current_pos = cabinet_group.bounds.min
          offset = Geom::Vector3d.new(
            new_x - current_pos.x,
            new_y - current_pos.y,
            new_z - current_pos.z
          )
          cabinet_group.transform!(Geom::Transformation.translation(offset))
          
          # Move cabinet into run group
          move_to_group(cabinet_group, run_group)
          
          # Update run countertop
          update_run_countertop(run_group)
          
          @model.commit_operation
          run_group
        rescue => e
          @model.abort_operation
          puts "Error connecting to run: #{e.message}"
          puts e.backtrace.first(5).join("\n")
          nil
        end
      end
      
      private
      
      # Find all cabinet groups in the model
      def find_all_cabinets
        cabinets = []
        
        @model.active_entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group)
          
          # Check if this looks like a cabinet
          if entity.name.start_with?('CABINET_') || entity.name.start_with?('Cabinet_')
            cabinets << entity
          end
          
          # Check if this is a run containing cabinets
          if entity.name.start_with?('Cabinet_Run_')
            entity.entities.each do |sub_entity|
              if sub_entity.is_a?(Sketchup::Group) && 
                 (sub_entity.name.start_with?('CABINET_') || sub_entity.name.start_with?('Cabinet_'))
                cabinets << sub_entity
              end
            end
          end
        end
        
        cabinets
      end
      
      # Find parent run group if cabinet is part of a run
      def find_parent_run(cabinet_group)
        @model.active_entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group)
          next unless entity.name.start_with?('Cabinet_Run_')
          
          # Check if this run contains the cabinet
          entity.entities.each do |sub_entity|
            return entity if sub_entity == cabinet_group
          end
        end
        
        nil
      end
      
      # Create a new run group
      def create_run_group(cabinet_groups)
        total_width = cabinet_groups.sum { |g| g.bounds.width / 1.inch }
        run_group = @model.active_entities.add_group
        run_group.name = "Cabinet_Run_#{total_width.round}in"
        run_group
      end
      
      # Move entity to a group while preserving transformation
      def move_to_group(entity, target_group)
        return entity unless entity.is_a?(Sketchup::Group)
        
        # Get the entity's current transformation
        transformation = entity.transformation
        
        # Create new group in target
        new_group = target_group.entities.add_group
        new_group.name = entity.name
        
        # Copy all entities from source to new group
        entity.entities.to_a.each do |e|
          begin
            # Copy the entity
            if e.is_a?(Sketchup::Group)
              copy_group_recursive(e, new_group.entities)
            elsif e.is_a?(Sketchup::Face)
              # Copy face
              new_face = new_group.entities.add_face(e.vertices.map(&:position))
              new_face.material = e.material if e.material
              new_face.back_material = e.back_material if e.back_material
            elsif e.is_a?(Sketchup::Edge)
              # Edges are created with faces, skip standalone edges
            end
          rescue => err
            puts "Warning: Could not copy entity: #{err.message}"
          end
        end
        
        # Apply transformation to new group
        new_group.transformation = transformation
        
        # Remove original
        entity.erase!
        
        new_group
      end
      
      # Recursively copy a group and its contents
      def copy_group_recursive(source_group, target_entities)
        new_group = target_entities.add_group
        new_group.name = source_group.name
        new_group.transformation = source_group.transformation
        
        source_group.entities.to_a.each do |e|
          if e.is_a?(Sketchup::Group)
            copy_group_recursive(e, new_group.entities)
          elsif e.is_a?(Sketchup::Face)
            new_face = new_group.entities.add_face(e.vertices.map(&:position))
            new_face.material = e.material if e.material
            new_face.back_material = e.back_material if e.back_material
          end
        end
        
        new_group
      end
      
      # Adjust spacing between cabinets in a run
      def adjust_cabinet_spacing(run_group)
        cabinets = []
        
        run_group.entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group)
          next unless entity.name.start_with?('CABINET_') || entity.name.start_with?('Cabinet_')
          cabinets << entity
        end
        
        return if cabinets.length < 2
        
        # Sort cabinets by X position
        cabinets.sort_by! { |c| c.bounds.min.x }
        
        # Adjust positions to be adjacent (no gaps, no overlap)
        current_x = cabinets.first.bounds.min.x
        
        cabinets.each do |cabinet|
          offset_x = current_x - cabinet.bounds.min.x
          
          if offset_x.abs > 0.001.inch
            # Move cabinet to correct position
            cabinet.transform! Geom::Transformation.translation([offset_x, 0, 0])
          end
          
          current_x += cabinet.bounds.width
        end
      end
      
      # Update or create continuous countertop for run
      def update_run_countertop(run_group)
        # Find all cabinets with countertops
        cabinets_with_countertops = []
        
        run_group.entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group)
          next unless entity.name.start_with?('CABINET_') || entity.name.start_with?('Cabinet_')
          
          # Check if has countertop group
          entity.entities.each do |sub|
            if sub.is_a?(Sketchup::Group) && sub.name == 'Countertop'
              cabinets_with_countertops << entity
              sub.erase!  # Remove individual countertop
              break
            end
          end
        end
        
        return if cabinets_with_countertops.empty?
        
        # Create continuous countertop
        # Get bounds of all cabinets
        min_x = cabinets_with_countertops.map { |c| c.bounds.min.x }.min
        max_x = cabinets_with_countertops.map { |c| c.bounds.max.x }.max
        depth = cabinets_with_countertops.first.bounds.depth
        height = cabinets_with_countertops.first.bounds.max.z
        
        # Create countertop group
        ct_group = run_group.entities.add_group
        ct_group.name = "Continuous_Countertop"
        
        overhang = Constants::COUNTERTOP[:overhang_side].inch
        ct_thickness = Constants::COUNTERTOP[:thickness].inch
        ct_overhang_front = Constants::COUNTERTOP[:overhang_front].inch
        
        width = (max_x - min_x) + (2 * overhang)
        
        # Create countertop slab
        pts = [
          Geom::Point3d.new(min_x - overhang, -ct_overhang_front, height),
          Geom::Point3d.new(min_x - overhang + width, -ct_overhang_front, height),
          Geom::Point3d.new(min_x - overhang + width, -ct_overhang_front + depth + overhang, height),
          Geom::Point3d.new(min_x - overhang, -ct_overhang_front + depth + overhang, height)
        ]
        
        bottom_face = ct_group.entities.add_face(pts)
        
        if bottom_face && bottom_face.valid?
          # Create top face
          top_pts = pts.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + ct_thickness) }
          top_face = ct_group.entities.add_face(top_pts.reverse)
          
          # Create side faces
          pts.each_with_index do |pt, i|
            next_i = (i + 1) % pts.length
            side_pts = [pts[i], pts[next_i], top_pts[next_i], top_pts[i]]
            ct_group.entities.add_face(side_pts)
          end
        end
      end
      
    end
    
  end
end
