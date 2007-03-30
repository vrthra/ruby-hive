require 'basetrait'
require 'fetchlib'
include Fetchlib

class FetchTrait
    include BaseTrait
    def init()
        @version = 0.2
        @inspect = "get #{@inspect}"
        @status = "unborn"
    end
    def run(cmd, args)
        case cmd
        when /^get/i
            return get(args)
        else
            return "nomatch: #{cmd} - #{args}"
        end
        return ""
    end

    def get(args)
        case args
        when /^http:\/\/([a-zA-Z0-9.-]+):*([0-9]*)(\/*[^ ,]*) *, *([^ ]+) *$/
            host = $1
            if $2.nil? or $2.strip.length == 0
                port = 80
            else
                port = $2.to_i
            end
            if $3.nil? or $3.strip.length == 0
                src = '/'
            else
                src = $3.strip
            end
            dest = $4.strip
            controller = Controller.new(host, port, src, dest)
            return controller.status
        else
            return "needs http://host:port/src,dest as args"
        end
    end

end
@traits['fetch'] = FetchTrait.new(self)
