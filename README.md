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

Knuckle Cluster can be used either as a part of an application via a rakefile, or at a system level.

You'll need to execute knuckle_cluster with appropriate AWS permissions on the cluster in question, stored in your ENV. I like to use `aws-vault` to handle this for me.

### System usage

Create a file: `~/.ssh/knuckle_cluster`.  This is the config file that will be used to make connections from the command line.  It is a yaml file.  The connection name is the key, and all parameters are below it. EG:
```
platform:
  cluster_name: platform-ecs-cluster-ABC123
  region: us-east-1
  bastion: platform_bastion
  rsa_key_location: ~/.ssh/platform_rsa_key
  ssh_username: ubuntu
  sudo: true
  aws_vault_profile: platform_super_user
  shortcuts:
    console:
      container: web
      command: bundle exec rails console
    db:
      container: worker
      command: script/db_console
  tunnels:
    db:
      local_port: 54321
      remote_host: postgres-db.yourcompany.com
      remote_port: 5432
```

You can also use inheritance to simplify the inclusion of multiple similar targets:
```
super_platform:
  cluster_name: super-platform-ecs-cluster-ABC123
  profile: default_platform

ultra_platform:
  cluster_name: ultra-platform-ecs-cluster-DEF987
  profile: default_platform
  sudo: false

default_platform:
  region: us-east-1
  bastion: platform_bastion
  rsa_key_location: ~/.ssh/platform_rsa_key
  ssh_username: ubuntu
  sudo: true
  aws_vault_profile: platform_super_user
```

See [Options for Knuckle Cluster](#options-for-knuckle-cluster) below for a list of what each option does.

Command line options:

```
knuckle_cluster CLUSTER_PROFILE agents - list all agents and select one to start a shell
knuckle_cluster CLUSTER_PROFILE containers - list all containers and select one to start a shell
knuckle_cluster CLUSTER_PROFILE logs CONTAINER_NAME - tail the logs for a container
knuckle_cluster CLUSTER_PROFILE CONTAINER_NAME [OPTIONAL COMMANDS] - connect to a container and start a shell or run a command
knuckle_cluster CLUSTER_PROFILE SHORTCUT_NAME - run a shortcut defined in your knuckle_cluster configuration
knuckle_cluster CLUSTER_PROFILE tunnel TUNNEL_NAME - open a tunnel defined in your knuckle_cluster configuration
```

### Rakefile usage

It takes one argument at minimum: `cluster_name` .  A region is likely also required as it will default to `us-east-1`.
Eg:
```
kc = KnuckleCluster.new(
  cluster_name: 'platform-ecs-cluster-ABC123',
  region: 'us-east-1',
  bastion: 'platform_bastion',
  rsa_key_location: "~/.ssh/platform_rsa_key",
  ssh_username: "ubuntu",
  sudo: true
)
task :agents do
  kc.connect_to_agents
end

task :containers do
  kc.connect_to_containers
end
```

invoke with `rake agents` or `rake containers`


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



Eg: To connect to a container, echo something and then immediately disconnect you could use:
```
kc.connect_to_containers(auto: true, command: "echo I love KnuckleCluster!")
```


## Options for Knuckle Cluster
Possible options are below. If left blank, they will be ignored and defaults used where available.:

Argument | Description
-------- | -----------
cluster_name | The name of the cluster (not the ARN). eg 'my-super-cluster'. Required
region | The AWS region you would like to use. Defaults to `us-east-1`
bastion | if you have a bastion to proxy to your ecs cluster via ssh, put the name of it here as defined in your `~/.ssh/config` file.
rsa_key_location | The RSA key needed to connect to an ecs agent eg `~/.ssh/id_rsa`.
ssh_username | The username to conncet. Will default to `ec2-user`
sudo | true or false - will sudo the `docker` command on the target machine. Usually not needed unless the user is not a part of the `docker` group.
aws_vault_profile | If you use the `aws-vault` tool to manage your AWS credentials, you can specify a profile here that will be automatically used to connect to this cluster.
profile | Another profile to inherit settings from. Settings from lower profiles can be overridden in higher ones.
