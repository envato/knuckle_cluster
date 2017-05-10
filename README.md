# KnuckleCluster

Have you ever wanted to shuck away the hard, rough exterior of an ECS cluster and get to the soft, chewy innards? Sounds like you need KnuckleCluster!
This tool provides scripts (usually invoked via rakefile) to list and connect to (and optionally run commands on) ecs agents and containers via ssh.

## Installation

Add this line to your application's Gemfile:

```ruby
source 'https://rubygems.envato.com/' do
  gem 'knuckle_cluster'
end
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install knuckle_cluster

## Usage

You'll need to execute this all with appropriate AWS permissions on the cluster in question, stored in your ENV. I like to use `aws-vault` to handle this for me.

It takes one argument at minimum: `cluster_name` .  A region is likely also required as it will default to `us-east-1`.
Eg:
```
kc = KnuckleCluster.new(cluster_name: 'cluster_name')
```

## Options for KnuckleCluster
Possible options are below. If left blank, they will be ignored and defaults used where available.:

Argument | Description
-------- | -----------
cluster_name | The name of the cluster (not the ARN). eg 'my-super-cluster'. Required
region | The AWS region you would like to use. Defaults to `us-east-1`
bastion | if you have a bastion to proxy to your ecs cluster via ssh, put the name of it here as defined in your `~/.ssh/config` file.
rsa_key_location | The RSA key needed to connect to an ecs agent eg `~/.ssh/id_rsa`.
ssh_username | The username to conncet. Will default to `ec2-user`


Once you have an instance of KnuckleCluster, you can now do things!
```
$ kc.connect_to_containers
```
Which will give you the output and run bash for you on the actual docker container:
```
Listing Containers
INDEX | NAME             | INSTANCE
------|------------------|--------------------
1     | container_1_name | i-062bfd0a0fa574d3d
2     | container_2_name | i-062bfd0a0fa574d3d

Connect to which container?
```

Same with connecting directly to agents
```
kc.connect_to_agents
```
```
Listing Agents
INDEX | INSTANCE_ID         | IP           | AZ              | TASKS
------|---------------------|--------------|-----------------|------------------------
1     | i-0ecf93dcae4a54725 | 10.97.96.141 | ap-southeast-2a | container_1_name, container_2_name

Connect to which agent?
```

Both `connect_to_containers` and `connect_to_agents` can have the following optional arguments:

Argument | Description
-------- | -----------
command | Runs a command on the specified container/agent. When connecting to containers, this defaults to `bash`
auto | Automatically connects to the first container/agent it can find. Handy when used in conjunction with `command`.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

