from pathlib import Path
from html import escape
import re

OUT=Path(__file__).resolve().parents[1]/'Docs'
OUT.mkdir(parents=True,exist_ok=True)
P=[]
NETS={}
MARKERS=set()
END_COLORS={}
PALETTE=['#245b9e','#c05a23','#27834a','#a03b46','#6b52a2','#976a21',
         '#287d8e','#a84980','#58636e','#6e8626','#4d70bf','#a4614b',
         '#2b9b82','#bd7434','#80513e','#9964a0','#6a934a','#427d9d',
         '#bd4d52','#446756','#8e7f36','#6e5f7d','#467f79','#8a536a',
         '#3a526f','#a17859','#566c96','#7c8b57','#a45b69','#377f95']
def port_color(label,role=None):
    return '#14212a'
def txt(x,y,t,n=20,anchor='start',bold=False,color='#14212a'):
    P.append(f'<text x="{x}" y="{y}" font-family="sans-serif" font-size="{n}" text-anchor="{anchor}" font-weight="{"bold" if bold else "normal"}" fill="{color}">{escape(t)}</text>')
def rect(x,y,w,h,fill='#fff',stroke='#283e4c',dash=None,width=2):
    style=f' stroke-dasharray="{dash}"' if dash else ''
    P.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"{style}/>')
def wire(points,net=None,bits=1,arrow=True):
    assert all(a[0]==b[0] or a[1]==b[1] for a,b in zip(points,points[1:])),points
    net=net or str(points[0])
    if net not in NETS:
        assert len(NETS)<len(PALETTE),'No reutilizar un color para otra conexión'
        NETS[net]=PALETTE[len(NETS)]
    color=NETS[net]
    END_COLORS[tuple(points[0])]=color
    END_COLORS[tuple(points[-1])]=color
    marker='arrow_'+color[1:]
    if marker not in MARKERS:
        P.append(f'<defs><marker id="{marker}" markerUnits="userSpaceOnUse" markerWidth="15" markerHeight="15" viewBox="0 0 10 10" refX="9" refY="5" orient="auto"><path d="M0,0 L10,5 L0,10 Z" fill="{color}"/></marker></defs>')
        MARKERS.add(marker)
    d='M'+' L'.join(f'{x},{y}' for x,y in points)
    width=5.2 if bits!=1 else 2.1
    P.append(f'<path d="{d}" class="wire-halo" fill="none" stroke="white" stroke-width="{width+2.4}"/>')
    P.append(f'<path d="{d}" data-net="{escape(net)}" data-bits="{bits}" fill="none" stroke="{color}" stroke-width="{width}"'+(f' marker-end="url(#{marker})"' if arrow else '')+f'><title>{escape(net)} — {bits} bit(s)</title></path>')
def dot(x,y,net):
    P.append(f'<circle cx="{x}" cy="{y}" r="5" fill="{NETS[net]}"/>')
def block(x,y,w,h,name,ins=(),outs=(),fill='#edf1f4',role=None,left_outs=(),right_ins=()):
    rect(x,y,w,h,fill)
    for label,yy in ins:txt(x+12,yy+7,label,18,color=port_color(label,role))
    for label,yy in outs:txt(x+w-12,yy+7,label,18,'end',color=port_color(label,role))
    for label,yy in left_outs:
        P.append('<g data-port-direction="out" data-side="left">')
        txt(x+12,yy+7,label,18,color=port_color(label,role));P.append('</g>')
    for label,yy in right_ins:
        P.append('<g data-port-direction="in" data-side="right">')
        txt(x+w-12,yy+7,label,18,'end',color=port_color(label,role));P.append('</g>')
    txt(x+w/2,y+h-18,name,24,'middle',True)
def begin(title,w=2100,h=1460):
    global P,NETS,MARKERS,END_COLORS
    NETS={};MARKERS=set();END_COLORS={}
    P=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
       f'<rect width="{w}" height="{h}" fill="white"/>',
       '<defs><marker id="a" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto"><path d="M0,0 L9,4.5 L0,9 Z" fill="#263e4f"/></marker></defs>']
    txt(32,45,title,29,bold=True)
    txt(32,78,'Un color por conexión; solo sus ramas repiten color. Trazo fino: 1 bit. Trazo grueso: bus o grupo de señales.',20)
