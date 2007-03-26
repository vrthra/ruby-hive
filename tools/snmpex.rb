require 'snmp'
include SNMP

puts "importing mib"
#MIB.import_module("/space/store/29.Jun.p43/iplanet/ias/server/src/cpp/iws/netsite/lib/libsnmp/proxyserv40.mib", ".")
#MIB.import_module("/space/store/29.Jun.p43/iplanet/ias/server/work/B1/SunOS5.8_DBG.OBJ/plugins/snmp/proxyserv40.mib", ".")
puts "----------------------"

#snmpwalk -v 1 -c public -t 4 0 1.3.6.1.4.1.42
host = ARGV[0] || 'agneyam.india.sun.com'

#manager = Manager.new(:Host => host, :Port => 161, :Community => 'public', :Version => :SNMPv1)
manager = SNMP::Manager.new(:Host => host, :Port => 161, :Community => 'public', :Version => :SNMPv1,
    :MibModules => ['PROXY-MIB'] )
#start_oid = ObjectId.new("1.3.6.1.2")
start_oid = ObjectId.new("1.3.6.1.4.1.42")
next_oid = start_oid
while next_oid.subtree_of?(start_oid)
    response = manager.get_next(next_oid)
    varbind = response.varbind_list.first
    break if EndOfMibView == varbind.value
    next_oid = varbind.name
    puts "#{varbind.name.to_s}  #{varbind.value.to_s}  #{varbind.value.asn1_type}"
end
