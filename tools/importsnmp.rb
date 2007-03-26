require 'snmp'
include SNMP

base =ARGV.shift

puts "importing mib"
MIB.import_module("#{base}/plugins/snmp/proxyserv40.mib", ".")
puts "----------------------"