def save(name):
    if name=='MIPI_TX_bloques.svg' and (OUT/'MIPI_TX_adopcion.md').exists():
        return
    result=[]
    for item in P:
        m=re.match(r'<text x="([\d.]+)" y="([\d.]+)"',item)
        if m:
            x,y=map(float,m.groups())
            for (px,py),color in END_COLORS.items():
                if abs(x-px)<=18 and 4<=y-py<=10:
                    item=re.sub(r'fill="#[0-9a-fA-F]+"',f'fill="{color}"',item);break
            if '>SEL_BYTE[1:0]</text>' in item and 'SEL_BYTE' in NETS:
                item=re.sub(r'fill="#[0-9a-fA-F]+"',f'fill="{NETS["SEL_BYTE"]}"',item)
        result.append(item)
    (OUT/name).write_text('\n'.join(result+['</svg>']))

def phy_lp_example(x,y,w=2040,h=500):
    P.append('<g id="lp-output-waveform">')
    rect(x,y,w,h,'#ffffff','#a1b1bd',width=1.3)
    txt(x+20,y+34,'Forma de onda de salida LPDT — ejemplo del byte de payload B0',25,bold=True)
    txt(x+20,y+66,'D0P / D0N y su diferencia. Bits LSB primero; niveles lógicos, no voltajes analógicos.',20)
    px=x+170;span=w-220;step=span/8
    for k in range(9):
        xx=px+k*step
        P.append(f'<path d="M{xx},'+str(y+118)+f' V{y+380}" stroke="#e4e9ed" stroke-width="1" stroke-dasharray="3,5" fill="none"/>')
        if k<8:txt(xx+step/2,y+103,f'b{k} = {(0xb0>>k)&1}',19,'middle')
    events=[]
    for k in range(8):
        bit=(0xb0>>k)&1
        events.extend([(k*.2,bit,1-bit),(k*.2+.1,0,0)])
    events.append((1.6,0,0))
    for component,base,amp,color in [('P',y+180,40,'#245b9e'),('N',y+260,40,'#27834a'),('D',y+340,30,'#6b52a2')]:
        points=[]
        for time,pv,nv in events:
            value=pv if component=='P' else nv if component=='N' else pv-nv
            xx=px+time*span/1.6;yy=base-value*amp
            if points:points.append((xx,points[-1][1]))
            points.append((xx,yy))
        path='M'+' L'.join(f'{a:.2f},{b:.2f}' for a,b in points)
        P.append(f'<path d="{path}" fill="none" stroke="{color}" stroke-width="2.2"/>')
    txt(x+26,y+164,'D0P',22,bold=True,color='#245b9e')
    txt(x+26,y+244,'D0N',22,bold=True,color='#27834a')
    txt(x+18,y+346,'D0P−D0N',19,bold=True,color='#6b52a2')
    for yy,label in [(y+140,'1'),(y+180,'0'),(y+220,'1'),(y+260,'0'),(y+310,'+1'),(y+340,'0'),(y+370,'−1')]:txt(px-12,yy+5,label,16,'end')
    P.append(f'<path d="M{px},{y+405} H{px+span}" stroke="#6f7d86" stroke-width="1" fill="none"/>')
    for t in (0,.4,.8,1.2,1.6):
        xx=px+t*span/1.6
        P.append(f'<path d="M{xx},{y+400} V{y+410}" stroke="#6f7d86" stroke-width="1" fill="none"/>')
        txt(xx,y+431,str(t).replace('.',','),18,'middle')
    txt(px+span/2,y+457,'Tiempo dentro del byte [µs]',20,'middle')
    txt(x+20,y+484,'Bit 1: 10→00; bit 0: 01→00; ~100 ns por fase. Onda idealizada. 87 lo genera LP_TX; bytes DSI desde ROM.',20)
    P.append('</g>')

# TOP, deliberately close to the structure of the supplied PDF.
begin('MIPI_LCD — TOP: control, memoria, transmisor y PHY',2100,1950)
rect(25,130,850,650,'#fafcfd','#bdc7ce',dash='2,6',width=1.2);txt(42,162,'INIT_SEQUENCER',21,bold=True)
block(370,185,290,270,'CTRL',ins=[('RESET',220),('DONE_DELAY',265),('OP[1:0]',310),('LAST',335),('DONE_TX',355),('READY',400)],
      outs=[('PANEL_RST',195),('INIT_REQ',220),('INC_A',265),('START_DELAY',310),('INIT_DONE',355),('RST_ALL',400)],fill='#dcecf3',role='init')
