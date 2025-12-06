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
            
            # Special handling for range placeholders - build into temporary group, then move to appliances
            if cabinet.type == :range
              # Ensure appliances_group exists first
              if !@current_run.appliances_group || !@current_run.appliances_group.valid?
                @current_run.instance_variable_set(:@appliances_group, 
                  @current_run.send(:create_subgroup, 'Appliances', 'appliances'))
              end
              
              # Build range geometry directly into appliances_group (not at model level)
              # This avoids all the transformation complexity
              
              # Build directly into the appliances group entities collection
              @box_builder.build(cabinet, @current_run.appliances_group.entities, position)
              
              # Clean up temp group
              temp_group.erase! if temp_group.valid?
            else
              # Build cabinet components into temp groups
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
              
              # For wall cabinets, adjust Z position based on height_from_floor
              # and Y position to align backs when depths differ
              final_position = position
              if cabinet.type == :wall || cabinet.type == :corner_wall || cabinet.type == :wall_stack_9ft || cabinet.type == :wall_stack
                z_offset = cabinet.height_from_floor.inch
                
                # Align wall cabinets by their backs instead of fronts
                # Cabinet back should be against wall - align all cabinet backs to same Y coordinate
                y_offset = 0
                if @current_run.last_cabinet_depth
                  puts "DEBUG: Cabinet depth=#{cabinet.depth}\", Reference depth=#{@current_run.last_cabinet_depth}\""
                  if cabinet.depth < @current_run.last_cabinet_depth
                    # Shallower cabinet - move back so front is recessed
                    # If ref is 24" at Y=0 (back at 24"), and this is 15" 
                    # We want this cabinet's back also at 24", so front at Y=9"
                    # BUT: Since position.y is already 0, we ADD the difference
                    y_offset = (@current_run.last_cabinet_depth - cabinet.depth).inch
                    puts "DEBUG: Shallower cabinet - offset by +#{y_offset / 1.inch}\" so front at Y=#{(position.y + y_offset) / 1.inch}\", back at Y=#{(position.y + y_offset + cabinet.depth.inch) / 1.inch}\""
                  elsif cabinet.depth > @current_run.last_cabinet_depth
                    puts "DEBUG: Deeper cabinet (#{cabinet.depth}\" > #{@current_run.last_cabinet_depth}\") - updating reference"
                    @current_run.last_cabinet_depth = cabinet.depth
                  else
                    puts "DEBUG: Same depth (#{cabinet.depth}\") - no offset"
                  end
                else
                  puts "DEBUG: First wall cabinet, depth=#{cabinet.depth}\", reference set (back at Y=#{cabinet.depth}\")"
                  @current_run.last_cabinet_depth = cabinet.depth
                end
                
                final_position = Geom::Point3d.new(position.x, position.y + y_offset, z_offset)
                puts "DEBUG: Position - X=#{position.x / 1.inch}\", Y=#{(position.y + y_offset) / 1.inch}\", Z=#{z_offset / 1.inch}\", cabinet back will be at Y=#{(position.y + y_offset + cabinet.depth.inch) / 1.inch}\""
              end
              
              # Move components into run's sub-groups
              move_to_run_groups(carcass_group, fronts_group, hardware_group, countertop_group, backsplash_group, final_position)
              
              # Clean up temporary group
              temp_group.erase! if temp_group.valid?
            end
            
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
          
          # Create a sub-group for this cabinet's fronts (DON'T explode to preserve materials)
          cabinet_fronts = fronts_group.entities.add_group
          cabinet_fronts.name = "Cabinet_#{cabinet.type}_Fronts"
          cabinet_hardware = hardware_group.entities.add_group
          cabinet_hardware.name = "Cabinet_#{cabinet.type}_Hardware"
          
          @door_drawer_builder.build(cabinet, cabinet_fronts, cabinet_hardware)
          cabinet_fronts.transformation = transformation
          cabinet_hardware.transformation = transformation
          # Don't explode - keep groups intact to preserve face materials
          
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
          
          # Helper to transfer geometry by moving the source group directly into target
          transfer_geometry = lambda do |source_group, target_group, name|
            return unless source_group && source_group.valid? && source_group.entities.length > 0
            return unless target_group && target_group.valid?
            
            begin
              # Convert source group to a component, then place an instance in target
              definition = source_group.definition
              target_group.entities.add_instance(definition, transformation)
            rescue => e
              puts "ERROR transferring #{name}: #{e.message}"
            end
          end
          
          # Transfer entities to run's sub-groups
          transfer_geometry.call(carcass, @current_run.carcass_group, "carcass")
          transfer_geometry.call(fronts, @current_run.faces_group, "fronts")
          transfer_geometry.call(hardware, @current_run.hardware_group, "hardware")
          transfer_geometry.call(countertop, @current_run.countertops_group, "countertop")
          transfer_geometry.call(backsplash, @current_run.backsplash_group, "backsplash")
        end
        
      end
      
    end
  end
end
