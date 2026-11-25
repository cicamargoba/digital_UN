from pathlib import Path
from html import escape
import xml.etree.ElementTree as ET

OUT=Path(__file__).resolve().parents[1]/'Docs'
ns='{http://www.w3.org/2000/svg}'
r=ET.parse(OUT/'MIPI_LCD_vid_mem_bloques.svg').getroot()
colors={e.get('data-net'):e.get('stroke') for e in r.findall(ns+'path') if e.get('data-net')}
s=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="4630" viewBox="0 0 1600 4630">',
   '<rect width="1600" height="4630" fill="white"/>',
   '<defs><marker id="a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#384d5c"/></marker></defs>']
def t(x,y,value,size=21,color='#1a2933',bold=False,anchor='start'):
    s.append(f'<text x="{x}" y="{y}" font-family="sans-serif" font-size="{size}" font-weight="{"bold" if bold else "normal"}" fill="{color}" text-anchor="{anchor}">{escape(value)}</text>')
def box(x,y,w,h,fill='#f7fafc'):
    s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="#526d7e" stroke-width="1.5"/>')
def arrow(points):
    assert all(a[0]==b[0] or a[1]==b[1] for a,b in zip(points,points[1:]))
    d='M'+' L'.join(f'{x},{y}' for x,y in points)
    s.append(f'<path d="{d}" fill="none" stroke="#384d5c" stroke-width="2.2" marker-end="url(#a)"/>')

def state(name,y,rst,req,inc=0,delay=0,x=200,w=600,done=0):
    s.append(f'<g id="{name}">')
    box(x,y,w,230,'#edf4f7')
    for i,(net,value) in enumerate([('RST_ALL',rst),('INC_A',inc),('START_DELAY',delay),('INIT_REQ',req),('INIT_DONE',done)]):
        t(x+50,y+43+i*38,f'{net} = {value}',25,color=colors.get(net,'#1a2933'))
    s.append('</g>')

t(35,43,'CTRL',29,bold=True)
t(500,85,'RESET',23,bold=True,anchor='middle')
arrow([(500,95),(500,120)])
state('S_INIT',120,1,0)
arrow([(500,350),(500,390)])
s.append('<polygon points="500,390 660,450 500,510 340,450" fill="#fff7e9" stroke="#526d7e" stroke-width="1.5"/>')
t(500,457,'RESET = 1?',23,bold=True,anchor='middle')
arrow([(660,450),(900,450),(900,235),(800,235)])
t(685,438,'Sí',20)
arrow([(500,510),(500,570)]);t(520,550,'No',20)
state('S_READ',570,0,0)
arrow([(500,800),(500,860)])
state('S_SEND',860,0,1)
arrow([(500,1090),(500,1150)])
state('S_WAIT_READY',1150,0,0)
arrow([(500,1380),(500,1440)])
s.append('<polygon points="500,1440 660,1500 500,1560 340,1500" fill="#fff7e9" stroke="#526d7e" stroke-width="1.5"/>')
t(500,1507,'INIT_READY = 1?',23,bold=True,anchor='middle')
arrow([(660,1500),(900,1500),(900,1265),(800,1265)])
t(685,1488,'No',20)
arrow([(500,1560),(500,1620)]);t(520,1600,'Sí',20)
state('S_INC_A',1620,0,0,inc=1)
arrow([(500,1850),(500,1910)])
state('S_CHECK_LAST',1910,0,0)
arrow([(500,2140),(500,2200)])
s.append('<polygon points="500,2200 660,2260 500,2320 340,2260" fill="#fff7e9" stroke="#526d7e" stroke-width="1.5"/>')
t(500,2267,'LAST = 1?',23,bold=True,anchor='middle')
arrow([(340,2260),(50,2260),(50,975),(200,975)]);t(310,2248,'No',20)
arrow([(660,2260),(1230,2260),(1230,2320)]);t(685,2248,'Sí',20)
state('S_WAIT_TX',2320,0,0,x=950,w=560)
arrow([(1230,2550),(1230,2600)])
s.append('<polygon points="1230,2600 1400,2660 1230,2720 1060,2660" fill="#fff7e9" stroke="#526d7e" stroke-width="1.5"/>')
t(1230,2667,'INIT_DONE_TX = 1?',23,bold=True,anchor='middle')
arrow([(1400,2660),(1550,2660),(1550,2435),(1510,2435)]);t(1420,2648,'No',20)
arrow([(1230,2720),(1230,2780)]);t(1250,2760,'Sí',20)
state('S_START_DELAY',2780,0,0,delay=1,x=950,w=560)
arrow([(1230,3010),(1230,3070)])
state('S_WAIT_DELAY',3070,0,0,x=950,w=560)
arrow([(1230,3300),(1230,3350)])
s.append('<polygon points="1230,3350 1400,3410 1230,3470 1060,3410" fill="#fff7e9" stroke="#526d7e" stroke-width="1.5"/>')
t(1230,3417,'DONE_DELAY = 1?',23,bold=True,anchor='middle')
arrow([(1400,3410),(1550,3410),(1550,3185),(1510,3185)]);t(1420,3398,'No',20)
arrow([(1230,3470),(1230,3530)]);t(1250,3510,'Sí',20)
state('S_INC_NEXT',3530,0,0,inc=1,x=950,w=560)
arrow([(1230,3760),(1230,3820)])
state('S_READ_NEXT',3820,0,0,x=950,w=560)
arrow([(1230,4050),(1230,4110)])
s.append('<polygon points="1230,4110 1400,4170 1230,4230 1060,4170" fill="#fff7e9" stroke="#526d7e" stroke-width="1.5"/>')
t(1230,4177,"OP = 2'b10?",23,bold=True,anchor='middle')
arrow([(1060,4170),(25,4170),(25,975),(200,975)]);t(1035,4158,'No',20,anchor='end')
arrow([(1230,4230),(1230,4290)]);t(1250,4270,'Sí',20)
state('S_END',4290,0,0,x=950,w=560,done=1)
arrow([(1510,4405),(1570,4405),(1570,4570),(1230,4570),(1230,4520)])
s.append('</svg>')
(OUT/'CTRL_flujo_inicio.svg').write_text('\n'.join(s))
print('CTRL_flujo_inicio.svg: pasos con asignaciones explícitas, sin comentarios ni ejemplos.')
