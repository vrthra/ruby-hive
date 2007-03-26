require 'net/http'
#==============================================
#this is the leaset we require to connect to
#the repository and get required code
#==============================================
#         Config
#==============================================
$base = 'http://webproxy.india.sun.com/hive/'
$verbose = 0
$daemonize = false

#these variables may be overridden in .hiverc
eval File.open('.hiverc').readlines.join("\n") if FileTest.exist? ".hiverc"

#minimum parsing required 
ARGV.each {|arg|
    case arg.strip
    when /^-v$/
        $verbose = 1
    when /^http:.*$/
        $base = arg
    end
}

if $base.kind_of? Array
    $base.each {|b| $: << '.' << b}
else
    $: << '.' << $base
end
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
require 'netbase'
#==============================================
#It will be same until here in every netclient.
#==============================================
base = NetBase.new(ARGV)
base.run do
    require 'remoteclient'
    require 'config'
    include Config
    include Agent
    RemoteClient.start $config['home']
end
