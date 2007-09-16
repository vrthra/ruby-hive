cr '0'
title 'generic connect'

puts "Connect requires the server name to be specified because of stupid blr03 domain system"
puts "It also requires modification of obj.conf for allowing all ports thru on connect://"

server.start

>[
CONNECT #{opt.server_host_port} HTTP/1.0

]
<[:$line=>/^\r\n$/
HTTP/1.1 200 OK
Server: Sun-Java-System-Web-Proxy-Server/4.0
/Date: .*/
Connection: close

]
#now upgrade to ssl
info "Upgrading to SSL"
take SSLProxyClientConn,conn

>[
GET /index.html HTTP/1.0

]

#it is being sent by us so no CRLF
<[:$line=>/^$/
HTTP/1.0 200 OK
Server: PAT/1.0
Content-type: text/html

]

<[:$line=>/^$/, :strict => true, :seq => true
<html>
    <head>
                <title>Phoenix</title>
        <link rel="SHORTCUT ICON" href="phoenix.png"/>
    </head>
    <frameset rows="170,*" frameborder="no" border="0">
        <frame src="header.html" name="header" frameborder="no" scrolling="no" noresize marginwidth="0" marginheight="0"/>
        <frame src="content.html" name="content" frameborder="no" noresize marginwidth="0" marginheight="0"/>
    </frameset>
</html>
]

server.stop
<[
/stopped/
]

