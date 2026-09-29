from OpenGL.GL import *
from OpenGL.GLUT import *
from OpenGL.GLU import *
import math
import random

# === Game State ===
player_pos = [0, 0]  
player_gun_angle = 0
bullets = []
enemies = []
camera_pos = [0, 500, 500]
camera_angle = 0
first_person_view = False
cheat_mode = False
cheat_vision = False
score = 0
missed_bullets = 0
lives = 5
game_over = False
start_time = 0  
last_frame_time = 0  
cheat_fire_delay = 0.5
cheat_last_shot_time=0  

# === Constants ===
bullet_speed = 3
enemy_speed = 20 
enemy_size = 30
fovY = 120
GRID_LENGTH = 600
MAX_MISSES = 10


# === Drawing ===
def draw_shapes():
    glPushMatrix()
    glTranslatef(player_pos[0], player_pos[1], 0)
    if game_over:
        glRotatef(90, 1, 0, 0)

    # Body
    glPushMatrix()
    glColor3f(0.2, 0.5, 0.8)
    glScalef(1.5, 1, 2.5)
    glutSolidCube(40)
    glPopMatrix()

    # Head
    glPushMatrix()
    glColor3f(1.0, 0.8, 0.6)
    glTranslatef(0, 0, 100)
    glutSolidSphere(20, 20, 20)
    glPopMatrix()

    # Neck
    glPushMatrix()
    glColor3f(0.6, 0.3, 0.1)
    glTranslatef(0, 0, 80)
    glRotatef(-90, 1, 0, 0)
    gluCylinder(gluNewQuadric(), 4, 4, 15, 10, 10)
    glPopMatrix()

    # Arms
    for d in [-1, 1]:
        glPushMatrix()
        glColor3f(1.0, 0.8, 0.6)
        glTranslatef(0, 0, 70)
        glRotatef(player_gun_angle, 0, 0, 1)
        glTranslatef(d * 30, 0, 0)
        glRotatef(90, 0, 1, 0)
        gluCylinder(gluNewQuadric(), 4, 4, 40, 10, 10)
        glPopMatrix()

    # Legs
    for d in [-1, 1]:
        glPushMatrix()
        glColor3f(1.0, 0.8, 0.6)  # Skin color
        glTranslatef(d * 15, 0, -20)  # Move to bottom of body
        glRotatef(-90, 1, 0, 0)  # Point the cylinder downward
        gluCylinder(gluNewQuadric(), 5, 5, 40, 10, 10)  # Height = 40
        glPopMatrix()
    # Gun
    glPushMatrix()
    glColor3f(0.1, 0.1, 0.1)
    glTranslatef(0, 0, 70)
    glRotatef(player_gun_angle, 0, 0, 1)
    glTranslatef(30, 0, 0)
    glRotatef(90, 0, 1, 0)
    gluCylinder(gluNewQuadric(), 3, 3, 30, 10, 10)
    glPopMatrix()

    glPopMatrix()

    for bullet in bullets:
        glPushMatrix()
        glTranslatef(bullet['x'], bullet['y'], 70)
        glColor3f(1, 1, 0)
        glutSolidCube(8)
        glPopMatrix()

def draw_enemies():
    if game_over:
        return

    t = glutGet(GLUT_ELAPSED_TIME) / 1000
    for e in enemies:
        scale = 0.8 + 0.2 * math.sin(t + e['phase'])
        
        #enemy body
        glPushMatrix()
        glTranslatef(e['x'], e['y'], 0)
        glScalef(scale, scale, scale)
        glColor3f(1, 0, 0) 
        glutSolidSphere(e['size'], 10, 10)
        glPopMatrix()
        
        #enemy head
        glPushMatrix()
        glTranslatef(e['x'], e['y'], e['size'] + 20)  
        glColor3f(1, 1, 0) 
        glutSolidSphere(e['size'] * 0.5, 10, 10)  
        glPopMatrix()

# === Enemy Functions ===
def add_enemy():
    while True:
        enemy_x = random.randint(-GRID_LENGTH, GRID_LENGTH)
        enemy_y = random.randint(-GRID_LENGTH, GRID_LENGTH)
        if math.hypot(enemy_x - player_pos[0], enemy_y - player_pos[1]) > 400:
            break
    enemies.append({'x': enemy_x, 'y': enemy_y, 'size': enemy_size, 'phase': random.uniform(0, math.pi * 2)})

def move_enemies(dt):
    if game_over:
        return
    for enemy in enemies:
        dx = player_pos[0] - enemy['x']
        dy = player_pos[1] - enemy['y']
        dist = math.hypot(dx, dy)
        if dist > 40:
            angle = math.atan2(dy, dx)
            enemy['x'] += enemy_speed * dt * math.cos(angle)
            enemy['y'] += enemy_speed * dt * math.sin(angle)

