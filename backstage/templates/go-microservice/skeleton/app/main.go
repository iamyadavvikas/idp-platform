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

func rootHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(`<!DOCTYPE html>
<html>
<head>
  <title>{{name}} - IDP Platform</title>
  <style>
    body { font-family: system-ui; max-width: 800px; margin: 50px auto; padding: 20px; background: #0f172a; color: #e2e8f0; }
    h1 { color: #22c55e; }
    .card { background: #1e293b; padding: 20px; border-radius: 8px; margin: 20px 0; border: 1px solid #334155; }
    .stat { display: inline-block; margin: 10px 20px; }
    .stat-value { font-size: 24px; font-weight: bold; color: #22c55e; }
    .stat-label { font-size: 12px; color: #64748b; }
    button { padding: 10px 20px; margin: 5px; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; }
    .btn-good { background: #22c55e; color: white; }
    .btn-bad { background: #ef4444; color: white; }
    .btn-crash { background: #dc2626; color: white; }
  </style>
</head>
<body>
  <h1>{{name}} <span style="font-size: 16px; color: #64748b;">v` + version + `</span></h1>
  <p>IDP Platform Standard Go Microservice</p>
  <div class="card">
    <h3>Status</h3>
    <div class="stat"><div class="stat-value" id="total">0</div><div class="stat-label">Total</div></div>
    <div class="stat"><div class="stat-value" id="success">0</div><div class="stat-label">2xx</div></div>
    <div class="stat"><div class="stat-value" id="errors">0</div><div class="stat-label">5xx</div></div>
    <div class="stat"><div class="stat-value" id="rate">0%</div><div class="stat-label">Error Rate</div></div>
  </div>
  <div class="card">
    <h3>Controls</h3>
    <button class="btn-good" onclick="setRate('0.01','1.0.0')">Good (1%)</button>
    <button class="btn-bad" onclick="setRate('0.15','2.0.0-bad')">Bad (15%)</button>
    <button class="btn-crash" onclick="setRate('0.50','2.0.0-crash')">Crash (50%)</button>
  </div>
  <script>
    async function fetchStatus() {
      const res = await fetch('/status');
      const data = await res.json();
      document.getElementById('total').textContent = data.totalReqs;
      document.getElementById('success').textContent = data.totalReqs - data.errorReqs;
      document.getElementById('errors').textContent = data.errorReqs;
      document.getElementById('rate').textContent = data.errorPercent.toFixed(1) + '%';
    }
    async function sendRequest() {
      const res = await fetch('/api');
      const data = await res.json();
      await fetchStatus();
    }
    async function setRate(rate, ver) {
      await fetch('/setenv?key=ERROR_RATE&val=' + rate, {method:'POST'});
      await fetch('/setenv?key=VERSION&val=' + ver, {method:'POST'});
      await fetchStatus();
    }
    setInterval(sendRequest, 1000);
    fetchStatus();
  </script>
</body>
</html>`))
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
	log.Printf("{{name}} v%s starting on %s (error_rate=%.2f)", version, addr, getErrorRate())
	log.Fatal(http.ListenAndServe(addr, mux))
}