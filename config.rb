module Config
    $config ||= {}
    $hive = {}
    $config['version'] = "0.1"
    #name of the query helper
    $config['queen'] = 'queen'
    $config['keeper'] = 'keeper'
    #the hive server.
    $config['home'] = 'localhost' # CHANGE THIS to your IRC/Jabber Hostname.
    $config['port'] = '6667' #5222
    $config['hive'] = '#hive'#'hive'
    
    $config['connector'] = 'ircconnector'#'jabberconnector'

    #$config['mail.smtphost'] = ''
    #$config['mail.host'] = ''
    #$config['mail.user'] = 
    #$config['mail.pass'] = 
    #$config['mail.box'] = 'hive'
    #$config['mail.type'] = 'RECENT' | 'ALL' | 'NEW'
    #$config['mail.addflags'] = [:Deleted,:Seen,:Answered,:Draft,:Flagged]
    #$config['mail.remflags'] = [:Seen]
    #$config['mail.copyto'] = 'hive-seen'
    #$config['mail.sleeptime'] = 
end

