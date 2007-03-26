require 'ircd'
require 'queryclient'
require 'beekeeper'
require 'config'

$config['version'] = '0.1'
$config['timeout'] = 10
$config['port'] = 6667
$config['hostname'] = Socket.gethostname.split(/\./).shift
$config['starttime'] = Time.now.to_s

s = IRCServer.new( :Port => $config['port'] )
begin
    trap("INT"){ 
        s.carp "killing #{$$}"
        system("kill -9 #{$$}")
        s.shutdown
    }
    p = Thread.new {
        s.do_ping()
    }
    
    s.addservice($config['queen'], Agent::DbActor)
    s.addservice($config['keeper'], IrcClient::BeeKeeper)

    s.start

rescue Exception => e
    s.carp e
end
