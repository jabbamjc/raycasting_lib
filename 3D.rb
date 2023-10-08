$gtk.reset
attr_gtk

$gtk.ffi_misc.gtk_dlopen("ext")
include FFI::CExt

class Matrix
    attr_accessor :matrix
    def initialize(matrix)
        @matrix = matrix
    end

    def make_cext_mat matrix
	    output = C_create_mat(matrix.length, matrix[0].length)
	    matrix.flatten.each_with_index do |point, i|
		    output[i] = point.to_f
	    end
	    output
    end

    def conv_cext_rb cmat, rows, cols
	    output = []
	    rows.times do |row|
		    temp = []
		    cols.times do |col|
			    temp << cmat[row * cols + col]
		    end
		    output << temp
	    end
	    output
    end

    def * other
        m2 = other.matrix if other.instance_of? Matrix
        m2 = (other.to_matrix).matrix if other.instance_of? Vector
        
        m1_p = make_cext_mat(@matrix)
        m2_p = make_cext_mat(m2)

	    rb_output = conv_cext_rb(C_mat_mul(m1_p, @matrix.length, @matrix[0].length, m2_p, m2.length, m2[0].length), @matrix.length, m2[0].length)

        c_free_mat(m1_p)
        c_free_mat(m2_p)

        Matrix.new(rb_output)
    end

    def to_vector
        @matrix.length > 2 ? z = @matrix[2][0] : z = 0
        Vector.new(@matrix[0][0], @matrix[1][0], z)
    end
end

class Vector
    attr_accessor :x, :y, :z
    def initialize(x, y, z)
        @x = x
        @y = y
        @z = z
    end

    def to_matrix
        matrix = Matrix.new([[@x],[@y],[@z]])
    end

    def * s
      Vector.new(@x * s, @y * s, @z * s)
    end

    def / s
      Vector.new(@x / s, @y / s, @z / s)
    end

    def + other
      Vector.new(@x + other.x, @y + other.y, @z + other.z)
    end

    def - other
      Vector.new(@x - other.x, @y - other.y, @z - other.z)
    end

    def to_s
      "(#{@x.round(2)}, #{@y.round(2)}, #{@z.round(2)})"
    end
end

class Shape
    attr_accessor :mid_x, :mid_y, :mid_z, :vector_points, :vertex_connections#, :x_rotation, :y_rotation:, :z_rotation

    def move x, y, z
        @mid_x += x
        @mid_y += y
        @mid_z += z
        @vector_points.each_with_index do |point, i|
            @vector_points[i] = point + Vector.new(x, y, z)
        end
    end

    def rotate_x angle
        angle *= Math::PI / 180
        rotation_x = Matrix.new([
            [1, 0, 0],
            [0, Math.cos(angle), -Math.sin(angle)],
            [0, Math.sin(angle), Math.cos(angle)]
        ])
        @vector_points.map! do |vec|
            vec -= Vector.new(@mid_x, @mid_y, @mid_z)
            vec = (rotation_x * vec).to_vector
            vec += Vector.new(@mid_x, @mid_y, @mid_z)
        end
    end

    def rotate_y angle
        angle *= Math::PI / 180
        rotation_y = Matrix.new([
            [Math.cos(angle), 0, -Math.sin(angle)],
            [0, 1, 0],
            [Math.sin(angle), 0, Math.cos(angle)]
        ])
        @vector_points.map! do |vec|
            vec -= Vector.new(@mid_x, @mid_y, @mid_z)
            vec = (rotation_y * vec).to_vector
            vec += Vector.new(@mid_x, @mid_y, @mid_z)
        end
    end

    def rotate_z angle
        angle *= Math::PI / 180
        rotation_z = Matrix.new([
            [Math.cos(angle), -Math.sin(angle), 0],
            [Math.sin(angle), Math.cos(angle), 0],
            [0, 0, 1]
        ])
        @vector_points.map! do |vec|
            vec -= Vector.new(@mid_x, @mid_y, @mid_z)
            vec = (rotation_z * vec).to_vector
            vec += Vector.new(@mid_x, @mid_y, @mid_z)
        end
    end

    def project_to_2d args
        vector_list = @vector_points.map do |vec|
            vec -= Vector.new(1280 / 2, 720 / 2, 0)
            vec -= Vector.new(0, 0, args.state.camera_z)

            z = args.state.screen_dist / vec.z

            vec = (Matrix.new([
                [z, 0, 0],
                [0, z, 0],
                [0, 0, z]
            ]) * vec).to_vector

            vec += Vector.new(1280 / 2, 720 / 2, 0)
        end

        flag = false
        @vertex_connections.each do |double|
            first, second = double[0], double[1]

            next if @vector_points[first].z < args.state.camera_z || @vector_points[second].z < args.state.camera_z
            next if @vector_points[first].z >= args.state.camera_z+args.state.render_distance || @vector_points[second].z >= args.state.camera_z+args.state.render_distance

            flag == true
            args.render_target(:shape).lines << { x: vector_list[first].x, y: vector_list[first].y, x2: vector_list[second].x, y2: vector_list[second].y, r: 200, g: 100, b: 100 }
        end
        args.render_target(:shape).clear if flag
        args.state.shape_targets << :shape
    end
