cr '0'
title 'cli - fails'

#should fail because of the extra XX

take Cli
>[
cat input/mexico.out
]
<[
1111111 1XX
]

#------------------------------------
