#!/usr/local/bin/ruby
require 'net/http'
#=================================
#         Config
#=================================
$base = 'http://webproxy.india.sun.com/netdb/'
eval File.open('.netdbrc').readlines.join("\n") if FileTest.exist? ".netdbrc"
#=================================

def require( resource )
    begin
        super
    rescue LoadError
        $:.each {|lp|
            begin
                if lp =~ /http:\/\//i
                    puts "fetch>#{lp}#{resource}.rb"
                    response = Net::HTTP.get_response(URI.parse("#{lp}#{resource}.rb"))
                    if response.code.to_i == 200
                        eval response.body
                        $" << "#{resource}.rb"
                        return true
                    else
                        puts "=>#{response.code}"
                    end
                end
            rescue;end
        }
    end
end

$:.push $base

require 'fetchlib'
require 'pathname'
include Fetchlib
host = ARGV.shift
port = 80
src = ARGV.shift
dest = ARGV.shift

case host
when /^([^:]+):([0-9]+)$/
    port = $2
    host = $1
when /^http:\/\/([^:]+):([0-9]+)(\/[^ ]+)$/
    port = $2
    host = $1
    src = $3
when /^http:\/\/([^\/]+)(\/[^ ]+)$/
    host = $1
    src = $2
end

if dest.nil?
    dest = Pathname.new(src).basename.to_s
end

begin
puts "host=#{host}, port=#{port}, src=#{src}, dest=#{dest}"
controller = Controller.new(host, port, src, dest)
puts "#{controller.count()} files"

rescue Exception => e 
    puts e.message
    puts e.backtrace.join("\n")
end
