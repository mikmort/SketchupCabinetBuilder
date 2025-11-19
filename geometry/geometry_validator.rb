# SketchUp Cabinet Builder - Geometry Validator
# Validates generated geometry against expected dimensions

module MikMort
  module CabinetBuilder
    
    class GeometryValidator
      
      def initialize
        @results = []
      end
      
      # Validate a cabinet's geometry
      def validate_cabinet(cabinet, cabinet_group)
        @results = []
        puts "\n=== GEOMETRY VALIDATION ==="
        puts "Cabinet Type: #{cabinet.type}"
        puts "Dimensions: #{cabinet.width}\" x #{cabinet.depth}\" x #{cabinet.height}\""
        
        # Expected dimensions
        expected = calculate_expected_dimensions(cabinet)
        puts "\n--- Expected Dimensions ---"
        expected.each { |k, v| puts "  #{k}: #{v}" }
        
        # Actual dimensions
        actual = measure_actual_geometry(cabinet_group)
        puts "\n--- Actual Measurements ---"
        actual.each { |k, v| puts "  #{k}: #{v}" }
        
        # Compare
        puts "\n--- Validation Results ---"
        compare_dimensions(expected, actual)
        
        # Print summary
        puts "\n--- Summary ---"
        errors = @results.select { |r| r[:status] == :error }
        warnings = @results.select { |r| r[:status] == :warning }
        
        if errors.empty? && warnings.empty?
          puts "✓ All checks passed!"
        else
          puts "✗ #{errors.count} errors, #{warnings.count} warnings"
          @results.each do |r|
            status_icon = r[:status] == :error ? "✗" : "⚠"
            puts "  #{status_icon} #{r[:message]}"
          end
        end
        
        puts "=========================\n"
        
        @results
      end
      
      private
      
      # Calculate what dimensions SHOULD be
      def calculate_expected_dimensions(cabinet)
        t = Constants::BASE_CABINET[:panel_thickness]
        
        expected = {
          "Cabinet Total Height" => "#{cabinet.height}\"",
          "Cabinet Interior Height" => "#{cabinet.interior_height}\"",
          "Box Bottom (z)" => "0\"",
          "Box Top (z)" => "#{cabinet.interior_height}\"",
          "Box Side Height" => "#{cabinet.interior_height}\"",
          "Bottom Panel Thickness" => "#{t}\"",
          "Side Panel Thickness" => "#{t}\""
        }
        
        if cabinet.type == :base || cabinet.type == :island
          kick_height = Constants::BASE_CABINET[:toe_kick_height]
          expected["Toe Kick Height"] = "#{kick_height}\""
          expected["Toe Kick Bottom (z)"] = "0\""
          expected["Toe Kick Top (z)"] = "#{kick_height}\""
        end
        
        if cabinet.has_countertop
          expected["Countertop Bottom (z)"] = "#{cabinet.interior_height}\""
          ct_thickness = Constants::COUNTERTOP[:thickness]
          expected["Countertop Top (z)"] = "#{cabinet.interior_height + ct_thickness}\""
        end
        
        # Door dimensions
        if cabinet.door_drawer_config == :doors
          door_count = (cabinet.width > 30) ? 2 : 1
          reveal = Constants::DOOR_DRAWER[:reveal]
          door_width = (cabinet.width - reveal * (door_count + 1)) / door_count
          
          expected["Door Count"] = door_count.to_s
          expected["Door Width"] = "#{door_width.round(3)}\""
          expected["Door Height"] = "#{cabinet.interior_height - 2 * reveal}\""
          expected["Door Reveal"] = "#{reveal}\""
          expected["Door Y Position"] = "-#{t}\""
        end
        
        expected
      end
      
      # Measure actual generated geometry
      def measure_actual_geometry(cabinet_group)
        actual = {}
        
        # Get bounding box of entire cabinet
        bbox = cabinet_group.bounds
        actual["Cabinet BBox Width"] = format_dim(bbox.width)
        actual["Cabinet BBox Depth"] = format_dim(bbox.depth)
        actual["Cabinet BBox Height"] = format_dim(bbox.height)
        actual["Cabinet BBox Min Z"] = format_dim(bbox.min.z)
        actual["Cabinet BBox Max Z"] = format_dim(bbox.max.z)
        
        # Find specific components
        cabinet_group.entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group)
          
          case entity.name
          when "Box"
            measure_box(entity, actual)
          when "Doors"
            measure_doors(entity, actual)
          when "Countertop"
            measure_countertop(entity, actual)
          end
        end
        
        actual
      end
      
      # Measure box geometry
      def measure_box(box_group, actual)
        bbox = box_group.bounds
        actual["Box BBox Height"] = format_dim(bbox.height)
        actual["Box BBox Min Z"] = format_dim(bbox.min.z)
        actual["Box BBox Max Z"] = format_dim(bbox.max.z)
        
        # Try to find specific faces
        min_z = Float::INFINITY
        max_z = -Float::INFINITY
        
        box_group.entities.each do |entity|
          if entity.is_a?(Sketchup::Face)
            entity.vertices.each do |vertex|
              z = vertex.position.z
              min_z = z if z < min_z
              max_z = z if z > max_z
            end
          end
        end
        
        actual["Box Face Min Z"] = format_dim(min_z) if min_z != Float::INFINITY
        actual["Box Face Max Z"] = format_dim(max_z) if max_z != -Float::INFINITY
      end
      
      # Measure door geometry
      def measure_doors(door_group, actual)
        door_count = 0
        door_positions = []
        door_widths = []
        door_heights = []
        
        door_group.entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group)
          next unless entity.name.start_with?("Door")
          
          door_count += 1
          bbox = entity.bounds
          door_widths << bbox.width
          door_heights << bbox.height
          door_positions << bbox.min.y
        end
        
        actual["Actual Door Count"] = door_count.to_s
        if door_count > 0
          actual["Door Width (avg)"] = format_dim(door_widths.sum / door_count)
          actual["Door Height (avg)"] = format_dim(door_heights.sum / door_count)
          actual["Door Y Position (min)"] = format_dim(door_positions.min)
        end
      end
      
      # Measure countertop geometry
      def measure_countertop(ct_group, actual)
        bbox = ct_group.bounds
        actual["Countertop BBox Min Z"] = format_dim(bbox.min.z)
        actual["Countertop BBox Max Z"] = format_dim(bbox.max.z)
        actual["Countertop Thickness"] = format_dim(bbox.height)
      end
      
      # Compare expected vs actual
      def compare_dimensions(expected, actual)
        # Map expected keys to actual keys
        comparisons = [
          ["Box Top (z)", "Box BBox Max Z", "Box height"],
          ["Box Bottom (z)", "Box BBox Min Z", "Box bottom position"],
          ["Door Count", "Actual Door Count", "Door count"],
          ["Countertop Bottom (z)", "Countertop BBox Min Z", "Countertop position"]
        ]
        
        comparisons.each do |exp_key, act_key, desc|
          next unless expected[exp_key] && actual[act_key]
          
          exp_val = parse_dim(expected[exp_key])
          act_val = parse_dim(actual[act_key])
          
          diff = (act_val - exp_val).abs
          
          if diff < 0.01
            @results << { status: :pass, message: "#{desc} correct (#{actual[act_key]})" }
          elsif diff < 0.1
            @results << { status: :warning, message: "#{desc} slightly off: expected #{expected[exp_key]}, got #{actual[act_key]} (diff: #{format_dim(diff)})" }
          else
            @results << { status: :error, message: "#{desc} WRONG: expected #{expected[exp_key]}, got #{actual[act_key]} (diff: #{format_dim(diff)})" }
          end
        end
      end
      
      # Format dimension in inches
      def format_dim(value)
        return "N/A" unless value.is_a?(Numeric)
        "#{(value / 1.inch).round(3)}\""
      end
      
      # Parse dimension string to numeric (in SketchUp units)
      def parse_dim(str)
        return 0 unless str.is_a?(String)
        str.gsub('"', '').to_f.inch
      end
      
    end
    
  end
end
