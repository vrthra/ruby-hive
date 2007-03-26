cr '0'
title 'generic file conn'

take FileConn,'input/file', 'w' do
>[
1111111 1x
222222 22x
33333 333x
]
end
take FileConn,'input/file', 'r' do
<[
1111111 1x
222222 22x
33333 333x
]
end
#------------------------------------
