# SketchUp Cabinet Builder - Cabinet Generator
# Main orchestrator that brings everything together to build cabinets

module MikMort
  module CabinetBuilder
    module Geometry
      
      class CabinetGenerator
        
        attr_reader :current_run
        
        def initialize(model, room_name, run_manager = nil)
          @model = model
          @room_name = room_name
          @materials = MaterialManager.new(model, room_name)
          @box_builder = BoxBuilder.new(model, @materials)
          @door_drawer_builder = DoorDrawerBuilder.new(model, @materials)
          @countertop_builder = CountertopBuilder.new(model, @materials)
          @validator = GeometryValidator.new
          @connection_manager = CabinetConnectionManager.new(model)
          
          # Use provided run manager or create default
          @current_run = run_manager || Models::CabinetRunManager.find_or_create(model, "Run 1", room_name)
        end
        
        # Set the active run
        def set_run(run_manager)
          @current_run = run_manager
        end
        
        # Generate a single cabinet and add it to the current run
        # @param cabinet [Cabinet] Cabinet specification
        # @param options [Hash] Options for positioning
        # @return [Boolean] Success status
        def generate_cabinet(cabinet, options = {})
          return false unless cabinet.valid?
          
          @model.start_operation('Add Cabinet to Run', true)
          
          begin
            # Determine position (either specified or next in run)
            position = options[:position] || @current_run.next_position
            
            puts "DEBUG: Creating cabinet at position: #{position.inspect}"
            
            # Create temporary groups for building
            temp_group = @model.active_entities.add_group
            
            carcass_group = temp_group.entities.add_group
            carcass_group.name = "Carcass_temp"
            
            fronts_group = temp_group.entities.add_group
            fronts_group.name = "Fronts_temp"
            
            hardware_group = temp_group.entities.add_group
            hardware_group.name = "Hardware_temp"
            
            countertop_group = nil
            backsplash_group = nil
            
            # Build cabinet components
            @box_builder.build(cabinet, carcass_group)
            @door_drawer_builder.build(cabinet, fronts_group, hardware_group)
            
            # Build countertop and backsplash if specified
            if cabinet.has_countertop
              countertop_group = temp_group.entities.add_group
              countertop_group.name = "Countertop_temp"
              backsplash_group = temp_group.entities.add_group
              backsplash_group.name = "Backsplash_temp"
              @countertop_builder.build_separate(cabinet, countertop_group, backsplash_group)
            end
            
            # Move components into run's sub-groups
            move_to_run_groups(carcass_group, fronts_group, hardware_group, countertop_group, backsplash_group, position)
            
            # Clean up temporary group
            temp_group.erase! if temp_group.valid?
            
            @model.commit_operation
            true
          rescue => e
            @model.abort_operation
            puts "Error creating cabinet: #{e.message}"
            puts e.backtrace.first(10).join("\n")
            false
          end
        end
        
        # Generate a cabinet run (multiple cabinets)
        # @param cabinet_run [CabinetRun] Cabinet run specification
        # @return [Sketchup::Group] The complete run group
        def generate_cabinet_run(cabinet_run)
          @model.start_operation('Create Cabinet Run', true)
          
          begin
            # Create main run group
            run_group = @model.active_entities.add_group
            run_group.name = "Cabinet_Run_#{cabinet_run.total_length.to_i}in"
            
            # Create shared groups for the entire run
            carcass_group = run_group.entities.add_group
            carcass_group.name = "Carcass"
            
            countertop_group = run_group.entities.add_group
            countertop_group.name = "Countertop"
            
            fronts_group = run_group.entities.add_group
            fronts_group.name = "Fronts"
            
            hardware_group = run_group.entities.add_group
            hardware_group.name = "Hardware"
            
            # Generate each cabinet in the run with shared groups
            cabinet_run.cabinets.each do |cabinet|
              generate_cabinet_in_run_groups(cabinet, carcass_group, fronts_group, hardware_group)
            end
            
            # Add continuous countertop if any cabinets have countertops
            countertop_cabinets = cabinet_run.cabinets.select { |c| c.has_countertop }
            if countertop_cabinets.any?
              @countertop_builder.build(countertop_cabinets, countertop_group)
            end
            
            # Add filler strips if any
            cabinet_run.filler_strips.each_with_index do |filler, index|
              add_filler_strip(carcass_group, filler, index)
            end
            
            @model.commit_operation
            run_group
          rescue => e
            @model.abort_operation
            UI.messagebox("Error creating cabinet run: #{e.message}")
            nil
          end
        end
        
        private
        
        # Generate a cabinet within run-level shared groups
        def generate_cabinet_in_run_groups(cabinet, carcass_group, fronts_group, hardware_group)
          return nil unless cabinet.valid?
          
          # Position transformation for this cabinet
          x, y, z = cabinet.position
          transformation = Geom::Transformation.new([x.inch, y.inch, z.inch])
          
          # Build cabinet components directly in shared groups with transformation
          # Create a temporary group for the box, then explode it into carcass_group
          temp_box = carcass_group.entities.add_group
          @box_builder.build(cabinet, temp_box)
          temp_box.transformation = transformation
          temp_box.explode  # Merge geometry into parent carcass group
          
          # Create a temporary group for fronts, then explode it
          temp_fronts = fronts_group.entities.add_group
          temp_hardware = hardware_group.entities.add_group
          @door_drawer_builder.build(cabinet, temp_fronts, temp_hardware)
          temp_fronts.transformation = transformation
          temp_hardware.transformation = transformation
          temp_fronts.explode  # Merge geometry into parent fronts group
          temp_hardware.explode  # Merge geometry into parent hardware group
          
          # Note: Countertop is added separately for the whole run
        end
        
        # Generate a cabinet within an existing group (legacy method for individual cabinets)
        def generate_cabinet_in_group(cabinet, parent_group)
          return nil unless cabinet.valid?
          
          # Create cabinet group within parent
          frame_type = cabinet.frame_type == :framed ? "Framed" : "Frameless"
          width_mm = (cabinet.width * 25.4).round
          depth_mm = (cabinet.depth * 25.4).round
          component_name = "CABINET_#{cabinet.type.to_s.capitalize}_#{width_mm}x#{depth_mm}_#{frame_type}"
          
          cabinet_group = parent_group.entities.add_group
          cabinet_group.name = component_name
          
          # Create organized sub-groups
          carcass_group = cabinet_group.entities.add_group
          carcass_group.name = "Carcass"
          
          fronts_group = cabinet_group.entities.add_group
          fronts_group.name = "Fronts"
          
          hardware_group = cabinet_group.entities.add_group
          hardware_group.name = "Hardware"
          
          # Position the cabinet
          x, y, z = cabinet.position
          cabinet_group.transformation = Geom::Transformation.new([x.inch, y.inch, z.inch])
          
          # Build cabinet components
          @box_builder.build(cabinet, carcass_group)
          @door_drawer_builder.build(cabinet, fronts_group, hardware_group)
          
          # Note: Countertop is added separately for the whole run
          
          cabinet_group
        end
        
        # Add a filler strip
        def add_filler_strip(parent_group, filler, index)
          entities = parent_group.entities
          filler_group = entities.add_group
          filler_group.name = "Filler_#{index + 1}"
          
          x = filler[:position].inch
          y = 0
          z = 0
          width = filler[:width].inch
          depth = 0.75.inch  # Standard filler depth
          height = filler[:height].inch
          
          # Create simple rectangular filler
          pts = [
            Geom::Point3d.new(x, y, z),
            Geom::Point3d.new(x + width, y, z),
            Geom::Point3d.new(x + width, y, z + height),
            Geom::Point3d.new(x, y, z + height)
          ]
          
          face = filler_group.entities.add_face(pts)
          face.material = @materials.box_material
          face.pushpull(depth)
        end
        
        private
        
        # Create a standalone cabinet (not connected to any run)
        def create_standalone_cabinet(cabinet)
          # Create main cabinet group with descriptive name
          frame_type = cabinet.frame_type == :framed ? "Framed" : "Frameless"
          width_mm = (cabinet.width * 25.4).round
          depth_mm = (cabinet.depth * 25.4).round
          component_name = "CABINET_#{cabinet.type.to_s.capitalize}_#{width_mm}x#{depth_mm}_#{frame_type}"
          
          cabinet_group = @model.active_entities.add_group
          cabinet_group.name = component_name
          
          # Create organized sub-groups
          carcass_group = cabinet_group.entities.add_group
          carcass_group.name = "Carcass"
          
          fronts_group = cabinet_group.entities.add_group
          fronts_group.name = "Fronts"
          
          hardware_group = cabinet_group.entities.add_group
          hardware_group.name = "Hardware"
          
          # Build cabinet box (carcass)
          @box_builder.build(cabinet, carcass_group)
          
          # Build doors and drawers (fronts + hardware)
          @door_drawer_builder.build(cabinet, fronts_group, hardware_group)
          
          # Build countertop if specified
          if cabinet.has_countertop
            @countertop_builder.build(cabinet, cabinet_group)
          end
          
          # Position the cabinet
          x, y, z = cabinet.position
          cabinet_group.transformation = Geom::Transformation.new([x.inch, y.inch, z.inch])
          
          # Validate geometry
          @validator.validate_cabinet(cabinet, cabinet_group)
          
          cabinet_group
        end
        
        # Extend a specific cabinet run
        def extend_specific_run(cabinet, run_name)
          # Find the run
          runs = @connection_manager.get_all_runs
          target_run = runs.find { |r| r[:name] == run_name }
          
          unless target_run
            @model.abort_operation
            UI.messagebox("Cabinet run '#{run_name}' not found!")
            return nil
          end
          
          # Build cabinet group
          cabinet_group = build_cabinet_group(cabinet)
          
          # Connect to the run (default: right side)
          result = @connection_manager.connect_to_run(cabinet_group, target_run[:group], :right)
          
          result
        end
        
        # Build a cabinet group with all components
        def build_cabinet_group(cabinet)
          frame_type = cabinet.frame_type == :framed ? "Framed" : "Frameless"
          width_mm = (cabinet.width * 25.4).round
          depth_mm = (cabinet.depth * 25.4).round
          component_name = "CABINET_#{cabinet.type.to_s.capitalize}_#{width_mm}x#{depth_mm}_#{frame_type}"
          
          cabinet_group = @model.active_entities.add_group
          cabinet_group.name = component_name
          
          # Create organized sub-groups
          carcass_group = cabinet_group.entities.add_group
          carcass_group.name = "Carcass"
          
          fronts_group = cabinet_group.entities.add_group
          fronts_group.name = "Fronts"
          
          hardware_group = cabinet_group.entities.add_group
          hardware_group.name = "Hardware"
          
          # Build components
          @box_builder.build(cabinet, carcass_group)
          @door_drawer_builder.build(cabinet, fronts_group, hardware_group)
          
          if cabinet.has_countertop
            @countertop_builder.build(cabinet, cabinet_group)
          end
          
          # Position
          x, y, z = cabinet.position
          cabinet_group.transformation = Geom::Transformation.new([x.inch, y.inch, z.inch])
          
          @validator.validate_cabinet(cabinet, cabinet_group)
          
          cabinet_group
        end
        
        private
        
        # Move component groups into the run's organized sub-groups
        def move_to_run_groups(carcass, fronts, hardware, countertop, backsplash, position)
          transformation = Geom::Transformation.translation(position.to_a.map { |v| v.to_f.inch })
          
          # Helper to transfer all geometry from source group to target group
          transfer_geometry = lambda do |source_group, target_group|
            return unless source_group && source_group.valid? && source_group.entities.length > 0
            
            # Copy all entities to target group with transformation applied
            entities_to_copy = source_group.entities.to_a
            entities_to_copy.each do |entity|
              next unless entity.valid?
              
              if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
                # For groups/components, add instance with transformation
                combined_transform = transformation * entity.transformation
                target_group.entities.add_instance(entity.definition, combined_transform)
              elsif entity.is_a?(Sketchup::Face)
                # For faces, transform vertices and add to target
                points = entity.vertices.map { |v| v.position.transform(transformation) }
                new_face = target_group.entities.add_face(points)
                new_face.material = entity.material if entity.material
                new_face.back_material = entity.back_material if entity.back_material
              elsif entity.is_a?(Sketchup::Edge)
                # Edges will be created automatically with faces
                # or we can add them explicitly if needed
              end
            end
          end
          
          # Transfer entities to run's sub-groups
          transfer_geometry.call(carcass, @current_run.carcass_group)
          transfer_geometry.call(fronts, @current_run.faces_group)
          transfer_geometry.call(hardware, @current_run.hardware_group)
          transfer_geometry.call(countertop, @current_run.countertops_group)
          transfer_geometry.call(backsplash, @current_run.backsplash_group)
        end
        
      end
      
    end
  end
end
