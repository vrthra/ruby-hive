cr '0'
title 'generic drb firing http requests'

take FtpFetchList,:host => 'webproxy.india.sun.com', :user => 'webproxy', :pass => 'webproxy' do
>[
docs/netdb/input
]

<[
inventory.xml
file
bib.xml
]
end

take FtpFetch,:host => 'webproxy.india.sun.com', :user => 'webproxy', :pass => 'webproxy' do
>[ :type => 'bin'
docs/index.html input/index.html
]

<[
input/index.html
]
end

take FtpFetch,:host => 'webproxy.india.sun.com', :user => 'webproxy', :pass => 'webproxy' do
>[ :type => 'text'
docs/index.html input/index.html
]

<[
input/index.html
]
end
