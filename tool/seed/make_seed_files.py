# -*- coding: utf-8 -*-
"""Makes the small REAL files the library and chapters seeds upload (run once; the outputs are committed).

    python tool/seed/make_seed_files.py

Writes to tool/seed/assets/library/ and tool/seed/assets/chapters/: multi-page PDFs (reportlab) from the text in
seed_content_pdf.py, Word (python-docx), Excel (openpyxl), CSV, text, a ZIP pack, a hand-written PowerPoint
(python-pptx is not installed, so the .pptx is built with zipfile) and a few PNG images (Pillow). Every file is
a few tens of kilobytes. The output is deterministic apart from the zip and office timestamps.
"""
import csv
import io
import os
import sys
import zipfile
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import seed_content_pdf as content  # noqa: E402

OUT_LIB = os.path.join(HERE, 'assets', 'library')
OUT_CH = os.path.join(HERE, 'assets', 'chapters')
os.makedirs(OUT_LIB, exist_ok=True)
os.makedirs(OUT_CH, exist_ok=True)

NAVY = '#144174'
BLUE = '#1D63A3'
SLATE = '#475569'


# ---------------------------------------------------------------------------
# PDF
# ---------------------------------------------------------------------------

def make_pdf(path, doc):
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import ListFlowable, ListItem, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

    ss = getSampleStyleSheet()
    title = ParagraphStyle('t', parent=ss['Title'], fontName='Helvetica-Bold', fontSize=20, leading=25,
                           textColor=colors.HexColor(NAVY), alignment=0, spaceAfter=4)
    sub = ParagraphStyle('s', parent=ss['Normal'], fontName='Helvetica', fontSize=10.5, leading=14,
                         textColor=colors.HexColor(SLATE), spaceAfter=14)
    h = ParagraphStyle('h', parent=ss['Heading2'], fontName='Helvetica-Bold', fontSize=13, leading=17,
                       textColor=colors.HexColor(BLUE), spaceBefore=12, spaceAfter=5)
    body = ParagraphStyle('b', parent=ss['BodyText'], fontName='Helvetica', fontSize=10, leading=14.5, spaceAfter=6)
    cell = ParagraphStyle('c', parent=body, fontSize=8.8, leading=11.5, spaceAfter=0)
    cellh = ParagraphStyle('ch', parent=cell, fontName='Helvetica-Bold', textColor=colors.white)

    def footer(canvas, d):
        canvas.saveState()
        canvas.setFont('Helvetica', 8)
        canvas.setFillColor(colors.HexColor('#64748B'))
        canvas.drawString(20 * mm, 12 * mm, 'ICR Digital Library  |  %s' % doc.get('kind', ''))
        canvas.drawRightString(A4[0] - 20 * mm, 12 * mm, 'Page %d' % d.page)
        canvas.setStrokeColor(colors.HexColor('#E2E8F0'))
        canvas.line(20 * mm, 16 * mm, A4[0] - 20 * mm, 16 * mm)
        canvas.restoreState()

    story = [Paragraph(escape(doc['title']), title), Paragraph(escape(doc['subtitle']), sub)]
    for block in doc['blocks']:
        kind = block[0]
        if kind == 'h':
            story.append(Paragraph(escape(block[1]), h))
        elif kind == 'p':
            for p in block[1]:
                story.append(Paragraph(escape(p), body))
        elif kind in ('b', 'n'):
            items = [ListItem(Paragraph(escape(t), body), leftIndent=14) for t in block[1]]
            story.append(ListFlowable(items, bulletType='bullet' if kind == 'b' else '1', bulletFontSize=8,
                                      leftIndent=14, bulletColor=colors.HexColor(BLUE)))
            story.append(Spacer(1, 4))
        elif kind == 't':
            head, rows, widths = block[1], block[2], block[3]
            data = [[Paragraph(escape(c), cellh) for c in head]] + [[Paragraph(escape(str(c)), cell) for c in r] for r in rows]
            t = Table(data, colWidths=widths, repeatRows=1)
            t.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor(NAVY)),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F1F5F9')]),
                ('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#CBD5E1')),
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 5), ('RIGHTPADDING', (0, 0), (-1, -1), 5),
                ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ]))
            story.append(t)
            story.append(Spacer(1, 6))
    SimpleDocTemplate(path, pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm, topMargin=18 * mm,
                      bottomMargin=22 * mm, title=doc['title'], author='ICR Digital Library').build(
        story, onFirstPage=footer, onLaterPages=footer)


