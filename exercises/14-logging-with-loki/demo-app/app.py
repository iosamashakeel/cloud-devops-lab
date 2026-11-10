import http.server
import logging
import random
import threading
import time

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("demo-app")

MESSAGES = [
    "user signed in",
    "order placed",
    "cache miss for product page",
    "payment webhook received",
    "slow query detected: 812ms",
]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        logger.info("GET %s from %s", self.path, self.client_address[0])
        if random.random() < 0.2:
            logger.warning("slow response for %s", self.path)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok\n")

    def log_message(self, *args):
        # Silence the default stderr access log; we log ourselves.
        pass


def background():
    while True:
        logger.info(random.choice(MESSAGES))
        time.sleep(random.randint(2, 6))


threading.Thread(target=background, daemon=True).start()
http.server.HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
