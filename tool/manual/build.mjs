#!/usr/bin/env node
// The mobile app's user manual: one Word book, from what the flows carried out.
//
//   node tool/manual/build.mjs [--as-of "12 November 2026"] [--out <dir>] [--draft]
//
// Reads  build/manual/<chapter>/manual.json   a chapter's title and its flows, in order
//        build/manual/<chapter>/<flow>.json   each flow's steps (text, picture)
//        docs/manual/src/book.json            the book: title, parts and their chapters, appendices
//        docs/manual/src/<chapter>.json       the words round a chapter's steps
// Writes docs/manual/ICR-Mobile-App-User-Manual.docx
//
// Fails when a step's picture is missing or a picture belongs to no step: the manual never
// prints a step nobody photographed, or the other way round. `--draft` builds whatever
// chapters have been captured so far and says so on the cover.
//
// The look is the website manuals' (ICR e2e/scripts/build-manuals.mjs); the layout differs
// because a phone picture is tall: each step sits beside its picture.
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  AlignmentType,
  BorderStyle,
  Document,
  Footer,
  Header,
  HeadingLevel,
  ImageRun,
  LevelFormat,
  Packer,
  PageNumber,
  Paragraph,
  ShadingType,
  Table,
  TableCell,
  TableRow,
  TextRun,
  VerticalAlign,
  WidthType,
} from 'docx';
import imageSize from 'image-size';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(HERE, '..', '..');
const argv = process.argv.slice(2);
const arg = (name) => {
  const i = argv.indexOf(name);
  return i > -1 ? argv[i + 1] : null;
};
const CAPTURED = process.env.MANUAL_OUT ? path.resolve(process.env.MANUAL_OUT) : path.join(ROOT, 'build', 'manual');
const SRC = path.join(ROOT, 'docs', 'manual', 'src');
const OUT = arg('--out') ? path.resolve(arg('--out')) : path.join(ROOT, 'docs', 'manual');
const asOf = arg('--as-of') ?? process.env.MANUAL_AS_OF ?? null;
const draft = argv.includes('--draft');

const INK = '1F2933';
const MUTED = '5F6B7A';
const BRAND = '0B5FA5';
const RULE = 'D5DBE3';
const TINT = 'F2F6FA';
const FONT = 'Calibri';

/** Page: A4, 2 cm margins → 17 cm of text. */
const cm = (n) => Math.round(n * 567); // twentieths of a point
const TEXT_CM = 17;
const PICTURE_CM = 5.7; // a phone screen at about two thirds of its real width
const PICTURE_COL_CM = 6.3;
const PX_PER_CM = 96 / 2.54; // docx sizes pictures in CSS pixels

// ── Small builders ─────────────────────────────────────────────────────────────

/** `**bold**` in a sentence becomes bold runs; everything else is plain. */
function runs(text, base = {}) {
  return String(text)
    .split(/(\*\*[^*]+\*\*)/g)
    .filter(Boolean)
    .map((part) =>
      part.startsWith('**')
        ? new TextRun({ ...base, text: part.slice(2, -2), bold: true })
        : new TextRun({ ...base, text: part }),
    );
}

const para = (text, opts = {}) =>
  new Paragraph({ spacing: { after: 120, line: 300 }, ...opts, children: runs(text, opts.run) });
const bullet = (text) =>
  new Paragraph({ numbering: { reference: 'bullets', level: 0 }, spacing: { after: 60, line: 290 }, children: runs(text) });
const h1 = (text) => new Paragraph({ heading: HeadingLevel.HEADING_1, pageBreakBefore: true, children: [new TextRun(text)] });
const h2 = (text, breakBefore = false) =>
  new Paragraph({ heading: HeadingLevel.HEADING_2, pageBreakBefore: breakBefore, children: [new TextRun(text)] });
const h3 = (text) => new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun(text)] });

const line = { style: BorderStyle.SINGLE, size: 4, color: RULE };
const none = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
const boxed = { top: line, bottom: line, left: line, right: line };
const unboxed = { top: none, bottom: none, left: none, right: none };