# ---------------------------------------------------------------------------
# Word
# ---------------------------------------------------------------------------

def make_docx(path, title, intro, sections, table=None):
    from docx import Document
    from docx.shared import Pt, RGBColor

    d = Document()
    d.core_properties.author = 'ICR Digital Library'
    d.core_properties.title = title
    st = d.styles['Normal']
    st.font.name = 'Calibri'
    st.font.size = Pt(10.5)
    h = d.add_heading(title, level=0)
    for r in h.runs:
        r.font.color.rgb = RGBColor(0x14, 0x41, 0x74)
    d.add_paragraph(intro)
    for heading, items in sections:
        d.add_heading(heading, level=2)
        for it in items:
            d.add_paragraph(it, style='List Bullet')
    if table:
        head, rows = table
        t = d.add_table(rows=1, cols=len(head))
        t.style = 'Light Grid Accent 1'
        for i, c in enumerate(head):
            t.rows[0].cells[i].text = c
        for r in rows:
            cells = t.add_row().cells
            for i, c in enumerate(r):
                cells[i].text = c
    d.save(path)


# ---------------------------------------------------------------------------
# Excel
# ---------------------------------------------------------------------------

def _style_header(ws, row, cols):
    from openpyxl.styles import Alignment, Font, PatternFill

    for c in range(1, cols + 1):
        cell = ws.cell(row=row, column=c)
        cell.font = Font(bold=True, color='FFFFFF')
        cell.fill = PatternFill('solid', fgColor='144174')
        cell.alignment = Alignment(horizontal='center', vertical='center', wrap_text=True)


def make_scorecard(path):
    from openpyxl import Workbook
    from openpyxl.formatting.rule import CellIsRule
    from openpyxl.styles import PatternFill

    wb = Workbook()
    ws = wb.active
    ws.title = 'Scorecard'
    ws.append(['Vendor SLA scorecard - monthly'])
    ws.append(['Weights: response 30%, resolution 30%, quality 25%, cost 15%. Score = weighted average (0-100).'])
    ws.append([])
    head = ['Vendor', 'Service', 'Response SLA met %', 'Resolution SLA met %', 'Quality audit %', 'Cost vs budget %', 'Score', 'Rating']
    ws.append(head)
    _style_header(ws, 4, len(head))
    data = [
        ('Brightline Housekeeping', 'Housekeeping', 97, 94, 91, 98),
        ('Sentinel Security', 'Security', 99, 96, 93, 100),
        ('CoolServe HVAC', 'HVAC O&M', 92, 88, 85, 104),
        ('VoltAssure Electrical', 'Electrical O&M', 95, 91, 90, 99),
        ('GreenScape', 'Landscape', 98, 97, 88, 96),
        ('LiftCare', 'Lifts', 90, 86, 92, 101),
        ('PestShield', 'Pest control', 100, 99, 95, 97),
        ('CafeOps', 'Cafeteria', 93, 90, 87, 103),
    ]
    for i, (v, s, a, b, c, d) in enumerate(data, start=5):
        cost_score = max(0, min(100, 200 - d))
        ws.append([v, s, a, b, c, d, '=ROUND(C%d*0.3+D%d*0.3+E%d*0.25+%d*0.15,1)' % (i, i, i, cost_score),
                   '=IF(G%d>=95,"Excellent",IF(G%d>=90,"Good",IF(G%d>=85,"Watch","Action")))' % (i, i, i)])
    last = 4 + len(data)
    ws.conditional_formatting.add('G5:G%d' % last, CellIsRule(operator='lessThan', formula=['90'],
                                                              fill=PatternFill('solid', bgColor='FDE68A')))
    for col, w in zip('ABCDEFGH', (26, 16, 18, 20, 16, 18, 10, 12)):
        ws.column_dimensions[col].width = w
    ws['A1'].font = ws['A1'].font.copy(bold=True, size=14)
    wb.save(path)


