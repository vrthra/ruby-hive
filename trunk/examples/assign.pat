cr '0'
title 'generic cli'

take Cli
>[
cat input/mexico.out
]

<[:$line => /^$/
/(1+) (1)/
/(2+) (2+)/
/(3+) (3+)/
]


matches.keys.each {|m|
    puts matches[m][1][2]
}

matches.keys.each {|m|
    puts matches[m][1][1]
}

<[
44444444
55555555
]


#------------------------------------
