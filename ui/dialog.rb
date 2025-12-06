# SketchUp Cabinet Builder - Dialog Manager
# Manages the HTML dialog for user input

module MikMort
  module CabinetBuilder
    
    class DialogManager
      
      def initialize
        @dialog = nil
        @current_run = nil
        @current_room = "Kitchen"
      end
      
      # Show the dialog
      def show
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
        else
          create_dialog
          @dialog.show
        end
      end
      
      private
      
      # Create the HTML dialog
      def create_dialog
        @dialog = UI::HtmlDialog.new(
          {
            dialog_title: "Cabinet Builder",
            preferences_key: "com.mikmort.cabinet_builder",
            scrollable: true,
            resizable: true,
            width: 550,
            height: 700,
            left: 100,
            top: 100,
            min_width: 500,
            min_height: 600
          }
        )
        
        # Set the HTML file with cache busting
        html_file = File.join(__dir__, '..', 'resources', 'dialog.html')
        html_content = File.read(html_file)
        puts "DEBUG: Loading HTML file: #{html_file}"
        puts "DEBUG: HTML contains corner options: #{html_content.include?('inside_36')}"
        # Add timestamp to force reload
        timestamp = Time.now.to_i
        html_content.sub!('<head>', "<head><!-- Cache bust: #{timestamp} --><meta http-equiv='Cache-Control' content='no-cache, no-store, must-revalidate'><meta http-equiv='Pragma' content='no-cache'><meta http-equiv='Expires' content='0'>")
        @dialog.set_html(html_content)
        
        # Add callbacks
        add_callbacks
      end
      
      # Add JavaScript callbacks
      def add_callbacks
        # Get existing cabinet runs
        @dialog.add_action_callback('get_existing_runs') do |action_context|
          runs = get_existing_runs
          @dialog.execute_script("receiveExistingRuns(#{runs.to_json})")
        end
        
        # Get current run info
        @dialog.add_action_callback('get_current_run') do |action_context|
          run_info = get_current_run_info
          @dialog.execute_script("receiveCurrentRun(#{run_info.to_json})")
        end
        
        # Create new run
        @dialog.add_action_callback('create_run') do |action_context, params|
          handle_create_run(params)
        end
        
        # Select run
        @dialog.add_action_callback('select_run') do |action_context, run_id|
          handle_select_run(run_id)
        end
        
        # Rename run
        @dialog.add_action_callback('rename_run') do |action_context, params|
          handle_rename_run(params)
        end
        
        # Delete run
        @dialog.add_action_callback('delete_run') do |action_context, run_id|
          handle_delete_run(run_id)
        end
        
        # Handle cabinet creation
        @dialog.add_action_callback('create_cabinet') do |action_context, params|
          handle_create_cabinet(params)
        end
        
        # Handle cancel
        @dialog.add_action_callback('cancel') do |action_context|
          @dialog.close
        end
      end
      
      # Get all existing cabinet runs from model
      def get_existing_runs
        model = Sketchup.active_model
        Models::CabinetRunManager.all(model).map(&:to_hash)
      end
      
      # Get current run information
      def get_current_run_info
        if @current_run && @current_run.group.valid?
          @current_run.to_hash
        else
          nil
        end
      end
      
      # Create a new run
      def handle_create_run(json_params)
        require 'json'
        puts "DEBUG: handle_create_run called with params: #{json_params}"
        
        begin
          params = JSON.parse(json_params)
          puts "DEBUG: Parsed params: #{params.inspect}"
          
          model = Sketchup.active_model
          run_name = params['name'] || "Run #{Models::CabinetRunManager.all(model).length + 1}"
          room_name = params['room_name'] || @current_room
          run_type = (params['run_type'] || 'base').to_sym
          
          # Extract run properties
          options = {
            frame_type: params['frame_type'] || 'frameless',
            has_countertop: params['has_countertop'] != false,
            has_backsplash: params['has_backsplash'] != false
          }
          
          puts "DEBUG: Creating run: name=#{run_name}, room=#{room_name}, type=#{run_type}, options=#{options}"
          
          @current_run = Models::CabinetRunManager.new(model, run_name, room_name, run_type, options)
          @current_room = room_name
          
          puts "DEBUG: Run created successfully: #{@current_run.inspect}"
          
          # Send updated run list and set current run
          runs = get_existing_runs
          @dialog.execute_script("receiveExistingRuns(#{runs.to_json})")
          @dialog.execute_script("receiveCurrentRun(#{@current_run.to_hash.to_json})")
        rescue => e
          puts "ERROR in handle_create_run: #{e.message}"
          puts e.backtrace.first(5).join("\n")
        end
      end
      
      # Select an existing run
      def handle_select_run(run_id)
        model = Sketchup.active_model
        run = Models::CabinetRunManager.all(model).find { |r| r.id == run_id }
        
        if run
          @current_run = run
          @current_room = run.room_name
          @dialog.execute_script("receiveCurrentRun(#{run.to_hash.to_json})")
        end
      end
      
      # Rename a run
      def handle_rename_run(json_params)
        require 'json'
        params = JSON.parse(json_params)
        
        model = Sketchup.active_model
        run = Models::CabinetRunManager.all(model).find { |r| r.id == params['run_id'] }
        
        if run
          run.rename(params['new_name'])
          @dialog.execute_script("receiveExistingRuns(#{get_existing_runs.to_json})")
        end
      end
      
      # Delete a run
      def handle_delete_run(run_id)
        model = Sketchup.active_model
        run = Models::CabinetRunManager.all(model).find { |r| r.id == run_id }
        
        if run
          run.delete
          @current_run = nil if @current_run && @current_run.id == run_id
          @dialog.execute_script("receiveExistingRuns(#{get_existing_runs.to_json})")
          @dialog.execute_script("receiveCurrentRun(null)")
        end
      end
      
      # Handle cabinet creation from dialog
      def handle_create_cabinet(json_params)
        require 'json'
        require 'uri'
        
        begin
          puts "DEBUG RAW PARAMS: #{json_params[0..200]}"
          # Decode URI component first (since we use encodeURIComponent in HTML)
          decoded_params = URI.decode_www_form_component(json_params)
          puts "DEBUG DECODED PARAMS: #{decoded_params[0..200]}"
          params = JSON.parse(decoded_params)
          room_name = params['room_name'] || @current_room
          run_type = (params['run_type'] || 'base').to_sym
          
          # Ensure we have a current run
          unless @current_run && @current_run.group.valid?
            model = Sketchup.active_model
            @current_run = Models::CabinetRunManager.find_or_create(model, "Run 1", room_name, run_type)
            @current_room = room_name
          end
          
          # Create the generator with the current run
          generator = Geometry::CabinetGenerator.new(Sketchup.active_model, room_name, @current_run)
          
          # Always create single cabinet (no build mode anymore)
          create_single_cabinet(generator, params)
          
          # Close dialog after creation
          @dialog.close
          
        rescue => e
          UI.messagebox("Error creating cabinet: #{e.message}\n\n#{e.backtrace.first(5).join("\n")}")
        end
      end
      
      # Map template + run_type to actual cabinet type
      def map_template_to_type(template, run_type)
        case template
        when 'standard'
          case run_type
          when 'base' then :base
          when 'wall' then :wall
          when 'island' then :island
          else :base
          end
        when 'dishwasher'
          :base  # Dishwasher is just a base cabinet with special handle
        when 'upper_42_12'
          :wall_stack_9ft
        when 'upper_42_12_12'
          :wall_stack
        when 'corner'
          run_type == 'wall' ? :corner_wall : :corner_base
        when 'tall'
          :tall
        when '3_door_graduated'
          :base  # 3 doors with graduated sizing
        else
          :base
        end
      end
      
      # Build door/drawer config from template or individual parameters
      def build_door_drawer_config_from_template(template)
        case template
        when '3_door_graduated'
          return '3_doors_graduated'
        else
          return nil  # Use individual params
        end
      end
      
      # Build door/drawer config from template (returns nil if template doesn't specify)
      def build_door_drawer_config_from_template(template)
        case template
        when 'dishwasher'
          return :door  # Single door
        when '3_door_graduated'
          return '3_doors_graduated'
        else
          return nil  # Use individual params
        end
      end
      
      # Build door/drawer config from individual parameters
      def build_door_drawer_config(door_count, drawer_count, drawer_sizing, layout_order)
        if door_count == 0 && drawer_count == 0
          :doors  # Default (2 doors)
        elsif door_count > 0 && drawer_count == 0
          # Doors only
          door_count == 1 ? :door : :doors
        elsif door_count == 0 && drawer_count > 0
          # Drawers only
          if drawer_sizing == 'custom'
            :custom_drawers
          elsif drawer_sizing == 'equal'
            "#{drawer_count}_equal_drawers".to_sym
          else
            drawer_count == 3 ? :drawers : "#{drawer_count}_drawers".to_sym
          end
        else
          # Both doors and drawers - use string with +
          # For custom sizing, mark it so backend knows to use custom heights
          drawer_config = drawer_sizing == 'custom' ? "#{drawer_count}_custom_drawers" : "#{drawer_count}_drawers"
          door_config = door_count == 1 ? "door" : "#{door_count}_doors"
          # NOTE: Sections are built bottom-to-top, so reverse the order
          if layout_order == 'drawers_top'
            "#{door_config}+#{drawer_config}"  # Door first (bottom), drawers second (top)
          else
            "#{drawer_config}+#{door_config}"  # Drawers first (bottom), door second (top)
          end
        end
      end
      
      # Create a single cabinet
      def create_single_cabinet(generator, params)
        begin
          cabinet_params = params['cabinet']
          
          # Get run type from params, or from active run for single mode
          run_type = params['run_type']
          if !run_type && generator && generator.current_run
            # For single cabinet mode, get run type from active run
            run_type = generator.current_run.run_type.to_s
          end
          run_type ||= 'base'
          
          puts "\n=== DIALOG PARAMS RECEIVED ==="
          puts "run_type: #{run_type}"
          puts "template: #{cabinet_params['template']}"
          puts "door_count: #{cabinet_params['door_count']}"
          puts "drawer_count: #{cabinet_params['drawer_count']}"
          puts "drawer_sizing: #{cabinet_params['drawer_sizing']}"
          puts "layout_order: #{cabinet_params['layout_order']}"
          puts "custom_drawer_heights: #{cabinet_params['custom_drawer_heights'].inspect}"
          puts "============================\n"
          
          # Map template + run_type to actual cabinet type
          type = map_template_to_type(cabinet_params['template'], run_type)
          frame_type = cabinet_params['frame_type'].to_sym
          
          # Build door/drawer config - check template first
          config = build_door_drawer_config_from_template(cabinet_params['template'])
          if !config
            # Use individual parameters
            door_count = cabinet_params['door_count'].to_i
            drawer_count = cabinet_params['drawer_count'].to_i
            drawer_sizing = cabinet_params['drawer_sizing'] || 'equal'
            layout_order = cabinet_params['layout_order'] || 'drawers_top'
            config = build_door_drawer_config(door_count, drawer_count, drawer_sizing, layout_order)
          end
          puts "Built config: #{config.inspect}"
          
          # Create cabinet options hash
          options = {
            frame_type: frame_type,
            width: cabinet_params['width'].to_f,
            depth: cabinet_params['depth'].to_f,
            height: cabinet_params['height'].to_f,
            height_from_floor: cabinet_params['height_from_floor'].to_f,
            door_drawer_config: config,
            has_countertop: cabinet_params['has_countertop'],
            has_backsplash: cabinet_params['has_backsplash'],
            template: cabinet_params['template']  # Pass template so we can check for dishwasher
          }
          
          # Add custom drawer heights if provided
          if cabinet_params['custom_drawer_heights']
            options[:custom_drawer_heights] = cabinet_params['custom_drawer_heights'].map(&:to_f)
          end
          
          # Add corner type if corner cabinet
          if type == :corner_base || type == :corner_wall
            puts "DEBUG: Setting corner_type from params: #{cabinet_params['corner_type']}"
            options[:corner_type] = cabinet_params['corner_type'].to_sym
            puts "DEBUG: corner_type symbol: #{options[:corner_type]}"
          end
          
          # Add seating side if island
          if type == :island
            options[:has_seating_side] = cabinet_params['has_seating_side']
          end
          
          # Create the cabinet
          puts "Creating cabinet with options: #{options.inspect}"
          cabinet = Cabinet.new(type, options)
          puts "Cabinet created: type=#{cabinet.type}, corner_type=#{cabinet.corner_type}, valid=#{cabinet.valid?}"
          
          # Handle run connection option
          run_option = params['run_connection'] || 'auto'
          
          case run_option
          when 'new_run'
            # Force creation of new run
            result = generator.generate_cabinet(cabinet, force_new_run: true)
          when 'extend_run'
            # Find and extend existing run
            run_name = params['target_run']
            result = generator.generate_cabinet(cabinet, extend_run: run_name)
          else
            # Auto mode (default behavior)
            result = generator.generate_cabinet(cabinet)
          end
          
          if !result
            UI.messagebox("Failed to create cabinet. Check Ruby Console for errors.")
          end
        rescue => e
          puts "Error in create_single_cabinet: #{e.message}"
          puts e.backtrace.first(10).join("\n")
          UI.messagebox("Error: #{e.message}")
        end
      end
      
      # Create a cabinet run
      def create_cabinet_run(generator, params)
        run_params = params['cabinet_run']
        
        # Convert appliance gaps
        appliance_gaps = []
        if run_params['appliance_gaps']
          run_params['appliance_gaps'].each do |gap|
            appliance_gaps << {
              position: gap['position'].to_f,
              width: gap['width'].to_f,
              label: gap['label']
            }
          end
        end
        
        # Create cabinet run
        options = {
          cabinet_type: run_params['cabinet_type'].to_sym,
          frame_type: run_params['frame_type'].to_sym,
          room_preset: params['room_preset'].to_sym,
          has_countertop: run_params['has_countertop'],
          has_backsplash: run_params['has_backsplash'],
          appliance_gaps: appliance_gaps
        }
        
        run = CabinetRun.new(run_params['total_length'].to_f, options)
        run.auto_layout
        
        generator.generate_cabinet_run(run)
        
        # Show summary
        filler_info = ""
        if run.filler_strips.any?
          filler_widths = run.filler_strips.map { |f| "#{f[:width].round(2)}\"" }.join(", ")
          filler_info = "\n\nFiller strips needed: #{filler_widths}"
        end
        
        UI.messagebox("Cabinet run created successfully!\n\nTotal cabinets: #{run.cabinets.length}#{filler_info}")
      end
      
    end
    
  end
end
