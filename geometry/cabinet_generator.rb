# SketchUp Cabinet Builder - Cabinet Generator
# Main orchestrator that brings everything together to build cabinets

module MikMort
  module CabinetBuilder
    module Geometry
      
      class CabinetGenerator
        
        def initialize(model, room_name)
          @model = model
          @materials = MaterialManager.new(model, room_name)
          @box_builder = BoxBuilder.new(model, @materials)
          @door_drawer_builder = DoorDrawerBuilder.new(model, @materials)
          @countertop_builder = CountertopBuilder.new(model, @materials)
          @validator = GeometryValidator.new
          @connection_manager = CabinetConnectionManager.new(model)
        end
        
        # Generate a single cabinet
        # @param cabinet [Cabinet] Cabinet specification
        # @param options [Hash] Options for run connection
        #   :force_new_run - Create new run even if nearby cabinets exist
        #   :extend_run - Name of specific run to extend
        # @return [Sketchup::Group] The complete cabinet group
        def generate_cabinet(cabinet, options = {})
          return nil unless cabinet.valid?
          
          @model.start_operation('Create Cabinet', true)
          
          begin
            # Handle run connection options
            if options[:extend_run]
              # Extend specific run
              return extend_specific_run(cabinet, options[:extend_run])
            elsif options[:force_new_run]
              # Create standalone or new run
              return create_standalone_cabinet(cabinet)
            else
              # Auto mode: position next to existing cabinets
              adjusted_position = @connection_manager.auto_position_cabinet(cabinet)
              cabinet.position = adjusted_position
            end
            
            puts "DEBUG: Creating cabinet at position: #{cabinet.position.inspect}"
            
            # Check for nearby cabinets to connect to (after positioning)
            connection = @connection_manager.find_nearby_cabinet(cabinet.position, cabinet.type)
            puts "DEBUG: Connection found: #{connection ? 'YES' : 'NO'}"
            puts "DEBUG: Connection distance: #{connection[:distance]} inches" if connection
            
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
            
            # Build countertop if specified (separate group at cabinet level)
            if cabinet.has_countertop
              @countertop_builder.build(cabinet, cabinet_group)
            end
            
            # Position the cabinet AFTER building
            x, y, z = cabinet.position
            cabinet_group.transformation = Geom::Transformation.new([x.inch, y.inch, z.inch])
            
            # Validate geometry
            @validator.validate_cabinet(cabinet, cabinet_group)
            
            # Connect to nearby cabinet if found
            if connection && connection[:distance] < 6.0
              final_group = @connection_manager.connect_cabinets(cabinet_group, connection)
              @model.commit_operation
              return final_group
            end
            
            @model.commit_operation
            cabinet_group
          rescue => e
            @model.abort_operation
            puts "Error creating cabinet: #{e.message}"
            puts e.backtrace.first(10).join("\n")
            UI.messagebox("Error creating cabinet: #{e.message}\n\nCheck Ruby Console for details.")
            nil
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
            
            # Generate each cabinet in the run
            cabinet_run.cabinets.each do |cabinet|
              generate_cabinet_in_group(cabinet, run_group)
            end
            
            # Add continuous countertop if any cabinets have countertops
            countertop_cabinets = cabinet_run.cabinets.select { |c| c.has_countertop }
            if countertop_cabinets.any?
              @countertop_builder.build(countertop_cabinets, run_group)
            end
            
            # Add filler strips if any
            cabinet_run.filler_strips.each_with_index do |filler, index|
              add_filler_strip(run_group, filler, index)
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
        
        # Generate a cabinet within an existing group
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
        
      end
      
    end
  end
end
