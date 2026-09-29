from OpenGL.GL import *
from OpenGL.GLUT import *
from OpenGL.GLU import *
import random
import time

class GameState:
    def __init__(self):
        self.catcher_left = 180
        self.catcher_right = 300
        self.catcher_top = 60
        self.catcher_bottom = 45
        self.catcher_color = (1.0, 0.5, 1.0) 
        self.diamond_size = 14
        self.diamond_x = 250
        self.diamond_y = 450
        self.diamond_color = (random.random(), random.random(), random.random())
        self.diamond_speed = 2.0
        self.diamond_acceleration = 0.20 
        self.diamond_falling = True
        self.score = 0
        self.game_over = False
        self.paused = False
        self.last_time = time.time()  
        self.button_size = 40
        self.restart_button_pos = (40, 450)
        self.play_pause_button_pos = (225, 450)
        self.exit_button_pos = (400, 450)
game = GameState()

def draw_point(x, y):
    glPointSize(3)
    glBegin(GL_POINTS)
    glVertex2f(x, y)
    glEnd()

def find_zone(x0, y0, x1, y1):
    dx = x1 - x0
    dy = y1 - y0 
    if abs(dx) > abs(dy):
        if dx >= 0 and dy >= 0:
            return 0
        elif dx <= 0 and dy >= 0:
            return 3
        elif dx <= 0 and dy <= 0:
            return 4
        else:
            return 7
    else: 
        if dx >= 0 and dy >= 0:
            return 1
        elif dx <= 0 and dy >= 0:
            return 2
        elif dx <= 0 and dy <= 0:
            return 5
        else:
            return 6

def convert_to_zone0(zone, x, y):
    if zone == 0:
        return x, y
    elif zone == 1:
        return y, x
    elif zone == 2:
        return y, -x
    elif zone == 3:
        return -x, y
    elif zone == 4:
        return -x, -y
    elif zone == 5:
        return -y, -x
    elif zone == 6:
        return -y, x
    elif zone == 7:
        return x, -y

def convert_from_zone0(zone, x, y):
    if zone == 0:
        return x, y
    elif zone == 1:
        return y, x
    elif zone == 2:
        return -y, x
    elif zone == 3:
        return -x, y
    elif zone == 4:
        return -x, -y
    elif zone == 5:
        return -y, -x
    elif zone == 6:
        return y, -x
    elif zone == 7:
        return x, -y

def midpoint_line(x0, y0, x1, y1):
    zone = find_zone(x0, y0, x1, y1)
    n_x0, n_y0 = convert_to_zone0(zone, x0, y0)
    n_x1, n_y1 = convert_to_zone0(zone, x1, y1)
    dx = n_x1 - n_x0
    dy = n_y1 - n_y0
    d = 2 * dy - dx
    incE = 2 * dy
    incNE = 2 * (dy - dx)
    x = n_x0
    y = n_y0
    while x <= n_x1:
        orig_x, orig_y = convert_from_zone0(zone, x, y)
        draw_point(orig_x, orig_y)
        if d <= 0:
            d += incE
            x += 1
        else:
            d += incNE
            x += 1
            y += 1

