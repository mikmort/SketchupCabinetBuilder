# SketchUp Cabinet Builder - Material Manager
# Manages materials with room-specific naming for TwinMotion

module MikMort
  module CabinetBuilder
    
    class MaterialManager
      
      def initialize(model, room_name)
        @model = model
        @room_name = room_name.gsub(/[^a-zA-Z0-9]/, '_') # Sanitize room name
        @materials = {}
      end
      
      # Get or create a material by type
      def get_material(material_type)
        return @materials[material_type] if @materials[material_type]
        
        material_name = "#{material_type}_#{@room_name}"
        material = @model.materials[material_name]
        
        unless material
          material = @model.materials.add(material_name)
          apply_default_color(material, material_type)
        end
        
        @materials[material_type] = material
        material
      end
      
      # Material types
      def box_material
        get_material('Box')
      end
      
      def door_face_material
        get_material('DoorFace')
      end
      
      def drawer_face_material
        get_material('DrawerFace')
      end
      
      def interior_material
        get_material('Interior')
      end
      
      def countertop_material
        get_material('Countertop')
      end
      
      def hardware_material
        get_material('Hardware')
      end
      
      def edge_band_material
        get_material('EdgeBand')
      end
      
      private
      
      # Apply default colors for visualization (before TwinMotion)
      def apply_default_color(material, material_type)
        color = case material_type
        when 'Box'
          Constants::MATERIAL_COLORS[:box_wood]
        when 'DoorFace', 'DrawerFace'
          Constants::MATERIAL_COLORS[:door_face]
        when 'Interior'
          Constants::MATERIAL_COLORS[:interior]
        when 'Countertop'
          Constants::MATERIAL_COLORS[:countertop]
        when 'Hardware'
          Constants::MATERIAL_COLORS[:hardware]
        when 'EdgeBand'
          Constants::MATERIAL_COLORS[:box_wood] # Match box
        else
          [200, 200, 200] # Default gray
        end
        
        material.color = Sketchup::Color.new(color[0], color[1], color[2])
      end
      
    end
    
  end
end
