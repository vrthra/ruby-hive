require 'net/http'
#==============================================
#this is the least we require to connect to
#the repository and get required code
#==============================================
#         Config
#==============================================
$base = 'http://webproxy.india.sun.com/hive/'
$verbose = 0
$daemonize = false

#these variables may be overridden in .hiverc
eval File.open('.hiverc').readlines.join("\n") if FileTest.exist? ".hiverc"

ARGV.each {|arg|
    case arg.strip
    when /^-v$/
        $verbose = true
    when /^http:.*$/
        $base = arg
    end
}

$: << '.' << $base
#==============================================
def require( resource )
    begin
        super
    rescue LoadError
        $:.each do |lp|
            begin
                if lp =~ /http:\/\//i
                    lp << '/' unless lp =~ /\/$/
                    res = "#{lp}#{resource}.rb"
                    response = Net::HTTP.get_response(URI.parse(res))
                    if response.code.to_i == 200
                        eval response.body
                        $" << "#{resource}.rb"
                        return true
                    else
                        puts "#{res}=>#{response.code}" if $verbose > 0
                    end
                end
            rescue;end
        end
        raise LoadError.new("can not find #{resource}")
    end
end
require 'netbase.rb'
#==============================================
#It will be same until here in every netclient.
#==============================================
base = NetBase.new(ARGV)
base.run do
    require 'config'
    include Config
    require 'queryclient'
    include Agent

    QueryClient.start $config['home']
end
