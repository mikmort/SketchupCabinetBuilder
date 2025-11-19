# SketchUp Cabinet Builder - Door and Drawer Builder
# Generates doors and drawers with proper spacing and hardware

module MikMort
  module CabinetBuilder
    module Geometry
      
      class DoorDrawerBuilder
        
        def initialize(model, material_manager)
          @model = model
          @materials = material_manager
        end
        
        # Build doors and/or drawers based on cabinet configuration
        # @param cabinet [Cabinet] The cabinet specification
        # @param fronts_group [Sketchup::Group] Fronts group for door/drawer faces
        # @param hardware_group [Sketchup::Group] Hardware group for handles/pulls
        # @return [Array<Sketchup::Group>] Array of door/drawer groups
        def build(cabinet, fronts_group, hardware_group)
          begin
            config_sections = cabinet.parse_config
            
            # Calculate available height for doors/drawers
            available_height = cabinet.interior_height
            
            # Account for frame if framed cabinet
            frame_offset = cabinet.frame_type == :framed ? Constants::FRAME[:width] : 0
            
            current_z = frame_offset
            
            config_sections.each do |section|
              section_height = available_height * section[:ratio]
              
              if section[:type] == :drawer
                build_drawers(fronts_group, hardware_group, cabinet, section[:count], current_z, section_height)
              else
                # Determine door count based on cabinet width
                door_count = (cabinet.width > 30) ? 2 : 1
                build_doors(fronts_group, hardware_group, cabinet, door_count, current_z, section_height)
              end
              
              current_z += section_height
            end
          rescue => e
            puts "Error building doors/drawers: #{e.message}"
            puts e.backtrace.first(5).join("\n")
          end
        end
        
        private
        
        # Build doors
        def build_doors(fronts_group, hardware_group, cabinet, door_count, start_z, total_height)
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          overlay = cabinet.frame_type == :framed ? Constants::DOOR_DRAWER[:overlay].inch : 0
          
          width = cabinet.width.inch
          depth = cabinet.depth.inch
          
          # For multiple doors, calculate width accounting for reveals
          total_reveal_width = reveal * (door_count + 1)
          door_width = (width - total_reveal_width) / door_count
          door_height = total_height.inch - (2 * reveal)
          
          # Position doors flush with front of cabinet box (at y=0)
          door_z = start_z.inch + reveal
          door_y = 0  # Flush with front of cabinet box
          
          # Create each door in its own named group
          (0...door_count).each do |i|
            door_x = reveal + (i * (door_width + reveal))
            
            # Create door group with descriptive name
            door_group = fronts_group.entities.add_group
            door_name = door_count > 1 ? "Door #{i == 0 ? 'Left' : 'Right'}" : "Door"
            door_group.name = door_name
            
            # Create door panel in door group
            create_door_panel(door_group.entities, 
                            [door_x, door_y, door_z],
                            door_width, thickness, door_height,
                            @materials.door_face_material)
            
            # Add hardware to hardware group
            add_door_handle(hardware_group.entities, door_x, door_y, door_z, 
                           door_width, door_height, thickness, i == 0 ? :right : :left, i + 1)
          end
        end
        
        # Build drawers
        def build_drawers(parent_group, cabinet, drawer_count, start_z, total_height)
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          overlay = cabinet.frame_type == :framed ? Constants::DOOR_DRAWER[:overlay].inch : 0
          
          width = cabinet.width.inch
          depth = cabinet.depth.inch
          
          # Calculate individual drawer heights
          # Use graduated sizing if more than 2 drawers
          drawer_heights = calculate_drawer_heights(drawer_count, total_height)
          
          current_z = start_z
          
          drawer_heights.each_with_index do |drawer_height, i|
            drawer_height_inch = drawer_height.inch
            
            # Create drawer front directly in parent (NO sub-group)
            drawer_x = reveal
            drawer_y = -thickness - overlay
            drawer_z = current_z.inch + reveal
            
            drawer_width = width - (2 * reveal)
            actual_drawer_height = drawer_height_inch - (2 * reveal)
            
            # Drawer face directly in parent
            create_door_panel(parent_group.entities,
                            [drawer_x, drawer_y, drawer_z],
                            drawer_width, thickness, actual_drawer_height,
                            @materials.drawer_face_material)
            
            # Add drawer box directly
            add_drawer_box(parent_group.entities, drawer_x, drawer_y + thickness,
                          drawer_z, drawer_width, depth * 0.75, actual_drawer_height)
            
            # Add drawer pull directly
            add_drawer_handle(parent_group.entities, drawer_x, drawer_y, drawer_z,
                            drawer_width, actual_drawer_height, thickness)
            
            # Add drawer slides (simplified)
            add_drawer_slides(drawer_group.entities, drawer_x, drawer_y + thickness,
                            drawer_z, drawer_width, depth * 0.75, actual_drawer_height)
            
            current_z += drawer_height
          end
        end
        
        # Calculate graduated drawer heights
        def calculate_drawer_heights(count, total_height)
          heights = []
          
          case count
          when 1
            heights = [total_height]
          when 2
            heights = [total_height * 0.45, total_height * 0.55]
          when 3
            heights = [total_height * 0.25, total_height * 0.30, total_height * 0.45]
          when 4
            heights = [total_height * 0.20, total_height * 0.25, total_height * 0.25, total_height * 0.30]
          else
            # Equal distribution
            heights = Array.new(count, total_height / count.to_f)
          end
          
          heights
        end
        
        # Create a door/drawer face panel
        # IMPORTANT: Don't use pushpull - it causes SketchUp to delete parent groups!
        def create_door_panel(entities, origin, width, thickness, height, material)
          x, y, z = origin
          
          # Skip if dimensions are invalid
          return nil if width.abs < 0.001 || height.abs < 0.001 || thickness.abs < 0.001
          
          begin
            # Create a 3D box manually without pushpull (to avoid SketchUp bug)
            # Front face
            front_pts = [
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x + width, y, z),
              Geom::Point3d.new(x + width, y, z + height),
              Geom::Point3d.new(x, y, z + height)
            ]
            front_face = entities.add_face(front_pts)
            front_face.material = material if front_face && material
            
            # Back face (offset by thickness)
            back_y = y - thickness
            back_pts = [
              Geom::Point3d.new(x, back_y, z),
              Geom::Point3d.new(x, back_y, z + height),
              Geom::Point3d.new(x + width, back_y, z + height),
              Geom::Point3d.new(x + width, back_y, z)
            ]
            back_face = entities.add_face(back_pts)
            back_face.material = @materials.interior_material if back_face
            
            # Side faces to close the box
            # Left side
            entities.add_face([
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x, y, z + height),
              Geom::Point3d.new(x, back_y, z + height),
              Geom::Point3d.new(x, back_y, z)
            ])
            
            # Right side
            entities.add_face([
              Geom::Point3d.new(x + width, y, z),
              Geom::Point3d.new(x + width, back_y, z),
              Geom::Point3d.new(x + width, back_y, z + height),
              Geom::Point3d.new(x + width, y, z + height)
            ])
            
            # Top edge
            entities.add_face([
              Geom::Point3d.new(x, y, z + height),
              Geom::Point3d.new(x + width, y, z + height),
              Geom::Point3d.new(x + width, back_y, z + height),
              Geom::Point3d.new(x, back_y, z + height)
            ])
            
            # Bottom edge
            entities.add_face([
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x, back_y, z),
              Geom::Point3d.new(x + width, back_y, z),
              Geom::Point3d.new(x + width, y, z)
            ])
            
            front_face
          rescue => e
            puts "Error creating door panel: #{e.message}"
            nil
          end
        end
        
        # Add hinges to a door
        def add_hinges(entities, door_x, door_y, door_z, door_height, side)
          hinge_width = Constants::DOOR_DRAWER[:hinge_width].inch
          hinge_height = Constants::DOOR_DRAWER[:hinge_height].inch
          
          # Place hinges at top and bottom (offset from edges)
          hinge_positions = [
            door_z + 3.inch,                    # Top hinge
            door_z + door_height - 3.inch       # Bottom hinge
          ]
          
          # Add middle hinge if door is tall
          if door_height > 36.inch
            hinge_positions.insert(1, door_z + door_height / 2)
          end
          
          hinge_positions.each_with_index do |z_pos, i|
            x_pos = side == :left ? door_x - 0.25.inch : door_x + hinge_width + 0.25.inch
            
            # Simplified hinge representation (small cylinder + plate)
            add_hinge(entities, x_pos, door_y, z_pos, side)
          end
        end
        
        # Add a single hinge
        def add_hinge(entities, x, y, z, side)
          # DISABLED: pushpull operations delete parent groups
          return
          begin
            hinge_height = Constants::DOOR_DRAWER[:hinge_height].inch
            
            # Cylinder for hinge pin
            center = Geom::Point3d.new(x, y, z + hinge_height / 2)
            circle = entities.add_circle(center, [1, 0, 0], 0.25.inch, 12)
            if circle && circle.length > 0
              face = entities.add_face(circle)
              if face && face.valid?
                face.material = @materials.hardware_material
                face.pushpull(1.inch)
              end
            end
          rescue => e
            puts "Error creating hinge: #{e.message}"
          end
        end
        
        # Add door handle
        def add_door_handle(entities, door_x, door_y, door_z, door_width, door_height, door_thickness, side)
          begin
            # Create small marker cube for hardware placement
            marker_size = 0.5.inch
            
            # Position marker
            handle_z = door_z + door_height / 2 - marker_size / 2
            handle_x = side == :left ? door_x + 2.inch : door_x + door_width - 2.inch - marker_size
            handle_y = door_y - marker_size
            
            # Create marker cube
            pts = [
              Geom::Point3d.new(handle_x, handle_y, handle_z),
              Geom::Point3d.new(handle_x + marker_size, handle_y, handle_z),
              Geom::Point3d.new(handle_x + marker_size, handle_y, handle_z + marker_size),
              Geom::Point3d.new(handle_x, handle_y, handle_z + marker_size)
            ]
            
            front_face = entities.add_face(pts)
            if front_face && front_face.valid?
              front_face.material = @materials.hardware_material
              
              # Create back face
              back_y = handle_y - marker_size
              back_pts = [
                Geom::Point3d.new(handle_x, back_y, handle_z),
                Geom::Point3d.new(handle_x, back_y, handle_z + marker_size),
                Geom::Point3d.new(handle_x + marker_size, back_y, handle_z + marker_size),
                Geom::Point3d.new(handle_x + marker_size, back_y, handle_z)
              ]
              entities.add_face(back_pts)
              
              # Create side faces
              entities.add_face([pts[0], pts[1], back_pts[3], back_pts[0]])
              entities.add_face([pts[1], pts[2], back_pts[2], back_pts[3]])
              entities.add_face([pts[2], pts[3], back_pts[1], back_pts[2]])
              entities.add_face([pts[3], pts[0], back_pts[0], back_pts[1]])
            end
          rescue => e
            puts "Error creating door handle marker: #{e.message}"
          end
        end
        
        # Add drawer handle
        def add_drawer_handle(entities, drawer_x, drawer_y, drawer_z, drawer_width, drawer_height, drawer_thickness)
          begin
            # Create small marker cube for hardware placement
            marker_size = 0.5.inch
            
            # Position marker at center top of drawer
            handle_x = drawer_x + drawer_width / 2 - marker_size / 2
            handle_y = drawer_y - marker_size
            handle_z = drawer_z + drawer_height - 2.inch - marker_size / 2
            
            # Create marker cube
            pts = [
              Geom::Point3d.new(handle_x, handle_y, handle_z),
              Geom::Point3d.new(handle_x + marker_size, handle_y, handle_z),
              Geom::Point3d.new(handle_x + marker_size, handle_y, handle_z + marker_size),
              Geom::Point3d.new(handle_x, handle_y, handle_z + marker_size)
            ]
            
            front_face = entities.add_face(pts)
            if front_face && front_face.valid?
              front_face.material = @materials.hardware_material
              
              # Create back face
              back_y = handle_y - marker_size
              back_pts = [
                Geom::Point3d.new(handle_x, back_y, handle_z),
                Geom::Point3d.new(handle_x, back_y, handle_z + marker_size),
                Geom::Point3d.new(handle_x + marker_size, back_y, handle_z + marker_size),
                Geom::Point3d.new(handle_x + marker_size, back_y, handle_z)
              ]
              entities.add_face(back_pts)
              
              # Create side faces
              entities.add_face([pts[0], pts[1], back_pts[3], back_pts[0]])
              entities.add_face([pts[1], pts[2], back_pts[2], back_pts[3]])
              entities.add_face([pts[2], pts[3], back_pts[1], back_pts[2]])
              entities.add_face([pts[3], pts[0], back_pts[0], back_pts[1]])
            end
          rescue => e
            puts "Error creating drawer handle marker: #{e.message}"
          end
        end
        
        # Add simplified drawer box (DISABLED - uses pushpull)
        def add_drawer_box(entities, x, y, z, width, depth, height)
          # DISABLED: pushpull operations delete parent groups
          return
          begin
            box_thickness = 0.5.inch
            
            # Bottom
            pts = [
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x + width, y, z),
              Geom::Point3d.new(x + width, y + depth, z),
              Geom::Point3d.new(x, y + depth, z)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.interior_material
              face.pushpull(box_thickness)
            end
            
            # Sides (simplified)
            # Left side
            pts = [
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x, y + depth, z),
              Geom::Point3d.new(x, y + depth, z + height),
              Geom::Point3d.new(x, y, z + height)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.interior_material
              face.pushpull(box_thickness)
            end
            
            # Right side
            pts = [
              Geom::Point3d.new(x + width - box_thickness, y, z),
              Geom::Point3d.new(x + width - box_thickness, y + depth, z),
              Geom::Point3d.new(x + width - box_thickness, y + depth, z + height),
              Geom::Point3d.new(x + width - box_thickness, y, z + height)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.interior_material
              face.pushpull(box_thickness)
            end
          rescue => e
            puts "Error creating drawer box: #{e.message}"
          end
        end
        
        # Add simplified drawer slides
        def add_drawer_slides(entities, x, y, z, width, depth, height)
          begin
            slide_height = 0.5.inch
            slide_thickness = 0.125.inch
            
            # Left slide
            pts = [
              Geom::Point3d.new(x, y, z + height/2 - slide_height/2),
              Geom::Point3d.new(x, y + depth, z + height/2 - slide_height/2),
              Geom::Point3d.new(x, y + depth, z + height/2 + slide_height/2),
              Geom::Point3d.new(x, y, z + height/2 + slide_height/2)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.hardware_material
              face.pushpull(-slide_thickness)
            end
            
            # Right slide
            pts = [
              Geom::Point3d.new(x + width, y, z + height/2 - slide_height/2),
              Geom::Point3d.new(x + width, y + depth, z + height/2 - slide_height/2),
              Geom::Point3d.new(x + width, y + depth, z + height/2 + slide_height/2),
              Geom::Point3d.new(x + width, y, z + height/2 + slide_height/2)
            ]
            face = entities.add_face(pts)
            if face && face.valid?
              face.material = @materials.hardware_material
              face.pushpull(-slide_thickness)
            end
          rescue => e
            puts "Error creating drawer slides: #{e.message}"
          end
        end
        
      end
      
    end
  end
end
