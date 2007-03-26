cr '0'
title 'generic get'

#@options.server_host_port = 'agneyam.india.sun.com:8882'
@server.start
<[
/exec/
]
puts "Using host:#{@options.server_host_port}"
puts "Using proxy:#{@options.proxy_host_port}"
>[
POST http://#{@options.server_host_port}/#{Time.now.to_i} HTTP/1.0
Content-length: 14

1111111111

]

<[:$line => /^\r\n$/
HTTP/1.1 200 OK
Content-length: 437
Content-type: text/html
Server: PAT/1.0
/Date: .*/
Last-modified: Wed, 22 Mar 2006 16:09:50 GMT
Etag: "1a7-442176ce"
Proxy-agent: Sun-Java-System-Web-Proxy-Server/4.0
Accept-ranges: bytes
Connection: close
/Via.*/

]

<[:strict => true, :seq => true
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

@server.stop
<[
/success/
]
