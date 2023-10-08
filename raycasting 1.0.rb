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
        m2 = (other.to_col_matrix).matrix if other.instance_of? Vector
        
        m1_p = make_cext_mat(@matrix)
        m2_p = make_cext_mat(m2)

        r1, c1, r2, c2 = @matrix.length, @matrix[0].length, m2.length, m2[0].length

	    rb_output = conv_cext_rb(C_mat_mul(m1_p, r1, c1, m2_p, r2, c2), r1, c2)

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

    def to_col_matrix
        Matrix.new([[@x],[@y],[@z]])
    end

    def to_row_matrix
        Matrix.new([[@x,@y,@z]])
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

def create_slider x, y, w, h, low, high
	slider = { high: high, low: low, range: [*low..high], current_value:low, slider_rect: { x: x-(w/2), y: y-(1.5*h), w: h, h: 3*h }, line_rect: { x: x-(w/2), y: y-(h/2), w: w, h: h } }

	slider[:primitives] = [
    { x: x-(w/2), y: y-(h/2), w: w, h: h, r: 70, g: 70, b: 70 }.solid,
    { x: x-(w/2), y: y-(h/2), w: w, h: h}.border,

    { x: x-(w/2), y: y-(1.5*h), w: h, h: 3*h, r: 220, g: 220, b: 220 }.solid,
    { x: x-(w/2), y: y-(1.5*h), w: h, h: 3*h}.border,

    { x: x-(w/2)-(3*h)-5, y: y-(1.5*h), w: 3*h, h: 3*h, r: 230, g: 230, b: 230 }.solid,
    { x: x-(w/2)-(1.5*h)-5, y: y+h, alignment_enum: 1, text: slider[:current_value]}.label,
    { x: x-(w/2)-(3*h)-5, y: y-(1.5*h), w: 3*h, h: 3*h}.border
	]
    
	slider
end

def slide_slider args, slider
    args.state.mouse_held = true if args.inputs.mouse.down
	args.state.mouse_held = false if args.inputs.mouse.up
	return unless args.state.mouse_held

    if (args.inputs.mouse.point.inside_rect? slider[:slider_rect]) || (args.inputs.mouse.point.inside_rect? slider[:line_rect])
        x = args.inputs.mouse.point.x - (slider[:primitives][2].w/2)

        return if x < slider[:primitives][0].x 
        return if x > slider[:primitives][0].x + slider[:primitives][0].w - (slider[:primitives][2].w/2)

        slider[:slider_rect].x = x
        slider[:primitives][2].x = x 
        slider[:primitives][3].x = x

        sects = (slider[:primitives][0].w - (slider[:primitives][2].w)) / (slider[:high]-slider[:low]).abs
        val = slider[:range][((slider[:primitives][0].x - slider[:primitives][2].x) / sects).abs]
        slider[:current_value] = val
        slider[:primitives][5][:text] = val

        return true
    end
end

class Line
    attr_accessor :x1, :y1, :x2, :y2, :length, :angle, :texture_path
    def initialize x1, y1, length, angle, r, g, b, texture_path
        @x1 = x1
        @y1 = y1
        @x2 = length*Math.sin(angle)+x1
        @y2 = length*Math.cos(angle)+y1
        @length = length
        @angle = angle

        @r = r
        @g = g
        @b = b

        @texture_path = texture_path
        @height = 0
    end

    def intersects_at line2
        x1, y1, x2, y2 = @x1, @y1, @x2, @y2
        x3, y3, x4, y4 = line2.x1, line2.y1, line2.x2, line2.y2

        t = ( (x1-x3)*(y3-y4)-(y1-y3)*(x3-x4) ) / ( (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4) )

        u = ( (x2-x1)*(y1-y3)-(y2-y1)*(x1-x3) ) / ( (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4) )

        if (t>=0 && t<=1) && (u>=0 && u<=1)
            return { x: (x1 + t*(x2-x1)), y: (y1 + t*(y2-y1)) }
        end
    end

    def update x1, y1, x2, y2, texture_path
        @x1 = x1
        @y1 = y1
        @x2 = x2
        @y2 = y2

        @length = Math.sqrt((x1-x2)**2 + (y1-y2)**2)

        @texture_path = texture_path
    end

    def render_raycast args, x, w
        return if (@length < args.state.ray_length+10) && (@length > args.state.ray_length-10)

        h = @length * Math.cos(@angle)
        h = 80000/h
        y = args.state.look_height - h/2
        h += @height 
        a = 0.8*h + 50 #SHADING

        #BUILD UV SHELL
        args.outputs.sprites << { x: x, y: y, w: w, h: h, path: @texture_path, r: a, g: a, b: a }
    end

    def render_small args
        x1, y1, x2, y2 = @x1/10, @y1/10 + 600, @x2/10, @y2/10 + 600
        args.outputs.lines << { x: x1, y: y1, x2: x2, y2: y2, r: @r, g: @g ,b: @b }
    end

    def render args
        x1, y1, x2, y2 = @x1, @y1, @x2, @y2
        args.outputs.lines << { x: x1, y: y1, x2: x2, y2: y2, r: @r, g: @g ,b: @b }
    end
end

