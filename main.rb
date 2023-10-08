$gtk.reset
attr_gtk

$gtk.ffi_misc.gtk_dlopen("ext")
include FFI::CExt

class Vector
    attr_accessor :data

    def initialize
        @data = []
    end

    def + other
        ret_vec = Vector.new

        if other.class.superclass == Vector
            ret_vec.data = @data.map_with_index do |axis, i|
                i < other.data.length ? axis += other.data[i] : axis
            end
        elsif other.class.superclass == Numeric
            ret_vec.data = @data.map { |axis| axis + other }
        else
            puts "Method + does not exist for #{self.class} on #{other.class}"
        end
        if self.class == Vec2 && other.class == Vec2
            ret_vec.to_vec2
        else
            ret_vec.to_vec3
        end
    end

    def - other
        ret_vec = Vector.new

        if other.class.superclass == Vector
            ret_vec.data = @data.map_with_index do |axis, i|
                i < other.data.length ? axis -= other.data[i] : axis
            end
        elsif other.class.superclass == Numeric
            ret_vec.data = @data.map { |axis| axis - other }
        else
            puts "Method - does not exist for #{self.class} on #{other.class}"
        end
        if self.class == Vec2 && other.class == Vec2
            ret_vec.to_vec2
        else
            ret_vec.to_vec3
        end
    end

    def * other
        ret_vec = Vector.new

        if other.class.superclass == Vector
            ret_vec.data = @data.map_with_index do |axis, i|
                i < other.data.length ? axis *= other.data[i] : axis
            end
        elsif other.class.superclass == Numeric
            ret_vec.data = @data.map { |axis| axis * other }
        else
            puts "Method * does not exist for #{self.class} on #{other.class}"
        end
        if self.class == Vec2 && other.class == Vec2
            ret_vec.to_vec2
        else
            ret_vec.to_vec3
        end
    end

    def / other
        ret_vec = Vector.new

        if other.class.superclass == Vector
            ret_vec.data = @data.map_with_index do |axis, i|
                i < other.data.length ? axis /= other.data[i] : axis
            end
        elsif other.class.superclass == Numeric
            ret_vec.data = @data.map { |axis| axis / other }
        else
            puts "Method / does not exist for #{self.class} on #{other.class}"
        end
        if self.class == Vec2 && other.class == Vec2
            ret_vec.to_vec2
        else
            ret_vec.to_vec3
        end
    end
    
    def x
        @data[0]
    end

    def y
        @data[1]
    end

    def z
        @data[2]
    end

    def to_s
        string = "("
        @data.each_with_index do |axis, i|
            string += "#{axis}"
            string += " : " if i < @data.length-1
        end
        string += ")"
        string
    end

    def to_vec2
        Vec2.new(@data[0], @data[1])
    end

    def to_vec3
        Vec3.new(@data[0],@data[1],@data[2])
    end

    def mag 
        sum = 0
        @data.each { |axis| sum += axis**2 }
        Math.sqrt(sum)
    end

    def dot other
        total = 0
        @data.each_with_index { |axis, i| total += axis*other.data[i] }
        total
    end
end

class Vec2 < Vector
    def initialize x, y
        @data = [x, y, 0]
    end

    #undef_method :z

    def cross other
        x * other.y - y * other.x
    end

end

class Vec3 < Vector
    def initialize x, y, z
        @data = [x, y, z]
    end
end

class Line
    attr_accessor :point1, :point2

    def intersects_at other
        p1 = @point1
        p2 = @point2 - @point1

        other_p1 = other.point1
        other_p2 = other.point2 - other.point1

        t = (other_p1 - p1).cross(other_p2) / p2.cross(other_p2)
        u = (other_p1 - p1).cross(p2) / p2.cross(other_p2)

        if p2.cross(other_p2) != 0 && t > 0 && t < 1 && u > 0 && u < 1
            return p1 + p2 * t
        else
            return nil
        end
    end

    def draw r, g, b
        outputs.lines << { x: @point1.x, y: @point1.y, x2: @point2.x, y2: @point2.y, r: r, g: g, b: b }
    end

    def draw_small r, g, b
        s = 5
        outputs.lines << { x: @point1.x/s, y: @point1.y/s + 500, x2: @point2.x/s, y2: @point2.y/s + 500, r: r, g: g, b: b }
    end

    def update point1, point2
        @point1 = point1
        @point2 = point2
    end

    def rotate angle, point
        
        @point1 -= point
        @point2 -= point

        x1 = (@point1.x * Math.cos(-angle)) + (@point1.y * -Math.sin(angle))
        y1 = (@point1.x * Math.sin(angle)) + (@point1.y * Math.cos(-angle))
        @point1 = Vec2.new(x1, y1)

        x2 = (@point2.x * Math.cos(-angle)) + (@point2.y * -Math.sin(angle))
        y2 = (@point2.x * Math.sin(angle)) + (@point2.y * Math.cos(-angle))
        @point2 = Vec2.new(x2, y2)

        @point1 += point
        @point2 += point

    end

    def len
        Math.sqrt((@point2.x - @point1.x)**2 + (@point2.y - @point1.y)**2)
    end

    def angle
        Math.atan2((@point2.x-@point1.x),(@point2.y-@point1.y))
    end
end

