#!/bin/sh
# private sends OLLAMA_API_KEY to its Ollama as a Bearer token, which an Ollama that Edgible
# publishes from another machine needs. A stub on this machine stands in for that Ollama and records
# the Authorization header; test/inputs.env points LITELLM_PRIVATE_URL at it with a made-up key.
set -eu
B="http://127.0.0.1:$LITELLM_PORT"
M="Authorization: Bearer $LITELLM_MASTER_KEY"
log=$(mktemp)
stub=$(mktemp)
cat > "$stub" <<'PY'
import http.server, json, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get("content-length", 0)))
        open(sys.argv[1], "a").write(self.headers.get("Authorization", "none") + "\n")
        body = json.dumps({"model": "x", "created_at": "2026-01-01T00:00:00Z", "response": "ok",
                           "message": {"role": "assistant", "content": "ok"}, "done": True, "done_reason": "stop"}).encode()
        self.send_response(200)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a):
        pass
http.server.HTTPServer(("127.0.0.1", 18081), H).serve_forever()
PY
python3 -I "$stub" "$log" &
pid=$!
trap 'kill $pid 2>/dev/null || true; wait $pid 2>/dev/null || true; rm -f "$log" "$stub"' EXIT
sleep 1
for m in private private-smart; do
  curl -fsS -m 60 "$B/v1/chat/completions" -H "$M" -H 'content-type: application/json' \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" >/dev/null \
    || { echo "$m did not answer"; exit 1; }
done
[ "$(grep -c "^Bearer $OLLAMA_API_KEY\$" "$log")" = 2 ] || { echo "the gateway did not send OLLAMA_API_KEY as a Bearer token to private and private-smart: $(cat "$log")"; exit 1; }
echo "private and private-smart send OLLAMA_API_KEY as a Bearer token"