def initialize args 
    args.state.mode = "map"

    args.state.player_x = 1280/2
    args.state.player_y = 720/2

    args.state.fov = 60
    args.state.orientation = args.state.fov/-2
    args.state.look_height = 720/2
    args.state.look_sensitivity = 4

    args.state.rays = []
    args.state.ray_count ||= 1280/4
    args.state.screen_segment_w = 1280/args.state.ray_count
    args.state.ray_length ||= 1500

    degrees = args.state.fov/args.state.ray_count

    args.state.ray_count.times do |ray|
        a = (ray*degrees+args.state.orientation)*Math::PI / 180

        x = args.state.player_x
        y = args.state.player_y

        args.state.rays << Line.new(x, y, args.state.ray_length, a, 255, 0, 0, "")
    end

    args.state.last_pos = args.inputs.mouse.point

    args.state.height_proportion = 600

    args.state.lines = []
end

def track_mouse args
    args.state.current_pos = args.inputs.mouse.point
    return if args.state.current_pos == args.state.last_pos

    args.state.orientation -= (args.state.last_pos[0] - args.state.current_pos[0])*(args.state.look_sensitivity/10)
    args.state.look_height += (args.state.last_pos[1] - args.state.current_pos[1])*args.state.look_sensitivity

    args.state.last_pos = args.state.current_pos
end

def move_forward args
    player_a = (args.state.orientation)*Math::PI / 180
    args.state.player_x += 4*Math.sin(player_a)*args.inputs.up_down
    args.state.player_y += 4*Math.cos(player_a)*args.inputs.up_down
end

def move_sideways args
    player_a = (args.state.orientation)*Math::PI / 180
    b = (90)*Math::PI / 180
    args.state.player_x += 4*Math.sin(player_a+b)*args.inputs.left_right
    args.state.player_y += 4*Math.cos(player_a+b)*args.inputs.left_right
end

def keybinds args

    track_mouse args

    move_sideways args
    move_forward args
end

def bird_view args
    args.state.rays.map_with_index do |ray, i| 
        ray.render_small args
    end
    args.state.lines.each do |line|
        line.render_small args
    end
end

def play_mode args
    keybinds args

    bird_view args

    a = (args.state.orientation)*Math::PI / 180

    forward_line = Line.new(args.state.player_x, args.state.player_y, args.state.ray_length, a, 0, 0, 255, "")
    forward_line.render_small args

    #args.state.rays.map_with_index do |ray, i|
    for i in 0...args.state.rays.length do
        ray = args.state.rays[i]

        ray.update args.state.player_x, args.state.player_y, args.state.ray_length*Math.sin(ray.angle+a)+args.state.player_x, args.state.ray_length*Math.cos(ray.angle+a)+args.state.player_y, ""

        #args.state.lines.each do |line|
        for j in 0...args.state.lines.length do
            line = args.state.lines[j]
            intersection = ray.intersects_at line
            if intersection
                ray.update args.state.player_x, args.state.player_y, intersection[:x], intersection[:y], line.texture_path
                #args.outputs.solids << { x: intersection[:x]-2, y: intersection[:y]-2, w: 4, h: 4, b:255} if intersection
            end
       
        end
        ray.render_raycast args, i*args.state.screen_segment_w, args.state.screen_segment_w
        #args.render_target(:screen).solids << { x: i*args.state.screen_segment_w, y: 720-(ray.length-200), w: args.state.screen_segment_w, h: ray.length-200, r: 150, g: 150, b: 150 }
    end
    #args.outputs.sprites << [0,0,1280,720,:screen]

    args.outputs.labels << { x: 1100, y: 600, text: "WASD to move", r: 255 }
    args.outputs.labels << { x: 1100, y: 580, text: "mouse to turn", r: 255 } 
    args.outputs.labels << { x: 1100, y: 560, text: "E to edit", r: 255 } 
end

def map_edit_mode args
    
    args.state.lines.each_with_index do |line, i|
        line.render args
    end

    if args.inputs.mouse.click
        args.state.start_x = args.inputs.mouse.x
        args.state.start_y = args.inputs.mouse.y

        args.state.line_start = true
    end

	if args.state.line_start 

        x1 = args.state.start_x
        y1 = args.state.start_y
        x2 = args.inputs.mouse.x
        y2 = args.inputs.mouse.y

        args.outputs.lines << { x: x1, y: y1, x2: x2, y2: y2, g: 255}

        l = Math.sqrt(((x1-x2)**2) + ((y1-y2)**2).to_f)
        x = (y1-y2)/l
        a = Math.atan2((x1-x2),(y2-y1))
        
        if args.inputs.mouse.up
            args.state.lines << Line.new(args.state.start_x, args.state.start_y, l, -a, 0, 255, 0, "sprites/brick_wall.png") 
            args.state.line_start = false
        end
    end
    args.state.lines.pop if args.inputs.keyboard.key_down.escape

    args.outputs.labels << { x: 1000, y: 600, text: "click and drag to draw lines", r: 255 }
    args.outputs.labels << { x: 1100, y: 580, text: "P to play", r: 255 }
end

def building_maker args
    #grid system - height - ceilings 
end

def tick args
    initialize args if args.state.tick_count == 0
    args.outputs.solids << [0,0,1280,720,100,100,100]

    args.state.mode = "map" if args.inputs.keyboard.key_down.e
    args.state.mode = "play" if args.inputs.keyboard.key_down.p

    play_mode args if args.state.mode == "play"
    map_edit_mode args if args.state.mode == "map"

    args.outputs.labels << [1270, 710, args.gtk.current_framerate, 0, 2, 255, 0, 0]
end
