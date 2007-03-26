cr '0'
title 'generic drb firing http requests'

puts "DRB needs drb://vayavyam machine up."
#machines = [ "vayavyam", "vaishnavam", "draco"]
machines = [ "vayavyam"]


c = HttpConn.new('webproxy.india.sun.com')
machines.each do |machine|
take Machine,machine, c do

>[
GET / HTTP/1.0

]


<[:$line=>/^\r\n$/
HTTP/1.1 200 OK
Content-type: text/html
/Content-length: .*/
Server: Sun-Java-System-Web-Proxy-Server/4.0.4
/Date: .*/
/Last-modified: .*/
Accept-ranges: bytes
Connection: close

]

<[:strict=>true, :seq=>true
<html>
    <head>
  <title>Phoenix</title>
        <link rel="SHORTCUT ICON" href="phoenix.png"/>
    </head>
    <frameset rows="195,*" frameborder="no" border="0">
        <frame src="header.html" name="header" frameborder="no" scrolling="no" noresize marginwidth="0" marginheight="0"/>
        <frame src="content.html" name="content" frameborder="no" noresize marginwidth="0" marginheight="0"/>
    </frameset>
</html>
]
end
end