block(50,195,230,155,'D_COUNT',ins=[('START',235),('DELAY_MS[7:0]',285),('RST',320)],outs=[('DONE',265)],fill='#e6eedc',role='init')
block(50,535,230,125,'A_COUNT',ins=[('INC',575),('RST',615)],outs=[('ADDR[A_AW-1:0]',575)],fill='#e6eedc',role='init')
block(370,535,290,205,'INIT_MEM',ins=[('ADDR',575)],outs=[('OP[1:0]',565),('INIT_BYTE[7:0]',605),('DELAY_MS[7:0]',645),('LAST',685)],fill='#f3e5df',role='init')
block(970,185,460,1055,'MIPI_TX',ins=[('INIT_REQ',220),('INIT_BYTE[7:0]',605),('INIT_LAST',685),('VID_REQ (START)',990),('VID_BYTE[7:0]',1030),('VID_HDR[23:0]',1070)],
      outs=[('LP_P/N[2:0]',900),('HS_BYTE0[7:0]',990),('HS_BYTE1[7:0]',1080),('HS_REQ / CLK_REQ',1170)],
      left_outs=[('INIT_DONE_TX',450),('INIT_READY',495),('VID_READY',1120)],right_ins=[('READY / LOCK',850)],fill='#f5f3de')
block(1550,820,400,420,'PHY',ins=[('LP_P/N[2:0]',900),('HS_BYTE0[7:0]',990),('HS_BYTE1[7:0]',1080),('HS_REQ / CLK_REQ',1170)],
      outs=[('CLKP / CLKN',915),('D0P / D0N',1035),('D1P / D1N',1155)],left_outs=[('READY / LOCK',850)],fill='#f5f3de')
rect(25,900,850,345,'#fafcfd','#bdc7ce',dash='2,6',width=1.2);txt(42,932,'VIDEO_SOURCE',21,bold=True)
block(50,970,230,180,'VIDEO_TIMING',ins=[('ENABLE',1010)],outs=[('VID_REQ (START)',990),('HDR[23:0]',1050)],fill='#e6eedc',role='video')
block(370,970,185,180,'V_COUNT',ins=[('INC',1010)],outs=[('ADDR',1080)],fill='#f3e5df',role='video')
block(625,970,230,180,'VIDEO_MEM',ins=[('ADDR',1080)],outs=[('BYTE[7:0]',1030)],fill='#f5f3de',role='video')

