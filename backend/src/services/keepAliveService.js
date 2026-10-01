const https = require('https');
const http = require('http');

class KeepAliveService {
  constructor() {
    this.timer = null;
    this.intervalMs = parseInt(process.env.PING_INTERVAL_MS, 10) || 8 * 60 * 1000; // Default: 8 minutes (Render sleeps at 15 mins)
    this.targetUrl = process.env.RENDER_EXTERNAL_URL || process.env.APP_URL || 'https://eligible-backend.onrender.com';
    this.pingsCount = 0;
    this.failedCount = 0;
    this.lastPingAt = null;
    this.lastStatus = null;
    this.lastLatencyMs = null;
    this.history = [];
    this.maxHistory = 20;
    this.startedAt = new Date().toISOString();
  }

  /**
   * Resolve full ping URL (defaults to /api/ping)
   */
  getPingUrl() {
    const base = (this.targetUrl || 'https://eligible-backend.onrender.com').replace(/\/+$/, '');
    return `${base}/api/ping`;
  }

  /**
   * Start periodic self-pinging keep-alive loop
   */
  start(customIntervalMs) {
    if (this.timer) {
      clearInterval(this.timer);
    }

    if (customIntervalMs) {
      this.intervalMs = customIntervalMs;
    }

    const intervalMinutes = Math.round(this.intervalMs / 60000);
    console.log(`💓 [KeepAlive] Live Server Pinger started!`);
    console.log(`   ├─ Target URL: ${this.getPingUrl()}`);
    console.log(`   ├─ Interval:   Every ${intervalMinutes} minutes (prevents Render instance from sleeping)`);
    console.log(`   └─ Status:     Active & Monitoring`);

    // Perform initial ping after 30 seconds to confirm connectivity
    setTimeout(() => {
      this.ping();
    }, 30000);

    // Run scheduled interval
    this.timer = setInterval(() => {
      this.ping();
    }, this.intervalMs);

    if (this.timer.unref) {
      this.timer.unref(); // Don't prevent clean process exit if shutting down
    }
  }

  /**
   * Stop the pinger timer
   */
  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
      console.log('⏹️  [KeepAlive] Live Server Pinger stopped.');
    }
  }

  /**
   * Execute single ping HTTP request
   */
  ping() {
    return new Promise((resolve) => {
      const pingUrl = this.getPingUrl();
      const startTime = Date.now();
      const isHttps = pingUrl.startsWith('https');
      const client = isHttps ? https : http;

      const req = client.get(
        pingUrl,
        {
          headers: {
            'User-Agent': 'EligibleCRM-Live-Pinger/1.0 (+https://eligible-backend.onrender.com)',
            'X-Purpose': 'keep-alive',
          },
          timeout: 15000,
        },
        (res) => {
          let body = '';
          res.on('data', (chunk) => (body += chunk));
          res.on('end', () => {
            const latencyMs = Date.now() - startTime;
            this.pingsCount++;
            this.lastPingAt = new Date().toISOString();
            this.lastStatus = res.statusCode;
            this.lastLatencyMs = latencyMs;

            const record = {
              cycle: this.pingsCount,
              timestamp: this.lastPingAt,
              statusCode: res.statusCode,
              latencyMs,
              success: res.statusCode >= 200 && res.statusCode < 300,
            };

            this.history.unshift(record);
            if (this.history.length > this.maxHistory) {
              this.history.pop();
            }

            console.log(
              `💓 [KeepAlive] Ping #${this.pingsCount} to ${pingUrl} | Status: ${res.statusCode} | Latency: ${latencyMs}ms | Instance Awake ✅`
            );
            resolve(record);
          });
        }
      );

      req.on('error', (err) => {
        const latencyMs = Date.now() - startTime;
        this.pingsCount++;
        this.failedCount++;
        this.lastPingAt = new Date().toISOString();
        this.lastStatus = 'ERROR';
        this.lastLatencyMs = latencyMs;

        const record = {
          cycle: this.pingsCount,
          timestamp: this.lastPingAt,
          statusCode: 'ERROR',
          error: err.message,
          latencyMs,
          success: false,
        };

        this.history.unshift(record);
        if (this.history.length > this.maxHistory) {
          this.history.pop();
        }

        console.warn(`⚠️ [KeepAlive] Ping #${this.pingsCount} failed: ${err.message} (${latencyMs}ms)`);
        resolve(record);
      });

      req.on('timeout', () => {
        req.destroy();
        console.warn(`⚠️ [KeepAlive] Ping timed out after 15s`);
      });
    });
  }

  /**
   * Return status summary
   */
  getStatus() {
    const nextPingEstimated = this.lastPingAt
      ? new Date(new Date(this.lastPingAt).getTime() + this.intervalMs).toISOString()
      : null;

    return {
      active: !!this.timer,
      targetUrl: this.getPingUrl(),
      intervalMinutes: Math.round(this.intervalMs / 60000),
      totalPings: this.pingsCount,
      failedPings: this.failedCount,
      lastPingAt: this.lastPingAt,
      lastStatus: this.lastStatus,
      lastLatencyMs: this.lastLatencyMs,
      nextPingEstimated,
      startedAt: this.startedAt,
      recentHistory: this.history,
    };
  }
}

const instance = new KeepAliveService();
module.exports = instance;
