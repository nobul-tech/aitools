async () => {
  const url = window.__pdfUrl;
  if (!window.pdfjsLib) {
    await new Promise((res, rej) => {
      const s = document.createElement('script');
      s.src = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js';
      s.onload = res; s.onerror = () => rej(new Error('pdf.js load failed'));
      document.head.appendChild(s);
    });
    window.pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
  }
  const resp = await fetch(url);
  if (!resp.ok) return 'HTTP ' + resp.status + ' for ' + url;
  const buf = await resp.arrayBuffer();
  const pdf = await window.pdfjsLib.getDocument({ data: buf }).promise;
  const out = [];
  for (let i = 1; i <= pdf.numPages; i++) {
    const page = await pdf.getPage(i);
    const tc = await page.getTextContent();
    let line = '';
    let lastY = null;
    const lines = [];
    for (const it of tc.items) {
      const y = it.transform ? Math.round(it.transform[5]) : null;
      if (lastY !== null && y !== lastY) { lines.push(line); line = ''; }
      line += it.str;
      lastY = y;
    }
    lines.push(line);
    out.push('=== PDF PAGE ' + i + ' ===\n' + lines.join('\n'));
  }
  window.__txt = out.join('\n');
  return 'URL: ' + url + '\nPAGES: ' + pdf.numPages + '\n' + window.__txt;
}