def draw_catcher():
    glColor3f(*game.catcher_color)
    midpoint_line(game.catcher_left, game.catcher_top, 
                 game.catcher_right, game.catcher_top) 
    midpoint_line(game.catcher_left, game.catcher_top, 
                 (game.catcher_left-70 + game.catcher_right) // 2, game.catcher_bottom)  
    midpoint_line(game.catcher_right, game.catcher_top, 
                 (game.catcher_left+70 + game.catcher_right) // 2, game.catcher_bottom) 
    midpoint_line((game.catcher_left + game.catcher_right) // 2 - 35, game.catcher_bottom, 
                 (game.catcher_left + game.catcher_right) // 2 + 35, game.catcher_bottom) 

def draw_diamond():
    if not game.diamond_falling:
        return
    glColor3f(*game.diamond_color)
    size = game.diamond_size
    center_x = game.diamond_x
    center_y = game.diamond_y
    midpoint_line(center_x, center_y - size-10, center_x + size, center_y)  
    midpoint_line(center_x + size, center_y, center_x, center_y + size+10)  
    midpoint_line(center_x, center_y + size+10, center_x - size, center_y)  
    midpoint_line(center_x - size, center_y, center_x, center_y - size-10)  

def draw_restart_button():
    glColor3f(0.0, 1.0, 0.5)  
    x, y = game.restart_button_pos
    size = game.button_size
    midpoint_line(x, y, x + size, y) 
    midpoint_line(x + 10, y + 10, x, y)  
    midpoint_line(x + 10, y - 10, x, y) 

def draw_play_pause_button():
    x, y = game.play_pause_button_pos
    size = game.button_size
    if game.paused:
        glColor3f(0.5, 0.5, 1)  
        midpoint_line(x, y - size//2, x, y + size//2)
        midpoint_line(x, y + size//2, x + size//2, y)
        midpoint_line(x, y - size//2, x + size//2, y)
    else:
        glColor3f(0.5, 0.5, 1)  
        midpoint_line(x - size//4, y - size//2, x - size//4, y + size//2)
        midpoint_line(x + size//4, y - size//2, x + size//4, y + size//2)

def draw_exit_button():
    glColor3f(1.0, 0.0, 0.0)  
    x, y = game.exit_button_pos
    size = game.button_size
    midpoint_line(x - size//2, y - size//2, x + size//2, y + size//2)
    midpoint_line(x - size//2, y + size//2, x + size//2, y - size//2)

def check_collision():
    diamond_left = game.diamond_x - game.diamond_size
    diamond_right = game.diamond_x + game.diamond_size
    diamond_bottom = game.diamond_y - game.diamond_size
    diamond_top = game.diamond_y + game.diamond_size
    catcher_left = game.catcher_left
    catcher_right = game.catcher_right
    catcher_bottom = game.catcher_bottom
    catcher_top = game.catcher_top
    if (diamond_bottom <= catcher_top and 
        diamond_top >= catcher_bottom and
        diamond_left <= catcher_right and 
        diamond_right >= catcher_left):
        return True
    return False

def update_diamond_position():
    if game.paused or game.game_over or not game.diamond_falling:
        return
    current_time = time.time()
    delta_time = current_time - game.last_time
    game.last_time = current_time
    game.diamond_y -= game.diamond_speed * delta_time * 60  
    if check_collision():
        game.score += 1
        print(f"Score: {game.score}")
        spawn_new_diamond()
    if game.diamond_y - game.diamond_size < 0:
        game.game_over = True
        game.catcher_color = (1.0, 0.0, 0.0) 
        game.diamond_falling = False
        print(f"Game Over! Final Score: {game.score}")

def spawn_new_diamond():
    game.diamond_x = random.randint(game.diamond_size, 500 - game.diamond_size)
    game.diamond_y = 400
    game.diamond_color = (random.random(), random.random(), random.random())
    game.diamond_speed += game.diamond_acceleration  
    game.diamond_falling = True

def reset_game():
    game.catcher_left = 200
    game.catcher_right = 300
    game.catcher_color = (1.0, 0.5, 1.0)
    game.score = 0
    game.game_over = False
    game.paused = False
    game.diamond_speed = 2.0
    spawn_new_diamond()
    print("Starting Over! Score: 0")

def keyboard_special(key, x, y):
    if game.game_over or game.paused:
        return
    move_speed = 15
    if key == GLUT_KEY_LEFT:
        if game.catcher_left - move_speed >= 0:
            game.catcher_left -= move_speed
            game.catcher_right -= move_speed
    elif key == GLUT_KEY_RIGHT:
        if game.catcher_right + move_speed <= 500:
            game.catcher_left += move_speed
            game.catcher_right += move_speed
    glutPostRedisplay()

def mouse_click(button, state, x, y):
    if button == GLUT_LEFT_BUTTON and state == GLUT_DOWN:
        gl_y = 500 - y      
        btn_x, btn_y = game.restart_button_pos
        size = game.button_size
        if (btn_x - size//2 <= x <= btn_x + size//2 and 
            btn_y - size//2 <= gl_y <= btn_y + size//2):
            reset_game()
        btn_x, btn_y = game.play_pause_button_pos
        if (btn_x - size//2 <= x <= btn_x + size//2 and 
            btn_y - size//2 <= gl_y <= btn_y + size//2):
            game.paused = not game.paused
            if game.paused:
                print(f"Paused. Current Score: {game.score}")
            else:
                game.last_time = time.time()  
        btn_x, btn_y = game.exit_button_pos
        if (btn_x - size//2 <= x <= btn_x + size//2 and 
            btn_y - size//2 <= gl_y <= btn_y + size//2):
            print(f"Goodbye! Final Score: {game.score}")
            glutLeaveMainLoop()
    glutPostRedisplay()

def display():
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glLoadIdentity()
    glViewport(0, 0, 500, 500)
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrtho(0.0, 500, 0.0, 500, 0.0, 1.0)
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    draw_catcher()
    draw_diamond()
    draw_restart_button()
    draw_play_pause_button()
    draw_exit_button()
    glutSwapBuffers()

def idle():
    update_diamond_position()
    glutPostRedisplay()

glutInit()
glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH)
glutInitWindowSize(500, 500)
glutInitWindowPosition(0, 0)
glutCreateWindow(b"Catch the Diamonds!") 
glutDisplayFunc(display)
glutSpecialFunc(keyboard_special)
glutMouseFunc(mouse_click)
glutIdleFunc(idle)
spawn_new_diamond()
glutMainLoop()