function table(head, rows, widths, points = null) {
  const size = points ? { size: points * 2 } : {};
  const total = widths.reduce((a, b) => a + b, 0);
  const cell = (text, w, header) =>
    new TableCell({
      borders: boxed,
      width: { size: w, type: WidthType.DXA },
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      shading: header ? { fill: TINT, type: ShadingType.CLEAR, color: 'auto' } : undefined,
      children: String(text)
        .split('\n')
        .map((t) => new Paragraph({ spacing: { after: 0, line: points ? 240 : 280 }, children: runs(t, header ? { bold: true, ...size } : size) })),
    });
  return new Table({
    width: { size: total, type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ tableHeader: true, cantSplit: true, children: head.map((t, i) => cell(t, widths[i], true)) }),
      ...rows.map((r) => new TableRow({ cantSplit: true, children: r.map((t, i) => cell(t, widths[i], false)) })),
    ],
  });
}

function phonePicture(file, alt) {
  const data = fs.readFileSync(file);
  const { width, height } = imageSize(data);
  const w = PICTURE_CM * PX_PER_CM;
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 0, after: 0 },
    children: [
      new ImageRun({
        type: 'jpg',
        data,
        transformation: { width: Math.round(w), height: Math.round((height / width) * w) },
        outline: { type: 'solidFill', solidFillType: 'rgb', value: RULE, width: 9525 },
        altText: { title: alt, description: alt, name: path.basename(file) },
      }),
    ],
  });
}

/** A step: its number and sentence on the left, the phone as it looks on the right. */
function stepRow(step, picture, figure) {
  const textCol = cm(TEXT_CM - PICTURE_COL_CM);
  const left = [
    new Paragraph({
      spacing: { before: 60, after: 100, line: 300 },
      children: [new TextRun({ text: `Step ${step.n}`, bold: true, color: BRAND, size: 24 })],
    }),
    new Paragraph({ spacing: { after: 100, line: 310 }, children: runs(step.text) }),
  ];
  if (step.note) left.push(new Paragraph({ spacing: { after: 80, line: 290 }, children: runs(step.note, { color: MUTED }) }));
  const right = picture
    ? [
        picture,
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 40, after: 0 },
          children: [new TextRun({ text: `Figure ${figure}`, color: MUTED, size: 16 })],
        }),
      ]
    : [new Paragraph('')];
  return new TableRow({
    cantSplit: true,
    children: [
      new TableCell({
        borders: { ...unboxed, top: line },
        width: { size: textCol, type: WidthType.DXA },
        margins: { top: 160, bottom: 160, left: 0, right: 240 },
        verticalAlign: VerticalAlign.TOP,
        children: left,
      }),
      new TableCell({
        borders: { ...unboxed, top: line },
        width: { size: cm(PICTURE_COL_CM), type: WidthType.DXA },
        margins: { top: 160, bottom: 160, left: 100, right: 0 },
        verticalAlign: VerticalAlign.TOP,
        children: right,
      }),
    ],
  });
}

function makeDoc(title, body) {
  return new Document({
    creator: 'ICR',
    title: `ICR User Manual: ${title}`,
    description: `How to use the ${title}, step by step, for every kind of account.`,
    styles: {
      default: { document: { run: { font: FONT, size: 22, color: INK } } },
      paragraphStyles: [
        { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: 40, bold: true, color: INK }, paragraph: { spacing: { before: 0, after: 220 }, outlineLevel: 0 } },
        { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: 30, bold: true, color: INK }, paragraph: { spacing: { before: 320, after: 140 }, outlineLevel: 1 } },
        { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: 24, bold: true, color: BRAND }, paragraph: { spacing: { before: 260, after: 100 }, outlineLevel: 2 } },
      ],
    },
    numbering: {
      config: [
        {
          reference: 'bullets',
          levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 500, hanging: 260 } } } }],
        },
      ],
    },
    sections: [
      {
        properties: {
          page: { size: { width: 11906, height: 16838 }, margin: { top: cm(2.2), right: cm(2), bottom: cm(2), left: cm(2) } },
          titlePage: true,
        },
        headers: {
          default: new Header({
            children: [
              new Paragraph({
                border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: RULE, space: 4 } },
                children: [new TextRun({ text: `ICR User Manual · ${title}`, color: MUTED, size: 18 })],
              }),
            ],
          }),
          first: new Header({ children: [new Paragraph('')] }),
        },
        footers: {
          default: new Footer({
            children: [
              new Paragraph({
                alignment: AlignmentType.CENTER,
                children: [new TextRun({ children: ['Page ', PageNumber.CURRENT], color: MUTED, size: 18 })],
              }),
            ],
          }),
          first: new Footer({ children: [new Paragraph('')] }),
        },
        children: body,
      },
    ],
  });
}

