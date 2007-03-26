cr '0'
title 'generic get request'

<[:$line=>/^\r\n$/
/GET \/[0-9]+ HTTP\/1.1/
Proxy-agent: Sun-Java-System-Web-Proxy-Server/4.0
/Host: .*/
/Via: 1.0 .*/
Connection: keep-alive

]
>[
HTTP/1.1 200 OK
Server: PAT/1.0
XDate: Sun, 07 May 2006 00:13:46 GMT
Content-length: 437
Content-type: text/html
Last-modified: Wed, 22 Mar 2006 16:09:50 GMT
Etag: "1a7-442176ce"
Accept-ranges: bytes

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

