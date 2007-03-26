cr '0'
title 'generic socks4'
<[:$line=>/^\r\n$/
/GET \/index\.html HTTP\/1.0/

]
>[
HTTP/1.1 200 OK
Server: PAT/1.0
Content-type: text/html

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

