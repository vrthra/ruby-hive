cr '0'
title 'Login to webserver'
@host = 'webt193'
@domainname = 'india.sun.com'

take HttpConn, @host do 
>[
GET /index.html HTTP/1.0

]

<[
HTTP/1.1 200 OK
]
end

take HttpConn, @host do 
>[
GET /amconsole/base/AMAdminFrame?&amconsoleRedirect=1&M0fajtkiS1lHksCyxHC1wD5ohK6HAJVhA4Hl8RqCks9akAJxHRrUhX5sqfqMkryCqQdejAGwmDGxGgGR HTTP/1.1
Host: #{@host}.#{@domainname}
User-Agent: Mozilla/5.0 (X11; U; SunOS sun4u; en-US; rv:1.7) Gecko/20060120
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Keep-Alive: 300
Connection: keep-alive
Referer: http://#{@host}.#{@domainname}/amconsole/

]

<[ 'case' => true
HTTP/1.1 200 OK
/Set-cookie: JSESSIONID=([^;]+);.*/
]
end

jsessionid = matches['Set-cookie: JSESSIONID=([^;]+);.*'][1][1]


take HttpConn, @host do 
>[
GET /amserver/UI/Login?service=adminconsoleservice&goto=/amconsole/base/AMAdminFrame&&M0fajtkiS1lHksCyxHC1wD5ohK6HAJVhA4Hl8RqCks9akAJxHRrUhX5sqfqMkryCqQdejAGwmDGxGgGR&org=dc%3Dindia%2Cdc%3Dsun%2Cdc%3Dcom&gx_charset=UTF-8 HTTP/1.1
Host: #{@host}.#{@domainname}:80
User-Agent: Mozilla/5.0 (X11; U; SunOS sun4u; en-US; rv:1.7) Gecko/20060120
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Keep-Alive: 300
Connection: keep-alive
Referer: http://#{@host}.#{@domainname}/amconsole/base/AMAdminFrame?&amconsoleRedirect=1&M0fajtkiS1lHksCyxHC1wD5ohK6HAJVhA4Hl8RqCks9akAJxHRrUhX5sqfqMkryCqQdejAGwmDGxGgGR
Cookie: JSESSIONID=#{jsessionid}

]
<[ 'case' => true
HTTP/1.1 200 OK
/Set-cookie: AMAuthCookie=([^;]+);.*/
/Set-cookie: amlbcookie=([^;]+);.*/
/Set-cookie: JSESSIONID=([^;]+);.*/
]
end

amauthcookie= matches['Set-cookie: AMAuthCookie=([^;]+);.*'][1][1]
amlbcookie= matches['Set-cookie: amlbcookie=([^;]+);.*'][1][1]
jsessionid = matches['Set-cookie: JSESSIONID=([^;]+);.*'][1][1]

take HttpConn, @host do 
>[
POST /amserver/UI/Login HTTP/1.1
Host: #{@host}.#{@domainname}
User-Agent: Mozilla/5.0 (X11; U; SunOS sun4u; en-US; rv:1.7) Gecko/20060120
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Keep-Alive: 300
Connection: keep-alive
Referer: http://#{@host}.#{@domainname}/amserver/UI/Login?service=adminconsoleservice&goto=/amconsole/base/AMAdminFrame&&M0fajtkiS1lHksCyxHC1wD5ohK6HAJVhA4Hl8RqCks9akAJxHRrUhX5sqfqMkryCqQdejAGwmDGxGgGR&org=dc%3Dindia%2Cdc%3Dsun%2Cdc%3Dcom&gx_charset=UTF-8
Cookie: JSESSIONID=#{jsessionid}; AMAuthCookie=#{amauthcookie}; amlbcookie=#{amlbcookie}
Content-Type: application/x-www-form-urlencoded
Content-Length: 142

IDToken0=&IDToken1=amAdmin&IDToken2=adminadmin&IDButton=Log+In&goto=L2FtY29uc29sZS9iYXNlL0FNQWRtaW5GcmFtZQ%3D%3D&encoded=true&gx_charset=UTF-8

]

<[ 'case' => true
HTTP/1.1 302 Moved Temporarily
/Set-cookie: iPlanetDirectoryPro=([^;]+);.*/
/Set-cookie: AMAuthCookie=([^;]+);.*/
]
end

amauthcookie= matches['Set-cookie: AMAuthCookie=([^;]+);.*'][1][1]
iplanetdirpro= matches['Set-cookie: iPlanetDirectoryPro=([^;]+);.*'][1][1]

take HttpConn, @host do 
>[
GET /amconsole/base/AMAdminFrame HTTP/1.1
Host: #{@host}.#{@domainname}
User-Agent: Mozilla/5.0 (X11; U; SunOS sun4u; en-US; rv:1.7) Gecko/20060120
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Keep-Alive: 300
Connection: keep-alive
Referer: http://#{@host}.#{@domainname}/amserver/UI/Login?service=adminconsoleservice&goto=/amconsole/base/AMAdminFrame&&M0fajtkiS1lHksCyxHC1wD5ohK6HAJVhA4Hl8RqCks9akAJxHRrUhX5sqfqMkryCqQdejAGwmDGxGgGR&org=dc%3Dindia%2Cdc%3Dsun%2Cdc%3Dcom&gx_charset=UTF-8
Cookie: JSESSIONID=#{jsessionid}; amlbcookie=#{amlbcookie}; iPlanetDirectoryPro=#{iplanetdirpro}

]

<[ 'case' => true
HTTP/1.1 200 OK
/Set-cookie: JSESSIONID=([^;]+);.*/
]
end

jsessionid = matches['Set-cookie: JSESSIONID=([^;]+);.*'][1][1]