def make_lease_audit(path, example):
    from openpyxl import Workbook

    wb = Workbook()
    ws = wb.active
    ws.title = 'Lease audit'
    ws.append(['Lease audit workbook' + (' - worked example (Tower B, floors 6-9)' if example else ' - template')])
    ws.append([])
    head = ['Clause', 'Topic', 'Lease says', 'Invoice / practice shows', 'Variance (Rs)', 'Action']
    ws.append(head)
    _style_header(ws, 3, len(head))
    rows = [
        ('4.2', 'Base rent', 'Rs 92 per sq ft per month on 38,400 sq ft', 'Billed on 39,100 sq ft', 64400 if example else None, 'Re-measure and credit'),
        ('4.5', 'Escalation', '5% after year 3', 'Billed at 7.5% from month 25', 33800 if example else None, 'Dispute with lease clause'),
        ('6.1', 'CAM charges', 'Pro rata, capped at 8% a year', 'No cap applied in year 2', 121500 if example else None, 'Request cap application'),
        ('7.3', 'Parking', '60 car bays included', '48 bays allotted', 36000 if example else None, 'Claim 12 bays or rebate'),
        ('9.4', 'Security deposit', '6 months, interest bearing', 'No interest statement', 0 if example else None, 'Request statement'),
        ('12.1', 'Repairs and restoration', 'Reasonable wear excepted', 'Not yet assessed', None, 'Schedule joint inspection'),
    ]
    for r in rows:
        ws.append(list(r))
    ws.append([])
    ws.append(['', '', '', 'Total variance', '=SUM(E4:E9)' if example else None, ''])
    for col, w in zip('ABCDEF', (8, 22, 40, 36, 16, 30)):
        ws.column_dimensions[col].width = w
    wb.save(path)


