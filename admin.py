import socket
import sys

HOST='192.168.2.107'
PORT=91
PWD='defaultpwd'

s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)      
s.connect((HOST,PORT))     

s.sendall(PWD + sys.argv[1])
print(s.recv(1024))

s.close()  