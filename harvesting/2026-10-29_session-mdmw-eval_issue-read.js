() => {
  const title = (document.querySelector('h1') || {}).innerText || document.title;
  const state = Array.from(document.querySelectorAll('span')).map(s => s.innerText).find(t => /^(Open|Closed)$/.test(t || '')) || 'unknown';
  const bodies = Array.from(document.querySelectorAll('[data-testid="markdown-body"], .markdown-body, .comment-body')).map(b => b.innerText.trim()).filter(Boolean);
  const authors = Array.from(document.querySelectorAll('[data-testid="issue-body-header-author"], a.author, [data-testid="avatar-link"]')).map(a => a.innerText.trim()).filter(Boolean);
  const times = Array.from(document.querySelectorAll('relative-time')).map(t => t.getAttribute('datetime'));
  return { url: location.href, title, state, authors: authors.slice(0, 15), times: times.slice(0, 15), bodies: bodies.slice(0, 12).map(b => b.slice(0, 1500)) };
}
