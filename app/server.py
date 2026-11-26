"""Small stateless HTTP API, standard library only; intentionally for local labs."""
import json, os, socket, threading, time, signal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

START = time.monotonic()
LOCK = threading.Lock()
COUNTS = {}
DURATION = {}
VERSION = os.getenv('APP_VERSION', 'v1')
MESSAGE = os.getenv('APP_MESSAGE', 'hello from kubernetes')
READY = os.getenv('APP_READY', 'true').lower() == 'true'
HOST = socket.gethostname()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        start = time.monotonic()
        url = urlparse(self.path)
        route = url.path if url.path in ('/', '/healthz', '/readyz', '/metrics', '/burn', '/error') else 'other'
        status = 200
        content_type = 'application/json'
        data = {'version': VERSION, 'pod': HOST, 'message': MESSAGE}
        if route == '/healthz':
            data = {'alive': True}
        elif route == '/readyz':
            status = 200 if READY else 503
            data = {'ready': READY}
        elif route == '/error':
            status, data = 500, {'error': 'intentional lab failure'}
        elif route == '/burn':
            try:
                ms = max(1, min(250, int(parse_qs(url.query).get('ms', ['100'])[0])))
            except ValueError:
                ms = 100
            deadline = time.monotonic() + ms / 1000
            while time.monotonic() < deadline:
                pass
            data = {'burn_ms': ms, 'pod': HOST}
        elif route == '/metrics':
            content_type = 'text/plain; version=0.0.4; charset=utf-8'
            with LOCK:
                lines = ['# TYPE lab_http_requests_total counter']
                for (path, code), count in sorted(COUNTS.items()):
                    lines.append(f'lab_http_requests_total{{route="{path}",status="{code}"}} {count}')
                lines += ['# TYPE lab_http_request_duration_seconds_sum counter', '# TYPE lab_http_request_duration_seconds_count counter']
                for path, (total, count) in sorted(DURATION.items()):
                    lines.append(f'lab_http_request_duration_seconds_sum{{route="{path}"}} {total:.9f}')
                    lines.append(f'lab_http_request_duration_seconds_count{{route="{path}"}} {count}')
                lines += ['# TYPE lab_uptime_seconds gauge', f'lab_uptime_seconds {time.monotonic()-START:.3f}']
            data = '\n'.join(lines) + '\n'
        elif route == 'other':
            status, data = 404, {'error': 'not found'}
        elapsed = time.monotonic() - start
        if route != '/metrics':
            with LOCK:
                key = (route, status)
                COUNTS[key] = COUNTS.get(key, 0) + 1
                total, count = DURATION.get(route, (0.0, 0))
                DURATION[route] = (total + elapsed, count + 1)
        payload = (data if isinstance(data, str) else json.dumps(data)).encode()
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            pass
        if route not in ('/healthz', '/readyz', '/metrics'):
            print(json.dumps({'level': 'error' if status >= 500 else 'info', 'route': route, 'status': status, 'pod': HOST, 'duration_ms': round(elapsed*1000, 2)}), flush=True)

    def log_message(self, *_):
        pass

if __name__ == '__main__':
    server = ThreadingHTTPServer(('0.0.0.0', int(os.getenv('PORT', '8080'))), Handler)
    def stop(*_):
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    print(json.dumps({'event': 'started', 'version': VERSION}), flush=True)
    server.serve_forever()
    server.server_close()
