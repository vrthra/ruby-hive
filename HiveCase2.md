HiveCase2

A notification needs to be sent to 2 channels #solaris, #windows when a mail arrives in
our name in the watching machine (let us call it _watchmachine).
The members in each of these channels will have to mail to testresults@hivehome.com on completion of the tests._

## Setting up the mailwatcher. ##

**mailwatcher.seq**
```
 [channel => '#hive'
 !do $me:tell[#solaris,#windows:initprocs] where $my:name =~/watchmachine/ when $mailwatch:mails[new:.*]
 ]
```

## Setting up the testmachines, ##


**tests.seq**
```
 ['#solaris','#windows'].each do |c|
 [channel => c
 !do $me:map[result:$pat:start[-s mytests.seq]] $mail:send[testresults@hivehome.com:$me:map[result]]
 ]
 end
```

note the usage of map variable here. (It can be done another way with out the map variable as I will show in wrap up)


## Wrapping it all up. ##

**case2.seq**
```
 [channel => '#hive'
 !do $me:tell[#solaris,#windows:initprocs] where $my:name =~~ /watchmachine/ when $mailwatch:mails[new:.*]
 ]
 ['#solaris','#windows'].each do |c|
 [channel => c
 !do $mail:send[testresults@hivehome.com:$pat:start[-s mytests.seq]]
 ]
 end
```

Here, the pat:start will get executed before the mailsend as it is with in the args of mail.

now go to #hive channel and do this.
```
   !do $me:seq[case2]
```