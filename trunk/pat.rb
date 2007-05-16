#!/usr/local/bin/ruby
#!/usr/local/bin/ruby -w -d
#=================================
#         Config
#=================================
$base = 'http://ruby-hive.googlecode.com/svn/trunk/'
eval File.open('.hiverc').readlines.join("\n") if FileTest.exist? ".hiverc"
#=================================

$:.push $base

def require( resource )
    begin
        super
    rescue LoadError
        $:.each {|lp|
            begin
                res = "#{lp}#{resource}.rb"
                if lp.strip !~ /\/$/
                    res = "#{lp}/#{resource}.rb"
                end
                if lp =~ /http:\/\//i
                    #puts ">#{res}"
                    response = Net::HTTP.get_response(URI.parse(res))
                    if response.code.to_i == 200
                        eval(response.body)
                        $" << "#{resource}.rb"
                        return true
                    else
                        #puts "=>#{response.code}"
                    end
                else
                    if FileTest.exist?(res)
                        eval File.open(res).readlines.join("\n") 
                        $" << "#{resource}.rb"
                        return true
                    end
                end
            rescue Exception => e
                #puts e.message
                #puts e.backtrace.join("\n")
            end
        }
    end
end

require 'thread'
require 'net/http'
require 'patlog'
require 'patscript'
include Pat

store = PatStore.new()
store.parse_opt(ARGV)
s = Seq.new store

