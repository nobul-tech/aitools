#!/usr/bin/env python3
"""Generate v2 session dashboards for sessions 5HyCwPtSDH and Z1IhGrcgGO.

Purpose: Produce comprehensive HTML dashboards with all agents, missions,
and the new v2 fields (context injected, captured intent, orchestration
patterns, workflow chains, delegation duty compliance, assumption tracker).
"""
import json
import textwrap

# ═══════════════════════════════════════════════════════════════
# SHARED CSS (dark theme, matching exemplar)
# ═══════════════════════════════════════════════════════════════

SHARED_CSS = r"""
  :root {
    --bg-primary: #0d1117;
    --bg-secondary: #161b22;
    --bg-tertiary: #21262d;
    --bg-hover: #30363d;
    --border: #30363d;
    --border-light: #484f58;
    --text-primary: #e6edf3;
    --text-secondary: #8b949e;
    --text-muted: #6e7681;
    --accent-blue: #58a6ff;
    --accent-green: #3fb950;
    --accent-yellow: #d29922;
    --accent-red: #f85149;
    --accent-purple: #bc8cff;
    --accent-orange: #f0883e;
    --accent-cyan: #56d4dd;
    --font-mono: 'SF Mono', 'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace;
    --font-sans: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    --radius: 6px;
    --shadow: 0 1px 3px rgba(0,0,0,0.3), 0 1px 2px rgba(0,0,0,0.2);
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html { font-size: 14px; scroll-behavior: smooth; }
  body { background: var(--bg-primary); color: var(--text-primary); font-family: var(--font-sans); line-height: 1.5; min-height: 100vh; }
  .header { position: sticky; top: 0; z-index: 100; background: var(--bg-secondary); border-bottom: 1px solid var(--border); padding: 12px 24px; box-shadow: var(--shadow); }
  .header-top { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; margin-bottom: 12px; }
  .header-title { font-size: 1.3rem; font-weight: 600; }
  .header-title span { color: var(--text-secondary); font-weight: 400; font-size: 0.9rem; }
  .session-id { font-family: var(--font-mono); color: var(--accent-blue); font-size: 0.85rem; }
  .stats-bar { display: flex; gap: 16px; flex-wrap: wrap; align-items: center; }
  .stat-card { background: var(--bg-tertiary); border: 1px solid var(--border); border-radius: var(--radius); padding: 6px 14px; display: flex; align-items: center; gap: 8px; }
  .stat-value { font-size: 1.2rem; font-weight: 700; font-family: var(--font-mono); }
  .stat-label { font-size: 0.75rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px; }
  .stat-value.green { color: var(--accent-green); }
  .stat-value.yellow { color: var(--accent-yellow); }
  .stat-value.red { color: var(--accent-red); }
  .stat-value.blue { color: var(--accent-blue); }
  .stat-value.purple { color: var(--accent-purple); }
  .stat-value.orange { color: var(--accent-orange); }
  .stat-value.cyan { color: var(--accent-cyan); }
  .controls { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; padding: 12px 24px; background: var(--bg-secondary); border-bottom: 1px solid var(--border); }
  .filter-group { display: flex; gap: 4px; }
  .filter-btn { background: var(--bg-tertiary); border: 1px solid var(--border); color: var(--text-secondary); padding: 4px 12px; border-radius: var(--radius); cursor: pointer; font-size: 0.8rem; font-family: var(--font-sans); transition: all 0.15s; }
  .filter-btn:hover { background: var(--bg-hover); color: var(--text-primary); }
  .filter-btn.active { background: var(--accent-blue); color: #fff; border-color: var(--accent-blue); }
  .search-box { background: var(--bg-tertiary); border: 1px solid var(--border); color: var(--text-primary); padding: 5px 12px; border-radius: var(--radius); font-size: 0.85rem; font-family: var(--font-sans); width: 280px; outline: none; transition: border-color 0.15s; }
  .search-box:focus { border-color: var(--accent-blue); }
  .search-box::placeholder { color: var(--text-muted); }
  .view-toggle { margin-left: auto; display: flex; gap: 4px; }
  .section-title { font-size: 0.85rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px; font-weight: 600; }
  .session-summary { padding: 20px 24px; border-bottom: 1px solid var(--border); background: var(--bg-secondary); }
  .summary-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; margin-top: 12px; }
  @media (max-width: 900px) { .summary-grid { grid-template-columns: 1fr; } }
  .summary-card { background: var(--bg-tertiary); border: 1px solid var(--border); border-radius: var(--radius); padding: 16px; }
  .summary-card-title { font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 10px; font-weight: 600; }
  .summary-card-content { font-size: 0.85rem; color: var(--text-secondary); line-height: 1.7; }
  .summary-card-content strong { color: var(--text-primary); }
  .summary-card-content .hl { color: var(--accent-blue); font-family: var(--font-mono); font-weight: 600; }
  .compliance-bar { margin-top: 8px; background: var(--bg-primary); border-radius: 4px; height: 8px; overflow: hidden; }
  .compliance-fill { height: 100%; border-radius: 4px; transition: width 0.6s ease; }
  .compliance-fill.green { background: var(--accent-green); }
  .compliance-fill.yellow { background: var(--accent-yellow); }
  .compliance-fill.red { background: var(--accent-red); }
  .tab-nav { display: flex; gap: 0; border-bottom: 1px solid var(--border); margin-bottom: 16px; }
  .tab-btn { background: none; border: none; border-bottom: 2px solid transparent; color: var(--text-secondary); padding: 8px 16px; cursor: pointer; font-size: 0.8rem; font-family: var(--font-sans); font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; transition: all 0.15s; }
  .tab-btn:hover { color: var(--text-primary); }
  .tab-btn.active { color: var(--accent-blue); border-bottom-color: var(--accent-blue); }
  .tab-panel { display: none; }
  .tab-panel.active { display: block; }
  .timeline-section { padding: 20px 24px; border-bottom: 1px solid var(--border); background: var(--bg-secondary); }
  .timeline-container { overflow-x: auto; padding-bottom: 8px; }
  .timeline { position: relative; min-height: 60px; width: 100%; min-width: 900px; }
  .timeline-axis { position: absolute; bottom: 0; left: 0; right: 0; height: 1px; background: var(--border); }
  .timeline-labels { display: flex; justify-content: space-between; padding-top: 4px; font-size: 0.7rem; color: var(--text-muted); font-family: var(--font-mono); }
  .timeline-bars { display: flex; flex-direction: column; gap: 2px; padding-bottom: 20px; }
  .timeline-row { display: flex; align-items: center; height: 18px; position: relative; }
  .timeline-bar-label { width: 55px; font-size: 0.65rem; color: var(--text-muted); font-family: var(--font-mono); text-align: right; padding-right: 6px; flex-shrink: 0; white-space: nowrap; overflow: hidden; }
  .timeline-bar-track { flex: 1; position: relative; height: 100%; }
  .timeline-bar { position: absolute; height: 12px; top: 3px; border-radius: 2px; cursor: pointer; transition: opacity 0.15s; min-width: 3px; }
  .timeline-bar:hover { opacity: 0.8; }
  .timeline-bar.s-completed { background: var(--accent-green); }
  .timeline-bar.s-blocked { background: var(--accent-yellow); }
  .timeline-bar.s-running { background: var(--accent-blue); }
  .timeline-bar.s-inline { background: var(--accent-purple); }
  .timeline-bar.s-partial { background: var(--accent-orange); }
  .timeline-bar.s-fragord { background: repeating-linear-gradient(45deg, var(--accent-yellow), var(--accent-yellow) 3px, rgba(210,153,34,0.4) 3px, rgba(210,153,34,0.4) 6px); }
  .timeline-bar .tooltip { display: none; position: absolute; bottom: 100%; left: 50%; transform: translateX(-50%); background: var(--bg-primary); border: 1px solid var(--border); padding: 4px 8px; border-radius: var(--radius); font-size: 0.75rem; white-space: nowrap; z-index: 10; pointer-events: none; }
  .timeline-bar:hover .tooltip { display: block; }
  .agents-container { padding: 20px 24px; display: flex; flex-direction: column; gap: 8px; }
  .agent-card { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden; transition: border-color 0.15s; }
  .agent-card:hover { border-color: var(--border-light); }
  .agent-card.highlight { border-color: var(--accent-blue); box-shadow: 0 0 0 1px var(--accent-blue); }
  .agent-card.fragord-card { border-left: 3px solid var(--accent-yellow); }
  .agent-card-header { display: grid; grid-template-columns: 48px 1fr auto; gap: 12px; padding: 12px 16px; cursor: pointer; align-items: center; }
  .agent-card-header:hover { background: var(--bg-tertiary); }
  .agent-number { width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 0.85rem; font-family: var(--font-mono); flex-shrink: 0; }
  .agent-number.role-s2 { background: #1f3a5f; color: var(--accent-blue); }
  .agent-number.role-s3 { background: #1a3d2a; color: var(--accent-green); }
  .agent-number.role-verifier { background: #3d2e1a; color: var(--accent-orange); }
  .agent-number.role-s1 { background: #3d1a3d; color: var(--accent-purple); }
  .agent-info { min-width: 0; }
  .agent-title-row { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  .agent-mission { font-weight: 600; font-size: 0.95rem; }
  .agent-role-badge { font-size: 0.7rem; padding: 1px 8px; border-radius: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; flex-shrink: 0; }
  .agent-role-badge.role-s2 { background: #1f3a5f; color: var(--accent-blue); }
  .agent-role-badge.role-s3 { background: #1a3d2a; color: var(--accent-green); }
  .agent-role-badge.role-verifier { background: #3d2e1a; color: var(--accent-orange); }
  .agent-role-badge.role-s1 { background: #3d1a3d; color: var(--accent-purple); }
  .pattern-badge { font-size: 0.65rem; padding: 1px 6px; border-radius: 4px; background: rgba(86,212,221,0.15); color: var(--accent-cyan); border: 1px solid rgba(86,212,221,0.3); font-family: var(--font-mono); font-weight: 600; }
  .fragord-badge { font-size: 0.65rem; padding: 1px 6px; border-radius: 4px; background: rgba(210,153,34,0.15); color: var(--accent-yellow); border: 1px solid rgba(210,153,34,0.3); font-family: var(--font-mono); font-weight: 600; }
  .worktree-badge { font-size: 0.65rem; padding: 1px 6px; border-radius: 4px; background: rgba(188,140,255,0.15); color: var(--accent-purple); border: 1px solid rgba(188,140,255,0.3); font-family: var(--font-mono); }
  .agent-meta { display: flex; gap: 12px; margin-top: 4px; flex-wrap: wrap; }
  .agent-meta-item { font-size: 0.75rem; color: var(--text-secondary); font-family: var(--font-mono); display: flex; align-items: center; gap: 4px; }
  .agent-status { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
  .status-badge { font-size: 0.7rem; padding: 2px 10px; border-radius: 10px; font-weight: 600; text-transform: uppercase; }
  .status-badge.completed { background: #1a3d2a; color: var(--accent-green); }
  .status-badge.blocked { background: #3d351a; color: var(--accent-yellow); }
  .status-badge.running { background: #1a2a3d; color: var(--accent-blue); }
  .status-badge.partial { background: #3d2a1a; color: var(--accent-orange); }
  .status-badge.inline { background: #2a1a3d; color: var(--accent-purple); }
  .expand-icon { color: var(--text-muted); transition: transform 0.2s; font-size: 1rem; flex-shrink: 0; }
  .agent-card.expanded .expand-icon { transform: rotate(90deg); }
  .agent-detail { display: none; border-top: 1px solid var(--border); padding: 16px; background: var(--bg-primary); }
  .agent-card.expanded .agent-detail { display: block; }
  .detail-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px; }
  @media (max-width: 768px) { .detail-grid { grid-template-columns: 1fr; } }
  .detail-section { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 12px; }
  .detail-section-title { font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; font-weight: 600; }
  .detail-section-content { font-size: 0.85rem; color: var(--text-secondary); }
  .detail-section-content.mono { font-family: var(--font-mono); font-size: 0.8rem; }
  .file-path { font-family: var(--font-mono); font-size: 0.8rem; color: var(--accent-blue); display: block; padding: 2px 0; word-break: break-all; }
  .context-item { display: flex; align-items: baseline; gap: 6px; padding: 2px 0; font-size: 0.82rem; color: var(--text-secondary); }
  .context-bullet { color: var(--accent-cyan); font-size: 0.7rem; flex-shrink: 0; }
  .duty-checklist { display: grid; grid-template-columns: 1fr 1fr; gap: 4px 12px; }
  .duty-item { display: flex; align-items: center; gap: 6px; font-size: 0.8rem; padding: 2px 0; }
  .duty-check { width: 16px; height: 16px; border-radius: 3px; display: flex; align-items: center; justify-content: center; font-size: 0.7rem; font-weight: 700; flex-shrink: 0; }
  .duty-check.pass { background: rgba(63,185,80,0.2); color: var(--accent-green); border: 1px solid rgba(63,185,80,0.4); }
  .duty-check.fail { background: rgba(248,81,73,0.2); color: var(--accent-red); border: 1px solid rgba(248,81,73,0.4); }
  .duty-label { color: var(--text-secondary); }
  .aar-outcome { font-size: 0.85rem; color: var(--text-primary); padding: 8px 12px; background: var(--bg-tertiary); border-left: 3px solid var(--accent-green); border-radius: 0 var(--radius) var(--radius) 0; }
  .deviation-item { display: flex; align-items: baseline; gap: 6px; padding: 3px 0; font-size: 0.82rem; color: var(--accent-orange); }
  .deviation-bullet { color: var(--accent-red); font-size: 0.7rem; flex-shrink: 0; }
  .finding-text { font-size: 0.85rem; color: var(--text-primary); line-height: 1.6; padding: 8px 12px; background: var(--bg-tertiary); border-left: 3px solid var(--accent-blue); border-radius: 0 var(--radius) var(--radius) 0; }
  .note-text { font-size: 0.8rem; color: var(--accent-yellow); padding: 6px 10px; background: rgba(210,153,34,0.1); border: 1px solid rgba(210,153,34,0.3); border-radius: var(--radius); margin-top: 8px; }
  .spot-check-text { font-size: 0.85rem; color: var(--text-secondary); padding: 6px 10px; background: var(--bg-tertiary); border-left: 3px solid var(--accent-purple); border-radius: 0 var(--radius) var(--radius) 0; }
  .prompt-section { margin-top: 12px; }
  .prompt-toggle { display: flex; align-items: center; gap: 6px; cursor: pointer; color: var(--text-secondary); font-size: 0.8rem; padding: 6px 0; user-select: none; }
  .prompt-toggle:hover { color: var(--text-primary); }
  .prompt-toggle .arrow { transition: transform 0.2s; font-size: 0.7rem; }
  .prompt-toggle.open .arrow { transform: rotate(90deg); }
  .prompt-content { display: none; margin-top: 8px; background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 12px; font-family: var(--font-mono); font-size: 0.78rem; line-height: 1.6; color: var(--text-secondary); white-space: pre-wrap; word-break: break-word; max-height: 500px; overflow-y: auto; }
  .prompt-content.open { display: block; }
  .full-width { grid-column: 1 / -1; }
  .chain-section { padding: 20px 24px; border-bottom: 1px solid var(--border); background: var(--bg-secondary); }
  .chain-card { background: var(--bg-tertiary); border: 1px solid var(--border); border-radius: var(--radius); padding: 12px; margin-bottom: 8px; }
  .chain-title { font-weight: 600; font-size: 0.9rem; color: var(--accent-cyan); margin-bottom: 6px; }
  .chain-agents { font-family: var(--font-mono); font-size: 0.8rem; color: var(--text-secondary); }
  .chain-flow { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-top: 6px; }
  .chain-node { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 2px 8px; font-family: var(--font-mono); font-size: 0.75rem; }
  .chain-arrow { color: var(--accent-cyan); font-size: 0.8rem; }
  .legend { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 8px; }
  .legend-item { display: flex; align-items: center; gap: 4px; font-size: 0.7rem; color: var(--text-muted); }
  .legend-dot { width: 8px; height: 8px; border-radius: 2px; }
  .legend-dot.green { background: var(--accent-green); }
  .legend-dot.yellow { background: var(--accent-yellow); }
  .legend-dot.blue { background: var(--accent-blue); }
  .legend-dot.purple { background: var(--accent-purple); }
  .legend-dot.orange { background: var(--accent-orange); }
  .legend-dot.fragord { background: repeating-linear-gradient(45deg, var(--accent-yellow), var(--accent-yellow) 2px, rgba(210,153,34,0.4) 2px, rgba(210,153,34,0.4) 4px); }
  .hidden { display: none !important; }
  ::-webkit-scrollbar { width: 8px; height: 8px; }
  ::-webkit-scrollbar-track { background: var(--bg-primary); }
  ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }
  ::-webkit-scrollbar-thumb:hover { background: var(--border-light); }
  .no-results { text-align: center; padding: 40px; color: var(--text-muted); font-size: 0.95rem; }
  .convergence-item { padding: 6px 0; border-bottom: 1px solid rgba(48,54,61,0.5); }
  .convergence-item:last-child { border-bottom: none; }
  .convergence-label { color: var(--accent-purple); font-weight: 600; font-size: 0.85rem; }
  .convergence-desc { font-size: 0.82rem; color: var(--text-secondary); margin-top: 2px; }
  .convergence-agents { font-family: var(--font-mono); font-size: 0.75rem; color: var(--text-muted); }
  .decision-item { padding: 6px 0; border-bottom: 1px solid rgba(48,54,61,0.5); display: flex; gap: 10px; align-items: baseline; }
  .decision-item:last-child { border-bottom: none; }
  .decision-id { color: var(--accent-cyan); font-family: var(--font-mono); font-size: 0.8rem; font-weight: 600; white-space: nowrap; }
  .decision-text { font-size: 0.82rem; color: var(--text-secondary); }
  .assumption-item { padding: 4px 0; display: flex; gap: 8px; align-items: baseline; }
  .assumption-status { font-size: 0.7rem; padding: 1px 6px; border-radius: 4px; font-weight: 600; font-family: var(--font-mono); white-space: nowrap; }
  .assumption-status.unverified { background: rgba(210,153,34,0.2); color: var(--accent-yellow); border: 1px solid rgba(210,153,34,0.3); }
  .assumption-status.verified { background: rgba(63,185,80,0.2); color: var(--accent-green); border: 1px solid rgba(63,185,80,0.4); }
  .assumption-status.falsified { background: rgba(248,81,73,0.2); color: var(--accent-red); border: 1px solid rgba(248,81,73,0.4); }
  .assumption-text { font-size: 0.82rem; color: var(--text-secondary); }
"""