wire([(280,265),(370,265)],'DONE_DELAY')
wire([(660,310),(710,310),(710,175),(15,175),(15,235),(50,235)],'START_DELAY')
wire([(660,265),(745,265),(745,750),(10,750),(10,575),(50,575)],'INC_A')
wire([(280,575),(370,575)],'INIT_ADDR',bits='A_AW')
wire([(660,565),(795,565),(795,480),(330,480),(330,310),(370,310)],'INIT_OP',bits=2)
wire([(660,645),(815,645),(815,500),(310,500),(310,285),(280,285)],'DELAY_MS',bits=8)
wire([(660,220),(970,220)],'INIT_REQ')
wire([(660,605),(970,605)],'INIT_BYTE',bits=8)
wire([(660,685),(830,685),(830,465),(350,465),(350,335),(370,335)],'INIT_LAST')
wire([(660,685),(970,685)],'INIT_LAST')
wire([(660,400),(700,400),(700,760),(35,760),(35,615),(50,615)],'RST_ALL')
wire([(35,760),(35,320),(50,320)],'RST_ALL')
wire([(970,450),(900,450),(900,110),(315,110),(315,355),(370,355)],'INIT_DONE_TX')
wire([(970,495),(920,495),(920,815),(340,815),(340,400),(370,400)],'INIT_READY')
wire([(660,355),(770,355),(770,880),(15,880),(15,1010),(50,1010)],'INIT_DONE')
wire([(660,195),(720,195),(720,95),(2060,95)],'PANEL_RST')
dot(830,685,'INIT_LAST');dot(35,760,'RST_ALL')
txt(2060,85,'PANEL_RST',18,'end')
wire([(280,1050),(305,1050),(305,1195),(895,1195),(895,1070),(970,1070)],'VID_HDR',bits=24)
wire([(555,1080),(625,1080)],'VID_ADDR',bits='VID_AW')
wire([(855,1030),(970,1030)],'VID_BYTE',bits=8)
wire([(970,1120),(950,1120),(950,1225),(460,1225),(460,1150)],'VID_READY')
txt(478,1190,'avance al aceptar un byte',17,color='#536775')
for yy,net,bits in [(900,'LP_P_N',6),(990,'HS_BYTE0',8),(1080,'HS_BYTE1',8),(1170,'HS_REQ_CLK_REQ',2)]:wire([(1430,yy),(1550,yy)],net,bits=bits)
wire([(1550,850),(1430,850)],'PHY_READY_LOCK',bits=2)
for yy,net in [(915,'CLK_P_N'),(1035,'D0_P_N'),(1155,'D1_P_N')]:wire([(1950,yy),(2060,yy)],net,bits=2)
wire([(50,110),(290,110),(290,220),(370,220)],'RESET')
txt(50,100,'RESET',18,color=NETS['RESET'])
P.append(f'<circle cx="50" cy="110" r="4" fill="white" stroke="{NETS["RESET"]}" stroke-width="2"/>')
wire([(280,990),(315,990),(315,950),(915,950),(915,990),(970,990)],'VID_REQ')
rect(30,1280,2040,215,'#f7fafc','#a1b1bd')
txt(50,1318,'RESET externo activo en 1. RST_ALL reinicia A_COUNT/D_COUNT. INIT_DONE habilita VIDEO_TIMING; VID_REQ inicia el paquete.',21)
for x,w,label,bits in [(50,230,'OP[1:0]','bits 10:9 — 2 bits'),(280,160,'LAST','bit 8 — 1 bit'),(440,300,'ARG[7:0]','bits 7:0 — 8 bits')]:
    rect(x,1340,w,50,'#ffffff','#a1b1bd',width=1)
    txt(x+w/2,1361,label,20,'middle',True);txt(x+w/2,1382,bits,15,'middle')
txt(780,1359,'ROM propuesta: 223 posiciones de 11 bits; dirección de 8 bits.',20,bold=True)
txt(780,1386,'OP: 00=BYTE; 01=WAIT_MS; 10=END. WAIT: 07h→7 ms; 09h→9 ms; 41h→65 ms.',20)
txt(50,1421,'LAST=1 identifica WAIT: no se transmite. Mantener su dirección; esperar INIT_DONE_TX antes de activar START_DELAY.',21,bold=True)
txt(50,1454,'INIT_BYTE=ARG[7:0]; DELAY_MS=ARG[7:0]. Inicialización lleva ECC/CRC en ROM; solo video los calcula. LP_TX añade 87.',20)
txt(50,1482,'D_COUNT cuenta unidades de 1 ms; el divisor de reloj es independiente del argumento de 8 bits guardado en ROM.',20)
P.append('<g id="init-frame-format">')
rect(1460,145,610,330,'#ffffff','#a1b1bd',width=1.3)
txt(1480,178,'Trama de salida LPDT — inicialización por D0',19,bold=True)
fields=[('87','8 bits',65),('DI','8 bits',65),('WC_L','8 bits',65),('WC_H','8 bits',65),
        ('ECC','8 bits',65),('PAYLOAD','N × 8 bits',150),('CRC','16 bits',95)]
x=1480
for label,width_label,w in fields:
    rect(x,200,w,52,'#f7fafc','#b8c4cd',width=1)
    txt(x+w/2,221,label,13,'middle',True);txt(x+w/2,242,width_label,12,'middle');x+=w
txt(1480,275,'DI = DT(6) + VC(2); ECC = 6+2 ceros; WC = N bytes.',14)
txt(1480,300,'Entrada: 11→10→00→01→00; 87; paquete DSI; salida a 11.',14)
txt(1480,327,'ROM: paquete B0 00 con ECC y CRC incluidos',17,bold=True)
byte_values=[0x87,0x29,0x02,0x00,0x00,0xb0,0x00,0xd6,0xca]
field_colors=['#eaf0f4']*5+['#e6f0e9']*2+['#f3eadc']*2
for j,(v,fill) in enumerate(zip(byte_values,field_colors)):
    x=1480+j*570/9
    rect(x,342,570/9,43,fill,'#bac5cd',width=1)
    txt(x+570/18,360,f'{v:02X}',15,'middle',True);txt(x+570/18,378,'8 bits',11,'middle')
