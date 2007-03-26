module NetUtils
    def carp(arg)
        if $verbose
            case  true
            when arg.kind_of?(Exception)
                puts "Error:" + arg.message 
                puts "#{self.class.to_s.downcase}:" + arg.message 
                puts arg.backtrace.collect{|s| "#{self.class.to_s.downcase}:" + s}.join("\n")
                arg.message
            else
                puts "#{self.class.to_s.downcase}:" + arg
                arg
            end
        end
    end

    def get_resource(resource, ext='.rb')
        $:.each do |lp|
            lp << '/' unless lp =~ /\/$/
            res = "#{lp}#{resource}"
            res << ext unless lp =~ Regexp.new("#{ext}$")
            if lp =~ /http:\/\//i
                begin
                    response = Net::HTTP.get_response(URI.parse(res))
                    if response.code.to_i == 200
                        return response.body
                    else
                        puts response.code
                    end
                rescue Exception => e
                    puts e.message()
                end
            else
                return File.read(res) if FileTest.exist?(res)
            end
        end
        raise resource + ' not found.'
    end
end
