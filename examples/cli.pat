cr '0'
title 'generic cli'

take Cli
>[
cat input/mexico.out
]
<[:$line => /^$/
1111111 1
222222 22
33333 333
]
<[
44444444
55555555
]

>[
cat input/mexico.out
]
<[:when? => /abc/
aaaaaaa a
]
<[:when? => /111/
1111111 1
]

if false

>[
cat input/mexico.out
]
<[:when? => /111/
aaaaaaa a
]
<[:when? => /abc/
1111111 1
]
end
#------------------------------------
