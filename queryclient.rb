module Agent
    require "socket"
    require "strscan"
    require 'ircclient'
    include IrcClient
    require 'netutils'

    #=================dbactor==============================
    require 'net/http'
    require "thread"
    require "yaml"
    include YAML
    require 'connectors'
    include Connectors
    
    require 'config'
    include Config

    require "collector"
    # The irc class, which talks to the server and holds the main event loop

    class Store
        def initialize(me,p)
            @me = me
            @proc = p
        end

        def invoke(str)
            @block.call(str)
        end

        def reply(str)
            @me.reply str
        end
        
        def tell(channels,msg)
            channels.split(/,/).each{|c|
                @me.send_message c.strip, msg
            }
        end
        def say(msg, channels, &block)
            channels.split(/,/).each{|c|
                @me.send_message c.strip, msg
            }
            if block_given?
                result = @me.get_reply channels
                result.each{|k,v|
                    block.call(k,v)
                }
            end
        end

        def query(statement,&block)
            @me.query(statement).each {|r|
                machine = r[0]
                exp = r[1]
                block.call(machine,exp) if block_given?
            }
        end
    end

    class Trigger
        @@mutex = Mutex.new
        def initialize(sym,me,args,p)
            @sym = sym
            @me = me
            @initargs = args
            @proc = p

        end

        def context
            return @me
        end

        def create(args)
            t = self.class.new(@sym,@me,args,@proc)
            @me.reply "creating new trigger[#{args}]"
            return t
        end

        def attach(channel)
            @me.reply "attaching to #{channel}"
        end

        def detach(channel)
            @me.reply "detaching from #{channel}"
        end

        def invoke(channel, machine, action, args)
            #invoke the current rather than what we have. It may have been redefined in a reload.
            @@mutex.synchronize {
                p = @proc[@sym.to_s]['proc'].context
                puts ".............#{@initargs}"
                p.initargs(@initargs)
                p.invoke channel, machine, action, args
            }
        end
    end

    class SqlProc
        def initialize(me,block)
            @me = me
            @block = block
        end

        def invoke(str)
            @block.call(str)
        end
    end

    class TriggerStore < Store
        def trigger(sym,&block)
            begin
                obj = Trigger.new(sym,self,nil,@proc)
                @block = block
                @proc[sym.to_s] = {'proc' => obj}
            rescue Exception => e
                puts e.message
                puts e.backtrace
            end
        end
        def initargs(args=nil)
            return @initargs if args.nil?
            return @initargs = args
        end
        def invoke(channel, machine, action, args)
            @block.call channel, machine, action, args
        end
    end
    
    class InlineTrigger < Trigger
        def initialize(me, store, exp)
            #exp will have the following args.
            #no channel no action
            #machine,args
            @store = store
            case exp
            when /^\{(.*)\} *$/
                x = $1
                @exp = @store.instance_eval <<-EP
                    proc {|machine,args| #{x} }
                EP
            when /^!.*/
                @exp = @store.instance_eval do
                    proc {|machine,args|
                        begin
                            say(exp,machine){|m,r|
                                reply m + ':' + r
                            } if machine =~ /^_/ 
                        rescue Exception => e
                            puts e.message
                            puts e.backtrace
                        end
                    }
                end
            end
            super(:inline,me,nil,nil)
        end
        def invoke(channel,machine,action,args)
            @channel = channel
            @action = action
            @machine = machine
            @args = args
            @exp.call(machine,args)
        end
    end


    class TriggerClient
        include NetUtils
        def initialize(irc)
            @irc = irc
            @invoke = []
            @eventqueue = []
            @lock = Mutex.new
            @buflock = Mutex.new
            @cv = ConditionVariable.new
            @bufcv = ConditionVariable.new
            @proc = {}
            
            @triggers = TriggerStore.new(self,@proc)
            @triggers.instance_eval get_resource('triggers')
        end

        def store
            @triggers
        end

        def reload_triggers
            @triggers.instance_eval get_resource('triggers')
        end

        def is_trigger(funct)
            if funct =~ /^([^\[\]]+)\[.+\]$/
                obj = @proc[$1]
            else
                obj = @proc[funct]
            end
            return !obj.nil? && !obj['proc'].nil?
        end

        def get_trigger(funct)
            obj = nil
            case funct
            when /^!.*/
                return InlineTrigger.new(self,@triggers,funct)
            when /^\{.*/
                return InlineTrigger.new(self,@triggers,funct)
            when /^([^\[\]]+)\[(.+)\]$/
                return @proc[$1]['proc'].create($2)
            else
                return @proc[funct]['proc'].create("")
            end
        end

        
        def start
            @thread = Thread.new {
                puts "starting trigger thread.."
                while true
                    begin
                        t = nil
                        @lock.synchronize {
                            @cv.wait(@lock) if @invoke.empty?
                            t = @invoke.shift
                        }
                        run t
                    rescue Exception => e
                        carp e
                        exit 0
                    end
                end
            }
        end

        def run(t)
            clear_input_buffer
            t['obj'].invoke(t['channel'], t['machine'], t['action'], t['args'])
        end

        def clear_input_buffer
            @buflock.synchronize { @eventqueue.clear }
        end

        def invoke_trigger(obj, machine, channel, action, args)
            trig = {}
            trig['obj'] = obj
            trig['machine'] = machine
            trig['channel'] = channel
            trig['action'] = action
            trig['args'] = args
            @lock.synchronize {
                @invoke << trig
                @cv.signal
            }
        end
        
        def push(user, channel, message)
            @buflock.synchronize {
                @eventqueue << [user,channel,message]
                @bufcv.signal
            }
        end

        def get_reply(machines)
            m = machines.split(/,/).collect{|x|x.strip}
            result = {}
            while true
                user,channel,msg = get_trig_input()
                if m.include?(user)
                    result[user] = msg
                    m.delete(user)
                end
                return result if m.empty?
            end
        end

        def reply(arg)
            @irc.reply arg
        end

        def send_message(channel, msg)
            @irc.send_message channel, msg
        end

        def get_trig_input
            #block until we have some thing to read.
            @buflock.synchronize {
                @bufcv.wait(@buflock) if @eventqueue.empty?
                return @eventqueue.shift
            }
        end
    end
    class ProcStore < Store

        def procedure(sym,&block)
            obj = SqlProc.new(self,block)
            @proc[sym.to_s] = {'proc' => obj}
        end

    end


    class SqlClient
        include NetUtils
        def initialize(irc)
            @irc = irc
            @inputbuf = []
            @db = {}
            @querybuf = []
            @config = {"v" => 0, 
                'sep' => '===========================================',
                'showhead' => true, 
                'more' => ''}
            @ignore = []
            @headding  = "-----------------"
            @lock = Mutex.new
            @return_channel = nil
            @cv = ConditionVariable.new

            @proc = (File.open('proc.yaml'){|f|YAML::load(f)} if FileTest.exists? 'proc.yaml') || {}

            @procedures = ProcStore.new(self,@proc)
            @procedures.instance_eval get_resource('procedures')
        end

        #procedure :os do

        def start
            @thread = Thread.new {
                puts "starting query thread.."
                while true
                    begin
                        input = get_input
                        type,user,channel,msg = input
                        handle_msg(user,channel,msg ,false) if type == :privmsg 
                    rescue Exception => e
                        carp e
                        exit 0
                    end
                end
            }
        end

        def push(*args)
            @lock.synchronize {
                @inputbuf << args
                @cv.signal
            }
        end

        def get_input
            #block until we have some thing to read.
            @lock.synchronize {
                @cv.wait(@lock) if @inputbuf.length == 0
                return @inputbuf.shift
            }
        end
        
        def reply(data)
            @irc.send_message(@return_channel, data)
        end

        def current_channel
            @return_channel
        end

        def store_query(cmd)
            reply("stored[#{@querybuf.length}]")
            @querybuf << cmd
        end

        def handle_msg(user,channel, cmd, is_busy)
            @return_channel = (channel == @irc.nick ? user : channel)
            case cmd.strip
            when /^!(.+)$/i
                if !is_busy
                    invoke_query($1) 
                else
                    store_query($1)
                end
            when /^:(.+)$/i
                invoke_command($1)
            else
                #store it in users last reply?
            end
        end
        
        def handle_ignore(cmd, act)
            machines = cmd.split(/ +/)
            machines.each{|m|
                m.chomp!
                if act
                    @ignore << m if !@ignore.include?(m)
                else
                    @ignore.delete_if {|i| i == m }
                end
            }
            reply(@ignore.join(" "))
        end
        
        def handle_use(c)
            cmd = c
            args = nil
            case c
            when /^([a-zA-Z0-9_-]+) *$/
                cmd = $1
                args = nil
            when /^([a-zA-Z0-9_-]+) +(.*)$/
                cmd = $1
                args = $2
            when /^([a-zA-Z0-9_-]+)\[+(.*)\]$/
                cmd = $1
                args = $2
            end
            if @proc[cmd].nil? 
                #reply ""
            else
                if !@proc[cmd]['sql'].nil? 
                    handle_sql(@proc[cmd]['sql'], args)
                else
                    @proc[cmd]['proc'].invoke(args)
                end
            end
        end

        def handle_help
            reply ":list [:list -lists the saved queries]"
            reply ":save [:save name=query -saves the query under 'name' the parameters used are @0, @1 etc..]"
            reply ":set [:set name=value -saves the variable under 'name']"
            reply ":set [:set name -show value of variable under 'name']"
            reply ":show [:show name -shows the saved query or stored procedure]"
            reply ":ignore [:ignore host -ignores the host for fetching results of queries]"
            reply ":break [:break -ask hive to stop waiting for machines yet to respond]"
            reply ":now [:now -shows the results fetched and the machines yet to respond]"
            reply ":clear [:clear -clears the query stack including the current query]"
            reply ":reload [:reload -reloads the triggers.rb and procedures.rb]"
            reply ":stack [:stack -shows the contents of the query stack]"
            reply ":$procedure [:$.. - executes the procedure]"
        end

        def handle_set(cmd)
            case cmd
            when /^([^=]+)=(.+)$/
                @config[$1] = $2
                reply "#{$1} => #{$2}"
            when /^([^=]+)$/
                reply "#{$1} => #{@config[$1]}"
            else
                @config.keys.each {|c| reply "#{c} => #{@config[c]}" }
            end
        end

        def handle_sql(sql, strargs)
            args = strargs.split(/,/)
            mysql = sql
            for i in 0...args.length
                mysql = mysql.gsub(Regexp.new("@#{i}"), args[i].strip)
            end
            invoke_query(mysql)
        end

        def handle_show(cmd)
            if @proc[cmd].nil? 
                #reply ""
            else
                if !@proc[cmd]['sql'].nil? 
                    reply @proc[cmd]['sql']
                else
                    reply "#{cmd}:procedure"
                end
            end
        end

        def handle_list(cmd)
            @proc.keys.each {|p|
                if !@proc[p]['sql'].nil? 
                    reply "#{p}:"+@proc[p]['sql']
                else
                    reply "#{p}:procedure"
                end
            }
        end

        def handle_stack()
            if !@querybuf.empty?
                @querybuf.each {|q| reply q }
            else
                reply "no stack"
            end
        end

        def handle_save(cmd, val)
            return if val.nil?
            @proc[cmd] = {'sql' => val}
            File.open("proc.yaml","w") {|f| f.puts @proc.to_yaml }
            reply "saved #{cmd}"
        end

        def handle_now(nicks,result, cmd)
            rkeys = result.keys.collect{|x| x.split(':')[0]}
            found = ""
            notfound = "["
            nicks.each{|n|
                if !rkeys.include?(n)
                    notfound += " #{n}"
                else
                    found += " #{n}" 
                end
            }
            reply cmd
            reply @headding
            reply found + " " + notfound + "]"
            handle_reply(result)
        end

        #=====================================================
        include Collector
        #=====================================================
        def collect(id, action, var)
            c = nil
            @db[id].each {|item|
                c = "''" if c.nil?
                c = "#{action}(#{c}, '#{item}')"
            }
            @db[id] = nil
            return "#_REMOVE_{#{c}}"
        end

        def provide(id, action, var)
            @db[id] = [] if @db[id].nil?
            @db[id] << var
        end

        def join_select(key)
            return "$irc.join(#{key})"
        end

        def part_select(key)
            return "$irc.part(#{key})"
        end

        def update_select(key)
            return "$system.sync(#{key})"
        end

        def process_channel(args)
            return args.split(/ *, */)
        end

        def process_statement(stat, action)
            e = StringScanner.new(stat)
            c = -1
            result = ""
            br = []
            id = 0
            while !e.eos?
                #puts "#.#{result}"
                #puts "[#{br}]=>#{stat[e.pos()..-1]}"
                if e.pos() == c
                    puts "partial:#{result}"
                    return "partial:#{result}"
                end
                c = e.pos()

                if !e.scan(/:/).nil?
                    token = e.scan(/[a-zA-Z0-9_.-]+/)
                    if !token.nil? 
                        if !e.scan(/\(/).nil?
                            br << "')}"
                            result += "#_REMOVE_{#{action}(#{id},'#{token}','"
                            id += 1
                            next
                        else
                            result += token
                            next
                        end
                    else
                        result += ":"
                    end
                end

                token = e.scan(/[a-zA-Z0-9_-]+/)
                if !token.nil?
                    result += token
                end

                if !e.scan(/\)/).nil?
                    b = br.pop
                    result += b if !b.nil?
                end

                if !e.scan(/\(/).nil?
                    br << ")"
                    result += "("
                end


                delim = e.scan(/[^:a-zA-Z0-9_()-]+/)
                if !delim.nil?
                    result += delim
                end
            end
            return result
        end

        #substitutes [xxx + yyy] expressions locally into their values
        def process_local(res)
            return "" if res.nil?
            e = StringScanner.new(res)
            c = -1
            result = ""
            br = []
            while !e.eos?
                #puts "#.#{result}"
                #puts "[#{br}]=>#{res[e.pos()..-1]}"
                if e.pos() == c
                    puts "partial:#{result}"
                    return "partial:#{result}"
                end
                c = e.pos()

                if !e.scan(/\[/).nil?
                    token = e.scan(/[^\]]+/)
                    if !token.nil?
                        result += "#{eval(token)}"
                        e.scan(/\]+/)
                    else
                        result += "["
                    end
                end
                oth = e.scan(/[^\[]+/)
                if !oth.nil?
                    result += oth
                end
            end
            return result
        end

        #process :sum(xxx) thingies
        def process_results(res)
            return "" if res.nil? 
            template = nil
            res.keys.each {|r|
                val = res[r]
                next if val.nil?
                if template.nil?
                    template = process_statement(val,"collect").gsub(/_REMOVE_/,"")
                end
                newval = process_statement(val,"provide")
                newval.gsub!(/_REMOVE_/,"")
                s = <<-END
s=<<EOS
#{newval}
EOS
                END
                eval(s)
            }
            out = eval("s=\"#{template}\"")
            out.gsub!(/_REMOVE_/,"")
            nout = eval("s=\"#{out}\"")
            return nout
        end

        def handle_reply(result)
            if @collect
                #first group by the key:group thingies
                #then for each group exec the template.
                group = {}
                result.keys.each do |res|
                    case res
                    when /^([^:]+):(.*)$/
                        group[$2] = {} if group[$2].nil?
                        group[$2][$1] = result[res]
                    end
                end
                group.keys.each do |g|
                    res = process_results(group[g])
                    res = process_local(res)
                    if @config['v'].nil? or @config['v'].to_i == 0
                        reply(res)
                    else
                        reply("#{g}| #{res}")
                    end
                end
            else
                result.keys.each do |key|
                    next if result[key].nil? 
                    res = result[key]
                    #res = process_local(res)
                    #we already allow that in remote via ruby.eval
                    if @config['v'].nil? or @config['v'].to_i == 0
                        reply(res)
                    else
                        reply("#{key} #{res}")
                    end
                end
            end
        end

        def invoke_query(cmd)
            case cmd
            when /^sequence (.+)$/
                result = query("select #{$1}")
                nicks = @newnicks
                remaining = result.keys.collect{|key| key.split(':')[0]}
                @newnicks = []
                result.keys.sort.each do|key|
                    mynick = key.split(':')[0]
                    @newnicks << mynick if  nicks.include? mynick
                    remaining.delete_if{|x| x == mynick }

                    if !@config['showhead'].nil? && @config['showhead'] != false
                        reply(@config['sep'])
                        reply "#{mynick} [#{remaining.sort.join(",")}]"
                        reply(@config['sep'])
                    end

                    handle_reply({key => result[key]})
                    while !@newnicks.empty?
                        handle_reply(collect_result(do_action(@newnicks,"!more"), cmd))
                    end
                end
            when /^select +(.+) +from +(.+)$/
                if !@config['showhead'].nil? && @config['showhead'] != false && @config['showhead'] != 'false'
                    reply(@config['sep'])
                    reply "#{$1}"
                    reply(@config['sep'])
                end
                handle_reply(query(cmd))
                while !@newnicks.nil? && @newnicks.length > 0
                    handle_reply(collect_result(do_action(@newnicks,"!more"), cmd))
                end
            when /^insert/
                handle_reply(query(cmd))
            when /^delete/
                handle_reply(query(cmd))
            when /^update/
                handle_reply(query(cmd))
            when /^create +(.+)$/ 
                handle_create($1)
            when /^drop +(.+)$/ 
                handle_drop($1)
            when /^triggers *(.*)$/ 
                handle_list_triggers($1)
            else
                #ignore
            end

            #handle any query that was in buffer at that time.
            while @querybuf.length > 0
                q = @querybuf.pop
                if !q.nil?
                    reply q
                    reply @headding
                    invoke_query(q) 
                end
            end
        end

        def reload_procs
            @procedures.instance_eval get_resource('procedures')
        end

        def invoke_command(cmd)
            case cmd
            when /^ignore(.*)$/i
                handle_ignore($1.strip, true)
            when /^noignore(.*)$/i
                handle_ignore($1.strip, false)
            when /^use (.+)$/i
                handle_use($1.strip)
            when /^show (.+)$/i
                handle_show($1.strip)
            when /^set *(.*)$/i
                handle_set $1
            when /^save ([^=]+)=(.*)$/i
                handle_save($1.strip, $2.strip)
            when /^list(.*)/i
                handle_list($1.strip)
            when /^stack(.*)/i
                handle_stack()
            when /^help$/i
                handle_help
            when /^echo +(.+)$/i
                reply "#{$1}"
            when /^reload *$/i
                reload_procs
                @irc.tc.reload_triggers
                reply "#{$1}"
            when /^\$(.+)/
                handle_use($1.strip)
            else
                reply "->#{cmd}"
            end
        end

        def query(cmd)
            selectstr, chanstr, wherestr, groupbystr = "","","",""
            case cmd
            when /^select +(.+) +from +(.+) +where +(.+) +group +by +(.+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = $1,$2,$3,$4
            when /^select +(.+) +from +(.+) +group +by +(.+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = $1,$2,"1",$3
            when /^select +(.+) +from +(.+) +where +(.+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = $1,$2,$3,""
            when /^select +(.+) +from +(.+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = $1,$2,"1",""
            when /^insert +into +(#[a-zA-Z0-9_-]+) +from +(.+) +where +(.+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = join_select($1),$2,$3,""
            when /^insert +into +([^ ]+) +from +([^ ]+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = join_select($1),$2,"1",""
            when /^delete +from +(.+) +where +(.+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = part_select($1), $1,$2,""
            when /^delete +from +([^ ]+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = part_select($1), $1, "1", ""
            when /^update +(.+) +with +(.+) +where +(.+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = update_select($2), $1, $3, ""
            when /^update +(.+) +with +(.+)$/
                selectstr, chanstr, wherestr, groupbystr,cmd = update_select($2), $1, "1", ""
            else
                return {}
            end
            nicks = collect_nicks(selectstr, chanstr, wherestr, groupbystr ,cmd)
            return collect_result(do_action(nicks, "!where #{wherestr} do %:% #{groupbystr}%:% #{selectstr}"), cmd)
        end

        def do_action(nicks, action)
            nicks.each { |user|
                @irc.send_message(user, action)
            }
            return nicks
        end

        def collect_nicks(selectstr, chanstr, wherestr, groupbystr,cmd)
            @collect = if selectstr =~ /:[a-zA-Z0-9_-]+\(/ 
                           true 
                       else 
                           false 
                       end
            #TODO: change the [ ] into _LOCAL< and >_LOCAL_ so that remote 
            #wont touch it either.

            group = process_channel(chanstr)
            channel = group.grep(/^#/)
            nicks = group.grep(/^[^#]+/)
            nicks.concat(collect_nicks_from_channel(channel)) if !channel.empty?
            nicks.uniq!
            nicks.delete_if{|n| @ignore.include?(n) }
            return nicks
        end

        def handle_create(cmd)
            case cmd
            when /^trigger +([^ ]+) +on +(.+) +for +(.+) +use +(.+)$/
                @irc.create_trigger($1, process_channel($2), process_actions($3), $4)
            when /^trigger +([^ ]+) +for +(.+) +use +(.+)$/
                @irc.create_trigger($1, process_channel(self.current_channel), process_actions($2), $3)
            end
        end
        
        def handle_drop(cmd)
            case cmd
            when /^trigger +([^ ]+) +on +(.+) +for +(.+)$/
                @irc.drop_trigger($1, $2, $3)
            when /^trigger +([^ ]+) +on +(.+)$/
                @irc.drop_trigger($1, $2, "*")
            when /^trigger +([^ ]+) +for +(.+)$/
                @irc.drop_trigger($1, self.current_channel, $2)
            when /^trigger +([^ ]+) *$/
                @irc.drop_trigger($1, self.current_channel, "*")
            end
        end
        
        def handle_list_triggers(cmd)
            case cmd
            when /^on +(.+) +for +(.+)$/
                handle_list_trigger($1, $2, ".*")
            when /^for +(.+)$/
                handle_list_trigger(self.current_channel, $1, ".*")
            when /^on +(.+) +using +(.+)$/
                handle_list_trigger($1, ".*", $2)
            when /^using +(.+)$/
                handle_list_trigger(self.current_channel, ".*", $1)
            when /^on +(.+)$/
                handle_list_trigger($1, ".*", ".*")
            when /^ *$/
                handle_list_trigger(self.current_channel, ".*", ".*")
            end
        end

        def handle_list_trigger(chan, action, funct)
            begin
                triggers = @irc.get_trigger_for_channel(chan)
                triggers.keys.each do |name|
                    procs = triggers[name]
                    next if procs.nil?
                    fun = procs['name']
                    if fun =~ Regexp.new("^"+funct+"$")
                        acts = procs['action']
                        acts.each {|a|
                            if a =~ Regexp.new("^"+action+"$")
                                reply "trigger: on: #{chan} name: #{name} for: #{a} using: #{fun}"
                            end
                        }
                    end
                end
            rescue Exception => e
                reply e.message
            end
        end

        def process_actions(args)
            return args.split(/ *, */)
        end
        def is_defined(funct)
            obj = if funct =~ /^([^()]+)\(.+\)$/ 
                      @proc[$1] 
                  else 
                      @proc[funct] 
                  end
            return !obj.nil? && !obj['proc'].nil?
        end


        def collect_result(nicks, cmd)
            count = 0
            result = {}
            tot = nicks.length
            @newnicks = []
            while count < nicks.length && (tot < nicks.length + 10)
                input = get_input()
                type = input.shift
                if type == :numeric
                    server,numeric,message,det = input
                    case numeric
                    when ERR_NOSUCHNICK
                        #nosuch channel
                        if message =~ / *([^ ]+) +([^ ]+) */
                            nick = $1
                            chan = $2
                            result["#{$2}:invalid"] = "invalid:#{$2}"
                            count += 1
                        else
                            raise "401 message Invalid : #{message}"
                        end
                    end
                else
                    user,channel,msg = input
                    tot -= 0
                    #Handle all the relevant :commands here, leave handle_msg to figure out the rest.
                    case msg
                    when /^:now$/i
                        handle_now(nicks,result, cmd)
                    when /^:break$/i
                        break
                    when /^:clear$/i
                        @querybuf = []
                        break
                    when /^=([0-9]+): *%:%(.+)%:%(.*)$/i
                        #has more
                        count += 1
                        has_more = $1
                        @newnicks << user
                        result["#{user}:#{$2}"] = @config['more'] + "#{$3}".strip if $3.strip.length > 0
                    when /^= +%:%(.+)%:%(.*)$/i
                        count += 1
                        result["#{user}:#{$1}"] = "#{$2}".strip
                    when /^= *$/i
                        #where not.
                        count += 1
                    when /^= error.*$/i
                        count += 1
                        result["#{user}: "] = "error"
                    else
                        handle_msg(user,channel,msg, true)
                    end
                end
            end
            return result
        end

        def collect_nicks_from_channel(channel)
            nicks = []
            channel.each {|c| nicks.concat(names(c))}
            return nicks.grep(/^_/)
        end

        def names(channel)
            return @irc.names(channel)
        end
        #similar implementation to Actor names.
        #Placed here because we can controll our input queue.
        def pnames(channel)
            #will be invoked from a thread different from that of the
            #primary IrcConnector thread.
            names = []
            @irc.send_names channel
            @eventbuf = []
            while true
                #wait for numeric
                input = get_input
                method = input[0]
                if method != :numeric
                    @eventbuf << input
                else
                    method,server,numeric,msg,detail = input
                    case numeric
                    when ERR_NOSUCHNICK
                        carp "401"
                        #nosuch channel
                        if msg =~ / *([^ ]+) */
                            if $1 == channel
                                carp "401"
                                break
                            else
                                @eventbuf << input
                            end
                        else
                            carp "401 message Invalid : #{msg}"
                        end
                    when RPL_ENDOFNAMES
                        carp "#{RPL_ENDOFNAMES} :#{msg}:#{channel}"
                        #end of /names list
                        if msg =~ / *([^ ]+) */
                            if $1 == channel
                                carp "366 #{names}"
                                break
                            else
                                @eventbuf << input
                            end
                        else
                            carp "#{RPL_ENDOFNAMES} message Invalid : #{msg}"
                        end
                    when RPL_NAMREPLY
                        carp "#{RPL_NAMREPLY} - #{msg}"
                        if msg =~ / *= +([^ ]+)*$/
                            if $1 == channel
                                nicks = detail.split(/ +/)
                                nicks.each {|n| names << $1.strip if n =~ /^@?([^ ]+)/ }
                                carp "nicks #{nicks}"
                            else
                                @eventbuf << input
                            end
                        else
                            carp "#{RPL_NAMREPLY} message Invalid : #{msg}"
                        end
                    else
                        @eventbuf << input
                    end
                end
            end
            @lock.synchronize {
                @inputbuf = @eventbuf + @inputbuf
            }
            return names
        end

    end

    class DbActor < IrcClient::IrcActor
        def initialize(client, channel=nil)
            super(client)
            channel ||= $config['hive']
            @channel = channel
            @rchannel = channel
            @has_more = 0
            @listen_channels = {}
            @tc = TriggerClient.new(self)
            @qc = SqlClient.new(self)

            on(:connect) do |server, port, nick, pass|
                begin
                    @port = port
                    @nick = nick
                    client.send_join channel

                    @tc.start
                    @qc.start
                rescue Exception => e
                    carp e
                end
            end

            on(:privmsg) do |user, channel, msg|
                begin
                    @tc.push(user,channel,msg)
                    @qc.push(:privmsg,user,channel,msg)
                rescue Exception => e
                    carp e
                end
            end
            on(:join) do |nick, channel|
                begin
                    on_join(nick,channel)
                rescue Exception => e
                    carp e
                end
            end
            on(:part) do |nick, channel, msg|
                begin
                    on_part(nick,channel,msg)
                rescue Exception => e
                    carp e
                end
            end
            on(:numeric) do |server, numeric, msg, detail|
                begin
                    #qc is not initialized during the first numeric
                    @qc.push(:numeric,server,numeric,msg,detail) if @qc
                rescue Exception => e
                    carp e
                end
            end
        end

        def reply(msg)
            send_message @rchannel, msg
        end
        
        def tc
            return @tc
        end
        
        def nick
            return @nick
        end

        def make_proc(procs, funct, action, chan)
            procs['name'] = funct
            procs['action'] = action
            procs['obj'] = tc.get_trigger(funct)
            procs['obj'].attach(chan)
            return procs
        end

        def create_trigger(name, channel, action, funct)
            carp "creating trigger #{name} on #{channel.join(',')}"
            #check if the trigger with that name exists in any of the channels
            if !tc.is_trigger(funct) && funct !~ /^(\{|!)/
                reply "#{funct} is undefined"
                return
            end
            channel.each do |chan|
                c = @listen_channels[chan]
                if c.nil?
                    c = {'name'=> chan}
                    c['triggers'] = { name => make_proc({}, funct, action, chan)}
                    @listen_channels[chan] = c
                    join chan
                else
                    triggers = c['triggers']
                    if triggers.nil?
                        c['triggers'] = {name => make_proc({},funct,action,chan)}
                    else
                        #procs = triggers[name]
                        #if procs.nil?
                            triggers[name] = make_proc({},funct,action,chan)
                        #else
                        #    acts = procs['action']
                        #    if acts.nil?
                        #        make_procs(procs, funct, action,chan)
                        #    else
                        #        #add any extra actions
                        #        procs['action'] = action | acts
                        #    end
                        #end
                    end
                end
            end
        end

        def drop_trigger(name, chanstr, actions)
            channel = process_channel(chanstr)
            action = process_actions(actions)
            channel.each {|chan|
                c = @listen_channels[chan]
                next if c.nil?
                part chan
                triggers = c['triggers']
                next if triggers.nil?
                procs = triggers[name]
                next if procs.nil?
                if actions =~ /^\*$/
                    #remote all actions attached in that name
                    triggers.delete(name)
                else
                    acts = procs['action']
                    newacts = acts - action
                    if newacts.empty?
                        triggers.delete(name)
                    else
                        procs['action'] = newacts
                    end
                end
            }
        end

        def get_trigger_for_channel(channel)
            c = @listen_channels[channel]
            raise "no triggers" if c.nil?
            triggers = c['triggers']
            raise "no triggers" if triggers.nil?
            return triggers
        end

        def invoke_trigger(nick, channel, action, args)
            triggers = get_trigger_for_channel(channel)
            triggers.keys.each {|name|
                procs = triggers[name]
                next if procs.nil?
                fun = procs['name']
                acts = procs['action']
                acts.each {|a|
                    if action =~ Regexp.new("^"+a+"$")
                        tc.invoke_trigger(procs['obj'], nick, channel, action, args)
                    end
                }
            }
        end

        def on_join(nick,channel)
            begin
                invoke_trigger(nick, channel, 'join', '')
            rescue Exception => e
                reply e.message if $verbose
            end
        end
        def on_part(nick,channel,msg)
            begin
                invoke_trigger(nick, channel, 'part', msg)
            rescue Exception => e
                reply e.message if $verbose
            end
        end
    end







    #=====================================================

    # The irc class, which talks to the server and holds the main event loop
    def include(arg)
        Object.module_eval "include #{arg}"
    end
    #=====================================================
    class QueryClient < IrcClient::IrcConnector
        def initialize(server)
            super(server, 6667, $config['queen'] , 'hivepass')
            @actor = DbActor.new(self)
        end
        def QueryClient.start(home)
            begin
                raise "No home defined" if !home
                QueryClient.new(home).run
            rescue SystemExit
                return
            rescue Interrupt
                return
            rescue Exception => e
                carp e
                return
            end
        end
        #=====================================================
    end
end