class Ray < Line 
    attr_accessor :intersects_with
    def initialize args, point1, point2
        @args = args
        @point1 = point1
        @point2 = point2
        @angle = Math.atan2((@point2.x-@point1.x),(@point2.y-@point1.y))
        @intersects_with = nil
    end

    def update point1, point2
        @point1 = point1
        @point2 = point2
    end

    def angle 
        @angle
    end

    def render_raycast seg_x, seg_w, point
        return unless @intersects_with

        h = 80000/(len * Math.cos(@angle)) 

        y = (720-h)/2

        a = 0.8*h + 50
        
        { x: seg_x, y: y, w: seg_w, h: h, source_x: ((@intersects_with.get_wall_segment point).idiv seg_w)*2, source_y: 0, source_w: 1, source_h: @intersects_with.height, path: @intersects_with.texture, r: a, g: a, b: a }
    end
end

class Wall < Line
    attr_accessor :texture, :height
    def initialize args, point1, point2
        @args = args
        @point1 = point1
        @point2 = point2
        @texture = "sprites/brick_wall.png"
        @height = 64*2
    end

    def get_wall_segment point
        Math.sqrt((@point1.x - point.x)**2 + (@point1.y - point.y)**2)
    end
end

def to_degrees rads
    rads * 180 / Math::PI
end

def to_rads degrees
    degrees * (Math::PI / 180)
end

def initialize args
    args.state.ray_count ||= 1280/2
    args.state.ray_length ||= 1500

    args.state.fov ||= to_rads 80
    args.state.player_orient ||= 0

    args.state.segments ||= args.state.fov / args.state.ray_count

    args.state.player_x ||= 1280/2
    args.state.player_y ||= 720/2

    args.state.rays = []
    args.state.ray_count.times do |ray|
        p1_x = args.state.player_x
        p1_y = args.state.player_y
        p2_x = args.state.ray_length * Math.sin(ray*args.state.segments - args.state.fov/2) + args.state.player_x
        p2_y = args.state.ray_length * Math.cos(ray*args.state.segments - args.state.fov/2) + args.state.player_y
        args.state.rays << Ray.new(args, Vec2.new(p1_x, p1_y), Vec2.new(p2_x, p2_y) )
    end


    args.state.walls ||= []
    
    args.state.look_sensitivity ||= 8
    args.state.look_height ||= 0
    args.state.mode = "edit"
end

def track_mouse args
    args.state.prev_pos ||= [1280/2,720/2]
    args.state.current_pos = args.inputs.mouse.point
    return if args.state.prev_pos == args.state.current_pos
 
    args.state.player_orient += (args.state.current_pos[0] - args.state.prev_pos[0])/(args.state.look_sensitivity*11)
    args.state.look_height -= (args.state.current_pos[1] - args.state.prev_pos[1])*args.state.look_sensitivity

    args.state.prev_pos = args.state.current_pos
end

def move_up_down args
    args.state.player_x += 4*Math.sin(args.state.player_orient)*args.inputs.up_down 
    args.state.player_y += 4*Math.cos(args.state.player_orient)*args.inputs.up_down 
end

def move_left_right args
    args.state.player_x += 4*Math.sin(args.state.player_orient + Math::PI/2)*args.inputs.left_right 
    args.state.player_y += 4*Math.cos(args.state.player_orient + Math::PI/2)*args.inputs.left_right 
end

def game args
    args.state.rays.each_with_index do |ray, i|
        ray.update Vec2.new(args.state.player_x, args.state.player_y), Vec2.new((args.state.ray_length * Math.sin(ray.angle + args.state.player_orient) + args.state.player_x), (args.state.ray_length * Math.cos(ray.angle + args.state.player_orient) + args.state.player_y))
        ray.intersects_with = nil

        args.state.walls.each do |wall|
            #wall.draw_small 0, 255, 0
            point = ray.intersects_at wall
            if point
                ray.intersects_with = wall 
                ray.update ray.point1, Vec2.new(point.x, point.y)

                screen_segment = (ray.render_raycast i*(1280/args.state.ray_count), 1280/args.state.ray_count, point)
                screen_segment[:y] += args.state.look_height
                args.outputs.sprites << screen_segment
            end
        end

        #ray.draw_small 255, 0, 0
    end

    track_mouse args
    move_up_down args 
    move_left_right args
end

def edit args
    
    args.state.walls.each do |wall|
        wall.draw 0, 255, 0
    end

    if args.inputs.mouse.click
        args.state.start_x = args.inputs.mouse.x
        args.state.start_y = args.inputs.mouse.y

        args.state.line_start = true
    end

	if args.state.line_start 

        x1 = 64*(args.state.start_x.idiv 64)
        y1 = 64*(args.state.start_y.idiv 64)
        x2 = 64*(args.inputs.mouse.x.idiv 64)
        y2 = 64*(args.inputs.mouse.y.idiv 64)

        args.outputs.lines << { x: x1, y: y1, x2: x2, y2: y2, g: 255}

        l = Math.sqrt(((x1-x2)**2) + ((y1-y2)**2).to_f)
        x = (y1-y2)/l
        a = Math.atan2((x1-x2),(y2-y1))
        
        if args.inputs.mouse.up
            args.state.walls << Wall.new(args, Vec2.new(x1,y1), Vec2.new(x2,y2)) 
            args.state.line_start = false
        end
    end
    args.state.walls.pop if args.inputs.keyboard.key_down.escape

    args.outputs.labels << { x: 1000, y: 600, text: "click and drag to draw lines", r: 255 }
    args.outputs.labels << { x: 1100, y: 580, text: "P to play", r: 255 }
end

def tick args
    initialize args if args.state.tick_count == 0
    args.outputs.solids << [0,0,1280,720,100,100,100]

    args.state.mode = "edit" if args.inputs.keyboard.key_down.e
    args.state.mode = "play" if args.inputs.keyboard.key_down.p

    game args if args.state.mode == "play"
    edit args if args.state.mode == "edit"

    args.outputs.labels << [1270, 710, args.gtk.current_framerate, 0, 2, 255, 0, 0]
end
