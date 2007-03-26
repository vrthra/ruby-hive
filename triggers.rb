#
#!create trigger mytr1 for join use !do $my:os
#!create trigger mytr1 for join use { reply machine + '|joined'}
trigger :dummytrig do |channel, machine, action, args|
    case action
    when /join/
        begin
            reply "channel:#{channel} machine:#{machine} action:#{action} args:#{args} initargs:#{initargs}"
            say '!do $system:version',machine do |machine,reply|
                reply "reply #{reply} from #{machine}:#{initargs}"
            end
        rescue Exception => e
            puts e.message
            puts e.backtrace.join("\n")
        end
    when /part/
        reply "#{machine} leaving #{channel}"
        reply "channel:#{channel} machine:#{machine} action:#{action} args:#{args}"
    end
end

