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
            puts "DEBUG: DoorDrawerBuilder.build called. Cabinet type: #{cabinet.type.inspect} (#{cabinet.type.class})"
            
            # Special handling for wall stack - create doors for each section
            if cabinet.type == :wall_stack || cabinet.type == :wall_stack_9ft || cabinet.type.to_s == 'wall_stack' || cabinet.type.to_s == 'wall_stack_9ft'
              build_wall_stack_doors(cabinet, fronts_group, hardware_group)
              return
            end
            
            # Special handling for corner cabinets - create doors on two faces
            if cabinet.type == :corner_base || cabinet.type == :corner_wall || cabinet.type.to_s == 'corner_base' || cabinet.type.to_s == 'corner_wall'
              puts "DEBUG: Detected corner cabinet. Calling build_corner_doors."
              build_corner_doors(cabinet, fronts_group, hardware_group)
              return
            end
            
            # Special handling for display cabinets - glass doors with frame
            if cabinet.type == :display_base || cabinet.type == :display_wall
              puts "DEBUG: Detected display cabinet. Calling build_display_doors."
              build_display_doors(cabinet, fronts_group, hardware_group)
              return
            end
            
            config_sections = cabinet.parse_config
            
            # Calculate available height for doors/drawers
            available_height = cabinet.interior_height
            
            # Account for frame if framed cabinet
            frame_offset = cabinet.frame_type == :framed ? Constants::FRAME[:width] : 0

            toe_kick_offset = toe_kick_base_offset(cabinet)
            current_z = frame_offset + toe_kick_offset
            
            puts "DEBUG: config_sections=#{config_sections.inspect}"
            
            config_sections.each do |section|
              section_height = available_height * section[:ratio]
              
              puts "DEBUG: Processing section: type=#{section[:type]}, ratio=#{section[:ratio]}, count=#{section[:count]}, section_height=#{section_height}"
              
              if section[:type] == :drawer
                equal_sizing = section[:equal_sizing] || false
                custom_heights = section[:custom_heights] ? cabinet.options[:custom_drawer_heights] : nil
                drawer_count = custom_heights ? custom_heights.length : section[:count]
                build_drawers(fronts_group, hardware_group, cabinet, drawer_count, current_z, section_height, equal_sizing, custom_heights)
              else
                door_count = section[:count]
                graduated = (cabinet.door_drawer_config == :'3_doors_graduated')
                build_doors(fronts_group, hardware_group, cabinet, door_count, current_z, section_height, graduated)
              end
              
              current_z += section_height
            end
          rescue => e
            puts "Error building doors/drawers: #{e.message}"
            puts e.backtrace.first(5).join("\n")
          end
        end
        
        private
        
        # Build doors for corner cabinets (TRUE L-SHAPED with bi-fold doors)
        def build_corner_doors(cabinet, fronts_group, hardware_group)
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          
          # Determine corner size from corner_type
          corner_size = case cabinet.corner_type
          when :inside_36, :outside_36 then 36.0
          when :inside_24, :outside_24 then 24.0
          else 36.0
          end
          
          is_inside = cabinet.corner_type.to_s.start_with?('inside')
          
          toe_kick_offset = toe_kick_base_offset(cabinet)
          door_height = cabinet.interior_height.inch - (2 * reveal)
          door_z = reveal + toe_kick_offset
          
          size = corner_size.inch
          cutout = 12.inch
          shift_y = -12.inch
          
          if is_inside
            puts "DEBUG: Building Inside Corner Doors"
            # TRUE L-SHAPED corner (Cutout at Front-Left)
            # Door 1: Back Leg Front (Y=12, X=0 to 12)
            # Door 2: Right Leg Side (X=12, Y=0 to 12)
            
            entities = fronts_group.entities
            
            # Door 1: Left Leg Front (at Y=0)
            # Width = 12" (minus reveals)
            # Reduce width to avoid collision with Door 2
            # Door 2 is at X=12. Door 1 should stop before X=12.
            # Let's stop at X=11.25 (cutout - thickness)
            door1_width = cutout - thickness - (2 * reveal)
            # Position at the front face (Y = cutout + shift_y)
            # For overlay, it sits in front (negative Y direction)
            door1_y = cutout + shift_y
            
            puts "DEBUG: Door 1: y=#{door1_y}, width=#{door1_width}"
            
            door1_pts = [
              Geom::Point3d.new(reveal, door1_y, door_z),
              Geom::Point3d.new(cutout - thickness - reveal, door1_y, door_z),
              Geom::Point3d.new(cutout - thickness - reveal, door1_y, door_z + door_height),
              Geom::Point3d.new(reveal, door1_y, door_z + door_height)
            ]
            face1 = entities.add_face(door1_pts)
            if face1 && face1.valid?
              face1.material = @materials.drawer_face_material
              face1.back_material = @materials.drawer_face_material
              face1.pushpull(thickness)
              puts "DEBUG: Door 1 created successfully"
            else
              puts "DEBUG: Door 1 creation failed"
            end
            
            # Door 2: Right Leg Side (at X=12)
            # This door covers the side of the Right Leg (Y=0 to -12)
            # It sits in front of the carcass (at X=12)
            # So Door Front is at X=11.25 (Overlay)
            
            # Width is the length along Y (12")
            door2_width = cutout - (2 * reveal) # 12" width
            door2_x = cutout - thickness # X = 11.25
            door2_y = 0 + shift_y + reveal # Y = -12 + reveal
            
            puts "DEBUG: Door 2 (Side): x=#{door2_x}, y=#{door2_y}, width=#{door2_width}, z=#{door_z}, h=#{door_height}"
            
            # Create door as a simple box
            # Front face at X = 11.25
            # Back face at X = 12
            
            d2_front_x = door2_x
            d2_back_x = door2_x + thickness
            
            # Points for the Front Face (in Y-Z plane)
            # Y goes from -12 to 0
            # Z goes from bottom to top
            
            # Front Face (X=11.25)
            f1 = entities.add_face([
              [d2_front_x, door2_y, door_z],
              [d2_front_x, door2_y + door2_width, door_z],
              [d2_front_x, door2_y + door2_width, door_z + door_height],
              [d2_front_x, door2_y, door_z + door_height]
            ])
            f1.material = @materials.drawer_face_material
            f1.back_material = @materials.drawer_face_material
            
            # Back Face (X=12.75)
            f2 = entities.add_face([
              [d2_back_x, door2_y, door_z],
              [d2_back_x, door2_y + door2_width, door_z],
              [d2_back_x, door2_y + door2_width, door_z + door_height],
              [d2_back_x, door2_y, door_z + door_height]
            ])
            f2.material = @materials.drawer_face_material
            f2.back_material = @materials.drawer_face_material
            
            # Top Face
            f3 = entities.add_face([
              [d2_front_x, door2_y, door_z + door_height],
              [d2_back_x, door2_y, door_z + door_height],
              [d2_back_x, door2_y + door2_width, door_z + door_height],
              [d2_front_x, door2_y + door2_width, door_z + door_height]
            ])
            f3.material = @materials.drawer_face_material
            
            # Bottom Face
            f4 = entities.add_face([
              [d2_front_x, door2_y, door_z],
              [d2_back_x, door2_y, door_z],
              [d2_back_x, door2_y + door2_width, door_z],
              [d2_front_x, door2_y + door2_width, door_z]
            ])
            f4.material = @materials.drawer_face_material
            
            # Left Side (Y = -12)
            f5 = entities.add_face([
              [d2_front_x, door2_y, door_z],
              [d2_back_x, door2_y, door_z],
              [d2_back_x, door2_y, door_z + door_height],
              [d2_front_x, door2_y, door_z + door_height]
            ])
            f5.material = @materials.drawer_face_material
            
            # Right Side (Y = 0)
            f6 = entities.add_face([
              [d2_front_x, door2_y + door2_width, door_z],
              [d2_back_x, door2_y + door2_width, door_z],
              [d2_back_x, door2_y + door2_width, door_z + door_height],
              [d2_front_x, door2_y + door2_width, door_z + door_height]
            ])
            f6.material = @materials.drawer_face_material
            
            puts "DEBUG: Door 2 created manually (Side, 6 faces)"
          else
            # Outside corner: doors wrap around the outside
            
            # 1. Front "Fake" Door (X wing front face)
            # No handle, just a panel
            # Full width of the front face (36")
            x_door_width = corner_size.inch - (2 * reveal)
            
            create_corner_door(fronts_group, hardware_group,
              reveal, 0, door_z,
              x_door_width, door_height, thickness, :front, false) # has_handle = false
            
            # 2. Right "Real" Door (Y wing right side) - FULL WIDTH
            # Spans from Y=0 to Y=size (36")
            # Has handle
            y_door_width = corner_size.inch - (2 * reveal)
            
            # Position: X=size (36), Y=reveal, Z=door_z
            create_corner_door(fronts_group, hardware_group,
              size, reveal, door_z,
              y_door_width, door_height, thickness, :right, true) # has_handle = true
          end
        end
        
        # Create a door panel for corner cabinets with specified orientation
        def create_corner_door(fronts_group, hardware_group, x, y, z, width, height, thickness, orientation, has_handle = false)
          begin
            puts "DEBUG: create_corner_door called. Orientation: #{orientation}, x=#{x}, y=#{y}, w=#{width}"
            
            # Create a group for the door to ensure material application works correctly
            door_group = fronts_group.entities.add_group
            entities = door_group.entities
            
            push_val = thickness
            pts = []
            
            case orientation
            when :front
              # Door on front face (normal Y = 0)
              # Points on XZ plane at Y=0
              pts = [
                Geom::Point3d.new(x, 0, z),
                Geom::Point3d.new(x + width, 0, z),
                Geom::Point3d.new(x + width, 0, z + height),
                Geom::Point3d.new(x, 0, z + height)
              ]
              # Extrude in +Y direction (thickness) because normal is -Y?
              # Wait, if we want it to be at Y=0..-0.75 (Outside), we need to push in -Y direction.
              # Face normal for (x,0,z)->(x+w,0,z) is -Y (0,-1,0).
              # Pushpull(val) moves face by val * normal.
              # If val is positive, it moves in -Y direction.
              # So we want positive thickness.
              push_val = thickness
              
              if has_handle
                add_door_handle(hardware_group.entities, x, 0, z, width, height, thickness, :right)
              end
              
            when :left
              # Door on left face (normal X = 0)
              pts = [
                Geom::Point3d.new(0, y, z),
                Geom::Point3d.new(0, y + width, z),
                Geom::Point3d.new(0, y + width, z + height),
                Geom::Point3d.new(0, y, z + height)
              ]
              push_val = -thickness # Push out to -X
              
            when :left_return
              # Door on return wing front (at X = x, facing -X direction)
              pts = [
                Geom::Point3d.new(x, y, z),
                Geom::Point3d.new(x, y + width, z),
                Geom::Point3d.new(x, y + width, z + height),
                Geom::Point3d.new(x, y, z + height)
              ]
              push_val = -thickness
              
            when :right
              # Door on right face (normal X = 1)
              pts = [
                Geom::Point3d.new(x, y, z),
                Geom::Point3d.new(x, y + width, z),
                Geom::Point3d.new(x, y + width, z + height),
                Geom::Point3d.new(x, y, z + height)
              ]
              push_val = thickness # Push out to +X
              
              if has_handle
                # Custom handle for right-facing door
                marker_size = 1.inch
                handle_z = z + height / 2 - marker_size / 2
                handle_y = y + 2.inch
                handle_x = x + thickness
                
                h_pts = [
                  [handle_x, handle_y, handle_z],
                  [handle_x, handle_y + marker_size, handle_z],
                  [handle_x, handle_y + marker_size, handle_z + marker_size],
                  [handle_x, handle_y, handle_z + marker_size]
                ]
                f = hardware_group.entities.add_face(h_pts)
                if f && f.valid?
                  f.material = "Gray"
                  f.pushpull(marker_size)
                end
              end
            end
            
            # Create door face
            if pts.length == 4
              face = entities.add_face(pts)
              if face && face.valid?
                face.material = @materials.drawer_face_material
                face.back_material = @materials.drawer_face_material
                face.pushpull(push_val)
                puts "DEBUG: Door created successfully. Material: #{@materials.drawer_face_material}"
              else
                puts "DEBUG: Failed to create door face"
              end
            else
              puts "DEBUG: Invalid points for door"
            end
            
            # Ensure all faces in the group have the material
            entities.grep(Sketchup::Face).each do |f|
              f.material = @materials.drawer_face_material
              f.back_material = @materials.drawer_face_material
            end
          rescue => e
            puts "ERROR in create_corner_door: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          end
        end
        
        # Build doors/drawers for wall stack (42" lower door + stacked 12" drawers)
        def build_wall_stack_doors(cabinet, fronts_group, hardware_group)
          # Get configuration based on type
          config = cabinet.type == :wall_stack_9ft ? Constants::WALL_STACK_9FT : Constants::WALL_STACK
          
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          
          lower_height = config[:lower_height]
          upper_height = config[:upper_stack_height]
          stack_count = config[:upper_stack_count]
          stack_reveal = config[:stack_reveal].inch
          
          width = cabinet.width.inch
          door_count = door_count_for_section(cabinet)
          
          current_z = 0
          
          # Lower 42" door
          build_doors(fronts_group, hardware_group, cabinet, door_count, current_z, lower_height)
          
          current_z += lower_height
          
          # Stacked 12" doors (one or two depending on config)
          stack_count.times do |i|
            build_doors(fronts_group, hardware_group, cabinet, door_count, current_z, upper_height)
            current_z += upper_height
          end
        end
        
        # Build display cabinet doors (glass doors with 1" frame)
        def build_display_doors(cabinet, fronts_group, hardware_group)
          puts "DEBUG: Building display cabinet doors"
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          frameless_reveal = Constants::DOOR_DRAWER[:frameless_reveal].inch
          center_reveal = cabinet.frame_type == :frameless ? frameless_reveal : reveal
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          frame_width = 1.0.inch  # 1" frame around glass
          
          width = cabinet.width.inch
          
          # Get door count from cabinet config (default to 2 if not specified)
          door_count = cabinet.options[:door_count] || 2
          door_count = [door_count.to_i, 1].max  # At least 1 door
          door_count = [door_count, 2].min       # At most 2 doors
          
          puts "DEBUG: Display cabinet door_count=#{door_count}"
          
          # Available width adjustments based on frame type
          if cabinet.frame_type == :frameless
            width_available = width - (2 * frameless_reveal)
            edge_start = frameless_reveal
          else
            width_available = width - (2 * reveal)
            edge_start = reveal
          end
          
          total_center_spacing = center_reveal * (door_count - 1)
          door_width = (width_available - total_center_spacing) / door_count
          door_height = cabinet.interior_height.inch - (2 * reveal)
          
          # Position doors - account for toe kick if display_base
          toe_kick_offset = toe_kick_base_offset(cabinet)
          door_z = reveal + toe_kick_offset
          door_y = 0  # Door face flush with cabinet front
          
          door_specs = []
          door_x = edge_start
          
          door_count.times do |i|
            door_specs << {
              x: door_x,
              y: door_y,
              z: door_z,
              width: door_width,
              height: door_height,
              name: door_count == 1 ? "Glass Door" : "Glass Door #{i + 1}",
              handle_side: door_count == 1 ? :right : (i.even? ? :right : :left)
            }
            door_x += door_width + center_reveal
          end
          
          # Validate fronts_group before using it
          unless fronts_group && fronts_group.valid?
            puts "WARNING: fronts_group is invalid at start of display door creation"
            return
          end
          
          # Create the glass doors
          door_specs.each do |spec|
            unless fronts_group && fronts_group.valid?
              puts "WARNING: fronts_group became invalid during door creation, stopping"
              break
            end
            
            # Create door group with descriptive name
            door_group = fronts_group.entities.add_group
            door_group.name = spec[:name]
            
            # Create glass door panel with frame
            create_glass_door_panel(door_group.entities,
                                   [spec[:x], spec[:y], spec[:z]],
                                   spec[:width], thickness, spec[:height],
                                   frame_width)
            
            # Add hardware to hardware group
            add_door_handle(hardware_group.entities, spec[:x], spec[:y], spec[:z],
                           spec[:width], spec[:height], thickness, spec[:handle_side])
          end
        end
        
        # Create a glass door panel with 1" wood frame around glass center
        def create_glass_door_panel(entities, origin, width, thickness, height, frame_width)
          x, y, z = origin
          
          # Skip if dimensions are invalid
          return nil if width.abs < 0.001 || height.abs < 0.001 || thickness.abs < 0.001
          
          begin
            back_y = y - thickness
            
            # Get or create the glass material
            glass_material = get_or_create_glass_material
            frame_material = @materials.drawer_face_material
            
            # Create the frame (4 pieces around the perimeter)
            # Left frame piece
            create_frame_piece(entities, x, y, z, frame_width, thickness, height, frame_material)
            
            # Right frame piece
            create_frame_piece(entities, x + width - frame_width, y, z, frame_width, thickness, height, frame_material)
            
            # Bottom frame piece (between left and right)
            create_frame_piece(entities, x + frame_width, y, z, width - (2 * frame_width), thickness, frame_width, frame_material)
            
            # Top frame piece (between left and right)
            create_frame_piece(entities, x + frame_width, y, z + height - frame_width, width - (2 * frame_width), thickness, frame_width, frame_material)
            
            # Create the glass center (inset by frame_width on all sides)
            glass_x = x + frame_width
            glass_z = z + frame_width
            glass_width = width - (2 * frame_width)
            glass_height = height - (2 * frame_width)
            glass_thickness = 0.25.inch  # 1/4" glass
            
            # Position glass slightly recessed from frame front
            glass_y = y - (thickness - glass_thickness) / 2
            
            create_glass_panel(entities, glass_x, glass_y, glass_z, glass_width, glass_thickness, glass_height, glass_material)
            
            true
          rescue => e
            puts "ERROR in create_glass_door_panel: #{e.message}"
            puts e.backtrace.first(3).join("\n")
            false
          end
        end
        
        # Create a frame piece (solid wood)
        def create_frame_piece(entities, x, y, z, width, thickness, height, material)
          back_y = y - thickness
          
          pts = [
            Geom::Point3d.new(x, y, z),
            Geom::Point3d.new(x + width, y, z),
            Geom::Point3d.new(x + width, y, z + height),
            Geom::Point3d.new(x, y, z + height)
          ]
          front_face = entities.add_face(pts)
          
          back_pts = [
            Geom::Point3d.new(x, back_y, z),
            Geom::Point3d.new(x, back_y, z + height),
            Geom::Point3d.new(x + width, back_y, z + height),
            Geom::Point3d.new(x + width, back_y, z)
          ]
          entities.add_face(back_pts)
          
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
          
          # Top
          entities.add_face([
            Geom::Point3d.new(x, y, z + height),
            Geom::Point3d.new(x + width, y, z + height),
            Geom::Point3d.new(x + width, back_y, z + height),
            Geom::Point3d.new(x, back_y, z + height)
          ])
          
          # Bottom
          entities.add_face([
            Geom::Point3d.new(x, y, z),
            Geom::Point3d.new(x, back_y, z),
            Geom::Point3d.new(x + width, back_y, z),
            Geom::Point3d.new(x + width, y, z)
          ])
          
          # Apply material to all faces
          entities.grep(Sketchup::Face).each do |face|
            face.material = material
            face.back_material = material
          end
        end
        
        # Create a glass panel
        def create_glass_panel(entities, x, y, z, width, thickness, height, material)
          back_y = y - thickness
          
          # Front face
          front_pts = [
            Geom::Point3d.new(x, y, z),
            Geom::Point3d.new(x + width, y, z),
            Geom::Point3d.new(x + width, y, z + height),
            Geom::Point3d.new(x, y, z + height)
          ]
          front_face = entities.add_face(front_pts)
          
          # Back face
          back_pts = [
            Geom::Point3d.new(x, back_y, z),
            Geom::Point3d.new(x, back_y, z + height),
            Geom::Point3d.new(x + width, back_y, z + height),
            Geom::Point3d.new(x + width, back_y, z)
          ]
          entities.add_face(back_pts)
          
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
          
          # Top
          entities.add_face([
            Geom::Point3d.new(x, y, z + height),
            Geom::Point3d.new(x + width, y, z + height),
            Geom::Point3d.new(x + width, back_y, z + height),
            Geom::Point3d.new(x, back_y, z + height)
          ])
          
          # Bottom
          entities.add_face([
            Geom::Point3d.new(x, y, z),
            Geom::Point3d.new(x, back_y, z),
            Geom::Point3d.new(x + width, back_y, z),
            Geom::Point3d.new(x + width, y, z)
          ])
          
          # Apply glass material to all faces
          entities.grep(Sketchup::Face).each do |face|
            # Only apply to glass faces (check bounds)
            bounds = face.bounds
            if bounds.min.x >= x - 0.01 && bounds.max.x <= x + width + 0.01 &&
               bounds.min.z >= z - 0.01 && bounds.max.z <= z + height + 0.01
              face.material = material
              face.back_material = material
            end
          end
        end
        
        # Get or create the glass material
        def get_or_create_glass_material
          material_name = "display_cabinet_glass"
          material = @model.materials[material_name]
          
          unless material
            material = @model.materials.add(material_name)
            # Light blue-ish tint for glass
            material.color = Sketchup::Color.new(200, 220, 240)
            material.alpha = 0.3  # Transparent
          end
          
          material
        end
        
        # Build doors
        def build_doors(fronts_group, hardware_group, cabinet, door_count, start_z, total_height, graduated = false)
          return if door_count.nil? || door_count <= 0
          door_count = door_count.to_i
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          frameless_reveal = Constants::DOOR_DRAWER[:frameless_reveal].inch
          center_reveal = cabinet.frame_type == :frameless ? frameless_reveal : reveal
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          overlay = cabinet.frame_type == :framed ? Constants::DOOR_DRAWER[:overlay].inch : 0
          
          width = cabinet.width.inch
          depth = cabinet.depth.inch
          
          # Available width adjustments based on frame type
          if cabinet.frame_type == :frameless
            # Frameless: doors are NARROWER than cabinet box to create 1/16" reveals on each side
            width_available = width - (2 * frameless_reveal)
            edge_start = frameless_reveal
          else
            width_available = width - (2 * reveal)
            edge_start = reveal
          end
          total_center_spacing = center_reveal * [door_count - 1, 0].max
          
          # Calculate door widths (graduated or equal)
          door_widths = []
          if graduated && door_count == 3
            # Graduated sizing: small (20%), medium (30%), large (50%)
            available_for_doors = width_available - total_center_spacing
            door_widths = [
              available_for_doors * 0.20,  # Left door (smallest)
              available_for_doors * 0.30,  # Middle door
              available_for_doors * 0.50   # Right door (largest)
            ]
          else
            # Equal sizing
            door_width = (width_available - total_center_spacing) / door_count
            door_widths = Array.new(door_count, door_width)
          end
          
          door_height = total_height.inch - (2 * reveal)
          
          # Position doors flush with cabinet box front
          # Door face is at y = 0 (flush with cabinet front)
          # Door thickness extends backward into cabinet (negative Y direction)
          door_z = start_z.inch + reveal
          door_y = 0  # Door face flush with cabinet front
          
          # Collect all door specifications FIRST (avoid entity invalidation)
          door_x = edge_start
          door_specs = (0...door_count).map do |i|
            spec = {
              x: door_x,
              y: door_y,
              z: door_z,
              width: door_widths[i],
              height: door_height,
              name: door_count == 1 ? "Door" : "Door #{i + 1}",
              handle_side: door_handle_side(i, door_count, cabinet)
            }
            door_x += door_widths[i] + center_reveal  # Move to next door position
            spec
          end
          
          # Validate fronts_group before using it
          unless fronts_group && fronts_group.valid?
            puts "WARNING: fronts_group is invalid at start of door creation"
            return
          end
          
          # Now create all door geometry
          door_specs.each do |spec|
            # Check if fronts_group is still valid before each iteration
            unless fronts_group && fronts_group.valid?
              puts "WARNING: fronts_group became invalid during door creation, stopping"
              break
            end
            
            # Create door group with descriptive name
            door_group = fronts_group.entities.add_group
            door_group.name = spec[:name]
            
            # Create door panel in door group
            create_door_panel(door_group.entities, 
                            [spec[:x], spec[:y], spec[:z]],
                            spec[:width], thickness, spec[:height],
                            @materials.drawer_face_material)
            
            # Add hardware to hardware group
            add_door_handle(hardware_group.entities, spec[:x], spec[:y], spec[:z], 
                           spec[:width], spec[:height], thickness, spec[:handle_side])
          end
        end

        def door_handle_side(index, door_count, cabinet = nil)
          # Dishwasher template gets top-center handle
          return :top_center if cabinet && cabinet.options && cabinet.options[:template] == 'dishwasher'
          return :right if door_count == 1
          index.even? ? :right : :left
        end

        def door_count_for_section(cabinet, requested_count = nil)
          return requested_count if requested_count && requested_count > 0
          return 1 if cabinet.options && cabinet.options[:single_door]
          width = cabinet.width || Constants::STANDARD_WIDTHS.min
          return 1 if width < 24
          2
        end
        
        # Build drawers
        def build_drawers(fronts_group, hardware_group, cabinet, drawer_count, start_z, total_height, equal_sizing = false, custom_heights = nil)
          reveal = Constants::DOOR_DRAWER[:reveal].inch
          frameless_reveal = Constants::DOOR_DRAWER[:frameless_reveal].inch
          thickness = Constants::DOOR_DRAWER[:thickness].inch
          overlay = cabinet.frame_type == :framed ? Constants::DOOR_DRAWER[:overlay].inch : 0
          
          width = cabinet.width.inch
          depth = cabinet.depth.inch
          
          # Calculate individual drawer heights
          drawer_heights = if custom_heights && !custom_heights.empty?
            custom_heights
          else
            calculate_drawer_heights(drawer_count, total_height, equal_sizing)
          end
          
          current_z = start_z
          
          drawer_heights.each_with_index do |drawer_height, i|
            # drawer_height is already in inches (as a number)
            # start_z and current_z are also in inches (as numbers)
            
            # Create each drawer in its own sub-group to prevent geometry merging
            drawer_group = fronts_group.entities.add_group
            drawer_group.name = "Drawer_#{i+1}"
            
            if cabinet.frame_type == :frameless
              # Frameless: drawer is NARROWER than cabinet box (1/16" reveal on each side)
              drawer_x = frameless_reveal
              drawer_width = width - (2 * frameless_reveal)
            else
              drawer_x = reveal
              drawer_width = width - (2 * reveal)
            end
            drawer_y = 0  # Drawer face flush with cabinet front
            drawer_z = current_z.inch + reveal
            
            # Subtract reveals from height (drawer_height is in inches as a number)
            actual_drawer_height = drawer_height.inch - (2 * reveal)
            
            puts "DEBUG: Creating drawer #{i+1}: pos=[#{drawer_x}, #{drawer_y}, #{drawer_z}], size=[#{drawer_width}, #{thickness}, #{actual_drawer_height}]"
            
            # Drawer face in its own group
            result = create_door_panel(drawer_group.entities,
                            [drawer_x, drawer_y, drawer_z],
                            drawer_width, thickness, actual_drawer_height,
                            @materials.drawer_face_material)
            
            puts "DEBUG: Drawer face created: #{result ? 'success' : 'FAILED'}"
            
            # Add drawer pull to hardware group
            add_drawer_handle(hardware_group.entities, drawer_x, drawer_y, drawer_z,
                            drawer_width, actual_drawer_height, thickness)
            
            # Move to next drawer position (drawer_height is in inches)
            current_z += drawer_height
          end
        end
        
        # Calculate graduated drawer heights
        def calculate_drawer_heights(count, total_height, equal_sizing = false)
          heights = []
          
          puts "DEBUG: calculate_drawer_heights - count=#{count}, total_height=#{total_height}, equal_sizing=#{equal_sizing.inspect} (class: #{equal_sizing.class})"
          
          # Check equal_sizing flag FIRST
          if equal_sizing
            # Equal distribution
            puts "DEBUG: Using EQUAL sizing"
            heights = Array.new(count, total_height / count.to_f)
          else
            # Use graduated sizing (smaller on top, larger on bottom)
            puts "DEBUG: Using GRADUATED sizing"
            case count
            when 1
              heights = [total_height]
            when 2
              # Reverse: largest first (bottom), smallest last (top)
              heights = [total_height * 0.55, total_height * 0.45]
            when 3
              # Reverse: largest first (bottom), smallest last (top)
              heights = [total_height * 0.45, total_height * 0.30, total_height * 0.25]
            when 4
              # Reverse: largest first (bottom), smallest last (top)
              heights = [total_height * 0.30, total_height * 0.25, total_height * 0.25, total_height * 0.20]
            when 5
              # Reverse: largest first (bottom), smallest last (top)
              heights = [total_height * 0.25, total_height * 0.22, total_height * 0.20, total_height * 0.18, total_height * 0.15]
            else
              # Equal distribution for 6+ drawers
              heights = Array.new(count, total_height / count.to_f)
            end
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
            back_y = y - thickness
            
            # Create all 6 faces of the box FIRST, then apply materials
            # This prevents SketchUp from deleting/recreating faces during geometry operations
            
            # Front face
            front_pts = [
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x + width, y, z),
              Geom::Point3d.new(x + width, y, z + height),
              Geom::Point3d.new(x, y, z + height)
            ]
            entities.add_face(front_pts)
            
            # Back face
            back_pts = [
              Geom::Point3d.new(x, back_y, z),
              Geom::Point3d.new(x, back_y, z + height),
              Geom::Point3d.new(x + width, back_y, z + height),
              Geom::Point3d.new(x + width, back_y, z)
            ]
            entities.add_face(back_pts)
            
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
            
            # Top
            entities.add_face([
              Geom::Point3d.new(x, y, z + height),
              Geom::Point3d.new(x + width, y, z + height),
              Geom::Point3d.new(x + width, back_y, z + height),
              Geom::Point3d.new(x, back_y, z + height)
            ])
            
            # Bottom
            entities.add_face([
              Geom::Point3d.new(x, y, z),
              Geom::Point3d.new(x, back_y, z),
              Geom::Point3d.new(x + width, back_y, z),
              Geom::Point3d.new(x + width, y, z)
            ])
            
            # Apply materials to all faces
            # For drawer/door panels, apply finished surface to ALL faces on both sides
            # This ensures consistent appearance regardless of face orientation
            entities.grep(Sketchup::Face).each do |face|
              face.material = material
              face.back_material = material
            end
            
            true
          rescue => e
            puts "Error creating door panel: #{e.message}"
            nil
          end
        end

        def toe_kick_base_offset(cabinet)
          case cabinet.type
          when :base, :island, :corner_base, :display_base
            Constants::BASE_CABINET[:toe_kick_height].inch
          when :miele_dishwasher
            Constants::MIELE_DISHWASHER[:toe_kick_height].inch
          else
            0
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
            
            # Position marker based on side
            if side == :top_center
              # Dishwasher: handle at top center
              handle_z = door_z + door_height - 2.inch - marker_size
              handle_x = door_x + door_width / 2 - marker_size / 2
            else
              # Regular door: handle at middle height on left or right
              handle_z = door_z + door_height / 2 - marker_size / 2
              handle_x = side == :left ? door_x + 2.inch : door_x + door_width - 2.inch - marker_size
            end
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
