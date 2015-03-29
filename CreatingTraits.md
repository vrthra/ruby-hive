All the traits reside in hiveclient/traits directory in the webserver.
After creating your traitfile.rb, you have to put it in this directly and
it will migrate automatically to needed systems


## Simplest ##
> does nothing but allows
> `!do $simple:version`

  * simple.rb

```
 require 'basetrait'
 class SimpleTrait
    include BaseTrait
    def init()
        @version = 0.1
        @inspect = "#{@inspect}"
    end
    def run(cmd, args)
        puts "I got invoked"
    end
 end
 @traits['simple'] = SimpleTrait.new(self)
```

## Returns a message on getting hi trait ##

  * hi.rb
> invoke as
> `!do $hi:hi[mexico]`

```
 require 'basetrait'
 class HiTrait
    include BaseTrait
    def init()
        @version = 0.1
        @inspect = "#{@inspect}"
    end
    def run(cmd, args)
        case cmd
        when /hi/
            return "hi for #{args}"
        else
            return "say hi please"
        end
    end
 end
 @traits['hi'] = HiTrait.new(self)
```

  * hi.rb with help text.
> invoke as
> `!do $hi:help`

```
 require 'basetrait'
 class HiTrait
    include BaseTrait
    def init()
        @version = 0.1
        @inspect = "#{@inspect}"
    end
    def run(cmd, args)
        case cmd
        when /hi/
            return "hi for #{args}"
        else
            return "say hi please"
        end
    end
    def help
        usage << USAGE
Help #{self.to_s}
$he:hi -> says hi.
USAGE
    end
 end
 @traits['hi'] = HiTrait.new(self)
```


## Sends something to a user or channel ##
  * hello.rb
> `!do $hello:hi[#db]`
or
> `!do $hello:hi[mynickname]`

```
 require 'basetrait'
 class HelloTrait
    include BaseTrait
    def init()
        @version = 0.1
        @inspect = "to #{@inspect}"
    end
    def run(cmd, args)
        case cmd
        when /^hi/i
            chan = args
            @trait.send_message chan, "Hello"
            return "sent to #{chan}"
        else
            return "nomatch: #{cmd} - #{args}"
        end
    end
 end
 @traits['msg'] = HelloTrait.new(self)
```

## Watches all communication ##

```
 require 'basetrait'
 class SpyTrait
    include BaseTrait
    def init()
        @version = 0.1
        @inspect = "#{@inspect}"
        @exps = []
        @trait.on(:privmsg) do |user, channel, msg|
            @exps.each {|e,cmd,channel|
                 puts "msg #{cmd} in #{channel}"
            }
        end
        @trait.on(:part) do |user, channel, msg|
            @exps.each {|e,cmd,channel|
                 puts "part #{cmd} in #{channel}"
            }
        end
        @trait.on(:join) do |user, channel|
            @exps.each {|e,cmd,channel|
                 puts "join #{cmd} in #{channel}"
            }
        end
    end
 end
 @traits['spy'] = SpyTrait.new(self)
```