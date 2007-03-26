require 'basetrait'
require 'net/smtp'
class MailTrait
    include BaseTrait
    def init()
        @version = 0.2
        @tag = {}
        @host = 'biff-mail1.india.sun.com'
    end
    def run(cmd, args)
        case cmd
        when /^send$/
            return sendmail(args)
        else
            puts "Unknown #{cmd} | #{args}"
        end
    end

    def sendmail(args)
        case args
        when /^([^:]+):(.+)/
            to = $1
            sub = $2
            message = <<EOF
From: bee@#{@me.nick}
To: #{to}
Subject: #{sub}
-from hive.
EOF
            host = $config['mail.smtphost'] || @host
            Net::SMTP.start(host) do |smtp|
                smtp.send_message message, 'bee@'+@me.nick, to
            end
            puts "Sending to #{to}"
            'sent'
        else
            puts "Unknown: #{args}"
            'invalid format'
        end
    end
end
@traits['mail'] = MailTrait.new(self)
