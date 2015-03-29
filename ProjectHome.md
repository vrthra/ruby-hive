This project has nothing to do with [Hive](http://hive.sourceforge.net/) from MIT

The Hive is a distributed cluster with multiple participating machines. It is OS agnostic, and the cluster membership is dynamic. it supports a publish/subscribe paradigm with the channels serving as blackboards.

This cluster can be used to administer the group of participating machines or to monitor and summarize the performance characteristics of the cluster as a whole.

Agents are created and added to a single repository from where they migrate to machines that needs to use them.

The whole cluster is implemented on top of IRC protocol as it provides a convenient text based protocol that allows easy monitoring and debugging.

A quick tutorial and relevant information is provided in page [Hive](Hive.md)

The [ruby-ircd](http://code.google.com/p/ruby-ircd/) daemon was developed for use in this project (and is used internally to provide the hive server).

Latest:
Jabber Connector is checked in (not tested thoroughly yet.)
Change the connector type in config.rb to use.

### Screen Shots ###

  * Querying individual bees directly.


![http://ruby-hive.googlecode.com/svn/wiki/images/eg.png](http://ruby-hive.googlecode.com/svn/wiki/images/eg.png)

  * Use the aggregator Queen bee to collect and summarize responses

![http://ruby-hive.googlecode.com/svn/wiki/images/query.png](http://ruby-hive.googlecode.com/svn/wiki/images/query.png)

  * Same thing but a bit more complex

![http://ruby-hive.googlecode.com/svn/wiki/images/complex-query.png](http://ruby-hive.googlecode.com/svn/wiki/images/complex-query.png)

  * Keeper keeps track of bees required in each channel. This shows one machine as out status, which indicates that it may have gone down. As soon as the machine comes back up, it is directed to rejoin the channel.

![http://ruby-hive.googlecode.com/svn/wiki/images/keeper-status.png](http://ruby-hive.googlecode.com/svn/wiki/images/keeper-status.png)

