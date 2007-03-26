require 'basetrait'
require 'thread'
class ITrait
    include BaseTrait
    def init()
        @version = 0.1
        @inspect = "join part say tell restart reload seq session tag map group #{@inspect}"
        @watchtable = {}
    end
    def help
        usage <<EOU
$#{self.to_s[/^[^:]+/]}:join[#channel1,#channel2]
->Joins the specified channels
-
EOU
        usage <<EOU
$#{self.to_s[/^[^:]+/]}:part[#channel1,#channel2]
->parts the specified channels
$#{self.to_s[/^[^:]+/]}:part
->parts the current channel
EOU
    end
    def run(cmd, args)
        case cmd
        when /^join$/i
            args.split(/[ \t]+/).each {|chan|
                @me.join(chan)
            }
            return "#{@me.nick()}:#{@me.channels.keys.join(',')}"
        when /^part$/i
            case args
            when /^ *$/
                @me.part(@me.session[:channel])
            else
                args.split(/[ \t]+/).each {|chan|
                    @me.part(chan)
                }
            end
            persist
            return "#{@me.nick()}:#{@me.channels.keys.join(',')}"
        when /^channels$/i
            return "#{@me.channels.keys.join(' ')}"
        when /^say$/i
            case args
            when /^([^:]+):(.+)$/
                return @me.say($1,$2)
            else
                return @me.say(args)
            end
        when /^tell$/i
            case args
            when /^([^:]+):(.+)$/
                return @me.say($2,$1)
            else
                return @me.say(args)
            end
        when /^restart$/
            exit(0)
            return true
        when /^seq$/
            return @me.seq(args.strip)
        when /^session$/
            if args.nil? || args.empty?
                return @me.session.keys.join(' ')
            else
                return @me.session[args.strip.to_sym]
            end
        when /^reload$/
            return @me.reload(args.strip)
        when /^jobs$/
            @me.threads.keys.sort.each{|i|
                @me.say "[#{i}]=>" + @me.threads[i][:expr]
            }
            return @me.threads.length - 1
        when /kill/
            t = @me.threads[args.strip.to_i] 
            Thread.kill t if t
            return @me.threads.length - 1
        when /^tag$/
            if args.nil? || args.empty?
                return @me.tag
            else
                return @me.tag = args.strip
            end
        when /^group$/
            if args.nil? || args.empty?
                return @me.group.join(' ')
            else
                case args
                when /^\+(.+)/
                    @me.group << $1.strip
                when /^\-$/
                    @me.group.clear
                when /^\-(.+)/
                    @me.group.delete_if{|s| s == $1.strip}
                when /^\?(.+)/
                    return @me.group.include?($1.strip)
                else
                    return @me.group.include?(args.strip)
                end
                return @me.group.join(' ')
            end
        when /^map$/
            if args.nil? || args.empty?
                return @me.map.keys.collect{|k| k + ':' + @me.map[k] }.join(' ')
            else
                case args
                when /^([^:]+):(.+)/
                    return @me.map[$1.strip] = $2.strip
                else
                    return @me.map[args.strip]
                end
                return @me.map.keys.join(' ')
            end
        when /^(nick|host|name)$/
            return @me.nick()
        when /^os$/
            return @me.session[:os]
        when /^more$/
            return @me.more()
        when /^traits$/
           return @me.loaded_traits.join(" ")
        when /^classes$/
            unless args.nil? or args.empty?
               return $".grep(Regexp.new(args.strip)).join(' ')
            else
               return $".join(' ')
            end
        when /^unload$/
           unless args.nil?
               return $".delete_if{|i| i =~ Regexp.new(args.strip)}.join(" ") 
           else
               $".clear
           end
        else
            @me.send "#{cmd} #{args}"
            return ""
        end
        return ""
    end
end

@traits['i'] = ITrait.new(self)
