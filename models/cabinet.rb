# SketchUp Cabinet Builder - Cabinet Model
# Represents a single cabinet unit with all its specifications

module MikMort
  module CabinetBuilder
    
    class Cabinet
      
      attr_accessor :type, :frame_type, :width, :depth, :height
      attr_accessor :door_drawer_config, :has_countertop, :has_backsplash
      attr_accessor :corner_type, :has_seating_side, :position
      
      # Initialize a new cabinet
      # @param type [Symbol] :base, :wall, :island, :tall, :corner_base, :corner_wall, :floating
      # @param options [Hash] Configuration options
      def initialize(type, options = {})
        @type = type
        @frame_type = options[:frame_type] || :frameless
        
        # Set default dimensions based on type
        set_default_dimensions
        
        # Override with custom dimensions if provided
        @width = options[:width] || @width
        @depth = options[:depth] || @depth
        @height = options[:height] || @height
        
        # Door/Drawer configuration
        # Can be: :doors, :drawers, or mixed like "2 drawers + door"
        @door_drawer_config = options[:door_drawer_config] || :doors
        
        # Countertop and backsplash
        @has_countertop = options[:has_countertop] || false
        @has_backsplash = options[:has_backsplash] || false
        
        # Corner specific
        @corner_type = options[:corner_type] # :blind, :lazy_susan, :diagonal
        
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
        when :base, :island
          @height - Constants::BASE_CABINET[:toe_kick_height]
        when :subzero_fridge
          # Full height minus top clearance for ventilation
          @height - Constants::SUBZERO_FRIDGE[:clearance_top]
        when :miele_dishwasher
          # Full height minus toe kick (like base cabinet)
          @height - Constants::MIELE_DISHWASHER[:toe_kick_height]
        when :range
          # Full height (no reduction for ranges)
          @height
        else
          @height
        end
      end
      
      # Parse door/drawer configuration
      # Returns array of sections: [{type: :drawer, ratio: 0.3}, {type: :door, ratio: 0.7}]
      def parse_config
        if @door_drawer_config.is_a?(String)
          parse_mixed_config(@door_drawer_config)
        elsif @door_drawer_config.is_a?(Symbol)
          parse_simple_config(@door_drawer_config)
        else
          [{type: :door, ratio: 1.0}] # Default to full door
        end
      end
      
      private
      
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
        when :island
          @width = 36.0
          @depth = Constants::ISLAND_CABINET[:depth]
          @height = Constants::ISLAND_CABINET[:height]
        when :tall
          @width = 24.0
          @depth = Constants::TALL_CABINET[:depth]
          @height = Constants::TALL_CABINET[:height]
        when :corner_base
          @width = Constants::CORNER[:blind_width]
          @depth = Constants::CORNER[:blind_width]
          @height = Constants::BASE_CABINET[:height]
        when :corner_wall
          @width = Constants::CORNER[:blind_width]
          @depth = Constants::CORNER[:blind_width]
          @height = Constants::WALL_CABINET[:height_standard]
        when :floating
          @width = 24.0
          @depth = Constants::WALL_CABINET[:depth]
          @height = 36.0
        when :subzero_fridge
          # Default to 36" model (most common)
          @width = Constants::SUBZERO_FRIDGE[:width_36]
          @depth = Constants::SUBZERO_FRIDGE[:depth_36]
          @height = Constants::SUBZERO_FRIDGE[:height_36]
        when :miele_dishwasher
          @width = Constants::MIELE_DISHWASHER[:width]
          @depth = Constants::MIELE_DISHWASHER[:depth]
          @height = Constants::MIELE_DISHWASHER[:height]
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
        when :doors
          [{type: :door, ratio: 1.0, count: 2}] # Two doors by default
        when :drawers
          [{type: :drawer, ratio: 1.0, count: 3}] # Three drawers
        when :drawer_bank_3
          [{type: :drawer, ratio: 0.4, count: 2}, {type: :door, ratio: 0.6, count: 1}]
        when :drawer_bank_4
          [{type: :drawer, ratio: 0.45, count: 3}, {type: :door, ratio: 0.55, count: 1}]
        else
          [{type: :door, ratio: 1.0, count: 2}]
        end
      end
      
      # Parse mixed configuration string like "2 drawers + door"
      def parse_mixed_config(config_string)
        sections = []
        parts = config_string.downcase.split('+').map(&:strip)
        
        # Calculate total ratio
        total_parts = parts.length
        
        parts.each_with_index do |part, index|
          if part.include?('drawer')
            # Extract number if present (e.g., "2 drawers")
            count = part.match(/(\d+)/)
            count = count ? count[1].to_i : 1
            
            # Equal distribution for now
            ratio = 1.0 / total_parts
            sections << {type: :drawer, ratio: ratio, count: count}
          elsif part.include?('door')
            count = part.match(/(\d+)/)
            count = count ? count[1].to_i : 2 # Default 2 doors
            
            ratio = 1.0 / total_parts
            sections << {type: :door, ratio: ratio, count: count}
          end
        end
        
        sections.empty? ? [{type: :door, ratio: 1.0, count: 2}] : sections
      end
      
    end
    
  end
end
