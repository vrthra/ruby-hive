module Config
    $config ||= {}
    $hive = {}
    $config['version'] = "0.1"
    #name of the irc query helper
    $config['queen'] = 'queen'
    $config['keeper'] = 'keeper'
    #the ircd server.
    $config['home'] = 'localhost'
    $config['hive'] = '#hive'
    
    
    #$config['mail.smtphost'] = 'biff-mail1.india.sun.com'
    #$config['mail.host'] = 'mail-apac.sun.com'
    #$config['mail.user'] = 
    #$config['mail.pass'] = 
    #$config['mail.box'] = 'hive'
    #$config['mail.type'] = 'RECENT' | 'ALL' | 'NEW'
    #$config['mail.addflags'] = [:Deleted,:Seen,:Answered,:Draft,:Flagged]
    #$config['mail.remflags'] = [:Seen]
    #$config['mail.copyto'] = 'hive-seen'
    #$config['mail.sleeptime'] = 
end

