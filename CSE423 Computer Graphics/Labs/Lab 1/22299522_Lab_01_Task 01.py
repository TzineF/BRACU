from OpenGL.GL import *
from OpenGL.GLUT import *
from OpenGL.GLU import *
import random


def build_house():
    glPointSize(4)
    glLineWidth(3)
    # body
    glBegin(GL_LINES)
    glColor3f(0, 0.5, 0.5)
    glVertex2f(550, 300)
    glVertex2f(550, 100)
    glVertex2f(200, 300)
    glVertex2f(200, 100)
    glVertex2f(198, 100)
    glVertex2f(551, 100)
    glColor3f(0, 1, 0)
    glEnd()
    #roof
    glBegin(GL_TRIANGLES)
    glVertex2f(375, 450)
    glVertex2f(175, 300)
    glColor3f(0.75, 0.5, 1)
    glVertex2f(575, 300)
    glVertex2f(375, 450)
    glEnd()
    #door
    glPointSize(5)
    glLineWidth(2)
    glBegin(GL_LINES)
    glColor3f(0.85, 0.75, 0)
    glVertex2f(350, 100)
    glVertex2f(350, 200)
    glVertex2f(310, 100)
    glVertex2f(310, 200)
    glVertex2f(350, 200)
    glVertex2f(310, 200)
    #windows
    glColor3f(0.85, 0.75, 0)
    glVertex2f(450, 200)
    glVertex2f(500, 200)
    glVertex2f(450, 200)
    glVertex2f(450, 250)
    glVertex2f(450, 250)
    glVertex2f(500, 250)
    glVertex2f(500, 250)
    glVertex2f(500, 200)
    glVertex2f(475, 200)
    glVertex2f(475, 250)
    glVertex2f(450, 225)
    glVertex2f(500, 225)
    glEnd()
    #doorknob
    glPointSize(5.5)
    glBegin(GL_POINTS)
    glColor3f(0, 0.5, 0.5)
    glVertex2f(320, 150)
    glEnd()


sky_backgrnd = (0.0, 0.1, 0.0, 0.0)
rain_angle = 0.25
raindrop_pos = []


def render_raindrop(x, y):
    glColor3f(0.1, 1, 1)
    glPointSize(2)
    glBegin(GL_POINTS)
    glVertex2f(x, y)
    glEnd()


for i in range(350):
    x = random.uniform(0, 750)
    y = random.uniform(100, 600)
    raindrop_pos.append((x, y))


def raindrop_falls():
    global rain_angle
    for i in range(0, len(raindrop_pos)):
        n_x, n_y = raindrop_pos[i]
        n_x += rain_angle
        n_y -= 1

        if (n_y < 100) or (205 < n_x < 555 and 100 < n_y < 300):
            n_x = random.uniform(0, 750)
            n_y = random.uniform(100, 600)
        raindrop_pos[i] = (n_x, n_y)


def specialKeyListener(key, x, y):
    global rain_angle
    if key == GLUT_KEY_RIGHT:
        rain_angle += 0.25
        print("Rotate Right")
    elif key == GLUT_KEY_LEFT:
        rain_angle -= 0.25
        print("Rotate Left")

    glutPostRedisplay()


def keyboardListener(key, x, y):
    global sky_backgrnd
    if (key == b'd'):
        sky_backgrnd = (0.9, 1, 1, 1)
        print("The background has changed to day")
    elif (key == b'b'):
        sky_backgrnd = (0.0, 0.0, 0.0, 0.0)
        print("The background has changed to night")
    glutPostRedisplay()


def animate():
    raindrop_falls()
    glutPostRedisplay()


def iterate():
    glViewport(0, 0, 750, 600)
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrtho(0.0, 750, 0.0, 700, 0.0, 1.0)
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()


def showScreen():
    glClearColor(*sky_backgrnd)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glLoadIdentity()
    iterate()
    build_house()
    for i in raindrop_pos:
        render_raindrop(i[0], i[1])
    glutSwapBuffers()


glutInit()
glutInitDisplayMode(GLUT_RGBA)
glutInitWindowSize(750, 600)
glutInitWindowPosition(0, 0)
wind = glutCreateWindow(b"Building a House in Rainfall")
glutDisplayFunc(showScreen)
glutKeyboardFunc(keyboardListener)
glutIdleFunc(animate)
glutSpecialFunc(specialKeyListener)
glutMainLoop()