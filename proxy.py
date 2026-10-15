#!/usr/bin/env python3
# JgXeinz VPN - proxy WebSocket (Python 3)
# Recibe el handshake WebSocket del payload y reenvia la conexion al SSH local
# (127.0.0.1:22). Si el request trae la ruta de Xray (/etc/jgxeinz/xray/path),
# lo pasa tal cual a Xray (VLESS/WS en 127.0.0.1:10080): mismo puerto para ambos.
import os, re, socket, threading, select, sys, time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 80
TARGET = ('127.0.0.1', 22)
XRAY_TARGET = ('127.0.0.1', 10080)
XRAY_PATH_FILE = '/etc/jgxeinz/xray/path'
RESP = b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n'

_xp = {'mtime': None, 're': None}


def xray_re():
    # ruta de Xray, releida solo si el archivo cambio
    try:
        mt = os.stat(XRAY_PATH_FILE).st_mtime
    except OSError:
        _xp['mtime'], _xp['re'] = None, None
        return None
    if mt != _xp['mtime']:
        try:
            p = open(XRAY_PATH_FILE, 'rb').read().strip()
        except OSError:
            p = b''
        _xp['mtime'] = mt
        _xp['re'] = re.compile(rb'^[A-Z]+ ' + re.escape(p) + rb'[ ?]', re.M) if p.startswith(b'/') else None
    return _xp['re']


def nodelay(s):
    # manda los paquetes chicos al toque (sin esperar a juntar): baja el ping en juegos
    try:
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    except Exception:
        pass


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


def wait_more(c, buf, rx, limit=2.0):
    # despues del payload: junta lo que mande el cliente hasta ver el saludo
    # de SSH o el pedido de Xray (V2Ray manda su WebSocket recien despues del 101)
    end = time.time() + limit
    while True:
        if b'SSH-' in buf:
            return buf, None
        m = rx.search(buf)
        if m:
            return buf, m
        left = end - time.time()
        if left <= 0 or len(buf) > 65536:
            return buf, None
        r, _, _ = select.select([c], [], [], left)
        if not r:
            return buf, None
        d = c.recv(65536)
        if not d:
            raise ConnectionError('cliente cerro')
        buf += d


def to_xray(c, buf):
    # le pasamos el request desde la linea con su ruta (descarta requests
    # "falsos" del payload) y Xray responde su propio 101
    r = socket.create_connection(XRAY_TARGET)
    nodelay(r)
    r.sendall(buf)
    pipe(c, r)


def handle(c):
    try:
        nodelay(c)
        c.settimeout(10)
        data = c.recv(65536)
        c.settimeout(None)
        rx = xray_re()
        m = rx.search(data) if rx else None
        if m:
            to_xray(c, data[m.start():])
            return
        c.sendall(RESP)
        rest = data.split(b'\r\n\r\n', 1)[1] if b'\r\n\r\n' in data else b''
        if rx:
            # con Xray instalado: ver si lo que sigue al payload es V2Ray o SSH
            rest, m = wait_more(c, rest, rx)
            if m:
                to_xray(c, rest[m.start():])
                return
        r = socket.create_connection(TARGET)
        nodelay(r)
        i = rest.find(b'SSH-')
        if i >= 0:
            r.sendall(rest[i:])
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
