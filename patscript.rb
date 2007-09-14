module Pat
require 'socket'
require 'timeout'
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'
require 'matchworld'
require 'connectors'
require 'transform'
require 'patlog'

include MatchWorld
include Connectors
include Transform
include Patlog


DAY = 60*60*24
$active_connections = []

#perhaps I should have used webrick and net/http[s] but being a control freak..
#==============================================    
class Chunk
    def initialize()
        @lines = []
        @source = []
    end
    def <(str)
        @lines << str
        return self
    end
end

class Req < Chunk
    #I need macros *NOW*

    def initialize(opt)
        @lines = []
        @source = []
        @opt = opt
    end

    def compile()
        @source << %Q(
#=======<receive>)
        @source <<%Q[
    #=========================
    @expstr = <<__DATA
#{@lines}__DATA
    @exp = @expstr.split($/)
    @opt = {#{@opt}}
    @connection.opt(@opt)
    if @cdata.empty?
        read_all()
    end
    log_request @cdata
    #=========================
    @transforms = @restrans.clone
    transform(@exp, @opt)
    transform(@cdata, @opt)
    if try_match(@opt)
        match_txt(@exp, @cdata, @opt) 
        @cdata.clear
    end
]
      
        @source << %Q(
#=======</receive>)
        return @source
    end
end

class Res < Chunk

    def initialize(opt)
        @lines = []
        @source = []
        @opt = opt
    end

    def compile
        @source << %Q(
#=======<send>)
        response = @lines.join()
        @source <<%Q[
    @cdata.clear
    @sdata =<<__DATA
#{response}__DATA
    @opt = {#{@opt}}
    @connection.opt(@opt)
    #we dont really want to touch the data
    #other than defined transforms so not splitting it.
    data = Array.new(1,@sdata)
    @transforms = {}
    transform(data,@opt)
    @sdata = data.shift
    @connection << @sdata
    log_response @sdata
#=======</send>]
        return @source
    end
end

# Executable Ruby statements
class Eval < Chunk
    def compile
        @source << %Q(
#=======<eval>)
        @source << %Q(
#{@lines}
#=======</eval>)
        return @source
    end
end

class EConf < Chunk
    def compile
        @source << %Q(
#=======<econf>)
        @source << %Q(
#{@lines}
#=======</econf>
)
        return @source
    end
end

class Conf < Chunk
    def process(line)
        test = line[/[^\[]+/]
        if line =~ /\[([^\]]+)\]/
            test << $1
        end
        return test
    end
    def compile
        @seq = []
        @lines.each do |l|
            line = l.chomp.rstrip.lstrip
            next if line.empty?
            if  line =~ /^[ \t]*#.*$/
                @source << "#runtest '#{process(line)}'"
            else
                @source << "runtest '#{process(line)}'"
            end
        end
        return @source
    end
end

class ConnProxy
    def initialize(conn)
        @connections = [conn]
    end

    def method_missing(method,*args)
        @connections.last.send(method,*args)
    end

    def <<(data)
        @connections.last << data
    end
    
    def opt(opt)
        @connections.last.opt(opt)
    end

    def <(conn)
        @connections << conn
    end
    def <(conn)
        @connections << conn
    end

    def close
        @connections.pop.close
    end
    def current()
        @connections.last
    end

    def destroy
        @connections.each {|conn|
            conn.close if !conn.closed?
        }
        @connections = []
    end
end

#the holder for executing test cases.
class PatObject
    def initialize(file, conn, store)
        @file = file 
        @connection = ConnProxy.new(conn)
        @store = store
        @log = store.log
        @options = store.options

        class << @options
            def [](arg)
                pairs[arg]
            end
        end
        

        @restrans = {
            'tabs' => Transform::TabTrans.new(' '),
            'case' => Transform::CaseTrans.new(),
            'trim' => Transform::TrimTrans.new(),
        }

        #allow setting of matcher from test cases
        @matcher = nil

        #data from socket
        @cdata = []

        #the assert language data
        @sdata = ""

        #the default server to use when testing apps that need a server.
        @server = PatServer.new file, self, @store
    end

    def conn
        return @connection.current
    end

    def opt
        return @options
    end

    #use take :Name , args
    def take(name,*args)
        @connection < name.new(*args)
        $active_connections << @connection.current
        if block_given?
            yield @connection.current
            drop
        end
    end

    def drop
        @connection.close
    end

    def include(arg)
        PatObject.module_eval "include #{arg}"
    end

    def match_txt(exp, data, opt)
        #allow setting of matcher from test cases
        @matcher = Match.new(opt,@store) if @matcher.nil?
        val = @matcher.compare(exp,data)
        @matcher = nil
        return val
    end


    def transform(arr, opts)
        opts.keys.each {|opt|
            case opt.to_s
            when /^case$/
                @transforms.delete('case')
            when /^tabs$/
                @transforms['tabs'] = TabTrans.new(opts['tabs'])
            when /^notrim$/
                @transforms.delete('trim')
            when /^chop$/
                @transforms['chop'] = ChopTrans.new()
            end
        }
        @transforms.keys.each {|trans|
            @transforms[trans].transform(arr)
        }
    end

    def readtill(*rest)
        hash = rest.first
        hash ||={}
        exp = hash[:exp]
        len = hash[:len]
        @cdata = [read_till(exp,len)]
    end
    def read_till(exp,len)
        data = ""
        l = 0
        begin
            while data << @connection.socket().readchar
                l+=1
                if !exp.nil? and 
                    ((exp.instance_of?(Regexp) and (data =~ exp)) or
                    (exp.instance_of?(String) and data.include?(exp)))
                    break
                end
                if !len.nil? and l >= len
                    break
                end
                break if @connection.eof?
            end
            @log.dmatch "matched:#{data} == #{exp}"
            return data
        rescue Exception => e
            carp e.message
            @log.bt e
            return data
        end
    end

    def read_all()
        reply = []
        exp = []
        maxlen = nil
        till = nil
        aexp = @opt[:$line]
        if !aexp.nil? 
            if !aexp.instance_of?(Array)
                exp << aexp
            else
                exp = aexp
            end
        end
        till = @opt[:$till]
        maxlen = @opt[:$len]
        if !till.nil? or !maxlen.nil?
            data = read_till(till, maxlen)
            @cdata = data.split(/\n/)
            return
        end
        until @connection.eof?
            line = @connection.readline
            reply << line
            #loop until we match all the delimiters.
            match = 0
            @log.dmatch "#{line}" if exp.length == 0
            exp.each {|e|
                if (e.instance_of?(Regexp) and (line =~ e)) or 
                    (e.instance_of?(String) and (line == e))
                    match += 1
                    @log.dmatch "#{line} == #{e.to_s.dump}"
                else
                    @log.dmatch "#{line} <> #{e.to_s.dump}"
                end
            }
            if match != 0 && match == exp.length
                @cdata = reply.compact
                return 
            end
        end
        @cdata = reply.compact
    end
    def try_match(opt)
        exp = opt[:when?]
        return true if exp.nil?
        case exp.class.to_s
        when /Regexp/
            return true if @cdata.grep( exp ).length > 0
        when /String/
            return true if @cdata.include?(exp)
        when /Proc/
            case exp.arity
            when 1
                return true if !@cdata.find(exp).nil?
#            when 0 #Hack warning :) allow instance variables like @cdata to be accessed from the exp.
#                return true if eval(exp, self.binding)
            end
        end
        return false
    end
    def matches
        return Thread.current['matches']
    end

    def execute(myfile)
        val = self.instance_eval myfile, @file
        @server.stop
        @server = nil
        return val
    rescue Exception => e
        @log.cause "#{@file} [#{e.message()}]"
        @log.bt e
        return false
    ensure
        begin
            @connection.destroy
            @server.stop unless @server.nil?
        rescue;end
    end

    def use(tc)
        p = Pathname.new(tc)
        #todo - place a libname in between.
        tcase = p.dirname.to_s + '/' + p.basename.to_s
        parser = Parser.create(tcase, @store)
        if !parser.nil?
            myfile = parser.getsrc()
            self.instance_eval myfile, tc
        end
    end
    #====================================
    #loggging
    def cr(cr)
        @log.cr cr
    end
    def title(title)
        @log.title title
    end
    def info(info)
        @log.info info
    end
    def log_request(data)
        @log.request(data)
    end
    def log_response(data)
        @log.response(data)
    end
    def client_data(arr)
        @cdata = arr if  !arr.nil? && !arr.empty?
    end
end


class Parser
    def initialize(file, store, txt)
        @file = file
        @src = []
        @store = store
        @log = store.log
        @test_objects = compile(txt,Eval.new)
    end
    def self.create(file,store)
        txt = store.io.getlines(file + '.pat')
        return nil if txt.nil?
        return Parser.new(file, store, txt)
    end
    def compile(txt,obj)
        tc = []
        ob = false
        txt.each {|line|
            #switch based on the line start
            case line
            when /^ *<\[(.*)$/  #outgoing request
                tc << obj
                obj = Req.new($1)
                ob = true
            when /^ *>\[(.*)/  #incoming request
                tc << obj
                obj = Res.new($1)
                ob = true
            when /^ *\] *$/  #end re(q|s)
                if ob 
                    tc << obj
                    obj = Eval.new()
                    ob = false
                end
            else
                obj<line
            end
        }
        tc << obj
        return tc
    end

    def process
        if !@store.options.usedump
            @test_objects.each {|obj|
                @src << obj.compile
            }
        end
        return true
    end

    def getsrc()
        process()
        if !@store.options.usedump
            myfile = @src.join "\n"
            myfile += "\nreturn true"
            myfile.gsub!(/%remove%/,"")
            if @store.options.dump
                File.open("#{@file}.pat.rb",'w') {|f|
                    f << myfile
                }
            end
        else
            myfile = File.open("#{@file}.pat.rb",'r').read
        end
        return myfile
    end
end
#=====================================================
class PatServer
    def initialize(tc, patobj, store)
        #will be initialized two times, one from the client.pat, and second
        #from the loading of server.pat so no code should be placed in initialize
        @tc = tc
        @callback = patobj
        @store = store
        @log = store.log
        @port = @store.options.server_port
    end

    def callback
        return @callback
    end
    def dir
        return Pathname.new(@tc).dirname.to_s
    end
    def status()
        @callback.client_data(@status)
    end
    def run()
        p = Pathname.new(@tc)
        tcase = p.dirname.to_s + '/servers/' + p.basename.to_s
        #use a thread here...
        parser = Parser.create(tcase, @store)
        if !parser.nil?
            @thread = Thread.new {
                conn = ServerConn.new(@port)
                #do not cause the binding of socket here as it will impede
                #the late binding with the user-specified server socket.
                @patobj = PatObject.new(tcase, conn, @store)
                myfile = parser.getsrc()
                if @patobj.execute(myfile)
                    @log.show "#{tcase} (server) successfully completed"
                    @status = ['success']
                else
                    @log.show "#{tcase} (server) failed"
                    @status = ['failed']
                end
            }
        else
            @log.error "TestCase #{tcase}.pat does not exist"
        end
    rescue Exception => e
        @log.error "#{e.message()}:(#{tcase})"
        @log.bt e
    end

    def start(opts={})
        {:tcase => nil, :port => nil}.merge!(opts)
        @tc = opts[:tcase] if !opts[:tcase].nil?
        @port = opts[:port] if !opts[:port].nil?
        @status = ['exec']
        status()
        run()
        return true
    end
    def stop()
        begin
            timeout(@store.options.timeout) do
                @callback.conn.close
                @thread.join if !@thread.nil?
                status()
                return true
            end
        rescue Timeout::Error
            $failed += 1
            @log.error "#{conf} timed-out - (#{@store.options.timeout})"
            if tc.alive?
                Thread.kill @thread
                @status = ['killed']
                status()
            end
            return false
        end
    end
end

class PatClient
    def initialize(store)
        @host_port = store.options.proxy_host_port
        @store = store
        @log = store.log
    end
    def run(tcase)
        parser = Parser.create(tcase, @store)
        if !parser.nil?
            conn = Connectors::ClientConn.new(@host_port)
            myfile = parser.getsrc()
            @patobj = PatObject.new(tcase, conn, @store)
            if @patobj.execute(myfile)
                @log.show "#{tcase} successfully completed"
            else
                $failed += 1
                @log.show "#{tcase} failed"
            end
        else
            @log.error "TestCase #{tcase}.pat does not exist"
        end
    rescue Exception => e
        @log.error "#{e.message()} (#{@host_port})"
        @log.bt e
    end
end

class StdIO
    def getlines(file)
        begin
            if !FileTest.exist?(file)
                #try http.
                txt = get_www(file)
                return txt
            else
                return File.open(file).readlines
            end
        rescue
            return nil
        end
    end
    def get_www( resource )
        begin
            lp = $base
            puts "get_www>#{lp}#{resource}"
            response = Net::HTTP.get_response(URI.parse("#{lp}#{resource}"))
            if response.code.to_i == 200
                return response.body
            else
                puts "=>#{response.code}"
                return nil
            end
        rescue Exception => detail
            puts "get_www:#{detail.message}"
            #puts detail.backtrace.join("/n")
            return nil
        end
    end
end

class PatStore
    def initialize(log=nil,io=nil)
        if log.nil?
            @log = StdoutLog.new 
        else
            @log = log
        end
        if io.nil?
            @io = StdIO.new
        else
            @io = io
        end
        at_exit do
            $active_connections.each do |conn|
                begin
                    conn.close if conn
                rescue 
                end
            end
        end
    end
    def io
        return @io
    end
    def parse_opt(args)
        @opt = OptRun.parse(args, @log)
        @log.useopt @opt
        @log.verbose "seq:#{@opt.seq} proxy:#{@opt.proxy_host_port} server:#{@opt.server_host}:#{@opt.server_port}"
    end
    def set_opt(arg)
        @opt = arg
    end
    def log
        return @log
    end
    def options
        return @opt
    end
    def seq
        return @opt.seq
    end
end

class Seq
    def initialize(store)
        $failed = 0
        @store = store
        @log = store.log
        @pc = PatClient.new @store
        tc = []
        time = Time.now
        if @store.seq =~ /\.seq$/
            #should we allow *.pat from http://index list ??
            use(@store.seq.sub(/\.seq$/,''))
        else
            txt = Dir[@store.seq]
            if txt.length != 0
                tc += compile(txt.grep(/(.+)\.pat/).collect{|l| l.sub(/\.pat$/,'')}, Conf.new)
            else
                if @store.seq =~ /\.pat$/
                    tc += compile(@store.seq.sub(/\.pat$/,''), Conf.new)
                end
            end
            process(@store.seq,tc)
        end
        @log.show("Failure: #{$failed}") if $failed > 0
        @log.showtime(Time.now - time)
    end
    
    def use(seq)
        txt = @store.io.getlines(seq + '.seq')
        return if txt.nil?
        tc = compile(txt, EConf.new)
        process(seq + '.seq',tc)
    end

    def compile(txt,obj)
        tc = []
        txt.each {|line|
            #switch based on the line start
            case line
            when /^ *\[/  #start of seq
                tc << obj
                obj = Conf.new()
            when /^ *\] *$/  #end seq
                tc << obj
                obj = EConf.new()
                #when /^[ \t]*#.*$/  #comments
                #nothing
            else
                obj<line
            end
        }
        tc << obj
        return tc
    end

    def process(seq,tc)
        if !@store.options.usedump
            src = []
            tc.each {|t|
                src << t.compile
            }
            s = src.join("\n")
            if @store.options.dump 
                File.open(seq + '.rb', 'w') {|f|
                    f << s
                }
            end
        else
            s = File.open(seq + '.rb','r').read
        end
        self.instance_eval s, seq
    end

    def has(grp)
        negate = false
        return true if @store.options.groups.empty?
        @store.options.groups.each do |opt|
            if opt[-1].chr == '-'
                negate = true
                return false if opt.chop.eql? grp
            else
                return true if opt.eql? grp
            end
        end
        return true if negate
        return false
    end


    def runtest(conf)
        @log.verbose "processing testcase #{conf}"
        arr = conf.split(/[ \t]+/)
        file = arr.shift
        if !arr.empty?
            arr.delete_if {|x| !has(x)}
            return false if arr.empty?
        end

        #making this into a thread since there is a tendency for this to hang
        #on waiting for input.
        tc = Thread.new {
            @pc.run file
        }

        #give timeout seconds to finish the execution
        #(there is no normal reason for it to wait even if it fails)
        begin
            timeout(@store.options.timeout) do
                tc.join
            end
        rescue Timeout::Error
            $failed += 1
            @log.error "#{conf} timed-out (#{@store.options.timeout})"
            if tc.alive?
                Thread.kill tc
            end
        end
    end
end

class OptRun
    def self.parse(args, log)
        @log = log
        @continue = true
        # The options specified on the command line will be collected in *options*.
        # We set default values here.
        hostname = Socket.gethostname.split(/\./).shift
        options = OpenStruct.new

        options.proxy_host = hostname.downcase.chomp 
        options.proxy_port = 2892
        options.proxy_host_port = options.proxy_host + ':' + "#{options.proxy_port}"

        options.server_host = hostname.downcase.chomp 
        options.server_port = 10240
        options.server_host_port = options.server_host + ':' + "#{options.server_port}"

        options.seq = 'pat.seq'
        options.verbose = 0
        options.dump = false
        options.usedump = false
        options.timeout = DAY
        options.groups = []

        opts = OptionParser.new do |opts|
            opts.banner = "Usage: pat.rb [options]"

            opts.separator ""
            opts.separator "Specific options:"

            opts.on("-s", "--seq=sequence", "The sequence of testcases") do |seq|
                options.seq = seq
            end
            
            opts.on("-t", "--timeout=timeout", "The max timeout in seconds") do |t|
                options.timeout = t.to_i
            end

            opts.on("-p", "--proxy=proxyname:port", "The proxy against which you want to run the tests") do |host_port|
                case host_port
                when /^([^:]+):([0-9]+)$/
                    options.proxy_host = $1
                    options.proxy_port = $2.to_i
                else
                    options.proxy_host = host_port
                end
                options.proxy_host_port = options.proxy_host + ':' + "#{options.proxy_port}"
            end

            opts.on("-r", "--serverhost=serverhost:port", "Server name(opt)") do |host_port|
                case host_port
                when /^([^:]+):([0-9]+)$/
                    options.server_host = $1
                    options.server_port = $2.to_i
                when /^([0-9]+)/
                    options.server_port = $1.to_i
                else
                    options.server_host = host_port
                end
                options.server_host_port = options.server_host + ':' + "#{options.server_port}"
            end

            opts.on("-v", "--verbose=verbose", "Run verbosely [1..]") do |v|
                options.verbose = v.to_i
            end

            opts.on("-d", "--[no-]dump", "dump evaluation") do |d|
                options.dump = d
            end

            opts.on("-u", "--usedump", "use earlier dumps") do |u|
                options.usedump = u
            end
            
            opts.on("-x", "--ext a b c", Array, "use bt-backtrace|delim-dumpdelimmatch|time|xchars|match|debug") do |e|
                options.extended = e
                $gopt ||= {}
                e.each do |opt|
                    case opt.strip
                    when /^bt$/
                        $gopt['showbt'] = true
                    when /^delim$/
                        $gopt['showdelimmatch'] = true
                    when /^debug$/
                        $gopt['showdebug'] = true
                    when /^time$/
                        $gopt['showtime'] = true
                    when /^xchars$/
                        $gopt['showxchars'] = true
                    when /^match$/
                        $gopt['showmatch'] = true
                    end
                end
            end
            
            opts.on_tail("-g", "--groups x y z", Array,  "selected groups") do |g|
                options.groups = g
            end

            opts.separator ""
            opts.separator "Common options:"

            # No argument, shows at tail.  This will print an options summary.
            # Try it and see!
            opts.on_tail("-h", "--help", "Show this message") do
                @log.show opts
                exit
            end

            opts.on_tail("--version", "Show version") do
                @log.show '0.9'
                exit
            end
        end

        opts.parse!(args)
        options.pairs = {}
        options.remaining = []
        args.each {|arg|
            #check if they contain '='
            if arg =~ /^(.+)=(.+)$/
                options.pairs[$1] = $2
            else
                options.remaining << arg
            end
        }
        options
    end
end

end