def check_collisions():
    global bullets, enemies, score
    if game_over:
        return
    to_remove = []
    for bullet in bullets:
        for enemy in enemies:
            if math.hypot(bullet['x'] - enemy['x'], bullet['y'] - enemy['y']) < enemy_size:
                to_remove.append((bullet, enemy))
                break
    for bullet, enemy in to_remove:
        bullets.remove(bullet)
        enemies.remove(enemy)
        add_enemy()
        score += 1

def check_player_collision():
    global lives, game_over
    if game_over:
        return
    for enemy in enemies:
        if math.hypot(enemy['x'] - player_pos[0], enemy['y'] - player_pos[1]) < 50:
            lives -= 1
            if lives <= 0:
                lives = 0
                game_over = True
            enemies.remove(enemy)
            add_enemy()

# === Cheat Mode ===
def is_enemy_in_sight():
    rad = math.radians(player_gun_angle)
    dx = math.cos(rad)
    dy = math.sin(rad)

    for enemy in enemies:
        ex = enemy['x'] - player_pos[0]
        ey = enemy['y'] - player_pos[1]
        dot = ex * dx + ey * dy
        if dot > 0:
            proj_x = dx * dot
            proj_y = dy * dot
            dist = math.hypot(ex - proj_x, ey - proj_y)
            if dist < 30:
                return True
    return False

def draw_grid():
    glColor3f(0.6, 0.8, 0.8)
    step = 50
    glBegin(GL_LINES)
    for i in range(-GRID_LENGTH, GRID_LENGTH+1, step):
        glVertex3f(i, -GRID_LENGTH, 0)
        glVertex3f(i, GRID_LENGTH, 0)
        glVertex3f(-GRID_LENGTH, i, 0)
        glVertex3f(GRID_LENGTH, i, 0)
    glEnd()

def draw_walls():
    glColor3f(0.5, 0.2, 0.9)
    h = 100
    glBegin(GL_QUADS)
    for x1, y1, x2, y2 in [
        (-GRID_LENGTH, -GRID_LENGTH, GRID_LENGTH, -GRID_LENGTH),
        (-GRID_LENGTH, GRID_LENGTH, GRID_LENGTH, GRID_LENGTH),
        (-GRID_LENGTH, -GRID_LENGTH, -GRID_LENGTH, GRID_LENGTH),
        (GRID_LENGTH, -GRID_LENGTH, GRID_LENGTH, GRID_LENGTH)]:
        glVertex3f(x1, y1, 0)
        glVertex3f(x2, y2, 0)
        glVertex3f(x2, y2, h)
        glVertex3f(x1, y1, h)
    glEnd()

def draw_text(x, y, text, font=GLUT_BITMAP_HELVETICA_18):
    glColor3f(1,1,1)
    glMatrixMode(GL_PROJECTION)
    glPushMatrix()
    glLoadIdentity()
    gluOrtho2D(0, 1000, 0, 800)
    glMatrixMode(GL_MODELVIEW)
    glPushMatrix()
    glLoadIdentity()
    glRasterPos2f(x, y)
    for ch in text:
        glutBitmapCharacter(font, ord(ch))
    glPopMatrix()
    glMatrixMode(GL_PROJECTION)
    glPopMatrix()
    glMatrixMode(GL_MODELVIEW)

# === Camera ===
def setupCamera():
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluPerspective(fovY, 1.25, 0.1, 1500)
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    if first_person_view:
        x, y, z = player_pos[0], player_pos[1], 60
        gluLookAt(x, y, z, x + math.cos(math.radians(player_gun_angle)), y + math.sin(math.radians(player_gun_angle)), z, 0, 0, 1)
    else:
        x, y, z = camera_pos
        gluLookAt(x, y, z, player_pos[0], player_pos[1], 0, 0, 0, 1)

# === Game Logic ===
def idle():
    global bullets, missed_bullets, start_time, last_frame_time, game_over
    if game_over:
        return
    current_time = glutGet(GLUT_ELAPSED_TIME) / 1000
    dt = current_time - last_frame_time
    last_frame_time = current_time

    for b in bullets:
        rad = math.radians(b['angle'])
        b['x'] += bullet_speed * math.cos(rad)
        b['y'] += bullet_speed * math.sin(rad)

    # Remove bullets that go out of bounds and count as missed
    active_bullets = []
    for b in bullets:
        dist = math.hypot(b['x'] - player_pos[0], b['y'] - player_pos[1])
        if dist > GRID_LENGTH:
            missed_bullets += 1
            if missed_bullets >= MAX_MISSES:
                game_over = True
        else:
            active_bullets.append(b)
    bullets = active_bullets

    global player_gun_angle, cheat_last_shot_time
    if cheat_mode and not game_over and enemies:
    # Find the nearest enemy
       closest_enemy = min(enemies, key=lambda e: math.hypot(e['x'] - player_pos[0], e['y'] - player_pos[1]))
       dx = closest_enemy['x'] - player_pos[0]
       dy = closest_enemy['y'] - player_pos[1]
       target_angle = math.degrees(math.atan2(dy, dx)) % 360

    # Smoothly rotate gun toward enemy
       angle_diff = (target_angle - player_gun_angle + 360) % 360
       if angle_diff > 180:
          player_gun_angle -= min(5, 360 - angle_diff)
       else:
          player_gun_angle += min(5, angle_diff)
       player_gun_angle %= 360

    # If aligned within 5 degrees and enemy in sight, shoot
       if abs(angle_diff) < 5 and is_enemy_in_sight():
          if current_time - cheat_last_shot_time >= cheat_fire_delay:
             mouseListener(GLUT_LEFT_BUTTON, GLUT_DOWN, 0, 0)
             cheat_last_shot_time = current_time

    if current_time - start_time > 1:
        move_enemies(dt)
        check_player_collision()

    check_collisions()
    glutPostRedisplay()

