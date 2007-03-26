begin
require 'connectors'
rescue Exception => e
    puts "remoteserver=> #{e.message}"
    puts e.backtrace.join("\n")
end

class RemoteServer
    def initialize()
    end
    def init(conn)
        puts "object:#{conn.machine}"
        @conn = conn
    end

    def close
        puts "closed"
        @conn.close if !@conn.nil?
    end

    def readline
        return @conn.readline if !@conn.nil?
    end

    def <<(expr)
        @conn << expr
    end
    
    def opt(opt)
        @conn.opt(opt)
    end
    
    def >>
        return readline();
    end

    def eof? 
        return @conn.eof?
    end
end
