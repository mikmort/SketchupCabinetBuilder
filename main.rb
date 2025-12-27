# SketchUp Cabinet Builder - Main Entry Point
# Loads all components and sets up the plugin

require 'sketchup.rb'

module MikMort
  module CabinetBuilder
    
    # Load all plugin files
    base_path = File.dirname(__FILE__)
    
    # Load constants first
    require File.join(base_path, 'constants.rb')
    
    # Load materials
    require File.join(base_path, 'materials', 'material_manager.rb')
    
    # Load models
    require File.join(base_path, 'models', 'cabinet.rb')
    require File.join(base_path, 'models', 'cabinet_run.rb')
    require File.join(base_path, 'models', 'cabinet_run_manager.rb')
    
    # Load geometry builders
    require File.join(base_path, 'geometry', 'box_builder.rb')
    require File.join(base_path, 'geometry', 'door_drawer_builder.rb')
    require File.join(base_path, 'geometry', 'countertop_builder.rb')
    require File.join(base_path, 'geometry', 'geometry_validator.rb')
    require File.join(base_path, 'geometry', 'cabinet_connection_manager.rb')
    require File.join(base_path, 'geometry', 'cabinet_generator.rb')
    require File.join(base_path, 'geometry', 'led_recess_builder.rb')
    
    # Load UI
    require File.join(base_path, 'ui', 'dialog.rb')
    
    # Create dialog manager instance
    @dialog_manager = nil
    
    # Show the cabinet builder dialog
    def self.show_dialog
      @dialog_manager ||= DialogManager.new
      @dialog_manager.show
    end
    
    # Create LED recess on selected carcass
    # @param edge [Symbol] Which edge to add recess: :front, :back, :left, :right
    def self.create_led_recess(edge = :front)
      model = Sketchup.active_model
      selection = model.selection
      
      if selection.empty?
        UI.messagebox("Please select a carcass group first.")
        return nil
      end
      
      group = selection.first
      unless group.is_a?(Sketchup::Group)
        UI.messagebox("Please select a group (carcass).")
        return nil
      end
      
      # Extract run name from the group (use group name or parent name if available)
      run_name = group.name.to_s
      if run_name.empty? || run_name == "Carcass"
        # Try to get name from parent if this is a nested group
        run_name = "Run"
      end
      
      model.start_operation('Create LED Recess', true)
      begin
        builder = Geometry::LEDRecessBuilder.new(model)
        recess_group = builder.create_recess(group, edge, run_name)
        
        if recess_group
          model.commit_operation
          UI.messagebox("LED recess created successfully!")
          recess_group
        else
          model.abort_operation
          UI.messagebox("Failed to create LED recess.")
          nil
        end
      rescue => e
        model.abort_operation
        UI.messagebox("Error creating LED recess: #{e.message}")
        puts e.backtrace.join("\n")
        nil
      end
    end
    
    # Quick create methods for testing/scripting
    
    # Create a base cabinet
    def self.create_base_cabinet(width = 24, options = {})
      model = Sketchup.active_model
      room_name = options[:room_name] || 'Kitchen'
      
      generator = Geometry::CabinetGenerator.new(model, room_name)
      cabinet = Cabinet.new(:base, {
        width: width,
        frame_type: options[:frame_type] || :frameless,
        door_drawer_config: options[:config] || :doors,
        has_countertop: options[:countertop].nil? ? true : options[:countertop],
        has_backsplash: options[:backsplash].nil? ? true : options[:backsplash]
      })
      
      generator.generate_cabinet(cabinet)
    end
    
    # Create a wall cabinet
    def self.create_wall_cabinet(width = 24, options = {})
      model = Sketchup.active_model
      room_name = options[:room_name] || 'Kitchen'
      
      generator = Geometry::CabinetGenerator.new(model, room_name)
      cabinet = Cabinet.new(:wall, {
        width: width,
        frame_type: options[:frame_type] || :frameless,
        door_drawer_config: :doors,
        has_countertop: false,
        has_backsplash: false
      })
      
      generator.generate_cabinet(cabinet)
    end
    
    # Create an island
    def self.create_island(width = 36, options = {})
      model = Sketchup.active_model
      room_name = options[:room_name] || 'Kitchen'
      
      generator = Geometry::CabinetGenerator.new(model, room_name)
      cabinet = Cabinet.new(:island, {
        width: width,
        frame_type: options[:frame_type] || :frameless,
        door_drawer_config: options[:config] || :doors,
        has_countertop: options[:countertop].nil? ? true : options[:countertop],
        has_backsplash: false,
        has_seating_side: options[:seating] || false
      })
      
      generator.generate_cabinet(cabinet)
    end
    
    # Create a SubZero panel-ready refrigerator
    # @param width [Integer] Width in inches: 30, 36, 42, or 48
    # @param series [Symbol] Series type: :classic or :designer
    # @param options [Hash] Additional options
    def self.create_subzero_fridge(width = 36, series = :classic, options = {})
      model = Sketchup.active_model
      room_name = options[:room_name] || 'Kitchen'
      
      # Validate width and get corresponding dimensions
      valid_widths = [30, 36, 42, 48]
      width = 36 unless valid_widths.include?(width)
      
      # Get dimensions for the specified series
      series_data = Constants::SUBZERO_FRIDGE[series]
      
      generator = Geometry::CabinetGenerator.new(model, room_name)
      cabinet = Cabinet.new(:subzero_fridge, {
        width: width,
        depth: series_data[:"depth_#{width}"],
        height: series_data[:"height_#{width}"],
        series: series,
        frame_type: :frameless,
        door_drawer_config: :doors,
        has_countertop: false,
        has_backsplash: false,
        position: options[:position] || [0, 0, 0],
        single_door: options[:single_door]
      })
      
      generator.generate_cabinet(cabinet) unless options[:skip_generation]
      
      return cabinet if options[:skip_generation]
    end
    
    # Create a split SubZero fridge/freezer combination
    # @param fridge_width [Integer] Width of fridge unit in inches: 24 or 30
    # @param freezer_width [Integer] Width of freezer unit in inches: 18 or 24
    # @param series [Symbol] Series type: :classic or :designer
    # @param options [Hash] Additional options
    def self.create_subzero_split(fridge_width, freezer_width, series = :classic, options = {})
      model = Sketchup.active_model
      room_name = options[:room_name] || 'Kitchen'
      
      generator = Geometry::CabinetGenerator.new(model, room_name)
      
      # Create fridge unit (force single door)
      fridge = create_subzero_fridge(fridge_width, series, options.merge(skip_generation: true, single_door: true))
      generator.generate_cabinet(fridge)
      
      # Position freezer next to fridge (force single door)
      freezer_options = options.merge(
        skip_generation: true,
        single_door: true,
        position: [fridge_width, 0, 0]
      )
      freezer = create_subzero_fridge(freezer_width, series, freezer_options)
      generator.generate_cabinet(freezer)
      
      # Return both units
      { fridge: fridge, freezer: freezer }
    end
    
    # Create a Miele panel-ready dishwasher
    # @param options [Hash] Additional options
    def self.create_miele_dishwasher(options = {})
      model = Sketchup.active_model
      room_name = options[:room_name] || 'Kitchen'
      
      generator = Geometry::CabinetGenerator.new(model, room_name)
      cabinet = Cabinet.new(:miele_dishwasher, {
        width: Constants::MIELE_DISHWASHER[:width],
        depth: Constants::MIELE_DISHWASHER[:depth],
        height: Constants::MIELE_DISHWASHER[:height],
        frame_type: :frameless,
        door_drawer_config: :'1_drawer',
        has_countertop: options[:countertop] || true,
        has_backsplash: false
      })
      
      generator.generate_cabinet(cabinet)
    end
    
    # Create a wall oven/microwave placeholder in tall cabinet
    # @param oven_type [Symbol] :single, :double, or :microwave
    # @param options [Hash] Additional options
    def self.create_wall_oven(oven_type = :single, options = {})
      model = Sketchup.active_model
      room_name = options[:room_name] || 'Kitchen'
      
      # Calculate total height based on oven type and drawer configuration
      oven_height = case oven_type
                   when :single
                     Constants::WALL_OVEN[:height_single]
                   when :double
                     Constants::WALL_OVEN[:height_double]
                   when :microwave
                     Constants::WALL_OVEN[:height_micro]
                   else
                     Constants::WALL_OVEN[:height_single]
                   end
      
      # Default: oven at 12" from bottom, with drawers above
      oven_bottom = options[:oven_bottom] || 12.0
      cabinet_height = options[:height] || Constants::TALL_CABINET[:height]
      
      generator = Geometry::CabinetGenerator.new(model, room_name)
      cabinet = Cabinet.new(:wall_oven, {
        width: Constants::WALL_OVEN[:width],
        depth: Constants::TALL_CABINET[:depth],
        height: cabinet_height,
        frame_type: :frameless,
        door_drawer_config: :'2_drawers',  # Drawers above oven by default
        has_countertop: false,
        has_backsplash: false,
        oven_type: oven_type,
        oven_bottom: oven_bottom
      })
      
      generator.generate_cabinet(cabinet)
    end
    
    # Create a generic range placeholder
    # @param width [Integer] Width in inches: 30, 36, or 48
    # @param options [Hash] Additional options
    def self.create_range(width = 30, options = {})
      model = Sketchup.active_model
      room_name = options[:room_name] || 'Kitchen'
      
      # Validate width
      valid_widths = [30, 36, 48]
      width = 30 unless valid_widths.include?(width)
      
      generator = Geometry::CabinetGenerator.new(model, room_name)
      cabinet = Cabinet.new(:range, {
        width: width,
        depth: Constants::RANGE[:"depth_#{width}"],
        height: Constants::RANGE[:"height_#{width}"],
        frame_type: :frameless,
        door_drawer_config: :doors,
        has_countertop: false,
        has_backsplash: false
      })
      
      generator.generate_cabinet(cabinet)
    end
    
    # Create a cabinet run
    def self.create_cabinet_run(length = 120, options = {})
      model = Sketchup.active_model
      room_name = options[:room_name] || 'Kitchen'
      
      run_options = {
        cabinet_type: options[:cabinet_type] || :base,
        frame_type: options[:frame_type] || :frameless,
        room_preset: options[:room_preset] || :kitchen,
        has_countertop: options[:countertop].nil? ? true : options[:countertop],
        has_backsplash: options[:backsplash].nil? ? true : options[:backsplash],
        appliance_gaps: options[:appliance_gaps] || []
      }
      
      generator = Geometry::CabinetGenerator.new(model, room_name)
      run = CabinetRun.new(length, run_options)
      run.auto_layout
      
      generator.generate_cabinet_run(run)
      
      # Return info
      {
        cabinets: run.cabinets.length,
        filler_strips: run.filler_strips
      }
    end
    
    # Set up menu items
    unless file_loaded?(__FILE__)
      
      # Add menu
      menu = UI.menu('Plugins')
      cabinet_menu = menu.add_submenu('Cabinet Builder')
      
      # Main dialog
      cabinet_menu.add_item('Build Cabinet...') {
        MikMort::CabinetBuilder.show_dialog
      }
      
      cabinet_menu.add_separator
      
      # LED Recess submenu
      led_menu = cabinet_menu.add_submenu('Create LED Recess')
      
      led_menu.add_item('Front Edge') {
        MikMort::CabinetBuilder.create_led_recess(:front)
      }
      
      led_menu.add_item('Back Edge') {
        MikMort::CabinetBuilder.create_led_recess(:back)
      }
      
      led_menu.add_item('Left Edge') {
        MikMort::CabinetBuilder.create_led_recess(:left)
      }
      
      led_menu.add_item('Right Edge') {
        MikMort::CabinetBuilder.create_led_recess(:right)
      }
      
      cabinet_menu.add_separator
      
      # Quick create options
      quick_menu = cabinet_menu.add_submenu('Quick Create')
      
      quick_menu.add_item('Base Cabinet (24")') {
        MikMort::CabinetBuilder.create_base_cabinet(24)
      }
      
      quick_menu.add_item('Base Cabinet (36")') {
        MikMort::CabinetBuilder.create_base_cabinet(36)
      }
      
      quick_menu.add_item('Wall Cabinet (30")') {
        MikMort::CabinetBuilder.create_wall_cabinet(30)
      }
      
      quick_menu.add_item('Island (48" with seating)') {
        MikMort::CabinetBuilder.create_island(48, seating: true)
      }
      
      quick_menu.add_separator
      
      # SubZero refrigerator options
      subzero_menu = quick_menu.add_submenu('SubZero Fridge')
      
      # Classic Series (with top vent)
      classic_menu = subzero_menu.add_submenu('Classic Series')
      
      classic_menu.add_item('30" Built-In') {
        MikMort::CabinetBuilder.create_subzero_fridge(30, :classic)
      }
      
      classic_menu.add_item('36" Built-In') {
        MikMort::CabinetBuilder.create_subzero_fridge(36, :classic)
      }
      
      classic_menu.add_item('42" Built-In') {
        MikMort::CabinetBuilder.create_subzero_fridge(42, :classic)
      }
      
      classic_48_menu = classic_menu.add_submenu('48" Built-In')
      
      classic_48_menu.add_item('24" Fridge + 24" Freezer') {
        MikMort::CabinetBuilder.create_subzero_split(24, 24, :classic)
      }
      
      classic_48_menu.add_item('30" Fridge + 18" Freezer') {
        MikMort::CabinetBuilder.create_subzero_split(30, 18, :classic)
      }
      
      # Designer Series (no top vent, flush design)
      designer_menu = subzero_menu.add_submenu('Designer Series')
      
      designer_menu.add_item('30" Built-In') {
        MikMort::CabinetBuilder.create_subzero_fridge(30, :designer)
      }
      
      designer_menu.add_item('36" Built-In') {
        MikMort::CabinetBuilder.create_subzero_fridge(36, :designer)
      }
      
      designer_menu.add_item('42" Built-In') {
        MikMort::CabinetBuilder.create_subzero_fridge(42, :designer)
      }
      
      designer_48_menu = designer_menu.add_submenu('48" Built-In')
      
      designer_48_menu.add_item('24" Fridge + 24" Freezer') {
        MikMort::CabinetBuilder.create_subzero_split(24, 24, :designer)
      }
      
      designer_48_menu.add_item('30" Fridge + 18" Freezer') {
        MikMort::CabinetBuilder.create_subzero_split(30, 18, :designer)
      }
      
      quick_menu.add_separator
      
      # Miele dishwasher
      quick_menu.add_item('Miele Dishwasher (24")') {
        MikMort::CabinetBuilder.create_miele_dishwasher
      }
      
      quick_menu.add_separator
      
      # Range placeholders
      range_menu = quick_menu.add_submenu('Range Placeholder')
      
      range_menu.add_item('30" Range') {
        MikMort::CabinetBuilder.create_range(30)
      }
      
      range_menu.add_item('36" Range') {
        MikMort::CabinetBuilder.create_range(36)
      }
      
      range_menu.add_item('48" Range') {
        MikMort::CabinetBuilder.create_range(48)
      }
      
      quick_menu.add_separator
      
      quick_menu.add_item('10 ft Base Run') {
        result = MikMort::CabinetBuilder.create_cabinet_run(120)
        UI.messagebox("Created #{result[:cabinets]} cabinets")
      }
      
      cabinet_menu.add_separator
      
      # Reload plugin (for development)
      cabinet_menu.add_item('Reload Plugin') {
        load File.join(__dir__, '../sketchup_cabinet_builder.rb')
        UI.messagebox("Plugin reloaded successfully!")
      }
      
      cabinet_menu.add_separator
      
      # Help/About
      cabinet_menu.add_item('About...') {
        UI.messagebox(
          "Cabinet Builder v#{PLUGIN_VERSION}\n\n" +
          "Professional cabinet builder for SketchUp with:\n" +
          "- US standard dimensions\n" +
          "- Kitchen, bathroom, and closet presets\n" +
          "- TwinMotion material naming\n" +
          "- Auto-layout for cabinet runs\n" +
          "- Realistic hardware details\n\n" +
          "Copyright (c) 2025 MikMort",
          MB_OK,
          "About Cabinet Builder"
        )
      }
      
      file_loaded(__FILE__)
    end
    
  end
end

puts "Cabinet Builder loaded successfully!"
