# $Id: smtpd.rb,v 1.6 2004/12/02 10:23:33 tommy Exp $
#
# Copyright (C) 2003-2004 TOMITA Masahiro
# tommy@tmtm.org
# slightly modified. (originally from http://raa.ruby-lang.org/project/smtpd/)
#

require "tempfile"

module GetsSafe
  def gets_safe(rs=nil, timeout=@timeout, maxlength=@maxlength)
    rs = $/ unless rs
    f = self.kind_of?(IO) ? self : STDIN
    @gets_safe_buf = "" unless @gets_safe_buf
    until @gets_safe_buf.include? rs do
      if maxlength and @gets_safe_buf.length > maxlength then
        raise Errno::E2BIG, "too long"
      end
      if IO.select([f], nil, nil, timeout) == nil then
        raise Errno::ETIMEDOUT, "timeout exceeded"
      end
      begin
        @gets_safe_buf << f.sysread(4096)
      rescue EOFError, Errno::ECONNRESET
        return @gets_safe_buf.empty? ? nil : @gets_safe_buf.slice!(0..-1)
      end
    end
    p = @gets_safe_buf.index rs
    if maxlength and p > maxlength then
      raise Errno::E2BIG, "too long"
    end
    return @gets_safe_buf.slice!(0, p+rs.length)
  end
  attr_accessor :timeout, :maxlength
end

class SMTPD
  class Error < StandardError
  end

  def initialize(sock, domain)
    @sock = sock
    @domain = domain
    @error_interval = 5
    class <<@sock
      include GetsSafe
    end
  end

  def start()
    @helo_name = nil
    @sender = nil
    @recipients = []
    catch :close do
      puts_safe "220 #{@domain} service ready"
      while comm = @sock.gets_safe do
	catch :next_comm do
	  comm.sub!(/\r?\n/,"")
	  comm, arg = comm.split(/\s+/,2)
          break if comm == nil
	  case comm.upcase
	  when "EHLO" then comm_helo arg
	  when "HELO" then comm_helo arg
	  when "MAIL" then comm_mail arg
	  when "RCPT" then comm_rcpt arg
	  when "DATA" then comm_data arg
	  when "RSET" then comm_rset arg
	  when "NOOP" then comm_noop arg
	  when "QUIT" then comm_quit arg
	  else
	    error "502 Error: command not implemented"
	  end
	end
      end
    end
  end

  def line_length_limit=(n)
    @sock.maxlength = n
  end

  def input_timeout=(n)
    @sock.timeout = n
  end

  attr_reader :line_length_limit, :input_timeout
  attr_accessor :error_interval
  attr_accessor :use_file, :max_size

  private
  def comm_helo(arg)
    if arg == nil or arg.split.size != 1 then
      error "501 Syntax: HELO hostname"
    end
    helo_hook arg if defined? helo_hook
    @helo_name = arg
    reply "250 #{@domain}"
  end

  def comm_mail(arg)
    if @sender != nil then
      error "503 Error: nested MAIL command"
    end
    if arg !~ /^FROM:/i then
      error "501 Syntax: MAIL FROM: <address>"
    end
    sender = parse_addr $'
    if sender == nil then
      error "501 Syntax: MAIL FROM: <address>"
    end
    mail_hook sender if defined? mail_hook
    @sender = sender
    reply "250 Ok"
  end

  def comm_rcpt(arg)
    if @sender == nil then
      error "503 Error: need MAIL command"
    end
    if arg !~ /^TO:/i then
      error "501 Syntax: RCPT TO: <address>"
    end
    rcpt = parse_addr $'
    if rcpt == nil then
      error "501 Syntax: RCPT TO: <address>"
    end
    rcpt_hook rcpt if defined? rcpt_hook
    @recipients << rcpt
    reply "250 Ok"
  end

  def comm_data(arg)
    if @recipients.size == 0 then
      error "503 Error: need RCPT command"
    end
    if arg != nil then
      error "501 Syntax: DATA"
    end
    reply "354 End data with <CR><LF>.<CR><LF>"
    if defined? data_hook then
      tmpf = @use_file ? Tempfile::new("smtpd") : ""
    end
    size = 0
    loop do
      l = @sock.gets_safe
      if l == nil then
	raise SMTPD::Error, "unexpected EOF"
      end
      if l.chomp == "." then break end
      if l[0] == ?. then
	l[0,1] = ""
      end
      size += l.size
      if @max_size and @max_size < size then
	error "552 Error: message too large"
      end
      data_each_line l if defined? data_each_line
      tmpf << l if defined? data_hook
    end
    if defined? data_hook then
      if @use_file then
	tmpf.pos = 0
      end
      data_hook tmpf
    end
    reply "250 Ok"
    @sender = nil
    @recipients = []
  end

  def comm_rset(arg)
    if arg != nil then
      error "501 Syntax: RSET"
    end
    rset_hook if defined? rset_hook
    reply "250 Ok"
    @sender = nil
    @recipients = []
  end

  def comm_noop(arg)
    if arg != nil then
      error "501 Syntax: NOOP"
    end
    noop_hook if defined? noop_hook
    reply "250 Ok"
  end

  def comm_quit(arg)
    if arg != nil then
      error "501 Syntax: QUIT"
    end
    quit_hook if defined? quit_hook
    reply "221 Bye"
    throw :close
  end

  def parse_addr(str)
    str = str.strip
    if str == "" then
      return nil
    end
    if str =~ /^<(.*)>$/ then
      return $1.gsub(/\s+/,"")
    end
    if str =~ /\s/ then
      return nil
    end
    str
  end

  def reply(msg)
    puts_safe msg
  end

  def error(msg)
    sleep @error_interval if @error_interval
    puts_safe msg
    throw :next_comm
  end

  def puts_safe(str)
    begin
      @sock.puts str+"\r\n"
    rescue
      raise SMTPD::Error, "cannot send to client: '#{str.gsub(/\s+/," ")}': #{$!.to_s}"
    end
  end
end

SMTPDError = SMTPD::Error



require 'webrick'
$myheaders = {'all' => ''}
$mydata = []
class SMTPServer < WEBrick::GenericServer
    def run(sock)
        s = SMTPD.new(sock, "vayavyam.india.sun.com")
        class << s
            def data_hook(msg)
                header = true
                lasth = 'all'
                msg.split(/\r\n/).each {|line|
                    begin
                        #p line
                        puts ">>#{line}|"
                        case true
                        when header
                            case line
                            when /^([^ ][^:]+):(.+)$/
                                if $myheaders[$1]
                                    $myheaders[$1] << '++' + $2.chomp 
                                else
                                    $myheaders[$1] = $2.chomp 
                                end
                                lasth = $1
                            when /^$/
                                header = false
                            else
                                $myheaders[lasth] << '+' + line.chomp
                            end
                        else
                            $mydata << line.chomp
                        end
                    rescue Exception => e
                        puts e.message
                        puts e.backtrace
                    end
                }
                $myheaders.keys.each {|key|
                    puts ">#{key} = #{$myheaders[key]}|"
                }
                puts $mydata.join("\n")
            end
        end
        s.start
    end
end

if __FILE__ == $0
    s = SMTPServer.new( :Port => 25 )
    begin
        while arg = ARGV.shift
            case arg
            when /-v/
                $verbose = true
            end
        end
        trap("INT"){ 
            system("kill -9 #{$$}")
            s.shutdown
        }
        s.start

    rescue Interrupt
        exit 0
    rescue SystemExit
        exit 0
    rescue Exception => e
        exit 0
    end
end

