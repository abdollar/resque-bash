Resque-bash
===========

Uisng Bash to provide pubhubsubbub - works across multiple machines using redis commands and is designed to be compatible with resque

Create background jobs and workers using a bash script.

Drop this into your rails project or use this repo as is.

Resque-bash supports the standard Resque web frontend which tells you what various bash workers are doing.

To create a job 

  $ ./script/resque-bash.sh -j

To run the bash script as a worker and process jobs from a queue

  $ ./script/resque-bash -w

To start the resque front end

  $ resque-web

To stop the resque front end

  $ resque-web --kill

Why did you I make this ? Should this exist at all? Rails can be slow to start and using bash to do quick ops-esque tasks is handy.

Note that this is calling redis-cli multiple times so it's starting and tearing down sockets constantly and is not performant, though redis can handle a lot of abuse

Your mileage will be bad with this tool, use it wisely.

<a name='section_Contributing'></a>
Contributing
------------

Read the [Contributing][cb] wiki page first.

Once you've made your great commits:

1. [Fork][1] Resque-bash
2. Create a topic branch - `git checkout -b my_branch`
3. Push to your branch - `git push origin my_branch`
4. Create a [Pull Request](https://help.github.com/pull-requests/) from your branch
5. That's it!
</a>