txt(1480,408,'72 bits = 8 LPDT + 32 header + 16 payload + 16 CRC.',14)
txt(1480,445,'DCS corto: 87 | 05 | 29 | 03 | 1F = 40 bits; sin CRC.',13)
P.append('</g>')
P.append('<g id="video-memory-format">')
rect(1460,495,610,300,'#ffffff','#a1b1bd',width=1.3)
txt(1480,527,'Trama de la memoria de video — ejemplo RGB888',18,bold=True)
txt(1480,553,'VIDEO_MEM: un byte de 8 bits en cada dirección.',15)
for j,(name,value,fill) in enumerate([('R0','96','#f4e5e5'),('G0','3C','#e6f0e9'),('B0','A5','#eaf0f4'),
                                      ('R1','69','#f4e5e5'),('G1','C3','#e6f0e9'),('B1','5A','#eaf0f4')]):
    x=1480+j*95
    rect(x,571,95,68,fill,'#b8c4cd',width=1)
    txt(x+47.5,590,f'ADDR {j}',12,'middle')
    txt(x+47.5,614,name,17,'middle',True)
    txt(x+47.5,633,f'{value}h — 8 bits',12,'middle')
txt(1480,661,'… R2, G2, B2 … hasta el último byte de la imagen.',14)
txt(1480,686,'VID_HDR[23:0] viene de VIDEO_TIMING; no ocupa VIDEO_MEM.',13)
x=1480
for label,width_label,w,fill in [('HDR DSI','32 bits',145,'#eaf0f4'),('VIDEO_MEM / píxeles','WC × 8 bits',300,'#e6f0e9'),('CRC','16 bits',125,'#f3eadc')]:
    rect(x,701,w,45,fill,'#b8c4cd',width=1)
    txt(x+w/2,719,label,13,'middle',True);txt(x+w/2,738,width_label,12,'middle');x+=w
txt(1480,762,'HDR: DI(8)=tipo/canal; WC(16)=nº bytes; ECC(8)=protección.',13)
txt(1480,784,'VID_HDR=DI+WC; MIPI_TX añade ECC. V_COUNT cuenta bytes de píxel.',13)
P.append('</g>')
P.append('<g id="video-frame-sequence">')
rect(30,1530,2040,380,'#ffffff','#a1b1bd',width=1.3)
txt(50,1568,'Secuencia temporal del video — paquetes de líneas, blanking y cuadros',25,bold=True)
def pixel_line(x,label):
    rect(x,1605,440,90,'#ffffff','#8ca1af',width=1.3)
    txt(x+220,1634,label,21,'middle',True)
    for xx,w,name,fill in [(x,90,'HDR 32','#eaf0f4'),(x+90,260,'Píxeles: WC bytes','#e6f0e9'),(x+350,90,'CRC 16','#f3eadc')]:
        rect(xx,1647,w,48,fill,'#b8c4cd',width=1)
        txt(xx+w/2,1677,name,17,'middle')
pixel_line(130,'Cuadro n: línea 0')
rect(570,1605,200,90,'#f2f4f6','#8ca1af',width=1.3)
txt(670,1642,'Sincronismo /',18,'middle');txt(670,1672,'blanking H',18,'middle')
pixel_line(770,'Línea 1')
rect(1210,1605,200,90,'#f2f4f6','#8ca1af',width=1.3)
txt(1310,1642,'Sincronismo /',18,'middle');txt(1310,1672,'blanking H',18,'middle')
txt(1460,1662,'…',32,'middle',True)
pixel_line(1510,'Última línea activa')
P.append('<path d="M1950,1650 H2020 V1715 H90 V1770 H130" fill="none" stroke="#384d5c" stroke-width="2" marker-end="url(#a)"/>')
rect(130,1735,600,70,'#f2f4f6','#8ca1af',width=1.3)
txt(430,1763,'Fin de cuadro: sincronismo / blanking vertical',19,'middle')
txt(430,1790,'No se leen píxeles de VIDEO_MEM en este intervalo',17,'middle')
P.append('<path d="M730,1770 H800" fill="none" stroke="#384d5c" stroke-width="2" marker-end="url(#a)"/>')
rect(800,1735,1150,70,'#e6f0e9','#8ca1af',width=1.3)
txt(1375,1763,'Cuadro n+1: línea 0 → blanking H → línea 1 → …',21,'middle',True)
txt(1375,1790,'Se vuelve a recorrer la imagen con la temporización del nuevo cuadro',17,'middle')
txt(50,1843,'VID_HDR[23:0] puede ser fijo para paquetes de píxeles con el mismo VC, formato y ancho; payload y CRC pueden cambiar.',21)
txt(50,1880,'Sync/blanking dependen del modo DSI. Esquema propuesto: la imagen se recuperó por actividad; los paquetes HS aún no se han validado.',20)
P.append('</g>')
save('MIPI_LCD_vid_mem_bloques.svg')