# ═══════════════════════════════════════════════════════════════
# SHARED JavaScript
# ═══════════════════════════════════════════════════════════════

SHARED_JS = r"""
function initDashboard() {
  const statsBar = document.getElementById('statsBar');
  const roleFilters = document.getElementById('roleFilters');
  const statusFilters = document.getElementById('statusFilters');
  const searchBox = document.getElementById('searchBox');
  const agentsList = document.getElementById('agentsList');
  const noResults = document.getElementById('noResults');
  const timeline = document.getElementById('timeline');

  let activeRole = 'all';
  let activeStatus = 'all';
  let activePattern = 'all';
  let searchTerm = '';

  // Stats
  const totalAgents = agents.length;
  const s2Count = agents.filter(a => a.role === 's2').length;
  const s3Count = agents.filter(a => a.role === 's3').length;
  const verifierCount = agents.filter(a => a.role === 'verifier').length;
  const completedCount = agents.filter(a => a.status === 'completed').length;
  const blockedCount = agents.filter(a => a.status === 'blocked').length;
  const totalTokens = agents.reduce((s, a) => s + (a.tokens || 0), 0);
  const totalDuration = agents.reduce((s, a) => s + (a.duration || 0), 0);

  statsBar.innerHTML = `
    <div class="stat-card"><div class="stat-value green">${totalAgents}</div><div class="stat-label">Agents</div></div>
    <div class="stat-card"><div class="stat-value blue">${s2Count}</div><div class="stat-label">S2</div></div>
    <div class="stat-card"><div class="stat-value green">${s3Count}</div><div class="stat-label">S3</div></div>
    ${verifierCount ? `<div class="stat-card"><div class="stat-value orange">${verifierCount}</div><div class="stat-label">Verifier</div></div>` : ''}
    <div class="stat-card"><div class="stat-value purple">${completedCount}/${totalAgents}</div><div class="stat-label">Complete</div></div>
    <div class="stat-card"><div class="stat-value yellow">${Math.round(totalTokens/1000)}K</div><div class="stat-label">Tokens</div></div>
    <div class="stat-card"><div class="stat-value cyan">${Math.round(totalDuration/60)}m</div><div class="stat-label">Compute</div></div>
  `;

  // Render timeline
  if (timeline) {
    const maxDur = Math.max(...agents.map(a => (a.startOffset||0) + (a.duration||10)));
    let bars = '<div class="timeline-bars">';
    agents.forEach(a => {
      const left = ((a.startOffset||0)/maxDur*100).toFixed(1);
      const width = Math.max(1, ((a.duration||10)/maxDur*100)).toFixed(1);
      const sc = a.isFragord ? 's-fragord' : `s-${a.statusClass || a.status}`;
      const label = `#${a.id}`;
      bars += `<div class="timeline-row">
        <div class="timeline-bar-label">${a.description ? a.description.substring(0,8) : label}</div>
        <div class="timeline-bar-track">
          <div class="timeline-bar ${sc}" style="left:${left}%;width:${width}%">
            <div class="tooltip">#${a.id} ${a.mission.substring(0,50)} (${a.durationLabel||'?'})</div>
          </div>
        </div>
      </div>`;
    });
    bars += '</div><div class="timeline-axis"></div>';
    timeline.innerHTML = bars;
  }

  // Render agents
  function renderAgents() {
    let html = '';
    let visible = 0;
    agents.forEach(a => {
      const matchRole = activeRole === 'all' || a.role === activeRole;
      const matchStatus = activeStatus === 'all' || a.status === activeStatus;
      const matchPattern = activePattern === 'all' || (a.pattern && a.pattern === activePattern);
      const text = JSON.stringify(a).toLowerCase();
      const matchSearch = !searchTerm || text.includes(searchTerm.toLowerCase());
      if (!matchRole || !matchStatus || !matchPattern || !matchSearch) return;
      visible++;

      const roleClass = `role-${a.role}`;
      const fragordClass = a.isFragord ? ' fragord-card' : '';
      const badges = [];
      if (a.isFragord) badges.push('<span class="fragord-badge">FRAGORD</span>');
      if (a.fragordOf) badges.push(`<span class="fragord-badge">FRAGORD of #${a.fragordOf}</span>`);
      if (a.worktree) badges.push('<span class="worktree-badge">worktree</span>');
      if (a.pattern) badges.push(`<span class="pattern-badge">${a.pattern}</span>`);

      // Duty checklist
      const dd = a.delegationDutyFulfilled || {};
      const dutyItems = [
        ['Identity', dd.identityEstablished],
        ['Prior results', dd.priorResultsIncluded],
        ['Critical rules', dd.criticalRulesInjected],
        ['AAR format', dd.aarFormatRequired],
        ['WRITE_BLOCKED', dd.writeBlockedSignal],
        ['Context files', dd.contextFilesListed !== false],
        ['Output path', dd.outputPathSpecified !== false],
        ['Schwerpunkt', dd.schwerpunktStated !== false],
        ['ultrathink', dd.ultrathinkEnabled !== undefined ? dd.ultrathinkEnabled : null],
        ['Learning duty', dd.learningDutyInjected !== undefined ? dd.learningDutyInjected : null],
        ['Assumptions', dd.assumptionsInjected !== undefined ? dd.assumptionsInjected : null],
      ].filter(([,v]) => v !== null && v !== undefined);

      let dutyHtml = '<div class="duty-checklist">';
      dutyItems.forEach(([label, val]) => {
        const cls = val ? 'pass' : 'fail';
        const icon = val ? '&#10003;' : '&#10007;';
        dutyHtml += `<div class="duty-item"><div class="duty-check ${cls}">${icon}</div><span class="duty-label">${label}</span></div>`;
      });
      dutyHtml += '</div>';

      // Context injected
      let ctxHtml = '';
      if (a.contextInjected && a.contextInjected.length) {
        ctxHtml = a.contextInjected.map(c => `<div class="context-item"><span class="context-bullet">&#9656;</span>${c}</div>`).join('');
      }

      // Deviations
      let devHtml = '';
      if (a.deviations && a.deviations.length) {
        devHtml = a.deviations.map(d => `<div class="deviation-item"><span class="deviation-bullet">&#9679;</span>${d}</div>`).join('');
      }

      html += `
      <div class="agent-card${fragordClass}" data-id="${a.id}">
        <div class="agent-card-header" onclick="this.parentElement.classList.toggle('expanded')">
          <div class="agent-number ${roleClass}">${a.id}</div>
          <div class="agent-info">
            <div class="agent-title-row">
              <span class="agent-mission">${a.mission}</span>
              <span class="agent-role-badge ${roleClass}">${a.roleLabel}</span>
              ${badges.join(' ')}
            </div>
            <div class="agent-meta">
              <span class="agent-meta-item">${a.durationLabel || 'n/a'}</span>
              <span class="agent-meta-item">${a.tokenLabel || 'n/a'} tokens</span>
              <span class="agent-meta-item">${a.toolUses || 0} tools</span>
            </div>
          </div>
          <div class="agent-status">
            <span class="status-badge ${a.statusClass || a.status}">${a.statusLabel}</span>
            <span class="expand-icon">&#9654;</span>
          </div>
        </div>
        <div class="agent-detail">
          <div class="detail-grid">
            <div class="detail-section">
              <div class="detail-section-title">Captured Intent (Auftrag)</div>
              <div class="detail-section-content">${a.capturedIntent || 'Not captured'}</div>
            </div>
            <div class="detail-section">
              <div class="detail-section-title">Context Injected</div>
              <div class="detail-section-content">${ctxHtml || 'No context injection recorded'}</div>
            </div>
            <div class="detail-section">
              <div class="detail-section-title">Delegation Duty (${dutyItems.filter(([,v])=>v).length}/${dutyItems.length})</div>
              <div class="detail-section-content">${dutyHtml}</div>
            </div>
            <div class="detail-section">
              <div class="detail-section-title">Key Finding</div>
              <div class="finding-text">${a.finding || 'No finding recorded'}</div>
            </div>
            ${a.aarOutcome ? `<div class="detail-section"><div class="detail-section-title">AAR Outcome</div><div class="aar-outcome">${a.aarOutcome}</div></div>` : ''}
            ${devHtml ? `<div class="detail-section"><div class="detail-section-title">Deviations</div><div class="detail-section-content">${devHtml}</div></div>` : ''}
            ${a.spotCheckResults ? `<div class="detail-section"><div class="detail-section-title">Spot-Check Results</div><div class="spot-check-text">${a.spotCheckResults}</div></div>` : ''}
            ${a.output ? `<div class="detail-section"><div class="detail-section-title">Output</div><div class="file-path">${a.output}</div></div>` : ''}
            ${a.note ? `<div class="detail-section full-width"><div class="note-text">${a.note}</div></div>` : ''}
          </div>
          ${a.prompt ? `<div class="prompt-section"><div class="prompt-toggle" onclick="this.classList.toggle('open');this.nextElementSibling.classList.toggle('open')"><span class="arrow">&#9654;</span> Delegation Prompt</div><div class="prompt-content">${typeof a.prompt === 'string' ? a.prompt : JSON.stringify(a.prompt)}</div></div>` : ''}
        </div>
      </div>`;
    });
    agentsList.innerHTML = html;
    noResults.classList.toggle('hidden', visible > 0);
  }

  // Filter handlers
  roleFilters.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      roleFilters.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeRole = btn.dataset.role;
      renderAgents();
    });
  });
  statusFilters.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      statusFilters.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeStatus = btn.dataset.status;
      renderAgents();
    });
  });
  const patternFilters = document.getElementById('patternFilters');
  if (patternFilters) {
    patternFilters.querySelectorAll('.filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        patternFilters.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        activePattern = btn.dataset.pattern;
        renderAgents();
      });
    });
  }
  searchBox.addEventListener('input', () => { searchTerm = searchBox.value; renderAgents(); });

  // Keyboard shortcuts
  document.addEventListener('keydown', e => {
    if (e.key === '/' && document.activeElement !== searchBox) { e.preventDefault(); searchBox.focus(); }
    if (e.key === 'Escape') { searchBox.value = ''; searchTerm = ''; searchBox.blur(); renderAgents(); }
  });

  // Expand/collapse all
  document.getElementById('expandAll').addEventListener('click', () => {
    document.querySelectorAll('.agent-card').forEach(c => c.classList.add('expanded'));
  });
  document.getElementById('collapseAll').addEventListener('click', () => {
    document.querySelectorAll('.agent-card').forEach(c => c.classList.remove('expanded'));
  });

  // Tabs
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const nav = btn.parentElement;
      const container = nav.parentElement;
      nav.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      container.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
      const target = container.querySelector('#tab-' + btn.dataset.tab);
      if (target) target.classList.add('active');
    });
  });

  renderAgents();
}
document.addEventListener('DOMContentLoaded', initDashboard);
"""

