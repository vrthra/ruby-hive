cr '0'
title 'generic ftp retrieve'
server.start
>[
GET ftp://#{opt.server_host_port}/retr/#{Time.now.to_i} HTTP/1.0

]
<[:$line=>/^\r\n$/
HTTP/1.1 200 OK
Server: Sun-Java-System-Web-Proxy-Server/4.0
/Date: .* GMT/
Proxy-agent: Sun-Java-System-Web-Proxy-Server/4.0
Via: 1.1 proxy-server1
Connection: close
]

<[:$line=>/^\r\n$/
my file
]
server.stop
<[
/stopped/
]