# Transmitter control and byte datapath.
begin('MIPI_TX — diagrama de conexiones: FSM y camino de datos',2100,1610)
block(90,180,390,650,'CTRL_TX',ins=[('INIT_REQ / VID_REQ',230),('MODE_LP_HS',295),('PHY_READY',360),('COUNT_END',425),('LP_DONE',460),('HS_DONE',500)],
      outs=[('HDR_SEL[1:0]',230),('PAY_EN / COUNT_EN',325),('CRC_INIT / CRC_EN',420),('SEL_BYTE[1:0]',510),('START_LP',565),('START_HS',610),('DONE_TX / READY',695),('SEL_SOURCE',755),('VID_LAST',800)],fill='#dcecf3')
block(650,180,330,180,'HEADER_REGS',ins=[('VID_HDR[23:0]',230),('SEL',290)],outs=[('HEADER_BYTE[7:0]',265),('WC[15:0]',310)],fill='#e6eedc')
block(1110,180,290,180,'ECC_VIDEO',ins=[('VID_HDR[23:0]',230)],outs=[('ECC[7:0]',290)],fill='#e6eedc')
block(650,470,330,180,'PAYLOAD_COUNT',ins=[('WC[15:0]',520),('EN / RST',575)],outs=[('END',560)],fill='#e6eedc')
block(1110,470,290,180,'CRC16_VIDEO',ins=[('BYTE[7:0]',520),('INIT / EN',575)],outs=[('CRC_BYTE[7:0]',560)],fill='#e6eedc')
P.append('<polygon id="packet-mux" points="1510,180 1880,260 1880,580 1510,650" fill="#f5f3de" stroke="#283e4c" stroke-width="2"/>')
for label,yy in [('HEADER_BYTE[7:0]',265),('ECC[7:0]',355),('PAYLOAD[7:0]',445),('CRC_BYTE[7:0]',535)]:txt(1522,yy+7,label,18)
txt(1868,427,'BYTE[7:0]',18,'end')
txt(1695,575,'PACKET_MUX',24,'middle',True)
txt(1710,640,'SEL_BYTE[1:0]',18)
block(650,820,330,180,'LP_LSR / BIT_COUNT',ins=[('LD / SH',860),('BYTE[7:0]',920)],outs=[('BIT0 / END_BYTE',900)],fill='#e6eedc')
block(1110,820,290,210,'CTRL_LP / TIMER',ins=[('START_LP',860),('BIT0 / END_BYTE',920),('INIT_LAST',960)],outs=[('DONE',845),('LP_P / LP_N',900),('LD / SH',950)],fill='#dcecf3')
block(650,1130,330,180,'LANE_SPLIT',ins=[('BYTE[7:0]',1180)],outs=[('BYTE0[7:0]',1180),('BYTE1[7:0]',1240)],fill='#e6eedc')
block(1510,1040,370,270,'CTRL_HS / TIMER',ins=[('START_HS',1090),('BYTE0[7:0]',1160),('BYTE1[7:0]',1230),('LAST',1260)],outs=[('HS0 / HS1[7:0]',1140),('HS_REQ / CLK_REQ',1210),('DONE',1260)],fill='#dcecf3')
block(1510,710,370,320,'SOURCE_MUX',ins=[('INIT_BYTE[7:0]',750),('INIT_LAST',800),('VID_PACKET[7:0]',850),('VID_LAST',900),('SEL_SOURCE',950)],
      outs=[('BYTE[7:0]',800),('LAST',950)],fill='#f5f3de')