def keyboardListener(key, x, y):
    global player_pos, player_gun_angle, first_person_view, cheat_mode, cheat_vision
    if game_over and key == b'r':
        reset_game()
    step = 10
    if key == b'w':
        rad = math.radians(player_gun_angle)
        player_pos[0] += step * math.cos(rad)
        player_pos[1] += step * math.sin(rad)
    elif key == b's':
        rad = math.radians(player_gun_angle)
        player_pos[0] -= step * math.cos(rad)
        player_pos[1] -= step * math.sin(rad)
    elif key == b'a':
        player_gun_angle = (player_gun_angle + 5) % 360
    elif key == b'd':
        player_gun_angle = (player_gun_angle - 5) % 360
    elif key == b'f':
        first_person_view = not first_person_view
    elif key == b'c':
        cheat_mode = not cheat_mode
    elif key == b'v':
        if cheat_mode and first_person_view:
           cheat_vision = not cheat_vision

def specialKeyListener(key, x, y):
    global camera_pos, camera_angle
    cx, cy, cz = camera_pos
    if key == GLUT_KEY_LEFT:
        camera_angle += 5
    elif key == GLUT_KEY_RIGHT:
        camera_angle -= 5
    elif key == GLUT_KEY_UP:
        cz -= 10
    elif key == GLUT_KEY_DOWN:
        cz += 10
    camera_pos = [math.cos(math.radians(camera_angle)) * 500, math.sin(math.radians(camera_angle)) * 500, cz]

def mouseListener(button, state, x, y):
    if game_over:
        return
    if button == GLUT_LEFT_BUTTON and state == GLUT_DOWN:
        rad = math.radians(player_gun_angle)
        bullets.append({'x': player_pos[0] + 30 * math.cos(rad), 'y': player_pos[1] + 30 * math.sin(rad), 'angle': player_gun_angle})
    elif button == GLUT_RIGHT_BUTTON and state == GLUT_DOWN:
        global first_person_view
        first_person_view = not first_person_view

# === Display ===
def showScreen():
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glLoadIdentity()
    glViewport(0, 0, 1000, 800)
    setupCamera()
    draw_grid()
    draw_walls()
    draw_shapes()
    draw_enemies()
    # draw_text(10, 770, f"Player position: {player_pos}")
    # draw_text(10, 740, f"Gun angle: {player_gun_angle}")
    draw_text(10, 700, f"Lives: {lives}  Score: {score}  Missed: {missed_bullets}")
    if game_over:
        draw_text(400, 400, "GAME OVER - Press R to Restart", GLUT_BITMAP_TIMES_ROMAN_24)
    glutSwapBuffers()

# === Main Setup ===
def reset_game():
    global player_pos, player_gun_angle, bullets, enemies
    global score, missed_bullets, lives, game_over
    global start_time, last_frame_time, cheat_mode, cheat_vision

    player_pos = [0, 0]
    player_gun_angle = 0
    bullets.clear()
    enemies.clear()
    for _ in range(5):
        add_enemy()
    score = 0
    missed_bullets = 0
    lives = 5
    game_over = False
    cheat_mode = False
    cheat_vision = False
    start_time = glutGet(GLUT_ELAPSED_TIME) / 1000
    last_frame_time = start_time


def main():
    global start_time, last_frame_time
    glutInit()
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGB | GLUT_DEPTH)
    glutInitWindowSize(1000, 800)
    glutInitWindowPosition(0, 0)
    glutCreateWindow(b"3D OpenGL Game - Bullet Frenzy")
    glEnable(GL_DEPTH_TEST)
    for _ in range(5):
        add_enemy()
    start_time = glutGet(GLUT_ELAPSED_TIME) / 1000
    last_frame_time = start_time
    glutDisplayFunc(showScreen)
    glutKeyboardFunc(keyboardListener)
    glutSpecialFunc(specialKeyListener)
    glutMouseFunc(mouseListener)
    glutIdleFunc(idle)
    glutMainLoop()

if __name__ == "__main__":
    main()  