def escape_js_string(s):
    """Escape a string for embedding inside JS single-quoted strings."""
    if not s:
        return ''
    return (s.replace('\\', '\\\\')
             .replace("'", "\\'")
             .replace('"', '\\"')
             .replace('\n', '\\n')
             .replace('\r', '')
             .replace('</', '<\\/'))

def generate_session_5HyCwPtSDH():
    """Generate the v2 dashboard for session 5HyCwPtSDH."""

    # All agents data for this session -- 18 agents across 13 missions
    agents_js = r"""
const agents = [
  {
    id: 1, role: "s2", roleLabel: "S2 (General)", mission: "Investigate missing briefing JSONs",
    description: "D1: Briefings", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 156, durationLabel: "~156s", tokens: 43000, tokenLabel: "43K", toolUses: 5,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 0,
    pattern: "single-agent",
    contextInjected: ["Investigation tasks (9 items)", "File paths to check", "Output format requirements"],
    capturedIntent: "Determine if briefing JSONs were deleted or never committed. Check all possible locations.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: false, aarFormatRequired: false, writeBlockedSignal: false },
    finding: "Briefing JSONs not lost -- .gitignore blanket .aitools/ prevents carry-forward. Planning-brief.json safe (tracked). Running-estimate.json local only (gitignored).",
    aarOutcome: null, output: ".scratch/session-5HyCwPtSDH/investigation-briefing-jsons.md",
    deviations: ["Used general-purpose instead of Explore -- correct in hindsight (never use Explore)"],
    spotCheckResults: "3 claims verified, 1 partially incorrect (subagent said nothing lost, but running estimate at risk)",
    note: null, prompt: "Investigate missing briefing JSON files. Check git history, .aitools/, plans/."
  },
  {
    id: 2, role: "s2", roleLabel: "S2 (Explore)", mission: "Investigate lost AARs and session archives",
    description: "D2a: AARs", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 76, durationLabel: "~76s", tokens: 100000, tokenLabel: "100K", toolUses: 45,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 160,
    pattern: "single-agent",
    contextInjected: ["Investigation tasks (9 items)", "File paths for hooks", "Dotprofile repo path", "CC local session path"],
    capturedIntent: "Determine if harvest hook .json bug is deployed, if AARs can be recovered, if session archives exist locally.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: false, aarFormatRequired: false, writeBlockedSignal: false },
    finding: "Harvest hook fix deployed. 2 AARs unrecoverable. 5 session files untracked in dotprofile (33.1 MB). Session e059186f: 4.2 MB archived, 11.4 MB locally.",
    aarOutcome: null, output: "Inline return (Explore agent)",
    deviations: ["Explore agent type -- can't write", "No WRITE_BLOCKED signal"],
    spotCheckResults: "4 claims verified (deploy diff, file sizes, git status, archived size)",
    note: "Launched as Explore -- should have been general-purpose", prompt: "Full investigation context with 9 tasks covering git history, hook analysis, session archives."
  },
  {
    id: 3, role: "s2", roleLabel: "S2 (Explore)", mission: "Investigate dotprofile repo state and CC local sessions",
    description: "D2b: Dotprofile", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 60, durationLabel: "~60s", tokens: 73000, tokenLabel: "73K", toolUses: 28,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 160,
    pattern: "single-agent",
    contextInjected: ["Dotprofile repo path", "CC projects path", "Hook analysis tasks"],
    capturedIntent: "Find all local session data that wasn't archived. Determine hook behavior.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: false, aarFormatRequired: false, writeBlockedSignal: false },
    finding: "33.1 MB untracked sessions across 4 projects. Hook is copy-only (no auto-commit/push).",
    aarOutcome: null, output: "Inline return (Explore agent)",
    deviations: ["Explore agent type", "Size discrepancy with D2a"],
    spotCheckResults: "Cross-referenced with D2a -- discrepancy caught",
    note: null, prompt: "Full investigation context with 5 tasks covering dotprofile state, CC local sessions."
  },
  {
    id: 4, role: "s2", roleLabel: "S2 (Explore)", mission: "Running estimate lifecycle investigation (ORIGINAL)",
    description: "M1: RE (Explore)", status: "blocked", statusLabel: "FRAGORD'd", statusClass: "blocked",
    duration: 41, durationLabel: "~41s", tokens: 61000, tokenLabel: "61K", toolUses: 12,
    worktree: false, isFragord: true, fragordOf: null, fragordRelaunchedAs: 5, startOffset: 300,
    pattern: "WRITE_BLOCKED-RELAUNCH",
    contextInjected: ["7 investigation tasks", "File paths for hooks/skills/tool-ops"],
    capturedIntent: "Determine why assumption was made that running estimate would be deleted at session end.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: false, aarFormatRequired: true, writeBlockedSignal: false },
    finding: ".json harvested not deleted, but harvest != carry-forward. 0/60 harvested artifacts are .json. /scratch skill warns against running estimates in scratch.",
    aarOutcome: "Inline prose AAR -- not persisted to file",
    output: "Inline return only -- no file written (Explore can't write)",
    deviations: ["Explore agent type -- CANNOT WRITE. Led to FRAGORD."],
    spotCheckResults: "Findings verified via M1-FRAGORD relaunch",
    note: "FRAGORD'd: launched as Explore (can't write). Findings carried forward to M1-FRAGORD relaunch.",
    prompt: "Investigation of running estimate lifecycle with 7 tasks."
  },
  {
    id: 5, role: "s2", roleLabel: "S2 (General)", mission: "Running estimate lifecycle (FRAGORD relaunch)",
    description: "M1-FRAGORD", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 162, durationLabel: "~162s", tokens: 75000, tokenLabel: "75K", toolUses: 24,
    worktree: false, isFragord: false, fragordOf: 4, startOffset: 350,
    pattern: "WRITE_BLOCKED-RELAUNCH",
    contextInjected: ["FRAGORD context (original findings)", "7 file paths", "AAR JSON schema", "WRITE_BLOCKED signal", "ultrathink"],
    capturedIntent: "Verify original M1 findings, expand with additional analysis, write persistent AAR file.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: true, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: "15 observations, verified all original M1 findings. .gitignore defeats three rules. .json harvest path never exercised (0/60).",
    aarOutcome: "15 observations, 7 insights, 5 proposals -- all with barrier analysis. 17.5 KB JSON.",
    output: ".scratch/session-5HyCwPtSDH/m1-running-estimate-lifecycle-aar.json",
    deviations: [], spotCheckResults: "O-9 verified (running estimate in scratch confirmed as anti-pattern)",
    note: "FRAGORD relaunch of Agent #4. Carried forward original findings + verified independently.",
    prompt: "FRAGORD context with original findings to verify. AAR JSON output required. WRITE_BLOCKED signal."
  },
  {
    id: 6, role: "s2", roleLabel: "S2 (General)", mission: "Scratch paths and lifecycle management",
    description: "M2: Scratch", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 291, durationLabel: "~5m", tokens: 96000, tokenLabel: "96K", toolUses: 53,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 350,
    pattern: "single-agent",
    contextInjected: ["8 investigation tasks", "File paths for briefings+skills+rules"],
    capturedIntent: "Determine if handoff scratch paths are broken. Map lifecycle management across skills/frameworks.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: false, aarFormatRequired: false, writeBlockedSignal: false },
    finding: "CRITICAL: All 30 scratch files from handoff are LOST. Only 4 survived (manually committed). Two-phase harvest reliability gap.",
    aarOutcome: "8 observations, 6 insights, 6 proposals. Prose converted to JSON by S3.",
    output: ".scratch/session-5HyCwPtSDH/m2-scratch-lifecycle-aar.json",
    deviations: ["Stale briefing (pre-correction)", "Prose AAR format (not JSON)", "No WRITE_BLOCKED signal"],
    spotCheckResults: "30-file loss confirmed independently",
    note: "Launched before 40-agent lessons. Prose AAR converted to JSON by delegating agent.",
    prompt: "Investigation of scratch path survivability with 8 tasks."
  },
  {
    id: 7, role: "s3", roleLabel: "S3 (Operations)", mission: "Convert handoff-prompt-v2.md to structured JSON (Schema B)",
    description: "M3: JSON", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 414, durationLabel: "~7m", tokens: 85000, tokenLabel: "85K", toolUses: 17,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 350,
    pattern: "single-agent",
    contextInjected: ["Schema B requirements (14 sections)", "3 full files to read", "AAR JSON schema", "WRITE_BLOCKED signal", "ultrathink"],
    capturedIntent: "Design handoff-briefing JSON schema. Produce the JSON. Capture both backward and forward-looking structure.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: "1035-line valid JSON with 14 top-level sections. Schema B captures forward+backward looking structure.",
    aarOutcome: "4 design observations, 4 insights on JSON vs prose, 4 schema improvement proposals.",
    output: ".scratch/session-5HyCwPtSDH/handoff-briefing.json",
    deviations: [], spotCheckResults: "Valid JSON verified (python3 json.load). 14 sections confirmed.",
    note: "Largest task. Read 3 full files (4400+ lines total) into context.",
    prompt: "Full Schema B requirements. Read 3 files IN FULL. WRITE_BLOCKED signal. ultrathink."
  },
  {
    id: 8, role: "s2", roleLabel: "S2 (Intelligence)", mission: "Concurrent sessions + channel architecture reconciliation",
    description: "M4: Concurrent", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 303, durationLabel: "~5m", tokens: 84000, tokenLabel: "84K", toolUses: 43,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 350,
    pattern: "single-agent",
    contextInjected: ["Concurrent session use case", "Commander per-session estimate decision", "7 full files to read", "AAR JSON schema", "WRITE_BLOCKED signal", "ultrathink"],
    capturedIntent: "Design channel architecture for multi-session concurrent use. Fix .current-session race.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: ".current-session pointer has race condition. Both root + nested .gitignore needed. Per-session estimates with reconciliation.",
    aarOutcome: "10 observations, 6 insights, 5 proposals -- all with barrier analysis. 20.7 KB JSON.",
    output: ".scratch/session-5HyCwPtSDH/m4-concurrent-channel-aar.json",
    deviations: [], spotCheckResults: ".current-session race verified (scratch-init.sh lines 37,40)",
    note: null, prompt: "Full concurrent session investigation. 5 tasks. Read 7 files IN FULL."
  },
  {
    id: 9, role: "s2", roleLabel: "S2 (Intelligence)", mission: "/aitool-* naming convention + user-level skill deployment",
    description: "M5: Naming", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 191, durationLabel: "~3m", tokens: 78000, tokenLabel: "78K", toolUses: 36,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 350,
    pattern: "single-agent",
    contextInjected: ["Commander's /aitool-* prefix choice", "Skill directory listing", "Build-deploy.sh skill embedding", "Planning brief decisions #16, #49"],
    capturedIntent: "Design naming convention for cross-repo skill availability. Evaluate prefix vs flat verbs.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: "Three-tier skill taxonomy: project-only, user-level, reference-card. Uniform /aitool-* prefix for all user skills.",
    aarOutcome: "13 observations, 8 insights, 7 proposals. 21.5 KB JSON.",
    output: ".scratch/session-5HyCwPtSDH/m5-aitool-naming-aar.json",
    deviations: [], spotCheckResults: "Skill count verified (9 user + 9 project)",
    note: null, prompt: "Full naming convention investigation. Read all skill directories. Check build system."
  },
  {
    id: 10, role: "s2", roleLabel: "S2 (Intelligence)", mission: "Trash recovery search for 30 lost files from session Z1IhGrcgGO",
    description: "M6: Trash", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 138, durationLabel: "~2m", tokens: 55000, tokenLabel: "55K", toolUses: 32,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 900,
    pattern: "S2-CHAIN",
    contextInjected: ["30 target filenames from handoff", "Deletion code paths (harvest-session.sh, scratch-init.sh)", "Recovery vectors to try"],
    capturedIntent: "Search macOS Trash, Spotlight, git history for 30 lost files. Identify all possible recovery vectors.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: "NOT RECOVERED from Trash/Spotlight/git. rm -rf bypasses Trash. Two uninvestigated vectors: Time Machine and CC transcripts.",
    aarOutcome: "11 observations, 6 insights, 4 proposals. Conclusion: NOT RECOVERED, 2 vectors remain.",
    output: ".scratch/session-5HyCwPtSDH/m6-trash-recovery-aar.json",
    deviations: [], spotCheckResults: "rm -rf behavior verified. Spotlight search confirmed empty.",
    note: null, prompt: "Trash recovery investigation. Search macOS Trash, Spotlight, git history."
  },
  {
    id: 11, role: "s3", roleLabel: "S3 (Operations)", mission: "Recover 30 lost files from CC session transcripts",
    description: "M7: Recovery", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 450, durationLabel: "~8m", tokens: 120000, tokenLabel: "120K", toolUses: 35,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 1050,
    pattern: "S2-THEN-S3",
    contextInjected: ["M6 findings (recovery vectors)", "CC transcript path", "Target filenames (30)", "Python extraction approach"],
    capturedIntent: "Parse CC session transcript JSONL files. Extract Write tool_use blocks. Reconstruct 30 lost files.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: true, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: "30/30 files recovered (100%). Also recovered 6 bonus substantive files and 19 WRITE_BLOCKED content blocks.",
    aarOutcome: "30/30 target files recovered. 6 bonus files. 36 ephemeral files discarded. 19 WRITE_BLOCKED blocks saved.",
    output: ".scratch/session-5HyCwPtSDH/m7-file-recovery-aar.json",
    deviations: [], spotCheckResults: "recovery_rate: 30/30 verified. Files written to harvesting/.",
    note: "Python script parsed 3592 JSONL lines + 52 subagent transcripts. Extracted 101 Write calls.",
    prompt: "Recover 30 lost files from CC transcript. Parse JSONL. Extract Write tool_use blocks."
  },
  {
    id: 12, role: "s3", roleLabel: "S3 (Operations)", mission: "Session activity dashboard v1 (11 agents)",
    description: "M8: Dashboard", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 300, durationLabel: "~5m", tokens: 90000, tokenLabel: "90K", toolUses: 8,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 1500,
    pattern: "single-agent",
    contextInjected: ["40-agent dashboard exemplar (FULL)", "All AAR files", "Running estimate"],
    capturedIntent: "Produce session activity dashboard HTML with 10 new fields over exemplar design.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: false, criticalRulesInjected: true, aarFormatRequired: false, writeBlockedSignal: true },
    finding: "2165-line HTML dashboard with dark theme, filterable cards, timeline, session-level summary panels.",
    aarOutcome: null,
    output: ".scratch/session-5HyCwPtSDH/session-dashboard.html",
    deviations: [], spotCheckResults: "Renders correctly in Chrome. All 11 agents present.",
    note: "V1 dashboard -- this is being superseded by the v2 dashboard.", prompt: "Produce session dashboard. Match exemplar design. Add 10 new fields."
  },
  {
    id: 13, role: "s2", roleLabel: "S2 (Intelligence)", mission: "Root-cause why S3 launched single-agent-per-mission instead of multi-agent workflows",
    description: "M9: Patterns", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 360, durationLabel: "~6m", tokens: 110000, tokenLabel: "110K", toolUses: 28,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 1800,
    pattern: "single-agent",
    contextInjected: ["40-agent dashboard (FULL)", "Running estimate (FULL)", "All AAR files", "Planning brief decisions #3,#4,#25,#26,#51", "Handoff-prompt-v2.md"],
    capturedIntent: "5-Whys root cause analysis: why did this session repeat the single-agent anti-pattern despite having the 40-agent exemplar?",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: true, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: "Root cause: Mission Command framework governs individual delegations but not composition into workflows. 5 orchestration patterns never codified.",
    aarOutcome: "15 observations, 7 insights, 6 proposals. Full 5-Whys chain. 6 contributing factors identified.",
    output: ".scratch/session-5HyCwPtSDH/m9-delegation-pattern-aar.json",
    deviations: [], spotCheckResults: "5-Whys chain verified against dashboard and running estimate.",
    note: null, prompt: "Root-cause analysis of single-agent pattern. 5-Whys. Read 40-agent dashboard FULL."
  },
  {
    id: 14, role: "s3", roleLabel: "S3 (Operations)", mission: "Reconciliation Phase 1a: Consolidate proposals from 7 AARs",
    description: "Recon: S2a", status: "completed", statusLabel: "Completed", statusClass: "inline",
    duration: 0, durationLabel: "inline", tokens: 0, tokenLabel: "inline", toolUses: 0,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 2200,
    pattern: "single-agent",
    contextInjected: ["All 7 AAR files in context", "Running estimate v4"],
    capturedIntent: "Extract all proposals from AARs, rank by cross-AAR convergence, group by target artifact.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: true, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: "38 proposals consolidated into 10 ranked themes. #1: .gitignore fix (4 AARs converge). 3 conflicts resolved.",
    aarOutcome: "10 convergence themes, 3 conflict analyses, 4-wave execution sequence.",
    output: ".scratch/session-5HyCwPtSDH/s2a-consolidated-proposals.json",
    deviations: [], spotCheckResults: "Convergence counts verified against AARs.",
    note: "Executed inline by S3 (synthesis of data already in context).", prompt: "Inline execution -- no delegation prompt."
  },
  {
    id: 15, role: "s2", roleLabel: "S2 (Intelligence)", mission: "Investigate assumption propagation through multi-agent missions",
    description: "M11: Assumptions", status: "completed", statusLabel: "Completed", statusClass: "completed",
    duration: 420, durationLabel: "~7m", tokens: 130000, tokenLabel: "130K", toolUses: 42,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 2400,
    pattern: "single-agent",
    contextInjected: ["40-agent dashboard (FULL)", "scratch-deletion-rca.md", "verification-lifecycle-gap-audit.md", "Running estimate v4", "All AAR files", "Glossary definition of assumption"],
    capturedIntent: "Investigate how unverified assumptions propagate through multi-agent missions. Design structural prevention.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: true, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: "8 insights on assumption propagation. Chain-of-trust failure: 3 verifiers trusted upstream claims instead of independently verifying. Commander is only reliable catch mechanism but doesn't scale.",
    aarOutcome: "15 observations, 8 insights, 8 proposals. Framework placement analysis: NOT standalone, fits Mission Command + Operational Learning.",
    output: ".scratch/session-5HyCwPtSDH/m11-assumption-propagation-aar.json",
    deviations: [], spotCheckResults: "Agent #29 false claim chain verified against recovered files.",
    note: null, prompt: "Assumption propagation investigation. Read scratch-deletion-rca and verification-lifecycle-gap-audit."
  },
  {
    id: 16, role: "s3", roleLabel: "S3 (Operations)", mission: "Session AAR: operational learning consolidation",
    description: "Session AAR", status: "completed", statusLabel: "Completed", statusClass: "inline",
    duration: 0, durationLabel: "inline", tokens: 0, tokenLabel: "inline", toolUses: 0,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 2850,
    pattern: "single-agent",
    contextInjected: ["All AARs and reconciliation outputs already in context"],
    capturedIntent: "Produce session-level AAR with metrics, observations, insights, and proposal summary.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: true, criticalRulesInjected: true, aarFormatRequired: true, writeBlockedSignal: true },
    finding: "10 missions, 38 proposals in 10 themes, 3 framework proposals, 10 commander corrections, 30 files recovered.",
    aarOutcome: "6 session observations, 3 session insights, 38 proposals consolidated, barrier analysis.",
    output: ".scratch/session-5HyCwPtSDH/session-aar.json",
    deviations: ["Running estimate in scratch violates /scratch skill prohibition"], spotCheckResults: null,
    note: "Executed inline by S3.", prompt: "Inline execution -- no delegation prompt."
  },
  {
    id: 17, role: "s3", roleLabel: "S3 (Operations)", mission: "Running (M12): v2 dashboards for this session + 40-agent session",
    description: "M12: Dashboards", status: "running", statusLabel: "Running", statusClass: "running",
    duration: 0, durationLabel: "running", tokens: 0, tokenLabel: "est.", toolUses: 0,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 2900,
    pattern: "single-agent",
    contextInjected: ["40-agent dashboard exemplar (FULL)", "All AARs", "Session AAR", "Reconciliation outputs", "Running estimate v4", "v1 dashboard"],
    capturedIntent: "Produce comprehensive v2 dashboards covering ALL missions. Open in Chrome DevTools and verify.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: true, criticalRulesInjected: true, aarFormatRequired: false, writeBlockedSignal: true },
    finding: null, aarOutcome: null,
    output: ".scratch/session-5HyCwPtSDH/2026-03-21_session-5HyCwPtSDH-dashboard-v2.html",
    deviations: [], spotCheckResults: null,
    note: "This agent (M13/S3) -- meta! Producing the dashboard that includes itself.", prompt: "Produce v2 dashboards. Read ALL source files IN FULL."
  },
  {
    id: 18, role: "s3", roleLabel: "S3 (Operations)", mission: "Meta: This agent producing the dashboard you are reading",
    description: "M13: Meta", status: "running", statusLabel: "Running", statusClass: "running",
    duration: 0, durationLabel: "running", tokens: 0, tokenLabel: "est.", toolUses: 0,
    worktree: false, isFragord: false, fragordOf: null, startOffset: 2900,
    pattern: "single-agent",
    contextInjected: ["Everything -- full session context"],
    capturedIntent: "S3 identity. Producing the dashboard that documents itself. Hofstadter would approve.",
    delegationDutyFulfilled: { identityEstablished: true, priorResultsIncluded: true, criticalRulesInjected: true, aarFormatRequired: false, writeBlockedSignal: true },
    finding: null, aarOutcome: null, output: "This file.",
    deviations: [], spotCheckResults: null,
    note: "The dashboard is both the deliverable and the observer. Session 5HyCwPtSDH, agent S3 (Operations), mission M13.",
    prompt: "You are looking at it."
  }
];
"""

    # Session summary data
    summary_html = """
<!-- SESSION-LEVEL SUMMARY -->
<div class="session-summary">
  <div class="section-title">Session-Level Summary</div>
  <div class="tab-nav">
    <button class="tab-btn active" data-tab="overview">Overview</button>
    <button class="tab-btn" data-tab="convergence">Convergence Themes</button>
    <button class="tab-btn" data-tab="decisions">Session Decisions</button>
    <button class="tab-btn" data-tab="assumptions">Assumptions</button>
  </div>

  <div class="tab-panel active" id="tab-overview">
    <div class="summary-grid">
      <div class="summary-card">
        <div class="summary-card-title">Session Metrics</div>
        <div class="summary-card-content">
          <strong>13 missions</strong> across <span class="hl">18 agents</span><br>
          <strong>38 proposals</strong> in <span class="hl">10 themes</span><br>
          <strong>30/30</strong> files recovered from Z1IhGrcgGO<br>
          <strong>10</strong> commander corrections<br>
          <strong>8</strong> session decisions captured<br>
          <strong>~1.3M</strong> tokens estimated
        </div>
      </div>
      <div class="summary-card">
        <div class="summary-card-title">Delegation Compliance</div>
        <div class="summary-card-content">
          Early agents (D1-D2): <strong style="color:var(--accent-red)">2/5</strong> duty components<br>
          Mid agents (M1-M5): <strong style="color:var(--accent-yellow)">3-5/5</strong> (improving)<br>
          Late agents (M6+): <strong style="color:var(--accent-green)">5/5</strong> full compliance<br>
          <div class="compliance-bar"><div class="compliance-fill yellow" style="width:72%"></div></div>
          <span style="font-size:0.75rem;color:var(--text-muted)">Overall: 72% delegation duty compliance</span>
        </div>
      </div>
      <div class="summary-card">
        <div class="summary-card-title">Orchestration Patterns Used</div>
        <div class="summary-card-content">
          <span class="pattern-badge">single-agent</span> 12 missions<br>
          <span class="pattern-badge">WRITE_BLOCKED-RELAUNCH</span> 1 (M1)<br>
          <span class="pattern-badge">S2-CHAIN</span> 1 (M6 &rarr; M7)<br>
          <span class="pattern-badge">S2-THEN-S3</span> 1 (M6 &rarr; M7)<br>
          <span style="color:var(--accent-red);font-size:0.8rem">No WRITE-VERIFY-AMEND or PARALLEL-INVESTIGATE used</span>
        </div>
      </div>
    </div>
  </div>

  <div class="tab-panel" id="tab-convergence">
    <div class="convergence-item">
      <div class="convergence-label">Rank 1: Fix .gitignore (CRITICAL)</div>
      <div class="convergence-desc">Replace blanket .aitools/ with selective patterns. Root cause blocker -- unblocks 8+ proposals.</div>
      <div class="convergence-agents">M1-P1, M2-P3, M4-P1, M4-P4 (4 AARs)</div>
    </div>
    <div class="convergence-item">
      <div class="convergence-label">Rank 2: Per-session running estimates</div>
      <div class="convergence-desc">Per-session estimates with reconciliation for concurrent sessions.</div>
      <div class="convergence-agents">M4-P2, M4-P5, M1-I7 (3 AARs)</div>
    </div>
    <div class="convergence-item">
      <div class="convergence-label">Rank 3: Fix .current-session race</div>
      <div class="convergence-desc">SessionEnd hook must use session_id from CC input, not .current-session file.</div>
      <div class="convergence-agents">M4-P3, M1-I5, M2-P2 (3 AARs)</div>
    </div>
    <div class="convergence-item">
      <div class="convergence-label">Rank 4: Harvest before stale-dir deletion</div>
      <div class="convergence-desc">scratch-init.sh stale cleanup destroys without harvesting. Root cause of 30 lost files.</div>
      <div class="convergence-agents">M1-P4, M2-P2, M6-P3 (3 AARs)</div>
    </div>
    <div class="convergence-item">
      <div class="convergence-label">Rank 5: Auto-commit harvested artifacts</div>
      <div class="convergence-desc">harvest-session.sh copies but never commits. Closes Phase 2 failure mode.</div>
      <div class="convergence-agents">M2-P1, M2-P5 (2 AARs)</div>
    </div>
    <div class="convergence-item">
      <div class="convergence-label">Rank 6: Codify orchestration patterns</div>
      <div class="convergence-desc">5 multi-agent patterns from 40-agent session need governance. PATTERN-CHECK as duty #10.</div>
      <div class="convergence-agents">M9-P1 through P6 (6 proposals from RCA)</div>
    </div>
  </div>

  <div class="tab-panel" id="tab-decisions">
    <div class="decision-item"><div class="decision-id">D-GITIGNORE-FIX</div><div class="decision-text">Replace .gitignore blanket .aitools/ with selective patterns (unanimous across M1/M2/M4)</div></div>
    <div class="decision-item"><div class="decision-id">D-MULTI-AGENT-PATTERNS</div><div class="decision-text">Codify 5 orchestration patterns with PATTERN-CHECK as delegation duty component 10</div></div>
    <div class="decision-item"><div class="decision-id">D-PER-SESSION-ESTIMATES</div><div class="decision-text">Per-session running estimates with reconciliation at handoff/session-end</div></div>
    <div class="decision-item"><div class="decision-id">D-CONTEXT-ROT-HOOK</div><div class="decision-text">Stop hook for Lagebeurteilung checkpoint at 20%+ context usage</div></div>
    <div class="decision-item"><div class="decision-id">D-OPERATIONAL-LEARNING</div><div class="decision-text">Every delegation prompt injects operational learning duty block</div></div>
    <div class="decision-item"><div class="decision-id">D-AITOOL-PREFIX</div><div class="decision-text">User-level skills use /aitool-* prefix. Three-tier taxonomy.</div></div>
    <div class="decision-item"><div class="decision-id">D-S1-LAUNCH</div><div class="decision-text">S1 (Administration) via S2->S1 delegation for incident/glossary filing</div></div>
    <div class="decision-item"><div class="decision-id">D-DASHBOARD-GOV</div><div class="decision-text">Dashboard production is S2 duty, governed under Operational Learning</div></div>
  </div>

  <div class="tab-panel" id="tab-assumptions">
    <div class="assumption-item"><span class="assumption-status unverified">unverified</span><span class="assumption-text">De-interpolation placeholder issue is a spec deviation</span></div>
    <div class="assumption-item"><span class="assumption-status unverified">unverified</span><span class="assumption-text">last-summary.txt inconsistency is separate code path issue</span></div>
    <div class="assumption-item"><span class="assumption-status unverified">unverified</span><span class="assumption-text">Stop hook can use transcript size as proxy for context growth</span></div>
    <div class="assumption-item"><span class="assumption-status unverified">unverified</span><span class="assumption-text">Reconciliation mission will use multi-agent patterns successfully</span></div>
    <div class="assumption-item"><span class="assumption-status verified">verified</span><span class="assumption-text">N-level delegation depth of 3 is sufficient for S3->S2->S1</span></div>
  </div>
</div>
"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Session 5HyCwPtSDH v2 Dashboard -- 2026-03-21</title>
<style>{SHARED_CSS}</style>
</head>
<body>

<div class="header">
  <div class="header-top">
    <div>
      <div class="header-title">Session Activity Report v2 <span>&mdash; 13 Missions, 18 Agents</span></div>
      <div class="session-id">5HyCwPtSDH &middot; 2026-03-21</div>
    </div>
    <div class="stats-bar" id="statsBar"></div>
  </div>
</div>

<div class="controls">
  <div class="filter-group" id="roleFilters">
    <button class="filter-btn active" data-role="all">All</button>
    <button class="filter-btn" data-role="s2">S2 Intel</button>
    <button class="filter-btn" data-role="s3">S3 Ops</button>
  </div>
  <div class="filter-group" id="statusFilters">
    <button class="filter-btn active" data-status="all">All Status</button>
    <button class="filter-btn" data-status="completed">Completed</button>
    <button class="filter-btn" data-status="blocked">FRAGORD</button>
    <button class="filter-btn" data-status="running">Running</button>
  </div>
  <div class="filter-group" id="patternFilters">
    <button class="filter-btn active" data-pattern="all">All Patterns</button>
    <button class="filter-btn" data-pattern="single-agent">Single</button>
    <button class="filter-btn" data-pattern="WRITE_BLOCKED-RELAUNCH">FRAGORD</button>
    <button class="filter-btn" data-pattern="S2-CHAIN">S2 Chain</button>
    <button class="filter-btn" data-pattern="S2-THEN-S3">S2->S3</button>
  </div>
  <input type="text" class="search-box" id="searchBox" placeholder="Search missions, findings, context... (/ to focus)" />
  <div class="view-toggle">
    <button class="filter-btn" id="expandAll">Expand All</button>
    <button class="filter-btn" id="collapseAll">Collapse All</button>
  </div>
</div>

{summary_html}

<!-- WORKFLOW CHAINS -->
<div class="chain-section">
  <div class="section-title">Workflow Chains</div>
  <div class="chain-card">
    <div class="chain-title">WRITE_BLOCKED-RELAUNCH: M1 Running Estimate Lifecycle</div>
    <div class="chain-flow">
      <span class="chain-node">#4 M1 Explore</span>
      <span class="chain-arrow">&rarr; FRAGORD &rarr;</span>
      <span class="chain-node">#5 M1-FRAGORD General</span>
    </div>
    <div class="chain-agents">Pattern: Agent launched as Explore (can't write), FRAGORD'd, relaunched with original findings + WRITE_BLOCKED signal</div>
  </div>
  <div class="chain-card">
    <div class="chain-title">S2-CHAIN then S2-THEN-S3: M6 Trash + M7 Recovery</div>
    <div class="chain-flow">
      <span class="chain-node">#10 M6 Trash Search</span>
      <span class="chain-arrow">&rarr; findings feed &rarr;</span>
      <span class="chain-node">#11 M7 Transcript Recovery</span>
    </div>
    <div class="chain-agents">Pattern: S2 identifies recovery vectors, S3 acts on transcript vector. 30/30 recovered.</div>
  </div>
  <div class="chain-card">
    <div class="chain-title">Inline Consolidation: Reconciliation Phases</div>
    <div class="chain-flow">
      <span class="chain-node">7 AARs</span>
      <span class="chain-arrow">&rarr;</span>
      <span class="chain-node">#14 S2a Consolidation</span>
      <span class="chain-arrow">&rarr;</span>
      <span class="chain-node">#16 Session AAR</span>
      <span class="chain-arrow">&rarr;</span>
      <span class="chain-node">#17 v2 Dashboards</span>
    </div>
    <div class="chain-agents">Pattern: S3 executes synthesis inline (data already in context). Subagent delegation would require re-reading all AARs.</div>
  </div>
</div>

<div class="timeline-section">
  <div class="section-title">Launch Timeline &amp; Duration</div>
  <div class="timeline-container"><div class="timeline" id="timeline"></div></div>
  <div class="legend">
    <div class="legend-item"><div class="legend-dot green"></div> Completed</div>
    <div class="legend-item"><div class="legend-dot yellow"></div> FRAGORD'd</div>
    <div class="legend-item"><div class="legend-dot blue"></div> Running</div>
    <div class="legend-item"><div class="legend-dot fragord"></div> FRAGORD (hatched)</div>
    <div class="legend-item"><div class="legend-dot purple"></div> Inline</div>
  </div>
</div>

<div class="agents-container" id="agentsList"></div>
<div class="no-results hidden" id="noResults">No agents match current filters.</div>

<script>
{agents_js}
{SHARED_JS}
</script>
</body>
</html>"""


