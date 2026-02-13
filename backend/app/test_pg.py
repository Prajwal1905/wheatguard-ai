import psycopg2
import socket

orig_getaddrinfo = socket.getaddrinfo
def ipv4_only(*args, **kwargs):
    return [ai for ai in orig_getaddrinfo(*args, **kwargs) if ai[0] == socket.AF_INET]
socket.getaddrinfo = ipv4_only

try:
    conn = psycopg2.connect(
        dbname="wheatguard",
        user="postgres",
        password="admin",      
        host="127.0.0.1",      
        port="5432"
    )
    print(" Connected successfully!")
    cur = conn.cursor()
    cur.execute("SELECT version();")
    print(cur.fetchone())
    conn.close()
except Exception as e:
    print(" Connection failed:")
    print(e)
