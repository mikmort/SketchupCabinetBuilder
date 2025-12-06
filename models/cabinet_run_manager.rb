# SketchUp Cabinet Builder - Cabinet Run Manager
# Manages the actual SketchUp group structure for cabinet runs

module MikMort
  module CabinetBuilder
    module Models
      
      class CabinetRunManager
        attr_accessor :name, :room_name, :run_type, :frame_type, :has_countertop, :has_backsplash
        attr_reader :id, :group
        
        # Sub-groups within the run
        attr_reader :faces_group, :carcass_group, :countertops_group, :hardware_group, :backsplash_group, :appliances_group
        
        # Track last cabinet depth for alignment
        attr_accessor :last_cabinet_depth
        
        def initialize(model, name, room_name = nil, run_type = :base, options = {})
          @model = model
          @id = generate_id
          @name = name
          @room_name = room_name || "Kitchen"
          @run_type = run_type
          @frame_type = options[:frame_type] || 'frameless'
          @has_countertop = options.key?(:has_countertop) ? options[:has_countertop] : true
          @has_backsplash = options.key?(:has_backsplash) ? options[:has_backsplash] : true
          @sections = []
          @last_cabinet_depth = nil
          
          # Calculate offset position for new run (6' behind existing runs)
          offset_y = calculate_run_offset(model)
          
          # Create the main run group
          @group = @model.active_entities.add_group
          @group.name = "#{@room_name} - #{@name}"
          @group.set_attribute('CabinetBuilder', 'type', 'cabinet_run')
          @group.set_attribute('CabinetBuilder', 'run_id', @id)
          @group.set_attribute('CabinetBuilder', 'run_name', @name)
          @group.set_attribute('CabinetBuilder', 'room_name', @room_name)
          @group.set_attribute('CabinetBuilder', 'run_type', @run_type.to_s)
          @group.set_attribute('CabinetBuilder', 'frame_type', @frame_type)
          @group.set_attribute('CabinetBuilder', 'has_countertop', @has_countertop)
          @group.set_attribute('CabinetBuilder', 'has_backsplash', @has_backsplash)
          @group.set_attribute('CabinetBuilder', 'created_at', Time.now.to_i)
          
          # Position the run group
          if offset_y != 0
            @group.transformation = Geom::Transformation.translation([0, offset_y.inch, 0])
          end
          
          # Create sub-groups
          create_subgroups
        end
        
        # Load existing run from a group
        def self.from_group(model, group)
          return nil unless group && group.valid?
          return nil unless group.get_attribute('CabinetBuilder', 'type') == 'cabinet_run'
          
          run = allocate
          run.instance_variable_set(:@model, model)
          run.instance_variable_set(:@group, group)
          run.instance_variable_set(:@id, group.get_attribute('CabinetBuilder', 'run_id'))
          run.instance_variable_set(:@name, group.get_attribute('CabinetBuilder', 'run_name'))
          run.instance_variable_set(:@room_name, group.get_attribute('CabinetBuilder', 'room_name') || 'Kitchen')
          run.instance_variable_set(:@run_type, (group.get_attribute('CabinetBuilder', 'run_type') || 'base').to_sym)
          run.instance_variable_set(:@frame_type, group.get_attribute('CabinetBuilder', 'frame_type') || 'frameless')
          run.instance_variable_set(:@has_countertop, group.get_attribute('CabinetBuilder', 'has_countertop', true))
          run.instance_variable_set(:@has_backsplash, group.get_attribute('CabinetBuilder', 'has_backsplash', true))
          run.instance_variable_set(:@sections, [])
          
          # Find sub-groups
          run.load_subgroups
          
          run
        end
        
        # Get all cabinet runs in the model
        def self.all(model)
          runs = []
          model.active_entities.grep(Sketchup::Group).each do |group|
            run = from_group(model, group)
            runs << run if run
          end
          runs
        end
        
        # Find a run by name
        def self.find_by_name(model, name, room_name = nil)
          all(model).find do |run|
            if room_name
              run.name == name && run.room_name == room_name
            else
              run.name == name
            end
          end
        end
        
        # Find or create a run
        def self.find_or_create(model, name, room_name = nil, run_type = :base)
          find_by_name(model, name, room_name) || new(model, name, room_name, run_type)
        end
        
        # Get the next position for a cabinet in this run
        def next_position
          # Reload subgroups to ensure we have valid references (they can become stale between operations)
          load_subgroups
          
          # Find the rightmost point across all groups (carcass and appliances)
          max_x = 0
          
          # Check carcass group
          if @carcass_group && @carcass_group.valid?
            begin
              carcass_bounds = @carcass_group.bounds
              if carcass_bounds.valid?
                max_x = carcass_bounds.max.x
              end
            rescue => e
              # Ignore errors reading carcass bounds
            end
          end
          
          # Check appliances group (for ranges, etc.)
          if @appliances_group && @appliances_group.valid?
            begin
              appliances_bounds = @appliances_group.bounds
              if appliances_bounds.valid? && appliances_bounds.max.x > 0
                appliances_max = appliances_bounds.max.x
                max_x = [max_x, appliances_max].max
              end
            rescue => e
              # Ignore errors reading appliances bounds
            end
          end
          
          Geom::Point3d.new(max_x, 0, 0)
        end
        
        # Add a cabinet section's components to the appropriate sub-groups
        def add_cabinet_components(carcass, faces, countertop, backsplash, hardware, position)
          # Move components into the run's sub-groups
          if carcass && carcass.valid?
            carcass.transform!(Geom::Transformation.translation(position))
            @carcass_group.entities.add_instance(carcass.definition, carcass.transformation)
            carcass.erase!
          end
          
          if faces && faces.valid?
            faces.transform!(Geom::Transformation.translation(position))
            @faces_group.entities.add_instance(faces.definition, faces.transformation)
            faces.erase!
          end
          
          if countertop && countertop.valid?
            countertop.transform!(Geom::Transformation.translation(position))
            @countertops_group.entities.add_instance(countertop.definition, countertop.transformation)
            countertop.erase!
          end
          
          if backsplash && backsplash.valid?
            backsplash.transform!(Geom::Transformation.translation(position))
            @backsplash_group.entities.add_instance(backsplash.definition, backsplash.transformation)
            backsplash.erase!
          end
          
          if hardware && hardware.valid?
            hardware.transform!(Geom::Transformation.translation(position))
            @hardware_group.entities.add_instance(hardware.definition, hardware.transformation)
            hardware.erase!
          end
        end
        
        # Delete this run
        def delete
          @group.erase! if @group && @group.valid?
        end
        
        # Rename this run
        def rename(new_name)
          @name = new_name
          update_group_name
        end
        
        # Change room name
        def change_room(new_room_name)
          @room_name = new_room_name
          @group.set_attribute('CabinetBuilder', 'room_name', @room_name)
          update_group_name
        end
        
        # Export run data for dialog
        def to_hash
          section_count = 0
          [@carcass_group, @faces_group].each do |g|
            section_count += g.entities.grep(Sketchup::Group).length if g && g.valid?
          end
          
          {
            id: @id,
            name: @name,
            room_name: @room_name,
            run_type: @run_type.to_s,
            frame_type: @frame_type,
            has_countertop: @has_countertop,
            has_backsplash: @has_backsplash,
            section_count: section_count
          }
        end
        
        def load_subgroups
          @group.entities.grep(Sketchup::Group).each do |subgroup|
            case subgroup.get_attribute('CabinetBuilder', 'subgroup_type')
            when 'carcass'
              @carcass_group = subgroup
            when 'faces'
              @faces_group = subgroup
            when 'countertops'
              @countertops_group = subgroup
            when 'backsplash'
              @backsplash_group = subgroup
            when 'hardware'
              @hardware_group = subgroup
            when 'appliances'
              @appliances_group = subgroup
            end
          end
          
          # Create missing subgroups
          @carcass_group ||= create_subgroup('Carcass', 'carcass')
          @faces_group ||= create_subgroup('Faces', 'faces')
          @countertops_group ||= create_subgroup('Countertops', 'countertops')
          @backsplash_group ||= create_subgroup('Backsplash', 'backsplash')
          @hardware_group ||= create_subgroup('Hardware', 'hardware')
          @appliances_group ||= create_subgroup('Appliances', 'appliances')
        end
        
        private
        
        def generate_id
          "run_#{Time.now.to_i}_#{rand(10000)}"
        end
        
        # Calculate Y offset for new run (6' behind each existing run)
        def calculate_run_offset(model)
          existing_runs = self.class.all(model)
          return 0 if existing_runs.empty?
          
          # Each run gets positioned 6' (72") behind the previous one
          existing_runs.length * -72
        end
        
        def create_subgroups
          # Create sub-groups in a specific order (bottom to top visibility)
          @carcass_group = create_subgroup('Carcass', 'carcass')
          @countertops_group = create_subgroup('Countertops', 'countertops')
          @backsplash_group = create_subgroup('Backsplash', 'backsplash')
          @faces_group = create_subgroup('Faces', 'faces')
          @hardware_group = create_subgroup('Hardware', 'hardware')
          @appliances_group = create_subgroup('Appliances', 'appliances')
        end
        
        def create_subgroup(name, type)
          group = @group.entities.add_group
          group.name = name
          group.set_attribute('CabinetBuilder', 'subgroup_type', type)
          group
        end
        
        def update_group_name
          @group.name = "#{@room_name} - #{@name}"
          @group.set_attribute('CabinetBuilder', 'run_name', @name)
        end
        
      end
      
    end
  end
end