function readJson(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) {
    if (fallback !== null && e.code === 'ENOENT') return fallback;
    throw new Error(`${file}: ${e.message}`);
  }
}

// ── The book ───────────────────────────────────────────────────────────────────

const book = readJson(path.join(SRC, 'book.json'));
const problems = [];
let figure = 0;
let stepCount = 0;
const body = [];

const captured = (id) => fs.existsSync(path.join(CAPTURED, id, 'manual.json'));
const parts = book.parts
  .map((p) => ({ ...p, chapters: p.chapters.filter((c) => captured(c) || (!draft && problems.push(`chapter ${c}: not captured`) && false)) }))
  .filter((p) => p.chapters.length);

// Cover
body.push(
  new Paragraph({ spacing: { before: 2600, after: 120 }, children: [new TextRun({ text: 'ICR USER MANUAL', color: BRAND, bold: true, size: 24, characterSpacing: 60 })] }),
  new Paragraph({ spacing: { after: 200 }, children: [new TextRun({ text: book.title, bold: true, size: 68, color: INK })] }),
  new Paragraph({ spacing: { after: 600 }, children: [new TextRun({ text: book.subtitle, size: 28, color: MUTED })] }),
  new Paragraph({
    border: { top: { style: BorderStyle.SINGLE, size: 12, color: BRAND, space: 12 } },
    spacing: { before: 400, after: 60 },
    children: [new TextRun({ text: 'Institute for Corporate Real Estate · icr.org.in', color: MUTED, size: 20 })],
  }),
  new Paragraph({ spacing: { after: 60 }, children: [new TextRun({ text: book.edition, color: MUTED, size: 20 })] }),
);
if (asOf) body.push(new Paragraph({ spacing: { after: 60 }, children: [new TextRun({ text: `Reflects the app as of ${asOf}.`, color: MUTED, size: 20 })] }));
if (draft) body.push(new Paragraph({ children: [new TextRun({ text: 'DRAFT: not every chapter is in this copy yet.', color: 'B42318', bold: true, size: 20 })] }));

// Contents
body.push(h1('In this manual'));
let chapterNo = 0;
const numbered = new Map();
for (const p of parts) {
  body.push(new Paragraph({ keepNext: true, spacing: { before: 200, after: 80 }, children: [new TextRun({ text: p.title, bold: true, color: BRAND })] }));
  for (const c of p.chapters) {
    chapterNo += 1;
    numbered.set(c, chapterNo);
    const manual = readJson(path.join(CAPTURED, c, 'manual.json'));
    body.push(new Paragraph({ spacing: { after: 50 }, indent: { left: 300 }, children: [new TextRun(`${chapterNo}. ${manual.title}`)] }));
  }
}
for (const a of book.appendices ?? []) body.push(new Paragraph({ spacing: { before: 120, after: 50 }, children: [new TextRun({ text: a.title, bold: true })] }));

// About
body.push(h1('About this manual'));
for (const p of book.about ?? []) body.push(para(p));
if (book.roles?.length) {
  body.push(h3('Find your chapters'));
  body.push(table(['If you are…', 'Read'], book.roles.map((r) => [r.who, r.read]), [cm(6), cm(11)]));
}
if (book.conventions?.length) {
  body.push(h3('How the steps are written'));
  for (const b of book.conventions) body.push(bullet(b));
}

