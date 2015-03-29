[Triggers](Triggers.md)
## Actions that can cause a trigger ##
join
part
privmsg

# Creating Triggers #
## Inline Triggers ##

Inline triggers are simple to create. They come in two major forms:

  1. A single command send to the machine that invokes the trigger
> `!create trigger mytr for join use !do $sys:rdate[hivehome] `


Here, the command `!do $sys:rdate[hivehome]` is sent to the machine that joins the current channel.

  1. A ruby block getting invoked in response to a triggered event
> `!create trigger mytr for join use {|machine,args|tell(machine,'welcome') if machine !~/^_/} `
Here, the ruby block gets executed with args machine,args.


## Persistant Triggers ##

Persistant triggers are those that are included directly in triggers.rb. An example below
```
trigger :mytrig do |channel, machine, action, args|
    case action 
    when /join/ 
        say '!do $system:version', machine do |reply|
            reply "got reply #{reply}" 
            reply "channel:#{channel} machine:#{machine} action:#{action} args:#{args}" 
        end
     when /part/ 
        reply "#{machine} leaving #{channel}" 
        reply "channel:#{channel} machine:#{machine} action:#{action} args:#{args}" 
    end 
    end 
end 
```

This is made use of below.
```
  !create trigger mytr for join use mytrig 
```

These triggers are also allowed to take an argument which will be available in @initargs inside the MyTrigger.
```
trigger :myargtrig do |channel, machine, action, args|
    @me.reply "Created with args #{@initargs}" 
end 
```

```
  !create trigger mytr for join use myargtrig(Created with this arg) 
```


# Using Triggers #

## Creating ##
General example:
```
  !create trigger dummyt on #hive for join use dummytrig 
```

Do it on default channel (no channel specified)
```
  !create trigger dummyt for join use dummytrig 
```

Do it with args
```
  !create trigger dummyt for join use dummytrig(myargs) 
```

Use Inline
```
  !create trigger mytr for join use !do $sys:rdate[hivehome] 
```

Use Inline second version
```
  !create trigger newtrig on #hive for part use {|machine,args| @me.send_message machine, '!do $sys:rdate[webproxy]'} 
```

## Dropping ##
General:
```
  !drop trigger dummytrig on #hive 
```

On current channel.
```
  !drop trigger dummytrig 
```

## Listing ##
List all triggers on channel
```
  !triggers on #hive 
```

Assume channel
```
  !triggers 
```

Triggers for action 'join'
```
  !triggers on #hive for join 
```

Triggers that use a particular procedure
```
  !triggers on #hive using dummytrig 
```

Triggers that use a particular procedure and for a particular action
```
  !triggers on #hive for join using dummytrig 
```