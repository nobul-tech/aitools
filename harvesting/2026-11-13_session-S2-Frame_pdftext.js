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
  if (!resp.ok) return { error: 'fetch ' + resp.status };
  const buf = await resp.arrayBuffer();
  const doc = await window.pdfjsLib.getDocument({ data: buf }).promise;
  const pages = [];
  for (let i = 1; i <= doc.numPages; i++) {
    const p = await doc.getPage(i);
    const c = await p.getTextContent();
    pages.push('--- page ' + i + ' ---\n' + c.items.map(it => it.str + (it.hasEOL ? '\n' : '')).join(''));
  }
  window.__pdfText = pages.join('\n');
  return { numPages: doc.numPages, chars: window.__pdfText.length };
}