wire([(480,230),(560,230),(560,290),(650,290)],'HDR_SEL',bits=2)
wire([(480,510),(590,510),(590,700),(1695,700),(1695,615)],'SEL_BYTE',bits=2)
wire([(500,445),(1510,445)],'VID_PAYLOAD',bits=8)
wire([(1055,445),(1055,520),(1110,520)],'VID_PAYLOAD',bits=8)
wire([(600,130),(620,130),(620,230),(650,230)],'VID_HDR',bits=24)
wire([(620,130),(1060,130),(1060,230),(1110,230)],'VID_HDR',bits=24)
wire([(980,310),(1000,310),(1000,410),(620,410),(620,520),(650,520)],'VID_WC',bits=16)
wire([(480,755),(500,755),(500,685),(1445,685),(1445,950),(1510,950)],'SEL_SOURCE')
wire([(480,800),(525,800),(525,680),(1440,680),(1440,900),(1510,900)],'VID_LAST')
wire([(1475,750),(1510,750)],'INIT_BYTE',bits=8)
wire([(1475,800),(1510,800)],'INIT_LAST')
wire([(980,265),(1020,265),(1020,400),(1475,400),(1475,265),(1510,265)],'HEADER_BYTE',bits=8)
wire([(1400,290),(1450,290),(1450,355),(1510,355)],'ECC_BYTE',bits=8)
wire([(1400,560),(1465,560),(1465,535),(1510,535)],'CRC_BYTE',bits=8)
wire([(480,325),(535,325),(535,575),(650,575)],'PAY_COUNT_EN',bits=2)
wire([(480,420),(565,420),(565,715),(1040,715),(1040,575),(1110,575)],'CRC_INIT_EN',bits=2)
wire([(980,560),(1015,560),(1015,110),(30,110),(30,425),(90,425)],'COUNT_END')
wire([(1880,420),(1960,420),(1960,670),(1465,670),(1465,850),(1510,850)],'VID_PACKET',bits=8)
wire([(1880,800),(1930,800),(1930,1035),(610,1035),(610,920),(650,920)],'TX_BYTE',bits=8)
wire([(610,1035),(610,1180),(650,1180)],'TX_BYTE',bits=8)
wire([(1880,950),(2010,950),(2010,1325),(1075,1325),(1075,960),(1110,960)],'TX_LAST')
wire([(1495,1325),(1495,1260),(1510,1260)],'TX_LAST')
wire([(480,565),(510,565),(510,780),(1070,780),(1070,860),(1110,860)],'START_LP')
wire([(980,900),(1030,900),(1030,920),(1110,920)],'LP_BIT_END',bits=2)
wire([(1400,950),(1430,950),(1430,1055),(570,1055),(570,860),(650,860)],'LP_LD_SH',bits=2)
wire([(1400,900),(1425,900),(1425,690),(2055,690)],'LP_P_N',bits=2)
wire([(980,1180),(1435,1180),(1435,1160),(1510,1160)],'HS_BYTE0',bits=8)
wire([(980,1240),(1450,1240),(1450,1230),(1510,1230)],'HS_BYTE1',bits=8)
wire([(480,610),(520,610),(520,1380),(1470,1380),(1470,1090),(1510,1090)],'START_HS')
wire([(1880,1140),(2055,1140)],'HS_BYTES',bits=16)
wire([(1880,1210),(2055,1210)],'HS_CLK_REQ',bits=2)
wire([(1400,845),(1415,845),(1415,660),(2000,660),(2000,1400),(40,1400),(40,460),(90,460)],'LP_DONE')
wire([(1880,1260),(2030,1260),(2030,1415),(25,1415),(25,500),(90,500)],'HS_DONE')
dot(1055,445,'VID_PAYLOAD');dot(610,1035,'TX_BYTE');dot(620,130,'VID_HDR');dot(1495,1325,'TX_LAST')
rect(30,1430,2040,140,'#f7fafc','#a1b1bd')
txt(50,1468,'SOURCE_MUX: inicialización pasa desde ROM con ECC/CRC incluidos; video pasa por HEADER/ECC/CRC/PACKET_MUX.',21)
txt(50,1507,'LP: LSR desplaza LSB primero. HS: LANE_SPLIT alterna bytes; CTRL_HS agrega SoT y gobierna el cierre del enlace.',21)
txt(50,1546,'En INIT, LAST=1 marca WAIT y pide cerrar LP sin enviar ARG. En video, LAST delimita el paquete generado.',20)
save('MIPI_TX_bloques.svg')

