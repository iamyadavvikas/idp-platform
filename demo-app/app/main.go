package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
)

var (
	version        = "1.0.0"
	errorRateEnv   = os.Getenv("ERROR_RATE")
	failHealth     = os.Getenv("FAIL_HEALTH")
	totalRequests  atomic.Int64
	errorRequests  atomic.Int64
	requestHistory []requestResult
	historyMu      sync.Mutex
	historyMax     = 50
)

type requestResult struct {
	Status  int    `json:"status"`
	Version string `json:"version"`
	Error   bool   `json:"error"`
}

func getErrorRate() float64 {
	if errorRateEnv != "" {
		rate, err := strconv.ParseFloat(errorRateEnv, 64)
		if err == nil {
			return rate
		}
	}
	return 0.01
}

func shouldFailHealth() bool {
	return failHealth == "true"
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	if shouldFailHealth() {
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprint(w, "unhealthy")
		return
	}
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ready")
}

func apiHandler(w http.ResponseWriter, r *http.Request) {
	errorRate := getErrorRate()
	isError := rand.Float64() < errorRate

	totalRequests.Add(1)

	result := requestResult{Version: version}

	if isError {
		errorRequests.Add(1)
		w.WriteHeader(http.StatusInternalServerError)
		result.Status = 500
		result.Error = true
		log.Printf("ERROR: returning 500 (error_rate=%.2f)", errorRate)
	} else {
		w.WriteHeader(http.StatusOK)
		result.Status = 200
		result.Error = false
	}

	historyMu.Lock()
	requestHistory = append(requestHistory, result)
	if len(requestHistory) > historyMax {
		requestHistory = requestHistory[len(requestHistory)-historyMax:]
	}
	historyMu.Unlock()

	json.NewEncoder(w).Encode(result)
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
	total := totalRequests.Load()
	errs := errorRequests.Load()
	var errRate float64
	if total > 0 {
		errRate = float64(errs) / float64(total) * 100
	}

	historyMu.Lock()
	hist := make([]requestResult, len(requestHistory))
	copy(hist, requestHistory)
	historyMu.Unlock()

	json.NewEncoder(w).Encode(map[string]any{
		"version":      version,
		"errorRate":    getErrorRate(),
		"totalReqs":    total,
		"errorReqs":    errs,
		"errorPercent": errRate,
		"history":      hist,
		"failHealth":   shouldFailHealth(),
	})
}

func setenvHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", 405)
		return
	}
	key := r.URL.Query().Get("key")
	val := r.URL.Query().Get("val")
	if key == "" {
		http.Error(w, "key required", 400)
		return
	}
	if key == "ERROR_RATE" {
		errorRateEnv = val
	}
	if key == "VERSION" {
		version = val
	}
	if key == "FAIL_HEALTH" {
		failHealth = val
	}
	totalRequests.Store(0)
	errorRequests.Store(0)
	historyMu.Lock()
	requestHistory = nil
	historyMu.Unlock()
	log.Printf("SET %s=%s", key, val)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok", "key": key, "val": val})
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	total := totalRequests.Load()
	errs := errorRequests.Load()
	success := total - errs

	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	fmt.Fprintf(w, `# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{status="2xx",version="%s"} %d
http_requests_total{status="5xx",version="%s"} %d
# HELP http_requests_error_rate Current error rate as a ratio
# TYPE http_requests_error_rate gauge
http_requests_error_rate{version="%s"} %s
`, version, success, version, errs, version, fmt.Sprintf("%.4f", getErrorRate()))
}

var dashboardHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>IDP Platform Demo</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; }
  .container { max-width: 960px; margin: 0 auto; padding: 20px 24px; }
  h1 { font-size: 22px; font-weight: 700; margin-bottom: 2px; display: flex; align-items: center; gap: 10px; }
  .subtitle { color: #64748b; font-size: 13px; margin-bottom: 20px; }
  .card { background: #1e293b; border-radius: 12px; padding: 16px 20px; margin-bottom: 12px; border: 1px solid #334155; }
  .card-title { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.06em; color: #64748b; margin-bottom: 10px; display: flex; align-items: center; justify-content: space-between; }
  .stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin-bottom: 12px; }
  .stat { background: #1e293b; border-radius: 10px; padding: 14px; border: 1px solid #334155; text-align: center; }
  .stat-value { font-size: 26px; font-weight: 700; font-variant-numeric: tabular-nums; }
  .stat-label { font-size: 11px; color: #64748b; margin-top: 2px; }
  .stat.good .stat-value { color: #22c55e; }
  .stat.warn .stat-value { color: #eab308; }
  .stat.bad .stat-value { color: #ef4444; }
  .row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  canvas { width: 100%; height: 160px; display: block; border-radius: 6px; }
  .controls { display: flex; gap: 6px; flex-wrap: wrap; }
  button { padding: 8px 16px; border: none; border-radius: 8px; font-size: 13px; font-weight: 500; cursor: pointer; transition: all 0.12s; font-family: inherit; }
  button:active { transform: scale(0.96); }
  .btn-good { background: #22c55e; color: #052e16; }
  .btn-good:hover { background: #16a34a; }
  .btn-bad { background: #ef4444; color: #450a0a; }
  .btn-bad:hover { background: #dc2626; }
  .btn-warn { background: #f59e0b; color: #451a03; }
  .btn-warn:hover { background: #d97706; }
  .btn-fix { background: #3b82f6; color: #172554; }
  .btn-fix:hover { background: #2563eb; }
  .btn-auto { background: #8b5cf6; color: #2e1065; }
  .btn-auto:hover { background: #7c3aed; }
  .btn-neutral { background: #334155; color: #e2e8f0; }
  .btn-neutral:hover { background: #475569; }
  .log { max-height: 200px; overflow-y: auto; font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace; font-size: 11px; }
  .log::-webkit-scrollbar { width: 5px; }
  .log::-webkit-scrollbar-track { background: #1e293b; }
  .log::-webkit-scrollbar-thumb { background: #475569; border-radius: 3px; }
  .log-entry { padding: 3px 6px; border-radius: 3px; margin-bottom: 1px; display: flex; align-items: center; gap: 6px; }
  .log-entry.ok { color: #86efac; background: rgba(34,197,94,0.06); }
  .log-entry.err { color: #fca5a5; background: rgba(239,68,68,0.06); }
  .badge { display: inline-block; padding: 1px 7px; border-radius: 999px; font-size: 10px; font-weight: 600; }
  .badge.ok { background: rgba(34,197,94,0.15); color: #22c55e; }
  .badge.err { background: rgba(239,68,68,0.15); color: #ef4444; }
  .badge.version { background: rgba(99,102,241,0.15); color: #818cf8; }
  .bar-container { width: 100%; height: 8px; background: #334155; border-radius: 999px; overflow: hidden; margin-top: 4px; }
  .bar-fill { height: 100%; border-radius: 999px; transition: width 0.3s, background 0.3s; min-width: 0; }
  .bar-fill.good { background: #22c55e; }
  .bar-fill.warn { background: #eab308; }
  .bar-fill.bad { background: #ef4444; }
  .env-badge { display: inline-block; padding: 2px 10px; border-radius: 999px; font-size: 11px; font-weight: 600; background: rgba(99,102,241,0.15); color: #818cf8; }
  .speed-row { display: flex; align-items: center; gap: 10px; margin-top: 6px; }
  .speed-row input { flex: 1; accent-color: #8b5cf6; }
  .kbd { display: inline-block; padding: 1px 5px; border-radius: 3px; background: #0f172a; border: 1px solid #334155; font-size: 10px; font-family: monospace; color: #64748b; }
  #rollbackOverlay { display: none; position: fixed; inset: 0; background: rgba(239,68,68,0.12); backdrop-filter: blur(4px); z-index: 1000; align-items: center; justify-content: center; flex-direction: column; }
  #rollbackOverlay.show { display: flex; }
  #rollbackOverlay .box { background: #1e293b; border: 2px solid #ef4444; border-radius: 16px; padding: 32px 48px; text-align: center; box-shadow: 0 0 60px rgba(239,68,68,0.3); }
  #rollbackOverlay h2 { font-size: 28px; color: #ef4444; margin-bottom: 8px; }
  #rollbackOverlay p { color: #94a3b8; font-size: 14px; max-width: 360px; }
  #rollbackOverlay .countdown { font-size: 48px; font-weight: 700; color: #ef4444; margin: 16px 0; font-variant-numeric: tabular-nums; }
  .canary-steps { display: flex; gap: 4px; margin-top: 6px; }
  .canary-step { flex: 1; height: 6px; border-radius: 3px; background: #334155; transition: background 0.3s; }
  .canary-step.done { background: #22c55e; }
  .canary-step.active { background: #eab308; box-shadow: 0 0 8px rgba(234,179,8,0.4); }
  .canary-step.failed { background: #ef4444; }
  .canary-label { font-size: 10px; color: #64748b; margin-top: 4px; display: flex; justify-content: space-between; }
  #terminalCard { border-color: #7c3aed; }
  #terminalLog { color: #a78bfa; background: #0f172a; border-radius: 6px; padding: 8px; font-family: 'SF Mono', 'Fira Code', monospace; font-size: 11px; max-height: 160px; overflow-y: auto; line-height: 1.5; }
  #terminalLog::-webkit-scrollbar { width: 4px; }
  #terminalLog::-webkit-scrollbar-track { background: #0f172a; }
  #terminalLog::-webkit-scrollbar-thumb { background: #334155; border-radius: 2px; }
</style>
</head>
<body>

<div id="rollbackOverlay">
  <div class="box">
    <h2>⚠ ROLLBACK TRIGGERED</h2>
    <div class="countdown" id="rollbackCountdown">3</div>
    <p>Argo Rollouts detected &gt;15% error rate<br>Reverting to last stable version...</p>
  </div>
</div>

<div class="container">
  <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:2px;">
    <h1>
      <span>IDP Platform Demo</span>
      <span class="env-badge" id="versionBadge">v1.0.0</span>
      <span style="display:inline-block;padding:2px 10px;border-radius:999px;font-size:11px;font-weight:600;background:rgba(34,197,94,0.12);color:#22c55e;" id="costBadge">$842/mo</span>
    </h1>
  </div>
  <div class="subtitle">Self-Service GitOps — deploy YAML, zero touch &middot; <span style="color:#64748b;">1</span>=good <span style="color:#64748b;">2</span>=bad <span style="color:#64748b;">3</span>=crash <span style="color:#64748b;">Space</span>=auto <span style="color:#64748b;">C</span>=clear</div>

  <div class="stats">
    <div class="stat good">
      <div class="stat-value" id="totalReqs">0</div>
      <div class="stat-label">Total</div>
    </div>
    <div class="stat good">
      <div class="stat-value" id="successReqs">0</div>
      <div class="stat-label">2xx</div>
    </div>
    <div class="stat bad">
      <div class="stat-value" id="errorReqs">0</div>
      <div class="stat-label">5xx</div>
    </div>
    <div class="stat" id="errorRateStat">
      <div class="stat-value" id="errorPercent">0%</div>
      <div class="stat-label">Error Rate</div>
    </div>
  </div>

  <div class="row">
    <div class="card">
      <div class="card-title">
        <span>Error Rate (60s)</span>
        <span style="color:#64748b;font-weight:400;text-transform:none;" id="configuredRate">target: 1%</span>
      </div>
      <canvas id="chart"></canvas>
    </div>
    <div class="card">
      <div class="card-title">
        <span>Canary Progress</span>
        <span style="color:#64748b;font-weight:400;text-transform:none;" id="canaryStepLabel">stable</span>
      </div>
      <div class="canary-steps" id="canarySteps">
        <div class="canary-step" data-idx="0"></div>
        <div class="canary-step" data-idx="1"></div>
        <div class="canary-step" data-idx="2"></div>
        <div class="canary-step" data-idx="3"></div>
        <div class="canary-step" data-idx="4"></div>
        <div class="canary-step" data-idx="5"></div>
      </div>
      <div class="canary-label">
        <span>10%</span>
        <span>25%</span>
        <span>50%</span>
        <span>75%</span>
        <span>100%</span>
        <span>pass</span>
      </div>
      <div class="bar-container" style="margin-top:10px;">
        <div class="bar-fill good" id="errorBar" style="width:0%"></div>
      </div>
      <div style="display:flex;justify-content:space-between;font-size:11px;color:#64748b;margin-top:2px;">
        <span>0%</span>
        <span id="currentErrorLabel">0.0%</span>
        <span>100%</span>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="card-title">
      <span>Controls</span>
      <span style="font-weight:400;text-transform:none;color:#64748b;font-size:11px;">
        <span id="healthStatus">health: ok</span>
      </span>
    </div>
    <div class="controls">
      <button class="btn-good" onclick="setErrorRate('0.01','1.0.0')">Good (1%)</button>
      <button class="btn-bad" onclick="setErrorRate('0.15','2.0.0-bad')">Bad (15%)</button>
      <button class="btn-bad" onclick="setErrorRate('0.50','2.0.0-crash')">Crash (50%)</button>
      <button class="btn-warn" onclick="toggleHealth()">Toggle Health</button>
      <button class="btn-fix" onclick="clearLog()">Clear Log</button>
      <button class="btn-fix" onclick="exportLog()">Export Log</button>
      <button class="btn-auto" id="autoBtn" onclick="toggleAuto()">Auto: ON</button>
      <button class="btn-neutral" onclick="sendRequest()">Fire !</button>
    </div>
    <div class="speed-row">
      <span style="font-size:11px;color:#64748b;">Interval</span>
      <input type="range" id="speedSlider" min="200" max="5000" value="1000" step="100">
      <span style="font-size:11px;color:#64748b;min-width:48px;" id="speedLabel">1.0s</span>
    </div>
  </div>

  <div class="card" id="terminalCard" style="display:none;border-color:#7c3aed;">
    <div class="card-title">
      <span>ArgoCD Terminal</span>
      <span style="font-weight:400;text-transform:none;color:#a78bfa;font-size:11px;">auto-rollback</span>
    </div>
    <div class="log" id="terminalLog" style="max-height:160px;font-size:11px;color:#a78bfa;">
    </div>
  </div>

  <div class="card">
    <div class="card-title">
      <span>Request Log</span>
      <span style="font-weight:400;text-transform:none;color:#64748b;font-size:11px;" id="logCount">0 entries</span>
    </div>
    <div class="log" id="logContainer">
      <div style="color:#475569;font-size:12px;padding:6px;">Waiting for requests...</div>
    </div>
  </div>
</div>

<script>
let autoMode = true;
let autoInterval = null;
let autoDelay = 1000;
let chartData = [];
const chartMaxPoints = 60;
let lastCount = 0;
let lastErrorCount = 0;
let isRollingBack = false;
let canaryStep = -1;
let logEntries = [];

function addLog(status, version, isError) {
  const container = document.getElementById('logContainer');
  const entry = document.createElement('div');
  entry.className = 'log-entry ' + (isError ? 'err' : 'ok');
  const ts = new Date().toLocaleTimeString();
  const html = '<span style="color:#475569;min-width:60px;">' + ts + '</span> ' +
    '<span class="badge ' + (isError ? 'err' : 'ok') + '">' + (isError ? '500' : '200') + '</span> ' +
    '<span class="badge version">' + version + '</span> ' +
    (isError ? 'Internal Server Error' : 'OK');
  entry.innerHTML = html;
  container.appendChild(entry);
  container.scrollTop = container.scrollHeight;
  const ph = container.querySelector('div:first-child');
  if (ph && ph.style.color === '#475569') ph.remove();
  if (container.children.length > 300) container.removeChild(container.firstChild);
  logEntries.push({ ts: new Date().toISOString(), status, version, isError });
  document.getElementById('logCount').textContent = logEntries.length + ' entries';
}

function addTerminalLine(text, type) {
  const container = document.getElementById('terminalLog');
  const line = document.createElement('div');
  line.style.cssText = 'padding:2px 0;opacity:0;transition:opacity 0.3s;';
  if (type === 'warn') line.style.color = '#fbbf24';
  else if (type === 'error') line.style.color = '#f87171';
  else if (type === 'info') line.style.color = '#60a5fa';
  else if (type === 'success') line.style.color = '#34d399';
  else line.style.color = '#a78bfa';
  const ts = new Date().toLocaleTimeString();
  line.textContent = '[' + ts + '] ' + text;
  container.appendChild(line);
  container.scrollTop = container.scrollHeight;
  requestAnimationFrame(() => line.style.opacity = '1');
}

function drawChart() {
  const canvas = document.getElementById('chart');
  const rect = canvas.parentElement.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  const w = rect.width - 40;
  const h = 160;
  canvas.width = w * dpr;
  canvas.height = h * dpr;
  canvas.style.width = w + 'px';
  canvas.style.height = h + 'px';
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);

  ctx.clearRect(0, 0, w, h);
  if (chartData.length < 2) return;

  const max = Math.max(50, Math.ceil(Math.max(...chartData) * 1.1));
  const pad = { top: 8, bottom: 20, left: 36, right: 8 };
  const cw = w - pad.left - pad.right;
  const ch = h - pad.top - pad.bottom;

  ctx.strokeStyle = '#334155';
  ctx.lineWidth = 1;
  for (let i = 0; i <= 4; i++) {
    const y = pad.top + (ch / 4) * i;
    ctx.beginPath();
    ctx.moveTo(pad.left, y);
    ctx.lineTo(w - pad.right, y);
    ctx.stroke();
    ctx.fillStyle = '#475569';
    ctx.font = '10px monospace';
    ctx.textAlign = 'right';
    ctx.fillText(Math.round(max - (max / 4) * i) + '%', pad.left - 6, y + 4);
  }

  const threshold5 = pad.top + ch - (5 / max) * ch;
  const threshold15 = pad.top + ch - (15 / max) * ch;

  ctx.fillStyle = 'rgba(234,179,8,0.08)';
  ctx.fillRect(pad.left, threshold5, cw, threshold15 - threshold5);
  ctx.fillStyle = 'rgba(239,68,68,0.08)';
  ctx.fillRect(pad.left, 0, cw, threshold15);

  ctx.setLineDash([4, 4]);
  ctx.strokeStyle = 'rgba(234,179,8,0.4)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(pad.left, threshold5);
  ctx.lineTo(w - pad.right, threshold5);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(239,68,68,0.4)';
  ctx.beginPath();
  ctx.moveTo(pad.left, threshold15);
  ctx.lineTo(w - pad.right, threshold15);
  ctx.stroke();
  ctx.setLineDash([]);

  const gradient = ctx.createLinearGradient(0, pad.top, 0, pad.top + ch);
  gradient.addColorStop(0, 'rgba(239,68,68,0.15)');
  gradient.addColorStop(0.5, 'rgba(234,179,8,0.10)');
  gradient.addColorStop(1, 'rgba(34,197,94,0.05)');

  const step = cw / (chartData.length - 1);
  ctx.beginPath();
  ctx.moveTo(pad.left, pad.top + ch);
  for (let i = 0; i < chartData.length; i++) {
    const x = pad.left + i * step;
    const y = pad.top + ch - (chartData[i] / max) * ch;
    ctx.lineTo(x, y);
  }
  ctx.lineTo(pad.left + (chartData.length - 1) * step, pad.top + ch);
  ctx.closePath();
  ctx.fillStyle = gradient;
  ctx.fill();

  ctx.beginPath();
  for (let i = 0; i < chartData.length; i++) {
    const x = pad.left + i * step;
    const y = pad.top + ch - (chartData[i] / max) * ch;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  const lineColor = chartData[chartData.length - 1] > 15 ? '#ef4444' : chartData[chartData.length - 1] > 5 ? '#eab308' : '#22c55e';
  ctx.strokeStyle = lineColor;
  ctx.lineWidth = 2;
  ctx.stroke();

  const last = chartData[chartData.length - 1];
  ctx.beginPath();
  ctx.arc(pad.left + (chartData.length - 1) * step, pad.top + ch - (last / max) * ch, 4, 0, Math.PI * 2);
  ctx.fillStyle = lineColor;
  ctx.fill();
  ctx.strokeStyle = '#0f172a';
  ctx.lineWidth = 2;
  ctx.stroke();
}

function updateCanary(pct) {
  const steps = [10, 25, 50, 75, 100];
  canaryStep = -1;
  if (pct < 5) { canaryStep = -1; }
  else {
    for (let i = 0; i < steps.length; i++) {
      if (pct >= steps[i]) canaryStep = i;
    }
  }
  document.querySelectorAll('.canary-step').forEach((el, i) => {
    el.className = 'canary-step';
    if (i < canaryStep) el.classList.add('done');
    else if (i === canaryStep && pct >= 5) el.classList.add('active');
  });
  const label = document.getElementById('canaryStepLabel');
  if (pct < 5) label.textContent = 'stable';
  else if (canaryStep === -1) label.textContent = 'stable';
  else if (canaryStep >= 4) label.textContent = 'promoted ✓';
  else label.textContent = 'step ' + (canaryStep + 1) + '/5';
}

function updateStats(data) {
  const pct = Math.min(data.errorPercent, 100);
  document.getElementById('totalReqs').textContent = data.totalReqs;
  document.getElementById('successReqs').textContent = data.totalReqs - data.errorReqs;
  document.getElementById('errorReqs').textContent = data.errorReqs;
  document.getElementById('errorPercent').textContent = data.errorPercent.toFixed(1) + '%';
  document.getElementById('configuredRate').textContent = 'target: ' + (data.errorRate * 100).toFixed(0) + '%';
  document.getElementById('versionBadge').textContent = 'v' + data.version;
  document.getElementById('healthStatus').textContent = 'health: ' + (data.failHealth ? 'FAIL' : 'ok');

  const statEl = document.getElementById('errorRateStat');
  statEl.className = 'stat';
  if (data.errorPercent < 5) statEl.classList.add('good');
  else if (data.errorPercent < 15) statEl.classList.add('warn');
  else statEl.classList.add('bad');

  const bar = document.getElementById('errorBar');
  bar.style.width = pct + '%';
  bar.className = 'bar-fill';
  if (data.errorPercent < 5) bar.classList.add('good');
  else if (data.errorPercent < 15) bar.classList.add('warn');
  else bar.classList.add('bad');

  document.getElementById('currentErrorLabel').textContent = data.errorPercent.toFixed(1) + '%';

  updateCanary(data.errorPercent);

  chartData.push(data.errorPercent);
  if (chartData.length > chartMaxPoints) chartData.shift();
  drawChart();

  if (data.errorPercent > 15 && !isRollingBack) triggerRollback();
  else if (data.errorPercent <= 5 && isRollingBack) dismissRollback();
}

function triggerRollback() {
  isRollingBack = true;
  const overlay = document.getElementById('rollbackOverlay');
  overlay.classList.add('show');
  let count = 3;
  const cd = document.getElementById('rollbackCountdown');
  cd.textContent = count;
  document.getElementById('canaryStepLabel').textContent = 'ROLLING BACK...';
  document.querySelectorAll('.canary-step').forEach(el => el.className = 'canary-step failed');

  document.getElementById('terminalCard').style.display = '';
  document.getElementById('terminalLog').innerHTML = '';

  const lines = [
    { t: '[Argo Rollouts] Detected error rate spike: 23.7%', type: 'warn' },
    { t: '[Argo Rollouts] AnalysisRun demo-app-6b9d7f-1: status=failed', type: 'warn' },
    { t: '[Argo Rollouts] Metric success-rate: 0.763 < 0.950 threshold', type: 'error' },
    { t: '[Argo Rollouts] Failure limit (3) reached. Initiating rollback...', type: 'error' },
    { t: '[ArgoCD] Reverting Rollout demo-app to revision 3', type: 'info' },
    { t: '[ArgoCD] Desired replicas: 5, Current: 5, Updated: 0', type: 'info' },
    { t: '[ArgoCD] Syncing to desired revision: v1.0.0', type: 'info' },
    { t: '[K8s] ReplicaSet demo-app-6b9d7f scaled down to 0', type: 'info' },
    { t: '[K8s] ReplicaSet demo-app-4a2c8f scaled up to 5', type: 'info' },
    { t: '[Prometheus] Alert CRITICAL: error_rate=23.7% (resolved)', type: 'success' },
  ];

  let lineIdx = 0;
  const lineIv = setInterval(() => {
    if (lineIdx < lines.length) {
      addTerminalLine(lines[lineIdx].t, lines[lineIdx].type);
      lineIdx++;
    } else {
      clearInterval(lineIv);
    }
  }, 400);

  const iv = setInterval(() => {
    count--;
    cd.textContent = count;
    if (count <= 0) {
      clearInterval(iv);
      clearInterval(lineIv);
      addTerminalLine('[Argo Rollouts] Rollback complete. Service healthy.', 'success');
      setErrorRate('0.01', '1.0.0');
      setTimeout(() => dismissRollback(), 1200);
    }
  }, 800);
}

function dismissRollback() {
  isRollingBack = false;
  document.getElementById('rollbackOverlay').classList.remove('show');
}

async function fetchStatus() {
  try {
    const res = await fetch('/status');
    const data = await res.json();
    updateStats(data);
  } catch(e) {}
}

async function sendRequest() {
  try {
    const res = await fetch('/api');
    const data = await res.json();
    addLog(data.status, data.version, data.error);
    await fetchStatus();
  } catch(e) {}
}

async function setErrorRate(rate, ver) {
  await fetch('/setenv?key=ERROR_RATE&val=' + rate, {method:'POST'});
  await fetch('/setenv?key=VERSION&val=' + ver, {method:'POST'});
  isRollingBack = false;
  document.getElementById('rollbackOverlay').classList.remove('show');
  await fetchStatus();
}

async function toggleHealth() {
  const res = await fetch('/status');
  const data = await res.json();
  const val = data.failHealth ? 'false' : 'true';
  await fetch('/setenv?key=FAIL_HEALTH&val=' + val, {method:'POST'});
  await fetchStatus();
}

async function clearLog() {
  await fetch('/setenv?key=VERSION&val=' + document.getElementById('versionBadge').textContent.slice(1), {method:'POST'});
  document.getElementById('logContainer').innerHTML = '<div style="color:#475569;font-size:12px;padding:6px;">Log cleared</div>';
  document.getElementById('terminalCard').style.display = 'none';
  document.getElementById('terminalLog').innerHTML = '';
  logEntries = [];
  document.getElementById('logCount').textContent = '0 entries';
  await fetchStatus();
}

function exportLog() {
  const data = JSON.stringify(logEntries, null, 2);
  const blob = new Blob([data], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'demo-app-requests-' + new Date().toISOString().slice(0, 19) + '.json';
  a.click();
  URL.revokeObjectURL(url);
}

function toggleAuto() {
  autoMode = !autoMode;
  document.getElementById('autoBtn').textContent = 'Auto: ' + (autoMode ? 'ON' : 'OFF');
  document.getElementById('autoBtn').className = autoMode ? 'btn-auto' : 'btn-fix';
  if (autoMode) startAuto();
  else stopAuto();
}

function startAuto() {
  stopAuto();
  autoInterval = setInterval(sendRequest, autoDelay);
}

function stopAuto() {
  if (autoInterval) { clearInterval(autoInterval); autoInterval = null; }
}

document.getElementById('speedSlider').addEventListener('input', function() {
  autoDelay = parseInt(this.value);
  document.getElementById('speedLabel').textContent = (autoDelay / 1000).toFixed(1) + 's';
  if (autoMode) { startAuto(); }
});

document.addEventListener('keydown', function(e) {
  if (e.target.tagName === 'INPUT') return;
  if (e.key === '1') setErrorRate('0.01', '1.0.0');
  else if (e.key === '2') setErrorRate('0.15', '2.0.0-bad');
  else if (e.key === '3') setErrorRate('0.50', '2.0.0-crash');
  else if (e.key === ' ') { e.preventDefault(); toggleAuto(); }
  else if (e.key === 'c' || e.key === 'C') clearLog();
  else if (e.key === 'e' || e.key === 'E') exportLog();
  else if (e.key === 'f' || e.key === 'F') sendRequest();
});

window.addEventListener('resize', drawChart);
fetchStatus();
startAuto();
</script>
</body>
</html>`

func rootHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(dashboardHTML))
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if v := os.Getenv("VERSION"); v != "" {
		version = v
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", rootHandler)
	mux.HandleFunc("/api", apiHandler)
	mux.HandleFunc("/status", statusHandler)
	mux.HandleFunc("/setenv", setenvHandler)
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/ready", readyHandler)
	mux.HandleFunc("/metrics", metricsHandler)

	addr := fmt.Sprintf(":%s", port)
	log.Printf("Demo App v%s starting on %s (error_rate=%.2f)", version, addr, getErrorRate())
	log.Fatal(http.ListenAndServe(addr, mux))
}
