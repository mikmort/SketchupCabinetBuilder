# SketchUp Cabinet Builder - Cabinet Run Model
# Represents a layout of multiple cabinets with auto-sizing and appliance gaps

module MikMort
  module CabinetBuilder
    
    class CabinetRun
      
      attr_reader :cabinets, :total_length, :appliance_gaps, :filler_strips
      
      # Initialize a new cabinet run
      # @param total_length [Float] Total length of the run in inches
      # @param options [Hash] Configuration options
      def initialize(total_length, options = {})
        @total_length = total_length
        @cabinet_type = options[:cabinet_type] || :base
        @frame_type = options[:frame_type] || :frameless
        @room_preset = options[:room_preset] || :kitchen
        @has_countertop = options[:has_countertop] || true
        @has_backsplash = options[:has_backsplash] || true
        
        @cabinets = []
        @appliance_gaps = options[:appliance_gaps] || [] # [{position: 48, width: 30, label: "Range"}]
        @filler_strips = []
      end
      
      # Auto-layout cabinets to fill the available space
      # Uses standard widths and calculates filler strips as needed
      def auto_layout
        @cabinets.clear
        @filler_strips.clear
        
        # Sort appliance gaps by position
        sorted_gaps = @appliance_gaps.sort_by { |gap| gap[:position] }
        
        # Split total length into sections around appliances
        sections = calculate_sections(sorted_gaps)
        
        current_position = 0
        
        sections.each do |section|
          # Add appliance gap if this section starts with one
          if section[:type] == :appliance
            current_position += section[:length]
          else
            # Fill section with cabinets
            cabinets_for_section = fill_section(section[:length], current_position)
            @cabinets.concat(cabinets_for_section)
            current_position += section[:length]
          end
        end
        
        @cabinets
      end
      
      # Add a specific cabinet to the run
      def add_cabinet(cabinet, position)
        cabinet.position = [position, 0, 0]
        @cabinets << cabinet
      end
      
      # Add an appliance gap
      def add_appliance_gap(position, width, label = "Appliance")
        @appliance_gaps << {position: position, width: width, label: label}
      end
      
      # Get total width including all cabinets and gaps
      def actual_width
        return 0 if @cabinets.empty? && @appliance_gaps.empty?
        
        max_position = 0
        
        @cabinets.each do |cabinet|
          cabinet_end = cabinet.position[0] + cabinet.width
          max_position = cabinet_end if cabinet_end > max_position
        end
        
        @appliance_gaps.each do |gap|
          gap_end = gap[:position] + gap[:width]
          max_position = gap_end if gap_end > max_position
        end
        
        max_position
      end
      
      # Check if layout is valid (doesn't exceed total length)
      def valid?
        actual_width <= @total_length
      end
      
      private
      
      # Calculate sections between appliances
      def calculate_sections(sorted_gaps)
        sections = []
        current_pos = 0
        
        sorted_gaps.each do |gap|
          # Add cabinet section before appliance
          if gap[:position] > current_pos
            sections << {
              type: :cabinets,
              start: current_pos,
              length: gap[:position] - current_pos
            }
          end
          
          # Add appliance gap
          sections << {
            type: :appliance,
            start: gap[:position],
            length: gap[:width],
            label: gap[:label]
          }
          
          current_pos = gap[:position] + gap[:width]
        end
        
        # Add final cabinet section after last appliance
        if current_pos < @total_length
          sections << {
            type: :cabinets,
            start: current_pos,
            length: @total_length - current_pos
          }
        end
        
        sections
      end
      
      # Fill a section with optimally-sized cabinets
      def fill_section(length, start_position)
        return [] if length <= 0
        
        cabinets = []
        remaining = length
        current_pos = start_position
        
        # Try to fill with standard widths (largest to smallest)
        sorted_widths = Constants::STANDARD_WIDTHS.sort.reverse
        
        while remaining > 0
          # Find largest standard width that fits
          selected_width = sorted_widths.find { |w| w <= remaining }
          
          if selected_width
            # Create cabinet with this width
            cabinet_options = {
              width: selected_width,
              frame_type: @frame_type,
              has_countertop: @has_countertop,
              has_backsplash: @has_backsplash,
              position: [current_pos, 0, 0]
            }
            
            # Apply room preset dimensions
            apply_room_preset(cabinet_options)
            
            cabinet = Cabinet.new(@cabinet_type, cabinet_options)
            cabinets << cabinet
            
            current_pos += selected_width
            remaining -= selected_width
          else
            # Remaining space is smaller than smallest standard width
            # Add as filler strip
            if remaining > 0.5 # Only add if more than 1/2 inch
              @filler_strips << {
                position: current_pos,
                width: remaining,
                height: get_cabinet_height
              }
            end
            break
          end
        end
        
        cabinets
      end
      
      # Apply room preset dimensions to cabinet options
      def apply_room_preset(options)
        preset = Constants::ROOM_PRESETS[@room_preset]
        return unless preset
        
        case @cabinet_type
        when :base
          options[:depth] ||= preset[:base_depth]
        when :wall
          options[:depth] ||= preset[:wall_depth]
          options[:height] ||= preset[:wall_height]
        end
      end
      
      # Get cabinet height based on type
      def get_cabinet_height
        case @cabinet_type
        when :base
          Constants::BASE_CABINET[:height]
        when :wall
          Constants::WALL_CABINET[:height_standard]
        when :tall
          Constants::TALL_CABINET[:height]
        else
          Constants::BASE_CABINET[:height]
        end
      end
      
    end
    
  end
end
