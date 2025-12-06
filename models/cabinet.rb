# SketchUp Cabinet Builder - Cabinet Model
# Represents a single cabinet unit with all its specifications

module MikMort
  module CabinetBuilder
    
    class Cabinet
      
      attr_accessor :type, :frame_type, :width, :depth, :height
      attr_accessor :door_drawer_config, :has_countertop, :has_backsplash
      attr_accessor :corner_type, :has_seating_side, :position, :height_from_floor
      attr_accessor :options
      
      # Initialize a new cabinet
      # @param type [Symbol] :base, :wall, :island, :tall, :corner_base, :corner_wall, :floating
      # @param options [Hash] Configuration options
      def initialize(type, options = {})
        @type = type
        @frame_type = options[:frame_type] || :frameless
        @options = options
        
        # Corner specific - set before default dimensions so size is correct
        @corner_type = options[:corner_type] # :inside_36, :inside_24, :outside_36, :outside_24
        
        # Set default dimensions based on type
        set_default_dimensions
        
        # Override with custom dimensions if provided
        # BUT NOT for corner cabinets - their dimensions are determined by corner_type
        unless @type == :corner_base || @type == :corner_wall
          @width = options[:width] || @width
          @depth = options[:depth] || @depth
        end
        @height = options[:height] || @height
        
        # Wall cabinet positioning
        @height_from_floor = options[:height_from_floor] || 54.0
        
        # Door/Drawer configuration
        # Can be: :doors, :drawers, or mixed like "2 drawers + door"
        @door_drawer_config = options[:door_drawer_config] || :doors
        
        # Countertop and backsplash
        @has_countertop = options[:has_countertop] || false
        @has_backsplash = options[:has_backsplash] || false
        
        # Island specific
        @has_seating_side = options[:has_seating_side] || false
        
        # Position in space (set by layout builder)
        @position = options[:position] || [0, 0, 0]
      end
      
      # Validate cabinet dimensions
      def valid?
        return false unless Constants::CABINET_TYPES.include?(@type)
        return false unless Constants::FRAME_TYPES.include?(@frame_type)
        return false if @width <= 0 || @depth <= 0 || @height <= 0
        
        # Validate corner type if corner cabinet
        if @type == :corner_base || @type == :corner_wall
          return false unless @corner_type && Constants::CORNER_TYPES.include?(@corner_type)
        end
        
        true
      end
      
      # Get effective interior width (accounting for frame if framed)
      def interior_width
        if @frame_type == :framed
          @width - (2 * Constants::FRAME[:width])
        else
          @width
        end
      end
      
      # Get effective interior depth
      def interior_depth
        if @frame_type == :framed
          @depth - Constants::FRAME[:width]
        else
          @depth
        end
      end
      
      # Get effective interior height
      def interior_height
        case @type
        when :base, :island, :corner_base, :miele_dishwasher
          @height - Constants::BASE_CABINET[:toe_kick_height]
        when :subzero_fridge
          # Full height minus top clearance for ventilation (series-specific)
          series = @options[:series] || :classic
          clearance = Constants::SUBZERO_FRIDGE[series][:clearance_top]
          @height - clearance
        when :range
          # Full height (no reduction for ranges)
          @height
        when :wall_oven
          # Full height for tall cabinet with oven
          @height
        else
          @height
        end
      end
      
      # Parse door/drawer configuration
      # Returns array of sections: [{type: :drawer, ratio: 0.3}, {type: :door, ratio: 0.7}]
      def parse_config
        puts "DEBUG parse_config: door_drawer_config=#{@door_drawer_config.inspect} (class: #{@door_drawer_config.class})"
        
        if @door_drawer_config.is_a?(String)
          # Try to convert string to symbol for known configs first
          config_sym = @door_drawer_config.to_sym
          if is_simple_config?(config_sym)
            puts "DEBUG: Using parse_simple_config for #{config_sym}"
            parse_simple_config(config_sym)
          else
            puts "DEBUG: Using parse_mixed_config for string: #{@door_drawer_config}"
            parse_mixed_config(@door_drawer_config)
          end
        elsif @door_drawer_config.is_a?(Symbol)
          puts "DEBUG: Using parse_simple_config for symbol #{@door_drawer_config}"
          parse_simple_config(@door_drawer_config)
        else
          [{type: :door, ratio: 1.0}] # Default to full door
        end
      end
      
      private
      
      # Check if config is a known simple config (not mixed like "2 drawers + door")
      def is_simple_config?(config_sym)
        simple_configs = [
          :door, :doors, :'1_drawer', :'2_drawers', :drawers, :'3_drawers', :'4_drawers', :'5_drawers',
          :'2_equal_drawers', :'3_equal_drawers', :'4_equal_drawers', :'1_drawer+door', :'2_drawers+door',
          :drawer_bank_3, :drawer_bank_4
        ]
        simple_configs.include?(config_sym)
      end
      
      # Set default dimensions based on cabinet type
      def set_default_dimensions
        case @type
        when :base
          @width = 24.0
          @depth = Constants::BASE_CABINET[:depth]
          @height = Constants::BASE_CABINET[:height]
        when :wall
          @width = 24.0
          @depth = Constants::WALL_CABINET[:depth]
          @height = Constants::WALL_CABINET[:height_standard]
        when :wall_stack
          @width = 24.0
          @depth = Constants::WALL_STACK[:depth]
          @height = Constants::WALL_STACK[:total_height]
        when :wall_stack_9ft
          @width = 24.0
          @depth = Constants::WALL_STACK_9FT[:depth]
          @height = Constants::WALL_STACK_9FT[:total_height]
        when :island
          @width = 36.0
          @depth = Constants::ISLAND_CABINET[:depth]
          @height = Constants::ISLAND_CABINET[:height]
        when :tall
          @width = 24.0
          @depth = Constants::TALL_CABINET[:depth]
          @height = Constants::TALL_CABINET[:height]
        when :corner_base
          # Size based on corner_type
          corner_size = case @corner_type
          when :inside_36, :outside_36, 'inside_36', 'outside_36' then 36.0
          when :inside_24, :outside_24, 'inside_24', 'outside_24' then 24.0
          else 36.0
          end
          @width = corner_size
          @depth = Constants::BASE_CABINET[:depth]
          @height = Constants::BASE_CABINET[:height]
        when :corner_wall
          # Size based on corner_type
          corner_size = case @corner_type
          when :inside_36, :outside_36, 'inside_36', 'outside_36' then 36.0
          when :inside_24, :outside_24, 'inside_24', 'outside_24' then 24.0
          else 36.0
          end
          @width = corner_size
          @depth = Constants::WALL_CABINET[:depth]
          @height = Constants::WALL_CABINET[:height_standard]
        when :floating
          @width = 24.0
          @depth = Constants::WALL_CABINET[:depth]
          @height = 36.0
        when :subzero_fridge
          # Default to 36" Classic series model (most common)
          series = @options[:series] || :classic
          series_data = Constants::SUBZERO_FRIDGE[series]
          @width = series_data[:width_36]
          @depth = series_data[:depth_36]
          @height = series_data[:height_36]
        when :miele_dishwasher
          @width = Constants::MIELE_DISHWASHER[:width]
          @depth = Constants::MIELE_DISHWASHER[:depth]
          @height = Constants::MIELE_DISHWASHER[:height]
        
        when :wall_oven
          # Default to tall cabinet with single oven opening
          @width = Constants::WALL_OVEN[:width]
          @depth = Constants::TALL_CABINET[:depth]
          @height = Constants::TALL_CABINET[:height]
        when :range
          # Default to 30" range (most common)
          @width = Constants::RANGE[:width_30]
          @depth = Constants::RANGE[:depth_30]
          @height = Constants::RANGE[:height_30]
        end
      end
      
      # Parse simple configuration (all doors or all drawers)
      def parse_simple_config(config)
        case config
        when :door
          [{type: :door, ratio: 1.0, count: 1}] # Single door
        when :doors
          # Check if single_door option is set (for split fridge/freezer units)
          door_count = (@options && @options[:single_door]) ? 1 : 2
          [{type: :door, ratio: 1.0, count: door_count}]
        when :'3_doors_graduated'
          [{type: :door, ratio: 1.0, count: 3}] # Three doors (graduated widths small to large)
        when :'1_drawer'
          [{type: :drawer, ratio: 1.0, count: 1, equal_sizing: true}] # Single large drawer
        when :'2_drawers', :'2_equal_drawers'
          [{type: :drawer, ratio: 1.0, count: 2, equal_sizing: true}] # Two equal drawers
        when :drawers, :'3_drawers'
          [{type: :drawer, ratio: 1.0, count: 3, equal_sizing: false}] # Three graduated drawers
        when :'4_drawers'
          [{type: :drawer, ratio: 1.0, count: 4, equal_sizing: false}] # Four graduated drawers
        when :'5_drawers'
          [{type: :drawer, ratio: 1.0, count: 5, equal_sizing: false}] # Five graduated drawers
        when :'3_equal_drawers'
          [{type: :drawer, ratio: 1.0, count: 3, equal_sizing: true}] # Three equal drawers
        when :'4_equal_drawers'
          [{type: :drawer, ratio: 1.0, count: 4, equal_sizing: true}] # Four equal drawers
        when :'custom_drawers'
          [{type: :drawer, ratio: 1.0, count: 0, equal_sizing: false, custom_heights: true}] # Custom drawer heights
        when :'1_drawer+door'
          [{type: :drawer, ratio: 0.3, count: 1, equal_sizing: true}, {type: :door, ratio: 0.7, count: 1}]
        when :'2_drawers+door'
          [{type: :drawer, ratio: 0.4, count: 2, equal_sizing: true}, {type: :door, ratio: 0.6, count: 1}]
        when :drawer_bank_3
          [{type: :drawer, ratio: 0.45, count: 3, equal_sizing: false}, {type: :door, ratio: 0.55, count: 1}]
        when :drawer_bank_4
          [{type: :drawer, ratio: 0.45, count: 3, equal_sizing: false}, {type: :door, ratio: 0.55, count: 1}]
        else
          [{type: :door, ratio: 1.0, count: 2}]
        end
      end
      
      # Parse mixed configuration string like "2 drawers + door" or "door+1_custom_drawers"
      def parse_mixed_config(config_string)
        puts "DEBUG parse_mixed_config: input=#{config_string.inspect}"
        sections = []
        parts = config_string.downcase.split('+').map(&:strip)
        puts "DEBUG: split parts=#{parts.inspect}"
        
        # Check if we have custom drawer heights
        custom_heights = @options && @options[:custom_drawer_heights]
        has_custom = parts.any? { |p| p.include?('custom') }
        
        # Calculate ratios based on custom heights if available
        if has_custom && custom_heights && !custom_heights.empty?
          # Calculate total height from custom drawer heights
          total_drawer_height = custom_heights.sum
          available_height = interior_height
          
          parts.each do |part|
            if part.include?('drawer')
              # Extract number of drawers
              count = part.match(/(\d+)/)
              count = count ? count[1].to_i : 1
              
              ratio = total_drawer_height / available_height
              sections << {type: :drawer, ratio: ratio, count: count, custom_heights: true}
            elsif part.include?('door')
              count = part.match(/(\d+)/)
              count = count ? count[1].to_i : 1 # Default 1 door when mixed
              
              # Door gets the remaining height
              ratio = 1.0 - (total_drawer_height / available_height)
              sections << {type: :door, ratio: ratio, count: count}
            end
          end
        else
          # Equal distribution when no custom heights
          total_parts = parts.length
          
          parts.each do |part|
            if part.include?('drawer')
              count = part.match(/(\d+)/)
              count = count ? count[1].to_i : 1
              
              ratio = 1.0 / total_parts
              sections << {type: :drawer, ratio: ratio, count: count}
            elsif part.include?('door')
              count = part.match(/(\d+)/)
              count = count ? count[1].to_i : 1 # Default 1 door when mixed
              
              ratio = 1.0 / total_parts
              sections << {type: :door, ratio: ratio, count: count}
            end
          end
        end
        
        puts "DEBUG: parse_mixed_config result=#{sections.inspect}"
        sections.empty? ? [{type: :door, ratio: 1.0, count: 2}] : sections
      end
      
    end
    
  end
end