def generate_session_Z1IhGrcgGO():
    """Generate the v2 dashboard for the 40-agent session Z1IhGrcgGO."""
    html_parts = []
    html_parts.append("""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Session Z1IhGrcgGO v2 Dashboard -- 2026-03-19</title>
<style>""")
    html_parts.append(SHARED_CSS)
    html_parts.append("""</style>
</head>
<body>

<div class="header">
  <div class="header-top">
    <div>
      <div class="header-title">Session Activity Report v2 <span>&mdash; 40 Agents, Multi-Agent Orchestration</span></div>
      <div class="session-id">Z1IhGrcgGO &middot; 2026-03-19</div>
    </div>
    <div class="stats-bar" id="statsBar"></div>
  </div>
</div>

<div class="controls">
  <div class="filter-group" id="roleFilters">
    <button class="filter-btn active" data-role="all">All</button>
    <button class="filter-btn" data-role="s2">S2 Intel</button>
    <button class="filter-btn" data-role="s3">S3 Ops</button>
    <button class="filter-btn" data-role="verifier">Verifier</button>
  </div>
  <div class="filter-group" id="statusFilters">
    <button class="filter-btn active" data-status="all">All Status</button>
    <button class="filter-btn" data-status="completed">Completed</button>
    <button class="filter-btn" data-status="blocked">Blocked</button>
    <button class="filter-btn" data-status="partial">Partial</button>
  </div>
  <div class="filter-group" id="patternFilters">
    <button class="filter-btn active" data-pattern="all">All Patterns</button>
    <button class="filter-btn" data-pattern="single-agent">Single</button>
    <button class="filter-btn" data-pattern="WRITE-VERIFY-AMEND">W-V-A</button>
    <button class="filter-btn" data-pattern="PARALLEL-INVESTIGATE">Parallel</button>
    <button class="filter-btn" data-pattern="S2-CHAIN">S2 Chain</button>
    <button class="filter-btn" data-pattern="WRITE_BLOCKED-RELAUNCH">WB-Relaunch</button>
  </div>
  <input type="text" class="search-box" id="searchBox" placeholder="Search missions, findings, patterns... (/ to focus)" />
  <div class="view-toggle">
    <button class="filter-btn" id="expandAll">Expand All</button>
    <button class="filter-btn" id="collapseAll">Collapse All</button>
  </div>
</div>

<!-- SESSION-LEVEL SUMMARY -->
<div class="session-summary">
  <div class="section-title">Session-Level Summary</div>
  <div class="tab-nav">
    <button class="tab-btn active" data-tab="overview">Overview</button>
    <button class="tab-btn" data-tab="chains">Workflow Chains</button>
    <button class="tab-btn" data-tab="writeblocked">WRITE_BLOCKED</button>
  </div>

  <div class="tab-panel active" id="tab-overview">
    <div class="summary-grid">
      <div class="summary-card">
        <div class="summary-card-title">Session Metrics</div>
        <div class="summary-card-content">
          <span class="hl">40</span> agents across <strong>2h54m</strong> compute<br>
          <span class="hl">~3.4M</span> tokens total<br>
          <strong>28</strong> S2 intelligence, <strong>5</strong> S3 operations, <strong>4</strong> Verifier, <strong>3</strong> blocked<br>
          <strong>5</strong> orchestration patterns demonstrated<br>
          <strong>4</strong> worktree-isolated agents
        </div>
      </div>
      <div class="summary-card">
        <div class="summary-card-title">Orchestration Patterns</div>
        <div class="summary-card-content">
          <span class="pattern-badge">WRITE-VERIFY-AMEND</span> Handoff (#26&rarr;27&rarr;28), Skill (#30&rarr;31&rarr;33&rarr;34)<br>
          <span class="pattern-badge">PARALLEL-INVESTIGATE</span> Barrier A/B/C (#14,15,16)<br>
          <span class="pattern-badge">S2-CHAIN</span> Q4+Q10&rarr;audit (#6,7&rarr;9), RCA&rarr;gap audit (#37&rarr;38)<br>
          <span class="pattern-badge">S2-THEN-S3</span> Bugs&rarr;briefing (#5&rarr;8)<br>
          <span class="pattern-badge">WRITE_BLOCKED-RELAUNCH</span> #21&rarr;#25
        </div>
      </div>
      <div class="summary-card">
        <div class="summary-card-title">WRITE_BLOCKED Impact</div>
        <div class="summary-card-content">
          <strong>19</strong> WRITE_BLOCKED events across <strong>7</strong> agents<br>
          <strong>3</strong> agents fully blocked (#20, #21, #24)<br>
          All blocked content later recovered from CC transcripts (M7, session 5HyCwPtSDH)<br>
          Root cause: background subagent Write permission model
        </div>
      </div>
    </div>
  </div>

  <div class="tab-panel" id="tab-chains">
    <div class="chain-card">
      <div class="chain-title">Handoff Write-Verify-Amend</div>
      <div class="chain-flow">
        <span class="chain-node">#26 S3 Write</span><span class="chain-arrow">&rarr;</span>
        <span class="chain-node">#27 Verifier (worktree)</span><span class="chain-arrow">&rarr; 7 amendments &rarr;</span>
        <span class="chain-node">#28 S3 Amend</span>
      </div>
    </div>
    <div class="chain-card">
      <div class="chain-title">/handoff Skill Write-Verify-Amend</div>
      <div class="chain-flow">
        <span class="chain-node">#30 S3 Build</span><span class="chain-arrow">&rarr;</span>
        <span class="chain-node">#31 Verifier (worktree)</span><span class="chain-arrow">&rarr;</span>
        <span class="chain-node">#33 S3 Update</span><span class="chain-arrow">&rarr;</span>
        <span class="chain-node">#34 Verifier (worktree)</span>
      </div>
    </div>
    <div class="chain-card">
      <div class="chain-title">Parallel Barrier Analysis</div>
      <div class="chain-flow">
        <span class="chain-node">#14 Barrier A</span>
        <span class="chain-node">#15 Barrier B</span>
        <span class="chain-node">#16 Barrier C</span>
      </div>
      <div class="chain-agents">3 concurrent S2 agents with different formulations of the same carry-forward question</div>
    </div>
    <div class="chain-card">
      <div class="chain-title">S2 Investigation Chains</div>
      <div class="chain-flow">
        <span class="chain-node">#6 Q4</span><span class="chain-node">#7 Q10</span>
        <span class="chain-arrow">&rarr;</span><span class="chain-node">#9 Cross-audit</span>
      </div>
      <div class="chain-flow" style="margin-top:4px">
        <span class="chain-node">#37 Scratch RCA</span><span class="chain-arrow">&rarr;</span>
        <span class="chain-node">#38 Verification gap audit</span>
      </div>
    </div>
    <div class="chain-card">
      <div class="chain-title">WRITE_BLOCKED Relaunch</div>
      <div class="chain-flow">
        <span class="chain-node" style="border-color:var(--accent-yellow)">#21 Cluster (blocked)</span>
        <span class="chain-arrow">&rarr; RELAUNCH &rarr;</span>
        <span class="chain-node">#25 Cluster (success)</span>
      </div>
    </div>
  </div>

  <div class="tab-panel" id="tab-writeblocked">
    <div class="summary-card-content">
      <div class="convergence-item"><div class="convergence-label">#20 Scope-creep governance</div><div class="convergence-desc">Analysis completed in-memory. File write denied. Content recovered session 5HyCwPtSDH.</div></div>
      <div class="convergence-item"><div class="convergence-label">#21 Briefing cluster analysis (first attempt)</div><div class="convergence-desc">11 minutes spent. Relaunched as #25 with WRITE_BLOCKED signal.</div></div>
      <div class="convergence-item"><div class="convergence-label">#24 Write failure RCA</div><div class="convergence-desc">Meta-failure: agent investigating write blocks was itself blocked.</div></div>
    </div>
  </div>
</div>

<div class="timeline-section">
  <div class="section-title">Launch Timeline &amp; Duration</div>
  <div class="timeline-container"><div class="timeline" id="timeline"></div></div>
  <div class="legend">
    <div class="legend-item"><div class="legend-dot green"></div> Completed</div>
    <div class="legend-item"><div class="legend-dot yellow"></div> WRITE_BLOCKED</div>
    <div class="legend-item"><div class="legend-dot orange"></div> Partial</div>
    <div class="legend-item"><div class="legend-dot purple"></div> Inline</div>
  </div>
</div>

<div class="agents-container" id="agentsList"></div>
<div class="no-results hidden" id="noResults">No agents match current filters.</div>

<script>
const agents = [
  {id:1,role:"verifier",roleLabel:"Verifier",mission:"Test hook with mock JSON pipe per tool-ops verification spec",description:"Hook test",status:"completed",statusLabel:"Inline",statusClass:"inline",duration:0,durationLabel:"inline",tokens:0,tokenLabel:"n/a",toolUses:0,worktree:false,isFragord:false,fragordOf:null,startOffset:0,pattern:"single-agent",contextInjected:["tool-ops verification spec"],capturedIntent:"Verify mock JSON pipe behavior against tool-ops spec.",delegationDutyFulfilled:{identityEstablished:true},finding:"Hook testing executed inline. Verified mock JSON pipe behavior.",aarOutcome:null,output:null,deviations:[],spotCheckResults:null,note:null,prompt:"Inline execution by main agent."},
  {id:2,role:"s2",roleLabel:"S2 (Explore)",mission:"Inventory every source and deploy script in this repo",description:"Deploy inventory",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:69,durationLabel:"~69s",tokens:62000,tokenLabel:"62K",toolUses:26,worktree:false,isFragord:false,fragordOf:null,startOffset:5,pattern:"single-agent",contextInjected:["deploy/ directory","scripts/ directory"],capturedIntent:"Map the full deployment surface area.",delegationDutyFulfilled:{identityEstablished:true},finding:"Comprehensive inventory of all deploy scripts, managed files, and config targets.",aarOutcome:null,output:null,deviations:[],spotCheckResults:null,note:null,prompt:"Inventory every source and deploy script."},
  {id:3,role:"s2",roleLabel:"S2 (Explore)",mission:"Read all 17 skill SKILL.md files, extract intent statements",description:"Skill intents",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:53,durationLabel:"~53s",tokens:81000,tokenLabel:"81K",toolUses:17,worktree:false,isFragord:false,fragordOf:null,startOffset:80,pattern:"single-agent",contextInjected:[".claude/skills/*/SKILL.md","shared/skills/*/SKILL.md"],capturedIntent:"Extract and catalogue intent statements from all 17 skills.",delegationDutyFulfilled:{identityEstablished:true},finding:"Extracted intents from all 17 skills. Identified gaps in intent coverage.",aarOutcome:null,output:null,deviations:[],spotCheckResults:null,note:null,prompt:"Read every SKILL.md. Extract intent blocks."},
  {id:4,role:"s2",roleLabel:"S2 (General)",mission:"Search session transcripts for user intent approval/rejection signals",description:"Intent signals",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:357,durationLabel:"~357s",tokens:133000,tokenLabel:"133K",toolUses:19,worktree:false,isFragord:false,fragordOf:null,startOffset:140,pattern:"single-agent",contextInjected:["Session transcripts (Mar 16)"],capturedIntent:"Find user intent approval/rejection signals in transcripts.",delegationDutyFulfilled:{identityEstablished:true},finding:"Mapped how intent statements evolved through user feedback cycles.",aarOutcome:null,output:null,deviations:[],spotCheckResults:null,note:null,prompt:"Search Mar 16 transcripts for intent approval/rejection."},
  {id:5,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Investigate 3 pre-existing bugs in check-post-push.sh",description:"Post-push AAR",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:847,durationLabel:"~14m",tokens:110000,tokenLabel:"110K",toolUses:90,worktree:false,isFragord:false,fragordOf:null,startOffset:500,pattern:"S2-THEN-S3",contextInjected:["scripts/check-post-push.sh","scripts/check-post-push.ps1"],capturedIntent:"Root-cause 3 bugs in check-post-push.sh. Produce full AAR.",delegationDutyFulfilled:{identityEstablished:true},finding:"Root-caused 3 bugs. Produced detailed AAR with fixes and prevention.",aarOutcome:"3 bugs root-caused with fix recommendations.",output:".scratch/session-Z1IhGrcgGO/s2-post-push-aar.md",deviations:[],spotCheckResults:null,note:null,prompt:"Investigate 3 bugs. Produce AAR."},
  {id:6,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Investigate lifecycle of operational artifacts (briefings, AARs, plans)",description:"Q4 lifecycle",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:202,durationLabel:"~202s",tokens:60000,tokenLabel:"60K",toolUses:37,worktree:false,isFragord:false,fragordOf:null,startOffset:500,pattern:"S2-CHAIN",contextInjected:["plans/","reference/",".claude/rules/"],capturedIntent:"Map lifecycle of briefings, AARs, plans through creation to pruning.",delegationDutyFulfilled:{identityEstablished:true},finding:"Mapped full artifact lifecycle. Identified gaps in briefing lifecycle.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/q4-lifecycle-investigation.md",deviations:[],spotCheckResults:null,note:null,prompt:"Investigate Q4: artifact lifecycle."},
  {id:7,role:"s2",roleLabel:"S2 (Intelligence)",mission:"How artifact roles feed into intent enforcement hooks",description:"Q10 roles",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:224,durationLabel:"~224s",tokens:70000,tokenLabel:"70K",toolUses:22,worktree:false,isFragord:false,fragordOf:null,startOffset:500,pattern:"S2-CHAIN",contextInjected:["plans/governance-and-compliance-framework.md","reference/harness.md"],capturedIntent:"Trace artifact classification to hook behavior chain.",delegationDutyFulfilled:{identityEstablished:true},finding:"Found tension between harness.md and planning brief on /artifact-roles skill.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/q10-artifact-roles-investigation.md",deviations:[],spotCheckResults:null,note:null,prompt:"Investigate Q10: artifact roles and hooks."},
  {id:8,role:"s3",roleLabel:"S3 (Operations)",mission:"Update post-push-fix-briefing.md with AAR findings",description:"Briefing update",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:80,durationLabel:"~80s",tokens:41000,tokenLabel:"41K",toolUses:3,worktree:true,isFragord:false,fragordOf:null,startOffset:1400,pattern:"S2-THEN-S3",contextInjected:["s2-post-push-aar.md"],capturedIntent:"Update briefing with AAR findings from bug investigation.",delegationDutyFulfilled:{identityEstablished:true},finding:"Successfully updated briefing with AAR findings.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/post-push-fix-briefing.md",deviations:[],spotCheckResults:null,note:"Worktree-isolated.",prompt:"Update briefing with AAR. Worktree."},
  {id:9,role:"s2",roleLabel:"S2 (Intelligence)",mission:"5-pass ambiguity/consistency audit of Q4 and Q10",description:"Q4-Q10 audit",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:218,durationLabel:"~218s",tokens:122000,tokenLabel:"122K",toolUses:18,worktree:false,isFragord:false,fragordOf:null,startOffset:750,pattern:"S2-CHAIN",contextInjected:["q4-lifecycle-investigation.md","q10-artifact-roles-investigation.md"],capturedIntent:"5-pass audit: terms, scope, contradictions, gaps, integration.",delegationDutyFulfilled:{identityEstablished:true},finding:"Found ambiguities in terminology, inconsistencies between Q4/Q10, misalignment with brief.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/q4-q10-ambiguity-audit.md",deviations:[],spotCheckResults:null,note:null,prompt:"5-pass audit comparing Q4 and Q10 against brief."},
  {id:10,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Audit briefings-at-.aitools/ decision",description:"Briefings location",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:208,durationLabel:"~208s",tokens:68000,tokenLabel:"68K",toolUses:22,worktree:false,isFragord:false,fragordOf:null,startOffset:1000,pattern:"single-agent",contextInjected:["aitools-workspace.md","plans/"],capturedIntent:"Audit .aitools/ briefing location against workspace rule.",delegationDutyFulfilled:{identityEstablished:true},finding:"Alignment with workspace rule but tension with plans/ convention.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/briefings-location-decision.md",deviations:[],spotCheckResults:null,note:null,prompt:"Audit briefings location decision."},
  {id:11,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Draft governed vocabulary definition for 'promotion'",description:"Promotion def",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:184,durationLabel:"~184s",tokens:79000,tokenLabel:"79K",toolUses:37,worktree:false,isFragord:false,fragordOf:null,startOffset:1200,pattern:"single-agent",contextInjected:["glossary.json",".claude/rules/glossary.md"],capturedIntent:"Draft governed definition for promotion (artifact to harness).",delegationDutyFulfilled:{identityEstablished:true},finding:"Drafted promotion definition aligned with glossary conventions.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/promotion-definition-draft.md",deviations:[],spotCheckResults:null,note:null,prompt:"Draft promotion definition via /glossary."},
  {id:12,role:"verifier",roleLabel:"Verifier",mission:"Audit promotion definition against glossary exemplars",description:"Promotion audit",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:166,durationLabel:"~166s",tokens:67000,tokenLabel:"67K",toolUses:14,worktree:false,isFragord:false,fragordOf:null,startOffset:1400,pattern:"WRITE-VERIFY-AMEND",contextInjected:["promotion-definition-draft.md","glossary.json"],capturedIntent:"Verify promotion definition: quality, barrier test, consistency.",delegationDutyFulfilled:{identityEstablished:true},finding:"Passed barrier tests. Minor scope precision improvements suggested.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/promotion-definition-audit.md",deviations:[],spotCheckResults:null,note:null,prompt:"Audit promotion definition against exemplars."},
  {id:13,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Draft governed definitions for repo and project",description:"Repo/project def",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:223,durationLabel:"~223s",tokens:71000,tokenLabel:"71K",toolUses:25,worktree:false,isFragord:false,fragordOf:null,startOffset:1600,pattern:"single-agent",contextInjected:["glossary.json","CLAUDE.md"],capturedIntent:"Distinguish repo (container) from project (work context).",delegationDutyFulfilled:{identityEstablished:true},finding:"Drafted definitions distinguishing repo from project.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/repo-project-definition-draft.md",deviations:[],spotCheckResults:null,note:null,prompt:"Draft repo and project definitions."},
  {id:14,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Barrier analysis: 'persisted in a way that survives machine switches'",description:"Barrier A",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:134,durationLabel:"~134s",tokens:54000,tokenLabel:"54K",toolUses:11,worktree:false,isFragord:false,fragordOf:null,startOffset:1800,pattern:"PARALLEL-INVESTIGATE",contextInjected:["aitools-workspace.md"],capturedIntent:"Barrier analysis of carry-forward formulation A.",delegationDutyFulfilled:{identityEstablished:true},finding:"Phrase could require specific persistence mechanisms. Proposed tighter formulation.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/carry-forward-barrier-A.md",deviations:[],spotCheckResults:null,note:null,prompt:"Barrier analysis on formulation A."},
  {id:15,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Barrier analysis: 'persisted in the repo's backing storage'",description:"Barrier B",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:164,durationLabel:"~164s",tokens:53000,tokenLabel:"53K",toolUses:15,worktree:false,isFragord:false,fragordOf:null,startOffset:1800,pattern:"PARALLEL-INVESTIGATE",contextInjected:["aitools-workspace.md","Formulation A results"],capturedIntent:"Barrier analysis of formulation B. Compare against A.",delegationDutyFulfilled:{identityEstablished:true},finding:"Tightly couples to git. Analyzed tradeoffs vs formulation A.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/carry-forward-barrier-B.md",deviations:[],spotCheckResults:null,note:null,prompt:"Barrier analysis on formulation B. Compare against A."},
  {id:16,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Barrier analysis: explicit per-mechanism enumeration",description:"Barrier C",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:105,durationLabel:"~105s",tokens:48000,tokenLabel:"48K",toolUses:7,worktree:false,isFragord:false,fragordOf:null,startOffset:1800,pattern:"PARALLEL-INVESTIGATE",contextInjected:["aitools-workspace.md","Formulations A and B results"],capturedIntent:"Barrier analysis of explicit enumeration. Compare all three.",delegationDutyFulfilled:{identityEstablished:true},finding:"Enumeration is brittle but unambiguous. Compared on ambiguity-flexibility spectrum.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/carry-forward-barrier-C.md",deviations:[],spotCheckResults:null,note:null,prompt:"Barrier analysis on formulation C. Compare against A and B."},
  {id:17,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Investigate harness.md vs Q10 contradiction on /artifact-roles",description:"Artifact tension",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:107,durationLabel:"~107s",tokens:47000,tokenLabel:"47K",toolUses:5,worktree:false,isFragord:false,fragordOf:null,startOffset:2000,pattern:"single-agent",contextInjected:["harness.md","q10-artifact-roles-investigation.md"],capturedIntent:"Resolve tension between harness.md and Q10 on /artifact-roles skill.",delegationDutyFulfilled:{identityEstablished:true},finding:"Skill referenced but doesn't exist yet -- governance gap.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/artifact-roles-tension-investigation.md",deviations:[],spotCheckResults:null,note:null,prompt:"Investigate artifact-roles skill contradiction."},
  {id:18,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Trace carry-forward concept through planning brief",description:"CF provenance",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:343,durationLabel:"~343s",tokens:132000,tokenLabel:"132K",toolUses:57,worktree:false,isFragord:false,fragordOf:null,startOffset:2100,pattern:"single-agent",contextInjected:["plans/","session transcripts","aitools-workspace.md"],capturedIntent:"Trace provenance of carry-forward concept through all artifacts.",delegationDutyFulfilled:{identityEstablished:true},finding:"Emerged organically from cross-machine workflow, not from single decision.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/carry-forward-provenance.md",deviations:[],spotCheckResults:null,note:null,prompt:"Trace carry-forward provenance."},
  {id:19,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Which frameworks inform carry-forward",description:"CF frameworks",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:264,durationLabel:"~264s",tokens:108000,tokenLabel:"108K",toolUses:34,worktree:false,isFragord:false,fragordOf:null,startOffset:2100,pattern:"single-agent",contextInjected:["framework-registry.json","reference/framework-*.md"],capturedIntent:"Identify source discipline for carry-forward.",delegationDutyFulfilled:{identityEstablished:true},finding:"Harness-native synthesis, no single external discipline.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/carry-forward-frameworks.md",deviations:[],spotCheckResults:null,note:null,prompt:"Analyze carry-forward framework sources."},
  {id:20,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Design scope-creep governance",description:"Scope-creep",status:"blocked",statusLabel:"WRITE_BLOCKED",statusClass:"blocked",duration:289,durationLabel:"~289s",tokens:144000,tokenLabel:"144K",toolUses:24,worktree:false,isFragord:false,fragordOf:null,startOffset:2400,pattern:"WRITE_BLOCKED-RELAUNCH",contextInjected:["plans/","ROADMAP.md",".claude/rules/"],capturedIntent:"Design scope-creep governance: boundaries, immediate-action framework.",delegationDutyFulfilled:{identityEstablished:true},finding:"Analysis completed but file write denied.",aarOutcome:null,output:null,deviations:["WRITE_BLOCKED"],spotCheckResults:null,note:"WRITE_BLOCKED. Content recovered from CC transcript in session 5HyCwPtSDH.",prompt:"Design scope-creep governance."},
  {id:21,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Graph analysis of 54-decision dependency structure",description:"Cluster (blocked)",status:"blocked",statusLabel:"WRITE_BLOCKED",statusClass:"blocked",duration:658,durationLabel:"~11m",tokens:129000,tokenLabel:"129K",toolUses:14,worktree:false,isFragord:true,fragordOf:null,fragordRelaunchedAs:25,startOffset:2700,pattern:"WRITE_BLOCKED-RELAUNCH",contextInjected:["planning-brief.md"],capturedIntent:"Build dependency graph of all 54 decisions.",delegationDutyFulfilled:{identityEstablished:true},finding:"Built graph but could not write results. Relaunched as #25.",aarOutcome:null,output:null,deviations:["WRITE_BLOCKED"],spotCheckResults:null,note:"WRITE_BLOCKED. Relaunched as #25 with signal.",prompt:"Graph analysis of 54 decisions."},
  {id:22,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Comprehensive status of all scratch artifacts",description:"State audit",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:484,durationLabel:"~8m",tokens:148000,tokenLabel:"148K",toolUses:27,worktree:false,isFragord:false,fragordOf:null,startOffset:3400,pattern:"single-agent",contextInjected:[".scratch/session-Z1IhGrcgGO/"],capturedIntent:"Catalogue every scratch file: status, dependencies, readiness.",delegationDutyFulfilled:{identityEstablished:true},finding:"Comprehensive audit. Identified orphaned artifacts and blocked outputs.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/session-state-audit.md",deviations:[],spotCheckResults:null,note:null,prompt:"Session state audit of all scratch files."},
  {id:23,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Research Auftragstaktik, IDF, NATO, Toyota, Cynefin, OODA",description:"Deep provenance",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:466,durationLabel:"~8m",tokens:90000,tokenLabel:"90K",toolUses:40,worktree:false,isFragord:false,fragordOf:null,startOffset:3400,pattern:"single-agent",contextInjected:["reference/framework-*.md"],capturedIntent:"Trace harness concepts to original doctrine sources.",delegationDutyFulfilled:{identityEstablished:true},finding:"Mapped which concepts actually inform the harness vs merely name-dropped.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/provenance-deep-research.md",deviations:[],spotCheckResults:null,note:null,prompt:"Deep provenance research on doctrine sources."},
  {id:24,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Investigate why subagents couldn't write files",description:"Write RCA",status:"blocked",statusLabel:"WRITE_BLOCKED",statusClass:"blocked",duration:151,durationLabel:"~151s",tokens:87000,tokenLabel:"87K",toolUses:25,worktree:false,isFragord:false,fragordOf:null,startOffset:3900,pattern:"WRITE_BLOCKED-RELAUNCH",contextInjected:[".claude/settings.json",".claude/settings.local.json"],capturedIntent:"RCA the WRITE_BLOCKED failures.",delegationDutyFulfilled:{identityEstablished:true},finding:"Meta-failure: agent investigating write blocks was itself blocked.",aarOutcome:null,output:null,deviations:["WRITE_BLOCKED (meta-failure)"],spotCheckResults:null,note:"WRITE_BLOCKED. Content recovered from CC transcript.",prompt:"RCA write failures. Check permissions."},
  {id:25,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Graph analysis of 54-decision dependency structure (relaunch)",description:"Cluster (success)",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:248,durationLabel:"~248s",tokens:111000,tokenLabel:"111K",toolUses:10,worktree:false,isFragord:false,fragordOf:21,startOffset:4100,pattern:"WRITE_BLOCKED-RELAUNCH",contextInjected:["planning-brief.md","WRITE_BLOCKED signal"],capturedIntent:"Relaunch of #21 with WRITE_BLOCKED signal.",delegationDutyFulfilled:{identityEstablished:true,writeBlockedSignal:true},finding:"Successfully completed 54-decision dependency graph. Identified clusters and critical path.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/briefing-cluster-analysis.md",deviations:[],spotCheckResults:null,note:"Relaunch of #21 with WRITE_BLOCKED signal.",prompt:"WRITE_BLOCKED signal. Graph analysis of 54 decisions."},
  {id:26,role:"s3",roleLabel:"S3 (Operations)",mission:"Write the complete handoff prompt from all session artifacts",description:"Handoff write",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:434,durationLabel:"~7m",tokens:127000,tokenLabel:"127K",toolUses:25,worktree:false,isFragord:false,fragordOf:null,startOffset:4400,pattern:"WRITE-VERIFY-AMEND",contextInjected:[".scratch/session-Z1IhGrcgGO/*.md","/handoff skill"],capturedIntent:"Synthesize ALL artifacts into handoff prompt.",delegationDutyFulfilled:{identityEstablished:true},finding:"Synthesized complete handoff covering decisions, artifacts, open questions.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/handoff-prompt-draft.md",deviations:[],spotCheckResults:null,note:"First in write-verify-amend chain (#26->27->28).",prompt:"Write complete handoff. Read every .md in scratch."},
  {id:27,role:"verifier",roleLabel:"Verifier",mission:"9-criteria verification of handoff prompt",description:"Handoff verify",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:219,durationLabel:"~219s",tokens:86000,tokenLabel:"86K",toolUses:22,worktree:true,isFragord:false,fragordOf:null,startOffset:4850,pattern:"WRITE-VERIFY-AMEND",contextInjected:["handoff-prompt-draft.md","/handoff skill criteria"],capturedIntent:"Verify handoff against 9 criteria in isolated worktree.",delegationDutyFulfilled:{identityEstablished:true},finding:"Found 7 amendments needed. Missing cluster analysis reference, incomplete inventory.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/handoff-verification.md",deviations:[],spotCheckResults:null,note:"Worktree-isolated. 9 criteria check.",prompt:"Verify handoff. 9 criteria. Worktree."},
  {id:28,role:"s3",roleLabel:"S3 (Operations)",mission:"Apply 7 amendments to handoff prompt based on verification",description:"Handoff amend",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:195,durationLabel:"~195s",tokens:89000,tokenLabel:"89K",toolUses:12,worktree:false,isFragord:false,fragordOf:null,startOffset:5100,pattern:"WRITE-VERIFY-AMEND",contextInjected:["handoff-verification.md","handoff-prompt-draft.md"],capturedIntent:"Apply all 7 amendments from verifier.",delegationDutyFulfilled:{identityEstablished:true},finding:"Applied 7 amendments. Handoff improved with cluster analysis, complete inventory.",aarOutcome:null,output:"Amended handoff-prompt-draft.md",deviations:[],spotCheckResults:null,note:"Third in write-verify-amend chain.",prompt:"Apply 7 amendments from verification."},
  {id:29,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Verify handoff Schwerpunkt against identified Reibung",description:"Schwerpunkt assessment",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:257,durationLabel:"~257s",tokens:97000,tokenLabel:"97K",toolUses:31,worktree:false,isFragord:false,fragordOf:null,startOffset:5300,pattern:"single-agent",contextInjected:["handoff-prompt-draft.md","identified Reibung"],capturedIntent:"Verify Schwerpunkt aims at biggest friction.",delegationDutyFulfilled:{identityEstablished:true},finding:"Schwerpunkt assessment with friction analysis. NOTE: Contains false claim about scratch persistence that propagated through 5 artifacts.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/schwerpunkt-assessment.md",deviations:["False claim: stated scratch dirs persist across sessions (they are rm -rf'd)"],spotCheckResults:"False claim caught by commander, led to agents #37-38 RCA chain.",note:"SOURCE OF FALSE CLAIM: 'scratch directories are NOT automatically cleaned up' -- factually wrong per harvest-session.sh line 165.",prompt:"Verify Schwerpunkt against Reibung."},
  {id:30,role:"s3",roleLabel:"S3 (Operations)",mission:"Build /handoff skill from planning brief and session artifacts",description:"Skill build",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:359,durationLabel:"~6m",tokens:143000,tokenLabel:"143K",toolUses:21,worktree:false,isFragord:false,fragordOf:null,startOffset:5600,pattern:"WRITE-VERIFY-AMEND",contextInjected:["Planning brief","All scratch artifacts","/handoff pattern"],capturedIntent:"Build the /handoff skill SKILL.md.",delegationDutyFulfilled:{identityEstablished:true},finding:"Built /handoff skill with 9-step process, verification criteria, lifecycle awareness.",aarOutcome:null,output:"shared/skills/handoff/SKILL.md",deviations:[],spotCheckResults:null,note:"First in second write-verify-amend chain.",prompt:"Build /handoff skill from all artifacts."},
  {id:31,role:"verifier",roleLabel:"Verifier",mission:"Re-verify handoff with CI/CD cross-check",description:"Skill verify 1",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:214,durationLabel:"~214s",tokens:72000,tokenLabel:"72K",toolUses:18,worktree:true,isFragord:false,fragordOf:null,startOffset:5970,pattern:"WRITE-VERIFY-AMEND",contextInjected:["handoff SKILL.md","planning brief"],capturedIntent:"Re-verify handoff skill with CI/CD cross-check.",delegationDutyFulfilled:{identityEstablished:true},finding:"Verification found areas needing CI/CD alignment.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/handoff-final-verification.md",deviations:[],spotCheckResults:null,note:"Worktree-isolated.",prompt:"Re-verify handoff skill. Worktree."},
  {id:32,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Investigate harness CI/CD feasibility",description:"CI/CD feasibility",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:377,durationLabel:"~6m",tokens:96000,tokenLabel:"96K",toolUses:34,worktree:false,isFragord:false,fragordOf:null,startOffset:6200,pattern:"single-agent",contextInjected:["All reference files","Planning brief"],capturedIntent:"Assess CI/CD feasibility for the harness.",delegationDutyFulfilled:{identityEstablished:true},finding:"CI/CD feasible but requires staged approach. Mapped build/test/deploy pipeline.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/harness-cicd-investigation.md",deviations:[],spotCheckResults:null,note:null,prompt:"Investigate harness CI/CD feasibility."},
  {id:33,role:"s3",roleLabel:"S3 (Operations)",mission:"Update /handoff skill based on verification findings",description:"Skill update",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:156,durationLabel:"~156s",tokens:68000,tokenLabel:"68K",toolUses:8,worktree:false,isFragord:false,fragordOf:null,startOffset:6600,pattern:"WRITE-VERIFY-AMEND",contextInjected:["Verification findings","handoff SKILL.md"],capturedIntent:"Apply verification findings to handoff skill.",delegationDutyFulfilled:{identityEstablished:true},finding:"Updated skill with verification feedback.",aarOutcome:null,output:"shared/skills/handoff/SKILL.md (updated)",deviations:[],spotCheckResults:null,note:null,prompt:"Update handoff skill from verification."},
  {id:34,role:"verifier",roleLabel:"Verifier",mission:"Final 5-part verification of /handoff skill",description:"Skill verify 2",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:253,durationLabel:"~253s",tokens:85000,tokenLabel:"85K",toolUses:19,worktree:true,isFragord:false,fragordOf:null,startOffset:6800,pattern:"WRITE-VERIFY-AMEND",contextInjected:["Updated handoff SKILL.md","All prior verifications"],capturedIntent:"Final 5-part verification of /handoff skill.",delegationDutyFulfilled:{identityEstablished:true},finding:"Final verification passed. Skill ready for deployment.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/handoff-final-verification-v2.md",deviations:["Did not challenge false claim from #29 (inherited trust)"],spotCheckResults:null,note:"Worktree-isolated. Final gate.",prompt:"Final 5-part verification. Worktree."},
  {id:35,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Investigate aitools-in-tool-ops for self-reference",description:"Self-ref audit",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:124,durationLabel:"~124s",tokens:52000,tokenLabel:"52K",toolUses:14,worktree:false,isFragord:false,fragordOf:null,startOffset:7100,pattern:"single-agent",contextInjected:["reference/tool-ops.json",".claude/rules/tool-ops.md"],capturedIntent:"Audit aitools self-reference in tool-ops registry.",delegationDutyFulfilled:{identityEstablished:true},finding:"Documented self-reference patterns and their implications.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/aitools-in-tool-ops-investigation.md",deviations:[],spotCheckResults:null,note:null,prompt:"Investigate aitools self-reference in tool-ops."},
  {id:36,role:"s2",roleLabel:"S2 (Intelligence)",mission:"CI/CD implementation feasibility assessment",description:"CI/CD assessment",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:198,durationLabel:"~198s",tokens:63000,tokenLabel:"63K",toolUses:17,worktree:false,isFragord:false,fragordOf:null,startOffset:7100,pattern:"single-agent",contextInjected:["harness-cicd-investigation.md"],capturedIntent:"Detailed feasibility for CI/CD implementation.",delegationDutyFulfilled:{identityEstablished:true},finding:"Implementation assessment with phased rollout plan.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/cicd-feasibility.md",deviations:[],spotCheckResults:null,note:null,prompt:"CI/CD feasibility deep-dive."},
  {id:37,role:"s2",roleLabel:"S2 (Intelligence)",mission:"RCA: why did 3 verifications miss the false claim about scratch persistence",description:"Scratch RCA",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:415,durationLabel:"~7m",tokens:114000,tokenLabel:"114K",toolUses:48,worktree:false,isFragord:false,fragordOf:null,startOffset:7400,pattern:"S2-CHAIN",contextInjected:["schwerpunkt-assessment.md","handoff-verification.md","handoff-final-verification.md","harvest-session.sh"],capturedIntent:"Root-cause why 3 verifications passed a factually wrong claim.",delegationDutyFulfilled:{identityEstablished:true},finding:"Verifiers checked document quality not system facts. Verification model checks present state not post-lifecycle state.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/scratch-deletion-rca.md",deviations:[],spotCheckResults:null,note:"Triggered by commander catching false claim. First in RCA chain.",prompt:"RCA: why did verifiers miss the false scratch persistence claim?"},
  {id:38,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Full verification lifecycle gap audit using RCA findings",description:"Gap audit",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:387,durationLabel:"~6m",tokens:131000,tokenLabel:"131K",toolUses:33,worktree:false,isFragord:false,fragordOf:null,startOffset:7850,pattern:"S2-CHAIN",contextInjected:["scratch-deletion-rca.md","All verification artifacts"],capturedIntent:"Full audit of verification lifecycle using RCA findings as input.",delegationDutyFulfilled:{identityEstablished:true},finding:"10 missed catch points documented. Consistent pattern: each agent checked own domain, none crossed boundary to verify against implementation.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/verification-lifecycle-gap-audit.md",deviations:[],spotCheckResults:null,note:"Second in RCA chain. Used #37 output as input.",prompt:"Full verification lifecycle gap audit from RCA findings."},
  {id:39,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Session transition testing and hook behavior verification",description:"Transition test",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:229,durationLabel:"~229s",tokens:68000,tokenLabel:"68K",toolUses:19,worktree:false,isFragord:false,fragordOf:null,startOffset:8300,pattern:"single-agent",contextInjected:["harvest-session.sh","scratch-init.sh"],capturedIntent:"Test session transition behavior: what happens to files between sessions.",delegationDutyFulfilled:{identityEstablished:true},finding:"Documented exact behavior of session transitions including edge cases.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/session-transition-testing.md",deviations:[],spotCheckResults:null,note:null,prompt:"Test session transition and hook behavior."},
  {id:40,role:"s2",roleLabel:"S2 (Intelligence)",mission:"Findings index: consolidate all session investigation outputs",description:"Findings index",status:"completed",statusLabel:"Completed",statusClass:"completed",duration:167,durationLabel:"~167s",tokens:51000,tokenLabel:"51K",toolUses:8,worktree:false,isFragord:false,fragordOf:null,startOffset:8550,pattern:"single-agent",contextInjected:["All scratch artifacts"],capturedIntent:"Create master index of all investigation findings.",delegationDutyFulfilled:{identityEstablished:true},finding:"Consolidated index of all session outputs with cross-references.",aarOutcome:null,output:".scratch/session-Z1IhGrcgGO/findings-index.md",deviations:[],spotCheckResults:null,note:"Final agent of the session.",prompt:"Create findings index from all artifacts."}
];
""")
    html_parts.append(SHARED_JS)
    html_parts.append("""
</script>
</body>
</html>""")

    return "".join(html_parts)


# ═══════════════════════════════════════════════════════════════
# GENERATE
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import os

    out1 = "/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/2026-03-21_session-5HyCwPtSDH-dashboard-v2.html"
    out2 = "/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/2026-03-19_session-Z1IhGrcgGO-dashboard-v2.html"

    html1 = generate_session_5HyCwPtSDH()
    with open(out1, "w", encoding="utf-8") as f:
        f.write(html1)
    print(f"Written: {out1} ({len(html1)} chars)")

    html2 = generate_session_Z1IhGrcgGO()
    with open(out2, "w", encoding="utf-8") as f:
        f.write(html2)
    print(f"Written: {out2} ({len(html2)} chars)")
