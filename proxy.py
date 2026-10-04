#!/usr/bin/env python3
# JgXeinz VPN - proxy WebSocket (Python 3)
# Recibe el handshake WebSocket del payload y reenvia la conexion al SSH local (127.0.0.1:22)
import socket, threading, select, sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 80
TARGET = ('127.0.0.1', 22)
RESP = b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n'


def pipe(a, b):
    try:
        while True:
            r, _, x = select.select([a, b], [], [a, b], 300)
            if x or not r:
                break
            for s in r:
                data = s.recv(65536)
                if not data:
                    return
                (b if s is a else a).sendall(data)
    except Exception:
        pass
    finally:
        a.close()
        b.close()


def handle(c):
    try:
        c.settimeout(10)
        data = c.recv(65536)
        c.settimeout(None)
        r = socket.create_connection(TARGET)
        c.sendall(RESP)
        if b'\r\n\r\n' in data:
            rest = data.split(b'\r\n\r\n', 1)[1]
            if rest.startswith(b'SSH-'):
                r.sendall(rest)
        pipe(c, r)
    except Exception:
        try:
            c.close()
        except Exception:
            pass


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(('0.0.0.0', PORT))
    srv.listen(200)
    while True:
        c, _ = srv.accept()
        threading.Thread(target=handle, args=(c,), daemon=True).start()


if __name__ == '__main__':
    main()
