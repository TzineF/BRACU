from OpenGL.GL import *
from OpenGL.GLUT import *
from OpenGL.GLU import *
import random

width, height = 700, 500
pts = []
sped = 1.0
blnk = False
pause = False

def display():
    glClear(GL_COLOR_BUFFER_BIT)
    glClearColor(0.0, 0.0, 0.0, 1.0)
    draw_pts()
    glutSwapBuffers()

def timespan(value):
    glutPostRedisplay()
    glutTimerFunc(16, timespan, 0)

def mouse_button(button, sts, x, y):
    global pts, blnk
    if button == GLUT_RIGHT_BUTTON and sts == GLUT_DOWN:
        n_x, n_y = random.choice([-1, 1]), random.choice([-1, 1])
        clr = (random.random(), random.random(), random.random())
        pts.append((x, height-y, n_x, n_y, clr))
    elif button == GLUT_LEFT_BUTTON and sts == GLUT_DOWN:
        blnk = not blnk

def draw_pts():
    global pts
    glPointSize(5)
    glBegin(GL_POINTS)
    for i in range(len(pts)):
        x, y, n_x, n_y, clr = pts[i]
        glColor3f(*clr if not blnk else [0, 0, 0])
        glVertex2f(x, y)
        if not pause:
            x += n_x * sped
            y += n_y * sped
            if x < 0 or x > width:
                n_x = -n_x
            if y < 0 or y > height:
                n_y = -n_y
            pts[i] = (x, y, n_x, n_y, clr)
    glEnd()

def keyboard_keys(key, x, y):
    global sped
    if key == GLUT_KEY_UP:
        sped *= 1.3
    elif key == GLUT_KEY_DOWN:
        sped /= 1.3

def pause_resume(key, x, y):
    global pause
    if key == b' ':
        pause = not pause

glutInit()
glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGB)
glutInitWindowSize(width, height)
glutCreateWindow(b"Amazing Box")
glOrtho(0, width, 0, height, -1, 1)
glutDisplayFunc(display)
glutSpecialFunc(keyboard_keys)
glutMouseFunc(mouse_button)
glutKeyboardFunc(pause_resume)
glutTimerFunc(0, timespan, 0)
glutMainLoop()