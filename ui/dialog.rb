# SketchUp Cabinet Builder - Dialog Manager
# Manages the HTML dialog for user input

module MikMort
  module CabinetBuilder
    
    class DialogManager
      
      def initialize
        @dialog = nil
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
        
        # Set the HTML file
        html_file = File.join(__dir__, '..', 'resources', 'dialog.html')
        @dialog.set_file(html_file)
        
        # Add callbacks
        add_callbacks
      end
      
      # Add JavaScript callbacks
      def add_callbacks
        # Handle cabinet creation
        @dialog.add_action_callback('create_cabinet') do |action_context, params|
          handle_create_cabinet(params)
        end
        
        # Handle cancel
        @dialog.add_action_callback('cancel') do |action_context|
          @dialog.close
        end
      end
      
      # Handle cabinet creation from dialog
      def handle_create_cabinet(json_params)
        require 'json'
        
        begin
          params = JSON.parse(json_params)
          room_name = params['room_name'] || 'Room'
          
          # Create the generator
          generator = Geometry::CabinetGenerator.new(Sketchup.active_model, room_name)
          
          if params['build_mode'] == 'single'
            # Create single cabinet
            create_single_cabinet(generator, params)
          else
            # Create cabinet run
            create_cabinet_run(generator, params)
          end
          
          # Close dialog after creation
          @dialog.close
          
        rescue => e
          UI.messagebox("Error creating cabinet: #{e.message}\n\n#{e.backtrace.first(5).join("\n")}")
        end
      end
      
      # Create a single cabinet
      def create_single_cabinet(generator, params)
        begin
          cabinet_params = params['cabinet']
          
          # Convert string keys to symbols where needed
          type = cabinet_params['type'].to_sym
          frame_type = cabinet_params['frame_type'].to_sym
          
          # Handle door/drawer config
          config = cabinet_params['door_drawer_config']
          if config.is_a?(String) && (config.include?('+') || config.include?('drawer'))
            # Keep as string for mixed configs
          else
            config = config.to_sym
          end
          
          # Create cabinet options hash
          options = {
            frame_type: frame_type,
            width: cabinet_params['width'].to_f,
            depth: cabinet_params['depth'].to_f,
            height: cabinet_params['height'].to_f,
            door_drawer_config: config,
            has_countertop: cabinet_params['has_countertop'],
            has_backsplash: cabinet_params['has_backsplash']
          }
          
          # Add corner type if corner cabinet
          if type == :corner_base || type == :corner_wall
            options[:corner_type] = cabinet_params['corner_type'].to_sym
          end
          
          # Add seating side if island
          if type == :island
            options[:has_seating_side] = cabinet_params['has_seating_side']
          end
          
          # Create the cabinet
          puts "Creating cabinet with options: #{options.inspect}"
          cabinet = Cabinet.new(type, options)
          
          result = generator.generate_cabinet(cabinet)
          
          if result
            UI.messagebox("Cabinet created successfully!")
          else
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
