// S2-Prov: load pdf.js (eval, blob worker), fetch same-origin PDFs, keep page texts in window.__pdf
async () => {
  if (!window.pdfjsLib) {
    try {
      const src = await (await fetch('https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js')).text();
      (0, eval)(src);
    } catch (e) {
      await new Promise((res, rej) => { const s = document.createElement('script'); s.src = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js'; s.onload = res; s.onerror = rej; document.head.appendChild(s); });
    }
    const wsrc = await (await fetch('https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js')).text();
    pdfjsLib.GlobalWorkerOptions.workerSrc = URL.createObjectURL(new Blob([wsrc], {type: 'text/javascript'}));
  }
  const urls = window.__urls || [];
  const res = {};
  window.__pdf = window.__pdf || {};
  for (const u of urls) {
    try {
      const r = await fetch(u);
      if (!r.ok) { res[u] = 'status ' + r.status; continue; }
      const doc = await pdfjsLib.getDocument({data: await r.arrayBuffer()}).promise;
      const pages = [];
      for (let i = 1; i <= doc.numPages; i++) { const p = await doc.getPage(i); pages.push((await p.getTextContent()).items.map(x => x.str + (x.hasEOL ? '\n' : '')).join('')); }
      window.__pdf[u] = pages;
      res[u] = {n: doc.numPages, head: pages.slice(0, 2).join(' ').replace(/\s+/g, ' ').slice(0, 600)};
    } catch (e) { res[u] = 'ERR ' + (e.message || e); }
  }
  return res;
}