begin('PHY — diagrama de conexiones LP/HS, serializadores y reloj',2100,1980)
block(100,170,360,240,'CLOCK_GEN',ins=[('CLK_REF',225),('RESET',290)],outs=[('CLK_BYTE',225),('CLK_HS',290),('LOCK',345)],fill='#e6eedc')
block(100,550,360,350,'PHY_CTRL',ins=[('LP_REQ / HS_REQ',605),('CLK_REQ',670),('LOCK',735)],outs=[('LP_EN',605),('HS_EN',670),('CLK_EN',735)],fill='#dcecf3')
block(650,170,400,210,'SERIALIZER_D0',ins=[('BYTE0[7:0]',225),('CLK_HS',280),('CLK_BYTE',320)],outs=[('HS_D0',260)],fill='#e6eedc')
block(650,470,400,210,'SERIALIZER_D1',ins=[('BYTE1[7:0]',525),('CLK_HS',580),('CLK_BYTE',620)],outs=[('HS_D1',560)],fill='#e6eedc')
block(650,790,400,180,'CLOCK_DDR',ins=[('CLK_HS',840),('ENABLE',900)],outs=[('HS_CLK',875)],fill='#e6eedc')
block(1300,170,380,320,'LP_DRIVERS',ins=[('LP_P[2:0]',225),('LP_N[2:0]',300),('ENABLE',385)],outs=[('LP P/N',330)],fill='#f5f3de')
block(1300,620,380,400,'HS_DRIVERS',ins=[('HS_D0',680),('HS_D1',760),('HS_CLK',840),('ENABLE',920)],outs=[('HS P/N',800)],fill='#f5f3de')
block(1790,330,260,640,'D-PHY PADS',ins=[('LP',400),('HS',800)],outs=[('D0P / D0N',480),('D1P / D1N',610),('CLKP / CLKN',740)],fill='#f3e5df')
wire([(460,290),(535,290),(535,280),(650,280)],'CLK_HS')
wire([(535,280),(535,580),(650,580)],'CLK_HS')
wire([(535,580),(535,840),(650,840)],'CLK_HS')
wire([(460,225),(550,225),(550,320),(650,320)],'CLK_BYTE')
wire([(550,320),(550,620),(650,620)],'CLK_BYTE')
wire([(550,225),(550,130),(30,130)],'CLK_BYTE')
wire([(460,345),(505,345),(505,460),(45,460),(45,735),(100,735)],'PLL_LOCK')
wire([(1050,260),(1150,260),(1150,680),(1300,680)],'HS_D0')
wire([(1050,560),(1185,560),(1185,760),(1300,760)],'HS_D1')
wire([(1050,875),(1215,875),(1215,840),(1300,840)],'HS_CLK')
wire([(460,605),(575,605),(575,420),(1250,420),(1250,385),(1300,385)],'LP_EN')
wire([(460,670),(560,670),(560,1120),(1260,1120),(1260,920),(1300,920)],'HS_EN')
wire([(460,735),(590,735),(590,900),(650,900)],'CLK_EN')
txt(112,850,'READY',18)
wire([(100,845),(30,845)],'PHY_READY')
wire([(1680,330),(1735,330),(1735,400),(1790,400)],'LP_PAIRS',bits=6)
wire([(1680,800),(1790,800)],'HS_PAIRS',bits=6)
dot(535,280,'CLK_HS');dot(535,580,'CLK_HS')
dot(550,225,'CLK_BYTE');dot(550,320,'CLK_BYTE')
rect(30,1190,2040,220,'#f7fafc','#a1b1bd')
txt(50,1230,'Entradas desde MIPI_TX: bytes HS de ambas lanes, valores LP P/N independientes y peticiones de modo.',22)
txt(50,1272,'Retorno: CLK_BYTE, LOCK y READY. Los pares físicos de salida son los puertos P/N situados a la derecha.',22)
txt(50,1314,'PHY_CTRL evita habilitar LP y HS simultáneamente. LP admite 11/10/01/00; HS usa excitación diferencial.',22)
txt(50,1356,'SERIALIZER y CLOCK_DDR se realizan con primitivas apropiadas. Drivers/pads requieren definir FPGA, placa y adaptación eléctrica.',20)
phy_lp_example(30,1450)
save('MIPI_PHY_bloques.svg')
print('Actualizados los tres diagramas de conexiones en',OUT)
