require 'patlib'
include PatLib
cr '0'
title 'generic ftp retrieve'

# passive port = l1*256 + l2
@l1 = 204
@l2 = 96
@passive_port = @l1 * 256 + @l2

@ip = ip_addr()

>[
220 #{opt.server_host} FTP server (Version 6.00LS) ready.
]

<[:$till=>'anonymous'
USER anonymous
]
>[
331 Guest login ok, send your email address as password.
]

<[:$till=> '@'
PASS SunProxy@
]
>[
230 Guest login ok, access restrictions apply.
]

<[:$till=>'SYST'
SYST
]
>[
215 UNIX Type: L8 Version: BSD-199506
]

<[:$till=>'PASV'
PASV
]
info "ftpretr:using passive port #{@passive_port}"

server.start :port => @passive_port, :tcase => 'examples/passivefile'

>[
227 Entering Passive Mode (#{@ip},#{@l1},#{@l2})
]


<[:$till=>'I'
/TYPE I/
]
>[
200 Type set to I.
]

<[:$till=>/RETR.*\n$/
/RETR .*/
]

>[
150 Opening BINARY mode data connection for '1234567890' (368 bytes) .
]


>[
226 Transfer complete.
]

server.stop
<[
/stopped/
]

