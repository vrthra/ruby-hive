require "thread"
require "servicestate"
require "net/imap"
require "ostruct"
require "yaml"
include YAML

require 'webrick'
require 'smtpd'
class MailWatcher < WEBrick::GenericServer
    attr_accessor :sleepTime, :priority
    MATCH = 0
    NOMATCH = 1
    EXCEPTION = 2
    def initialize(port=25,&callback)
        super(:Port => port)
        @expressions = {}
        @callback = callback
        @thread = Thread.new {
            start
        }
    end
    def add(name,exp)
        @expressions[name] = exp
    end

    def remove(name)
        @expressions.delete(name)
    end

    def clear
        @expressions.clear
    end

    def run(sock)
        s = SMTPD.new(sock, Socket.gethostname)
        class << s
            def init(exp,callback)
               @expressions = exp 
               @callback = callback
            end
            def data_hook(msg)
                header = true
                mailheaders = {}
                mailbody = []
                lasth = ''
                msg.split(/\r\n/).each {|line|
                    begin
                        #p line
                        case true
                        when header
                            case line
                            when /^([^ ][^:]+):(.+)$/
                                if mailheaders[$1.to_sym]
                                    mailheaders[$1.to_sym] << '++' + $2.chomp 
                                else
                                    mailheaders[$1.to_sym] = $2.chomp 
                                end
                                lasth = $1.to_sym
                            when /^$/
                                header = false
                            else
                                mailheaders[lasth] << '+' + line.chomp
                            end
                        else
                            mailbody << line.chomp
                        end
                    rescue Exception => e
                        puts e.message
                        puts e.backtrace
                    end
                }
                begin
                    mail = {:headers => mailheaders, :body => mailbody}
                    subject = mailheaders[:Subject]
                    from = mailheaders[:From]
                    match = false
                    @expressions.values.each{|val|
                        str = from + ':' + subject
                        if str =~ Regexp.new(val)
                            @callback.call(MATCH, mail) 
                            match = true
                        end
                    }
                    @callback.call(NOMATCH, mail)  if !match

                rescue Exception => e
                    puts e.message
                    puts e.backtrace
                    @callback.call(EXCEPTION, e.message)
                end
                #mailheaders.keys.each {|key|
                #    puts ">#{key} = #{mailheaders[key]}|"
                #}
                #puts mailbody.join("\n")
            end
        end
        s.init(@expressions,@callback)
        s.start
    end
end