def make_ppm_schedule(path):
    from openpyxl import Workbook

    wb = Workbook()
    ws = wb.active
    ws.title = 'PPM schedule'
    head = ['Asset class', 'Task', 'Frequency', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    ws.append(head)
    _style_header(ws, 1, len(head))
    tasks = [
        ('Chiller', 'Tube cleaning, refrigerant and oil check', 'Quarterly', (3, 6, 9, 12)),
        ('AHU', 'Filter change, belt and bearing check', 'Monthly', tuple(range(1, 13))),
        ('DG set', 'Load test and fuel polishing', 'Monthly', tuple(range(1, 13))),
        ('UPS', 'Battery discharge test', 'Half-yearly', (4, 10)),
        ('Fire pump', 'Churn run and flow test', 'Weekly (shown monthly)', tuple(range(1, 13))),
        ('Lift', 'Statutory inspection and safety test', 'Annual', (5,)),
        ('STP', 'Blower and diffuser service', 'Quarterly', (2, 5, 8, 11)),
        ('Cooling tower', 'Fill and drift eliminator clean', 'Half-yearly', (3, 9)),
    ]
    for cls, task, freq, months in tasks:
        ws.append([cls, task, freq] + ['X' if m in months else '' for m in range(1, 13)])
    for col, w in zip('ABC', (16, 42, 22)):
        ws.column_dimensions[col].width = w
    wb.save(path)


def write_csv(path, head, rows):
    with io.open(path, 'w', encoding='utf-8', newline='') as f:
        w = csv.writer(f)
        w.writerow(head)
        w.writerows(rows)


# ---------------------------------------------------------------------------
# PowerPoint (hand-written: python-pptx is not installed)
# ---------------------------------------------------------------------------

_NS = ('xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
       'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
       'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"')

_THEME = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="ICR"><a:themeElements>
<a:clrScheme name="ICR"><a:dk1><a:srgbClr val="111C2D"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="144174"/></a:dk2><a:lt2><a:srgbClr val="F1F5F9"/></a:lt2>
<a:accent1><a:srgbClr val="1D63A3"/></a:accent1><a:accent2><a:srgbClr val="10B981"/></a:accent2><a:accent3><a:srgbClr val="F59E0B"/></a:accent3><a:accent4><a:srgbClr val="6B4EA8"/></a:accent4><a:accent5><a:srgbClr val="C0392B"/></a:accent5><a:accent6><a:srgbClr val="64748B"/></a:accent6>
<a:hlink><a:srgbClr val="1D63A3"/></a:hlink><a:folHlink><a:srgbClr val="6B4EA8"/></a:folHlink></a:clrScheme>
<a:fontScheme name="ICR"><a:majorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>
<a:fmtScheme name="ICR"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
<a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="28575"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>
</a:themeElements></a:theme>'''


def _para(text, size, bold=False, color='111C2D'):
    return ('<a:p><a:r><a:rPr lang="en-IN" sz="%d" b="%d"><a:solidFill><a:srgbClr val="%s"/></a:solidFill></a:rPr>'
            '<a:t>%s</a:t></a:r></a:p>') % (size, 1 if bold else 0, color, escape(text))


def _shape(sid, name, x, y, w, h, paras, fill=None):
    fill_xml = '<a:solidFill><a:srgbClr val="%s"/></a:solidFill>' % fill if fill else '<a:noFill/>'
    return ('<p:sp><p:nvSpPr><p:cNvPr id="%d" name="%s"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
            '<p:spPr><a:xfrm><a:off x="%d" y="%d"/><a:ext cx="%d" cy="%d"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>%s</p:spPr>'
            '<p:txBody><a:bodyPr wrap="square" lIns="182880" tIns="91440" rIns="182880" bIns="91440"/><a:lstStyle/>%s</p:txBody></p:sp>') % (
        sid, name, x, y, w, h, fill_xml, ''.join(paras))


def make_pptx(path, deck_title, subtitle, slides):
    """slides: list of (heading, [bullets]). A title slide is added first."""
    W, H = 9144000, 5143500  # 16:9
    all_slides = [('__title__', [deck_title, subtitle])] + slides
    parts = {}
    ct = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
          '<Default Extension="xml" ContentType="application/xml"/>',
          '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
          '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
          '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>',
          '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>']
    for i in range(1, len(all_slides) + 1):
        ct.append('<Override PartName="/ppt/slides/slide%d.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>' % i)
    ct.append('</Types>')
    parts['[Content_Types].xml'] = ''.join(ct)
    parts['_rels/.rels'] = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>')
    sld_ids = ''.join('<p:sldId id="%d" r:id="rId%d"/>' % (255 + i, i + 1) for i in range(1, len(all_slides) + 1))
    parts['ppt/presentation.xml'] = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:presentation %s>'
                                     '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
                                     '<p:sldIdLst>%s</p:sldIdLst><p:sldSz cx="%d" cy="%d"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>') % (_NS, sld_ids, W, H)
    rels = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>']
    for i in range(1, len(all_slides) + 1):
        rels.append('<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide%d.xml"/>' % (i + 1, i))
    rels.append('<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/></Relationships>' % (len(all_slides) + 2))
    parts['ppt/_rels/presentation.xml.rels'] = ''.join(rels)
    parts['ppt/theme/theme1.xml'] = _THEME
    parts['ppt/slideMasters/slideMaster1.xml'] = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster %s><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>'
        '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>'
        '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
        '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>') % _NS
    parts['ppt/slideMasters/_rels/slideMaster1.xml.rels'] = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>')
    parts['ppt/slideLayouts/slideLayout1.xml'] = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout %s type="blank" preserve="1"><p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>') % _NS
    parts['ppt/slideLayouts/_rels/slideLayout1.xml.rels'] = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>')
    for i, (heading, items) in enumerate(all_slides, start=1):
        if heading == '__title__':
            shapes = (_shape(2, 'Band', 0, 0, W, H, [_para(' ', 1000)], fill='144174')
                      + _shape(3, 'Title', 640000, 1500000, W - 1280000, 1100000, [_para(items[0], 4000, True, 'FFFFFF')])
                      + _shape(4, 'Subtitle', 640000, 2700000, W - 1280000, 800000, [_para(items[1], 1800, False, 'C3D0DF')]))
        else:
            paras = [_para(b, 1800) for b in items]
            shapes = (_shape(2, 'Bar', 0, 0, W, 120000, [_para(' ', 600)], fill='1D63A3')
                      + _shape(3, 'Heading', 500000, 380000, W - 1000000, 800000, [_para(heading, 3000, True, '144174')])
                      + _shape(4, 'Body', 500000, 1300000, W - 1000000, H - 1900000, paras)
                      + _shape(5, 'Footer', 500000, H - 450000, W - 1000000, 300000, [_para('ICR Digital Library', 1000, False, '64748B')]))
        parts['ppt/slides/slide%d.xml' % i] = (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sld %s><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
            '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>%s</p:spTree></p:cSld>'
            '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>') % (_NS, shapes)
        parts['ppt/slides/_rels/slide%d.xml.rels' % i] = (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>')
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        # [Content_Types].xml first, as Office writes it.
        z.writestr('[Content_Types].xml', parts.pop('[Content_Types].xml'))
        for name, xml in parts.items():
            z.writestr(name, xml)


# ---------------------------------------------------------------------------
# Images
# ---------------------------------------------------------------------------

def _font(size, bold=False):
    from PIL import ImageFont

    for name in (('arialbd.ttf' if bold else 'arial.ttf'), 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'):
        for base in (r'C:\Windows\Fonts', '/usr/share/fonts/truetype/dejavu'):
            p = os.path.join(base, name)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def make_infographic(path, title, subtitle, items, colors):
    from PIL import Image, ImageDraw

    W, H = 900, 560
    im = Image.new('RGB', (W, H), '#F8FAFC')
    d = ImageDraw.Draw(im)
    for y in range(120):
        t = y / 120
        r = int(0x14 + (0x1D - 0x14) * t)
        g = int(0x41 + (0x63 - 0x41) * t)
        b = int(0x74 + (0xA3 - 0x74) * t)
        d.line([(0, y), (W, y)], fill=(r, g, b))
    d.text((32, 24), title, font=_font(30, True), fill='white')
    d.text((32, 70), subtitle, font=_font(16), fill='#C3D0DF')
    y = 150
    for i, (label, value) in enumerate(items):
        col = colors[i % len(colors)]
        d.rounded_rectangle([32, y, W - 32, y + 58], radius=10, fill='white', outline='#E2E8F0')
        d.rounded_rectangle([32, y, 46, y + 58], radius=4, fill=col)
        d.text((64, y + 16), label, font=_font(20), fill='#0F172A')
        d.text((W - 60 - 8 * len(value), y + 14), value, font=_font(24, True), fill=col)
        y += 70
    im.save(path, optimize=True)


# ---------------------------------------------------------------------------
# What gets made
# ---------------------------------------------------------------------------

def out(folder, name):
    return os.path.join(folder, name)


def main():
    # PDFs: the library's documents and the chapters' whitepapers.
    for slug, doc in content.PDFS.items():
        make_pdf(out(OUT_LIB, slug + '.pdf'), doc)
    for slug in content.CITY:
        make_pdf(out(OUT_CH, 'workplace-benchmark-%s.pdf' % slug), content.whitepaper(slug))

    # Word.
    make_docx(
        out(OUT_LIB, 'service-contract-review-checklist.docx'),
        'Service Contract Review Checklist',
        'Use this checklist before signing or renewing a facility services contract. Tick each item, note the owner and the date.',
        [('Scope and service levels', ['Scope lists every area, asset class and shift covered, with exclusions stated',
                                       'Response and resolution times by priority, with how they are measured',
                                       'Service credits apply automatically, not on request']),
         ('Commercials', ['Price basis (fixed, unit rate, cost-plus) and what triggers a change',
                          'Escalation clause tied to a published index, with a cap',
                          'Payment terms, retention and set-off rights']),
         ('People and compliance', ['Minimum wage, PF/ESI and statutory compliance evidence monthly',
                                    'Background verification and training records for site staff',
                                    'Insurance certificates and incident reporting duties']),
         ('Exit', ['Notice periods, step-in rights and a handover obligation',
                   'Return of keys, access cards, data and asset registers'])],
        table=(['Item', 'Owner', 'Done', 'Date'], [['Scope schedule agreed', '', '[ ]', ''], ['SLA schedule agreed', '', '[ ]', ''],
                                                    ['Legal review', '', '[ ]', '']]))
    make_docx(
        out(OUT_LIB, 'incident-report-template.docx'),
        'Incident Report Template',
        'Complete within 24 hours of any safety, security or service-affecting incident. Attach photographs and witness statements.',
        [('What happened', ['Date, time and exact location', 'People involved and witnesses', 'Sequence of events in plain words']),
         ('Immediate actions', ['Who was informed and when', 'Injuries and first aid given', 'Area secured or isolated']),
         ('Cause and follow-up', ['Root cause (use the five whys)', 'Corrective actions with owners and dates', 'Lessons shared with the wider team'])])

    # Excel and CSV.
    make_scorecard(out(OUT_LIB, 'vendor-sla-scorecard.xlsx'))
    make_lease_audit(out(OUT_LIB, 'lease-audit-template.xlsx'), example=False)
    make_lease_audit(out(OUT_LIB, 'lease-audit-worked-example.xlsx'), example=True)
    make_ppm_schedule(out(OUT_LIB, 'ppm-schedule.xlsx'))
    write_csv(out(OUT_LIB, 'ppm-calendar.csv'), ['asset_class', 'task', 'frequency', 'owner', 'next_due'],
              [['Chiller', 'Tube cleaning', 'Quarterly', 'MEP lead', '2026-12-01'], ['AHU', 'Filter change', 'Monthly', 'HVAC technician', '2026-11-05'],
               ['DG set', 'Load test', 'Monthly', 'Electrical lead', '2026-11-03'], ['Fire pump', 'Churn run', 'Weekly', 'Fire engineer', '2026-10-31'],
               ['Lift', 'Statutory inspection', 'Annual', 'Lift contractor', '2027-05-10'], ['STP', 'Blower service', 'Quarterly', 'Utilities lead', '2027-02-02']])
    write_csv(out(OUT_LIB, 'asset-register-template.csv'), ['asset_tag', 'description', 'location', 'make', 'model', 'installed', 'warranty_end', 'criticality'],
              [['CHL-001', 'Water-cooled chiller 450 TR', 'Plant room B1', '', '', '', '', 'A'], ['AHU-014', 'Air handling unit', 'Level 6 east', '', '', '', '', 'B']])

    # Text.
    with io.open(out(OUT_LIB, 'visitor-management-policy.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('VISITOR MANAGEMENT POLICY\n=========================\n\n'
                '1. Purpose\nEvery visitor is registered, badged and escorted so the building knows who is inside at all times.\n\n'
                '2. Before arrival\n- The host pre-registers the visitor (name, company, vehicle, purpose, time).\n'
                '- Contractors need a permit to work before they are admitted.\n\n'
                '3. At the desk\n- Photo ID is checked and logged; the badge shows the host, the floor and the expiry time.\n'
                '- Devices that record are declared; restricted floors need a second approval.\n\n'
                '4. Inside\n- Visitors are escorted or badge-restricted to the floors they were approved for.\n'
                '- Badges are returned at exit and the log is closed.\n\n'
                '5. Review\nThe security lead reviews tailgating and unreturned-badge incidents monthly.\n')

    # PowerPoint.
    make_pptx(out(OUT_LIB, 'gcc-workplace-briefing.pptx'), 'GCC Workplace Leadership: Quarterly Briefing',
              'ICR Council on Workplace Strategy',
              [('Where occupancy has settled', ['Mid-week peak at 60 to 65% of seats', 'Mondays and Fridays under 35%', 'Team days beat individual days']),
               ('What operators are changing', ['Seat ratios of 0.6 to 0.7 per employee', 'Bookable neighbourhoods instead of fixed desks', 'Service levels tied to peak days']),
               ('What to do next quarter', ['Meter floor-level occupancy', 'Renegotiate cleaning and cafeteria to a peak-day model', 'Publish a seat-ratio target by site'])])
    for slug, c in content.CITY.items():
        make_pptx(out(OUT_CH, 'chapter-meetup-deck-%s.pptx' % slug), 'ICR %s Chapter: Meetup Deck' % c['name'],
                  'Highlights from the last chapter meetup',
                  [('Market snapshot', ['%s: %s' % (a, b) for a, b in c['stats'][:4]]),
                   ('Themes we heard', c['themes'][:4]),
                   ('Next steps', ['Share your site data with the committee', 'Volunteer for the next session', 'Join the working group on service levels'])])
    make_scorecard(out(OUT_CH, 'vendor-sla-scorecard-template.xlsx'))

    # Archive: a contractor induction pack.
    with zipfile.ZipFile(out(OUT_LIB, 'contractor-induction-pack.zip'), 'w', zipfile.ZIP_DEFLATED) as z:
        z.write(out(OUT_LIB, 'visitor-management-policy.txt'), 'visitor-management-policy.txt')
        z.write(out(OUT_LIB, 'ppm-calendar.csv'), 'sign-in-sheet.csv')
        z.writestr('README.txt', 'Contractor induction pack: policy, sign-in sheet and the induction deck are in this archive.\n')
        z.write(out(OUT_CH, 'workplace-benchmark-bengaluru.pdf'), 'induction-reference.pdf')

    # Images.
    make_infographic(out(OUT_LIB, 'plant-room-walkdown.png'), 'Chiller plant room walk-down', 'Photo checklist, level B1',
                     [('Chilled water supply / return', '7.0 / 12.1 C'), ('Condenser approach', '3.2 C'), ('Pump vibration', '2.1 mm/s'),
                      ('Refrigerant level', 'Normal'), ('Leaks or corrosion', 'None noted')], ['#1D63A3', '#10B981', '#F59E0B', '#6B4EA8', '#C0392B'])
    make_infographic(out(OUT_LIB, 'energy-dashboard.png'), 'Energy intensity dashboard', 'kWh per sq ft per year, 12-month view',
                     [('Baseline year', '19.8'), ('Year 1', '17.4'), ('Year 2', '16.2'), ('Target', '15.5')], ['#64748B', '#1D63A3', '#10B981', '#F59E0B'])

    for folder in (OUT_LIB, OUT_CH):
        print('%s: %d files, %d KB' % (os.path.relpath(folder, HERE), len(os.listdir(folder)),
                                       sum(os.path.getsize(os.path.join(folder, n)) for n in os.listdir(folder)) // 1024))


if __name__ == '__main__':
    main()
