module Connectors
    require 'pathname'
    require 'fetchlib'
    #==================================
    #only if you need connect
    begin
    require 'openssl'
    rescue LoadError;rescue;end
    #==================================
    #only if you need socks
    begin
    require 'net/ssh'
    require 'net/ssh/proxy/socks4'
    require 'net/ssh/proxy/socks5'
    rescue LoadError;rescue;end
    #==================================
    #only if you need snmp
    begin
    require 'snmp'
    rescue LoadError;rescue;end
    #==================================
    #only if you need ftp
    begin
    require 'net/ftp'
    rescue;end
    #==================================
    #only if you need xml parsing
    require 'rexml/document'
    include REXML
    #==================================
    #only if you need remoting
    require 'drb'
    #==================================
    #only if you need expect
    begin
    require 'pty'
    require 'expect'
    rescue;end
    #==================================
    class Conn
        def initialize()
            @opt = {}
        end

        def opt(opt)
            @opt = opt if !opt.nil?
        end

        def port(port=nil)
            @port = port if !port.nil?
            return @port
        end

        def <<(data)
            socket() << data
        end

        def closed?
            return true if socket().closed?
        end

        def readlines
            lines = []
            while !eof?
                line = readline
                if block_given?
                    yield line
                else
                    lines << line
                end
            end
            return lines unless block_given?
        end

        def write(data)
            self << data
        end

        def readchar()
            return socket().readchar
        end
        
        def machine
            return "#{self}"
        end

        def split_host_port(hp, def_port)
            host = hp
            port = def_port
            case hp
            when /^([^:]+):([0-9]+)$/
                host = $1
                port = $2.to_i
            end
            return [host, port]
        end

        def >>
            return readline()
        end

        def eof?
            return socket().eof?
        end

        def readline
            return socket().readline
        end

        def close
            socket().close
        end
    end


    class ServerConn < Conn
        def server
            if @srv.nil?
                @srv = TCPserver.open('0.0.0.0', @port)
            end
            return @srv
        end

        def initialize(port)
            @port = port
            @sock = nil
            @srv = nil
        end

        def <<(data)
            dat = nil
            if @opt.nil? || !@opt.include?("nocrlf")
                d = data.split(/\z/).collect {|l|l.chomp().sub(/\z/,"\r\n")}
                dat = d.join("")
            else
                dat = data
            end
            socket() << dat
        end

        def bind
            server()
        end

        def socket
            if @sock.nil?
                @sock = server().accept
            end
            return @sock
        end

        def close
            @sock.close unless @sock.nil? or @sock.closed?
            @sock = nil
            @srv.close unless @srv.nil? or @srv.closed?
            @srv = nil
        end

        def closed?
            return true if @sock.nil? || @sock.closed?
        end
    end

    class ClientConn < Conn
        def initialize(host_port)
            @host, @port  = split_host_port(host_port,80)
            @sock = nil
        end
        def machine
            return "#{@host}:#{@port}"
        end

        def opt(opt)
            @opt = opt if !opt.nil?
        end
        
        def <<(data)
            if @opt.nil? || !@opt.include?("nocrlf")
                d = data.split(/\Z/).collect {|l|l.chomp().sub(/\Z/,"\r\n")}
                socket() << d.join("")
            else
                socket() << data
            end
        end

        def socket
            if @sock.nil?
                @sock =  TCPSocket.open(@host, @port)
            end
            return @sock
        end
        def close
            @sock.close unless @sock.nil? or @sock.closed?
        end
        
        def closed?
            return true if @sock.nil? || @sock.closed?
        end
    end

    class HttpConn < ClientConn
    end

    #==============================================    
    #exclusive connect stuff
    #==============================================    
    class SSLServerConn < Conn
        def initialize(port)
            @port = port
            @sock = nil
            @srv = nil
            @nossl = nil
            @ssl = nil
            #weird ssl stuff
            key = OpenSSL::PKey::RSA.new(512)
            cert = OpenSSL::X509::Certificate.new
            cert.not_before = Time.now
            cert.not_after = Time.now + 3600
            cert.public_key = key.public_key
            cert.sign(key, OpenSSL::Digest::SHA1.new)

            @ctx = OpenSSL::SSL::SSLContext.new
            @ctx.key = key
            @ctx.cert = cert

        end

        def socket
            if @sock.nil?
                @srv = TCPserver.open('0.0.0.0', @port)
                @ssl = OpenSSL::SSL::SSLServer.new(@srv, @ctx)
                @sock = @ssl.accept
            end
            return @sock
        end

        def close
            @sock.close unless @sock.nil? or @sock.closed?
            @sock = nil
            @ssl.close unless @ssl.nil? or @ssl.closed?
            @ssl = nil
            @nossl.close unless @nossl.nil? or @nossl.closed?
            @nossl = nil
            @srv.close unless @srv.nil? or @srv.closed?
            @srv = nil
        end
    end

    class SSLClientConn < Conn
        def initialize(host_port)
            @host, @port  = split_host_port(host_port,443)
            @nosslsock = nil
            @sock = nil
        end

        def socket
            if @sock.nil?
                @nosslsock =  TCPSocket.open(@host, @port)
                @sock =  OpenSSL::SSL::SSLSocket.new(@nosslsock,  OpenSSL::SSL::SSLContext.new)
                @sock.sync = true
                @sock.connect
            end
            return @sock
        end

        def close
            @nosslsock.close unless @nosslsock.nil? or @nosslsock.closed?
            @nosslsock = nil
            @sock.close unless @sock.nil? or @sock.closed?
            @sock = nil
        end
    end

    #necessary because we want to upgrade to ssl in the middle of a tcp session.
    class SSLProxyClientConn < SSLClientConn
        def initialize(sock)
            raise "invalid socket passed to SSLProxyClientConn" if sock.nil?
            @nosslsock = sock.socket()
            @sock = nil
        end

        def socket
            if @sock.nil?
                @sock =  OpenSSL::SSL::SSLSocket.new(@nosslsock,  OpenSSL::SSL::SSLContext.new)
                @sock.sync = true
                @sock.connect
            end
            return @sock
        end
    end

    #==============================================    
    #exclusive socks stuff
    #==============================================    

    class Socks5ProxyClientConn < ClientConn
        def initialize(socks_host_port, server_host_port, user = nil, password = nil)
            @socks_host, @socks_port  = split_host_port(socks_host_port,1080)
            @server_host, @server_port  = split_host_port(server_host_port,80)

            @user = user
            @password = password
            @sock = nil
            @ssock = nil
        end

        def socket
            if @sock.nil?
                if @user.nil?
                    @ssock = Net::SSH::Proxy::SOCKS5.new( @socks_host, @socks_port)
                else
                    @ssock = Net::SSH::Proxy::SOCKS5.new( @socks_host, @socks_port,
                                                         :user => @user,
                                                         :password => @password)
                end
                @sock = @ssock.open(@server_host, @server_port)
            end
            return @sock
        end

        def close
            @sock.close unless @sock.nil? or @sock.closed?
            @sock = nil
            @ssock= nil
        end
    end

    class Socks4ProxyClientConn < ClientConn
        def initialize(socks_host_port, server_host_port, user = nil)
            @socks_host, @socks_port  = split_host_port(socks_host_port,1080)
            @server_host, @server_port  = split_host_port(server_host_port,80)
            @user = user
            @sock = nil
            @ssock = nil
        end
        
        def socket
            if @sock.nil?
                if @user.nil?
                    @ssock = Net::SSH::Proxy::SOCKS4.new( @socks_host, @socks_port )
                else
                    @ssock = Net::SSH::Proxy::SOCKS4.new( @socks_host, @socks_port,
                                                         :user => @user)
                end
                @sock = @ssock.open(@server_host, @server_port)
            end
            return @sock
        end

        def close
            @sock.close unless @sock.nil? or @sock.closed?
            @sock = nil
            @ssock= nil
        end
    end

    #==============================================    
    #exclusive snmp stuff
    #==============================================    
    class SnmpServerConn < Conn
        #dummy
        def initialize(port)
        end

        def socket
            return nil
        end

        def close
        end
    end

    class SnmpClientConn < Conn
        def initialize(host_port, modules)
            @host, @port  = split_host_port(host_port,161)
            @manager = nil
            @modules = modules
        end
        def manager
            if @manager.nil?
                @manager = SNMP::Manager.new(:Host => @host, :Port => @port, 
                                             :Community => 'public', :Version => :SNMPv1, 
                                             :MibModules => @modules )
            end
            return @manager
        end

        def socket
            return nil
        end

        def close
            return nil
        end

        def readline
            if @response.nil? 
                @response = manager().get(@oids)
                return nil if @response.nil? or @response.varbind_list.empty?
                @vars_bound = @response.varbind_list
            end
            var = @vars_bound.shift
            return nil if var.nil? or var.value.nil?
            return var.value.to_s
        end

        def <<(oids)
            @oids = oids.strip.split(/[ \t]+/)
            @response = nil
            @vars_bound = nil
        end

        def >>
            return readline()
        end

        def eof?
            return true if !@response.nil? and (@vars_bound.nil? or @vars_bound.empty?)
            return false
        end
    end

    class SnmpWalkerClientConn < SnmpClientConn
        def readline
            @response = @manager.get_next(@next_oid)
            @varbind = @response.varbind_list.first
            @next_oid = @varbind.name
            return @varbind.value.to_s
        end

        def <<(oid)
            @start_oid = ObjectId.new(oid.strip!)
            @next_oid = @start_oid
        end

        def >>
            return readline();
        end

        def eof?
            #we want to get only relevant branches.
            return true if EndOfMibView == @varbind.value
            return !(@next_oid.subtree_of?(@start_oid))
        end
    end

    #==============================================    
    #exclusive console stuff
    #ConsoleClientConn for writing to args
    #ConsoleOutClientConn for writing to stdout
    #it can be upgraded in the middle like Connect
    #==============================================    
    class ConsoleClientConn < Conn
        def initialize()
            @cmd = nil
        end

        def socket
            return @cmd
        end

        def close
            if !@cmd.nil?
                @cmd.close if !@cmd.closed?
                @exitval = ($? >> 8)
                @cmd = nil
                raise "Command #{@cmdstr} failed (#{@exitval})." if @exitval
            end
            @cmdstr = nil
        end

        def readline
            return @cmd.gets
        end

        def <<(cmd)
            @cmdstr = cmd.chomp
            @cmd = open("|#{@cmdstr}")
        end

        def >>
            return readline;
        end

        def eof?
            return true if @cmd.nil? or @cmd.eof?
        end
    end

    class Cli < ConsoleClientConn
    end

    class CatFile < ConsoleClientConn
        def <<(file)
            @cmdstr = file
            @cmd = open(@cmdstr)
        end
    end

    class FileConn < ConsoleClientConn
        def initialize(file, type='a')
            @file = File.open(file, type)
        end
        def close()
            @file.close if !@file.nil?
        end
        def <<(str)
            @file << str
        end
        def socket
            return @file
        end
        def >>
            return readline();
        end
        def readline()
            return @file.gets
        end
        def eof?
            return @file.eof?
        end
    end
    #==================================
    class PConn < Conn
        def initialize(cmd)
            @cmdstr = cmd
            @cmd = IO.popen("#{@cmdstr}", "w+")
        end

        def socket
            return @cmd
        end

        def close
            @cmd.close if !@cmd.nil?
            @cmd = nil
            @cmdstr = nil
        end

        def readline
            return @cmd.gets
        end
        def read(i)
            return @cmd.read(i)
        end
        
        def <<(str)
            @cmd << str
        end

        def >>
            return readline();
        end

        def eof?
            return true if @cmd.nil? or @cmd.eof?
        end
    end
    #=============================
    #xml files
    class XmlClientConn < Conn
        #do not save any unserializable data here.
        def initialize(xmlfile)
            @xml = xmlfile
            @processed = true
            @result = []
            @xpath = []
            @xmldoc = nil
        end

        def xmldoc
            if @xmldoc.nil?
                @xmlfile = File.new(@xml)
                @xmldoc = Document.new(@xmlfile)
            end
            return @xmldoc
        end

        def socket
            return nil
        end

        def close
            @xmlfile.close if !@xmlfile.nil?
        end

        def readline
            begin
                if !@processed
                    @xpath.each {|xpr|
                        xmldoc().elements.each(xpr) { |item|
                            item.to_s.split($/).each { |str|
                                @result << str
                            }
                        }
                    }
                    @processed = true
                end
                if !@result.empty?
                    val = @result.shift
                    return val
                else
                    @xpath.clear
                    return ""
                end
            rescue Exception => e
                carp e
                @result.clear
                @xpath.clear
                return ""
            end
        end

        def <<(expr)
            @xpath.clear
            expr.split($/).each {|line|
                #TODO: check if it ends with an attrib -> //mexico/@capital
                #if so make it into //mexico .attributes['capital']
                @xpath << line.chomp
            }
            @processed = false
        end

        def >>
            return readline();
        end

        def eof? 
            if @result.empty? && @processed
                return true 
            end
        end
    end
    #==================remote stuff=====================
    class RemoteProxyClientConn < Conn
        @@initialized = nil
        def init()
            if @@initialized.nil?
                carp "starting drb..."
                DRb.start_service()
                @@initialized = true
            end
        end

        def initialize(host, conn)
            @conn = conn
            ref = host
            case host
            when /^([^:]+):([0-9]+)$/
                ref = host.strip
            else
                ref = host.strip + ':9000'
            end
            carp "connecting to #{ref}"
            init()
            @obj = DRbObject.new(nil, "druby://#{ref}")
            @obj.init(conn)
            carp "initialization complete for #{ref}"
        end

        def method_missing(method,*args)
            return @obj.send(method,*args)
        end

        def close
            return @obj.close if !@obj.nil?
        end

        def readline
            return @obj.readline
        end

        def <<(expr)
            @obj << expr
        end

        def opt(opt)
            @obj.opt(opt)
        end

        def >>
            return readline();
        end

        def eof? 
            return @obj.eof?
        end
    end
    class Machine < RemoteProxyClientConn
    end
    #=================transfer=========================
    #rsync -avz /tmp/rsync xxxx@vayavyam.india.sun.com:/tmp/

    class RsyncTransConn < Conn
        def initialize(lm, rm)
            @src_machine = lm.nil? ? "": lm + ":"
            @dest_machine =  rm.nil? ? "": rm + ":"
        end

        def socket
            return nil
        end

        def close
            @cmd.close if !@cmd.nil?
            @cmd = nil
            @dir = nil 
        end

        def readline
            return @cmd.gets
        end

        def sync(src, dest)
            self << "#{src} #{dest}"
            while !self.eof?
                puts self.readline()
            end
            self.close
        end

        def <<(dir)
            @dir = dir.split(/ +/)
            #rsync likes to create the directory all by itself so if the directory is present,
            #it will create a new directory inside it.
            srcdir = @dir[0]
            destdir = Pathname.new(@dir[1]).dirname.to_s
            @cmd = open("|rsync -avrzI #{@src_machine}#{srcdir} #{@dest_machine}#{destdir}")
        end

        def >>
            return readline();
        end

        def eof?
            return true if @cmd.nil? or @cmd.eof?
        end
    end

    class Rsync < RsyncTransConn
    end
    
    class HttpsyncTransConn < Conn
        def initialize(lm)
            @src_machine = lm
        end

        def socket
            return nil
        end

        def close
            @cmd.close if !@cmd.nil?
            @cmd = nil
            @dir = nil 
        end

        def readline
            return @cmd.gets
        end

        def sync(src, dest)
            count = 0
            self << "#{src} #{dest}"
            while !self.eof?
                count += 1
                puts self.readline()
            end
            self.close
            return count - 3
        end

        def <<(dir)
            @dir = dir.split(/ +/)
            puts("|httpsync -t #{@dir[1]}  @http://#{@src_machine}#{@dir[0]}/packing.lst")
            @cmd = open("|httpsync -t #{@dir[1]}  @http://#{@src_machine}#{@dir[0]}/packing.lst")
        end

        def >>
            return readline();
        end

        def eof?
            return true if @cmd.nil? or @cmd.eof?
        end
    end

    class Httpsync < HttpsyncTransConn
    end
  
    #need for pat.rb 
    class HttpfetchTransConn < Conn
        def initialize(host_port)
            @src_machine, @port  = split_host_port(host_port,80)
        end

        def socket
            return nil
        end

        def close
            @cmd.close if !@cmd.nil?
            @cmd = nil
        end

        def readline
            return @cmd.gets
        end

        def sync(src, dest)
            count = 0
            self << "#{src} #{dest}"
            while !self.eof?
                count += 1
                puts self.readline()
            end
            puts "#{count} files"
            self.close
            return count
        end

        def <<(dir)
            dirs = dir.chomp.split(/ +/)
            @cmd = Fetchlib::Controller.new(@src_machine, @port, dirs[0], dirs[1])
        end

        def >>
            return readline();
        end

        def eof?
            return true if @cmd.nil? or @cmd.eof?
        end
    end
    class Httpfetch < HttpfetchTransConn
    end

    class Httpfetchdir < HttpfetchTransConn
        def <<(dir)
            @cmd = Fetchlib::Controller.new(@src_machine, @port, dir)
        end
    end

    class FtpFetchList < Conn
        def initialize(opts={})
            {:host => nil, :user => 'ftp', :pass => 'anonymous@pat' }.merge!(opts)
            @src_machine, @port  = split_host_port(opts[:host],21)
            @user = opts[:user]
            @pass = opts[:pass]
            @ftp = nil
            @list = nil
        end
        def socket
            if @ftp.nil?
                @ftp = Net::FTP::new(@src_machine)
                @ftp.connect(@src_machine,@port)
                @ftp.login @user, @pass
                @home = @ftp.pwd
            end
            return @ftp
        end
        def >>
            return readline();
        end

        def <<(dir)
            socket().chdir(@home)
            socket().chdir(dir.chomp)
            @list = socket().list()
            @list.pop #loose total.
        end

        def readline
            return @list.pop.split(/ +/)[8]
        end
        def close
            socket().close
        end
        def eof?
            !@list.nil? && @list.empty?
        end
        def closed?
            socket().closed?
        end
    end    
    class FtpFetch < FtpFetchList
        def <<(files)
            remote,local = *(files.chomp.split(/ +/))
            p = Pathname.new(remote)
            dir = p.dirname.to_s
            rfile = p.basename.to_s
            socket().chdir(@home)
            socket().chdir(dir)
            if @opt['type'] =~ /bin/
                socket().getbinaryfile(rfile, local)
            else
                socket().gettextfile(rfile, local)
            end
            if @list.nil?
                @list = [local]
            else
                @list << local
            end
        end
        def readline
            return @list.pop
        end
    end
    #=================transfer=========================
    class ExpectConn < ClientConn
        def initialize(process)
            @process = process
            @pipes = nil
            @lines = []
            @second = false
        end

        def opt(opt)
            @opt = opt
        end

        def buf
            if @lines.empty?
                rpipe().expect(@opt[:$line]).each { |lines|
                    @lines += lines.split("\n")
                }
            end
            @lines.shift
        end

        def pipes
            if @pipes.nil?
                @pipes = PTY.spawn(@process)
                @pipes[1].sync = true
                $expect_verbose = $gopt['showdebug']
            end
            return @pipes
        end
        def rpipe
            pipes()[0]
        end
        def wpipe
            pipes()[1]
        end
        def pid
            pipes()[2]
        end

        def close
            begin
            @pipes[0].close
            @pipes[1].close
            rescue e
                puts e.message
            end
        end

        def readline
            buf()
        end

        def <<(str)
            wpipe().print str
        end

        def >>
            return readline()
        end

        def eof?
            return false
        end
    end

end
