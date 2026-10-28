// Writes the website's legal pages (frontend/src/app/{privacy,terms}/page.tsx) as JSON for the app to bundle:
// assets/legal/<page>.json. The website is the source of the words; run this again when they change.
//
//   cd <portal> && node <icr-mobile>/tool/legal/extract.cjs <icr-mobile>/assets/legal
//
// It reads the SECTIONS array and the props of <LegalArticle …> with the TypeScript compiler (the portal's own
// node_modules), so nothing is parsed by hand.
const fs = require('node:fs');
const path = require('node:path');
const ts = require(require.resolve('typescript', { paths: [process.cwd()] }));

const out = process.argv[2];
if (!out) throw new Error('usage: node extract.cjs <output dir>');
fs.mkdirSync(out, { recursive: true });

for (const page of ['privacy', 'terms']) {
  const file = path.join('frontend', 'src', 'app', page, 'page.tsx');
  const text = fs.readFileSync(file, 'utf8');
  const source = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
  let sections = null;
  const props = {};
  const visit = (node) => {
    if (ts.isVariableDeclaration(node) && node.name.getText() === 'SECTIONS' && node.initializer) {
      sections = eval('(' + node.initializer.getText() + ')');
    }
    if ((ts.isJsxSelfClosingElement(node) || ts.isJsxOpeningElement(node)) && node.tagName.getText() === 'LegalArticle') {
      for (const attr of node.attributes.properties) {
        if (!ts.isJsxAttribute(attr) || !attr.initializer) continue;
        const name = attr.name.getText();
        const init = attr.initializer;
        if (ts.isStringLiteral(init)) props[name] = init.text;
        else if (ts.isJsxExpression(init) && init.expression && ts.isStringLiteral(init.expression)) props[name] = init.expression.text;
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(source);
  if (!sections) throw new Error(`${file}: no SECTIONS array`);
  const json = { page, title: props.title, updated: props.updated, intro: props.intro, contactEmail: props.contactEmail, sections };
  fs.writeFileSync(path.join(out, `${page}.json`), JSON.stringify(json, null, 1) + '\n');
  console.log(page, '→', sections.length, 'sections,', JSON.stringify(sections).length, 'bytes of text; title:', props.title, '; updated:', props.updated);
}