for (const part of parts) {
  body.push(
    new Paragraph({ pageBreakBefore: true, spacing: { before: 3200, after: 160 }, children: [new TextRun({ text: part.kicker ?? '', color: BRAND, bold: true, size: 24, characterSpacing: 60 })] }),
    new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { after: 240 }, children: [new TextRun({ text: part.title, size: 56 })] }),
  );
  for (const p of part.intro ?? []) body.push(para(p, { run: { size: 24, color: MUTED } }));

  for (const c of part.chapters) {
    const dir = path.join(CAPTURED, c);
    const manual = readJson(path.join(dir, 'manual.json'));
    const words = readJson(path.join(SRC, `${c}.json`), {});
    const used = new Set();
    const flows = manual.flows.map((id) => {
      const file = path.join(dir, `${id}.json`);
      if (!fs.existsSync(file)) {
        problems.push(`${c} / ${id}: not captured`);
        return { id, title: id, steps: [] };
      }
      const f = readJson(file);
      if (f.failed) problems.push(`${c} / ${id}: the flow failed (${f.failed})`);
      return f;
    });

    body.push(h1(`${numbered.get(c)}. ${manual.title}`));
    if (words.who) body.push(new Paragraph({ spacing: { after: 120 }, children: [new TextRun({ text: `For: ${words.who}`, color: MUTED, italics: true })] }));
    for (const p of words.overview ?? []) body.push(para(p));
    if (words.menu?.length) {
      body.push(h3(words.menuTitle ?? 'What your menu shows'));
      body.push(table(['Menu row', 'Pages it opens'], words.menu.map((r) => [r.row, r.pages]), [cm(4.5), cm(12.5)]));
    }
    if (words.can?.length) {
      body.push(h3('What you can do in the app'));
      for (const b of words.can) body.push(bullet(b));
    }
    if (words.before?.length) {
      body.push(h3('Before you start'));
      for (const b of words.before) body.push(bullet(b));
    }

    flows.forEach((f, i) => {
      const extra = words.flows?.[f.id] ?? {};
      body.push(h2(`${numbered.get(c)}.${i + 1}  ${f.title}`, i > 0 || Boolean(words.overview?.length)));
      if (f.who) body.push(new Paragraph({ spacing: { after: 100 }, children: [new TextRun({ text: `Who: ${f.who}`, color: MUTED, italics: true })] }));
      if (f.intro) body.push(para(f.intro));
      for (const p of extra.intro ?? []) body.push(para(p));
      const rows = [];
      for (const s of f.steps) {
        stepCount += 1;
        let picture = null;
        if (s.file) {
          const img = path.join(dir, s.file);
          if (!fs.existsSync(img)) {
            problems.push(`${c} / ${f.id} step ${s.n} (${s.id}): picture missing`);
            continue;
          }
          used.add(path.normalize(s.file));
          figure += 1;
          picture = phonePicture(img, String(s.text).replace(/\*\*/g, ''));
        }
        rows.push(stepRow(s, picture, figure));
      }
      if (rows.length) {
        body.push(new Table({ width: { size: cm(TEXT_CM), type: WidthType.DXA }, columnWidths: [cm(TEXT_CM - PICTURE_COL_CM), cm(PICTURE_COL_CM)], rows }));
      }
      if (extra.after?.length) {
        body.push(h3('What happens next'));
        for (const b of extra.after) body.push(bullet(b));
      }
      if (extra.rules?.length) {
        body.push(h3('Good to know'));
        for (const b of extra.rules) body.push(bullet(b));
      }
      const flowDir = path.join(dir, f.id);
      if (fs.existsSync(flowDir)) {
        for (const name of fs.readdirSync(flowDir)) {
          if (/^[^.].*\.jpe?g$/.test(name) && !used.has(path.normalize(path.join(f.id, name)))) problems.push(`${c} / ${f.id}/${name}: belongs to no step`);
        }
      }
    });

    if (words.website?.length) {
      body.push(h2('Done on the website instead'));
      body.push(para(words.websiteIntro ?? 'The app does not have these yet. Sign in at **icr.org.in** in a browser for them.'));
      for (const b of words.website) body.push(bullet(b));
    }
    if (words.faq?.length) {
      body.push(h2('Common questions'));
      for (const q of words.faq) {
        body.push(new Paragraph({ keepNext: true, spacing: { before: 160, after: 60 }, children: [new TextRun({ text: q.q, bold: true })] }));
        body.push(para(q.a));
      }
    }
  }
}

for (const a of book.appendices ?? []) {
  body.push(h1(a.title));
  for (const block of a.blocks ?? []) {
    if (block.heading) body.push(h3(block.heading));
    for (const p of block.paragraphs ?? []) body.push(para(p));
    for (const b of block.bullets ?? []) body.push(bullet(b));
    if (block.table) body.push(table(block.table.head, block.table.rows, block.table.widths.map(cm), block.table.size ?? null));
  }
}

if (problems.length) {
  console.error('✗ The manual was not built:');
  for (const p of problems) console.error(`    ${p}`);
  process.exit(1);
}
fs.mkdirSync(OUT, { recursive: true });
const file = path.join(OUT, `ICR-Mobile-App-User-Manual${draft ? '-DRAFT' : ''}.docx`);
fs.writeFileSync(file, await Packer.toBuffer(makeDoc(book.title, body)));
console.log(`✓ ${path.relative(ROOT, file)}  ${chapterNo} chapters, ${stepCount} steps, ${figure} figures, ${(fs.statSync(file).size / 1_048_576).toFixed(1)} MB`);
