path='/space/store/20.Nov.ws70/iplanet/ias/server/work/B1/SunOS5.8_DBG.OBJ/bin/'

take ExpectConn,"#{path}wadm --user admin --no-ssl" do

<[:$line=>/^Please enter admin-user-password> $/
/.*/
]

>[
adminadmin
]

<[:$line=>/wadm\> $/
/Sun Java System/
]

>[:chop=>true
list-config\t
]

<[:$line=>/wadm\> $/
/list-config-files   list-configs/
]

>[:chop=>true
s\t
]

<[:$line=>/ $/
/^list-configs.$/
]

>[
quit
]

end