end

class Cube < Shape 
    def initialize(x, y, z, side_length)
        l = side_length/2
        @mid_x = x
        @mid_y = y
        @mid_z = z
        @vector_points = [
             Vector.new(x+l, y+l, z+l),
             Vector.new(x+l, y-l, z+l),
             Vector.new(x-l, y+l, z+l),
             Vector.new(x-l, y-l, z+l),

             Vector.new(x+l, y+l, z-l),
             Vector.new(x+l, y-l, z-l),
             Vector.new(x-l, y+l, z-l),
             Vector.new(x-l, y-l, z-l)
        ]
        
        @vertex_connections = [
            [0,1], [0,2], [0,4],
            [3,1], [3,2], [3,7],
            [5,1], [5,4], [5,7],
            [6,2], [6,4], [6,7],
        ]
    end
end 

class Sphere < Shape
    def initialize(x, y, z, r, clarity)
        @mid_x = x
        @mid_y = y
        @mid_z = z
        @vector_points = []

        clarity = 10/clarity 

        sphere_segments = 180.idiv clarity
        theta = 180 / sphere_segments
        segment_height = 0
        (0..sphere_segments).each do |i|
            
            CS_radius = r * Math.sin((theta*i)*Math::PI / 180)
            segment_height = r - (r * Math.cos((theta*i)*Math::PI / 180))

            (0..(2*sphere_segments)).each do |j|

                vec_x = x + (CS_radius * Math.sin((theta*j)*Math::PI / 180))
                vec_y = y + (segment_height) - r
                vec_z = z + (CS_radius * Math.cos((theta*j)*Math::PI / 180))

                @vector_points << Vector.new(vec_x, vec_y, vec_z)
            end
        end
 
        @vertex_connections = []
        (0...@vector_points.length-1).each_with_index do |i|
 
            @vertex_connections << [i, i+1]
            @vertex_connections << [i, i-(2*sphere_segments)] if i-(2*sphere_segments) >= 0
            @vertex_connections << [i, i-((2*sphere_segments)+1)] if i-((2*sphere_segments)+1) >= 0
        end
    end
end

def tick args
    args.state.render_distance ||= 3000
    args.state.screen_dist ||= 500
    args.state.camera_z ||= 0

    args.state.shapes ||= []
    args.state.shape_targets ||= []

    if args.inputs.keyboard.key_down.p
        args.state.shapes << Cube.new(args.inputs.mouse.x, args.inputs.mouse.y, args.state.camera_z+600, 200)
    end

    if args.inputs.keyboard.key_down.o
        args.state.shapes << Sphere.new(args.inputs.mouse.x, args.inputs.mouse.y, args.state.camera_z+600, 200, 0.35)
    end

    (args.state.shapes.pop && args.state.shape_targets.pop) if args.inputs.keyboard.key_down.escape

    args.state.camera_z += 30*args.inputs.mouse.wheel.y if args.inputs.mouse.wheel

    args.state.shapes.each_with_index do |shape, index|

        if args.inputs.keyboard.key_held.q || !(args.inputs.keyboard.up_down == 0) || !(args.inputs.keyboard.left_right == 0) || args.inputs.keyboard.key_down.p || args.inputs.keyboard.key_down.o || args.inputs.mouse.wheel || args.inputs.keyboard.key_down.escape
            shape.rotate_z 1.0 if args.inputs.keyboard.key_held.q
            shape.rotate_x 1.0*args.inputs.keyboard.up_down if args.inputs.keyboard.up_down
            shape.rotate_y 1.0*args.inputs.keyboard.left_right if args.inputs.keyboard.left_right

            args.state.shape_targets.delete_at(index)
            shape.project_to_2d args
        end
        args.outputs.sprites << [0, 0, 1280, 720, args.state.shape_targets[index]]
        
    end

    args.outputs.lines << { x: 1280/2, y: (720/2)-10, x2: 1280/2, y2: (720/2)+10, r: 100, g: 100, b: 100 }
    args.outputs.lines << { x: (1280/2)-10, y: 720/2, x2: (1280/2)+10, y2: 720/2, r: 100, g: 100, b: 100 }
    args.outputs.labels << [1270, 710, args.gtk.current_framerate, 0, 2, 255, 0, 0]
end
