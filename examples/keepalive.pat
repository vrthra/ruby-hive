cr '0'
title 'generic keepalive'

@server.start

>[
GET http://#{@options.server_host_port}/keepalive/1/#{Time.now.to_i} HTTP/1.1
Host: #{@options.server_host_port}
Connection: keep-alive

]

<[:$line=>/^\r\n$/
HTTP/1.1 200 OK
/Date: .*/
Content-length: 438
Content-type: text/html
Server: PAT/1.0
Last-modified: Wed, 22 Mar 2006 16:09:50 GMT
Etag: "1a7-442176ce"
Accept-ranges: bytes
/Via: 1.1 .*/
Proxy-agent: Sun-Java-System-Web-Proxy-Server/4.0

]
#we lost one CR in the delim
<[:$line=>/^\r\n$/, :strict => true, :seq => true
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

#info "going for the second request"

>[
GET http://#{@options.server_host_port}/keepalive/2/#{Time.now.to_i} HTTP/1.1
Host: #{@options.server_host_port}
Connection: keep-alive

]
<[:$line=>/^\r\n$/
HTTP/1.1 200 OK
/Date: .*/
Content-length: 438
Content-type: text/html
Server: PAT/1.0
Last-modified: Wed, 22 Mar 2006 16:09:50 GMT
Etag: "1a7-442176ce"
Accept-ranges: bytes
/Via: 1.1 .*/
Proxy-agent: Sun-Java-System-Web-Proxy-Server/4.0
]
<[:$line=>/^\r\n$/, :strict => true, :seq => true
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


