# KnuckleCluster

Have you ever wanted to shuck away the hard, rough exterior of an ECS cluster and get to the soft, chewy innards? Sounds like you need KnuckleCluster!
This tool provides scripts, invoked via cli or rakefile, to list, connect to and/or run commands on ecs agents and containers via ssh.  This makes it very easy to interrogate ECS agents and containers without having to go digging for IP addresses and things.
Primarily created as a tool to connect to instances in an ECS cluster and see what is running on them, it has evolved slightly to include the ability to list instances in spot requests and auto-scaling groups.

## Features
* See what agents in your ECS cluster are doing
* Easily connect to running agents
* Easily connect and get a console inside running containers
* Create shortcuts to oft-used commands and run them easily
* Optionally integrates with [aws-vault](https://github.com/99designs/aws-vault) for AWS authentication

## Development Status
Is being used in production for various projects and is considered stable. Any new features/bug fixes etc are most welcome!

## Installation

KnuckleCluster can be used in two ways:
1.  As a system-wide executable with a config file (preferred)
1.  As a rake task in your project

Install the executable with:

    $ gem install knuckle_cluster

OR

Add this line to your application's Gemfile:

```ruby
source 'https://rubygems.envato.com/' do
  gem 'knuckle_cluster'
end
```

And then execute:

    $ bundle


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
  hide:
    container: some_container_regex_i_dont_care_about
    task: some_task_regex_i_dont_care_about
```

You can also use inheritance to simplify the inclusion of multiple similar targets:
```
super_platform:
  <<: *default_platform
  cluster_name: super-platform-ecs-cluster-ABC123

ultra_platform:
  <<: *default_platform
  cluster_name: ultra-platform-ecs-cluster-DEF987
  sudo: false

default_platform: &default_platform
  region: us-east-1
  bastion: platform_bastion
  rsa_key_location: ~/.ssh/platform_rsa_key
  ssh_username: ubuntu
  sudo: true
  aws_vault_profile: platform_super_user

other_platform: &other_platform
  region: us-east-1
  bastion:
    username: ubuntu
    host: bastion.endpoint.example.com
    rsa_key_location: ~/.ssh/bastion_rsa_key
  rsa_key_location: ~/.ssh/platform_rsa_key
  ssh_username: ubuntu
  sudo: true
  aws_vault_profile: platform_super_user
```

See [Options for Knuckle Cluster](#options-for-knuckle-cluster) below for a list of what each option does.

Command line options:

```
knuckle_cluster list - list all available clusters
knuckle_cluster CLUSTER_PROFILE agents - list all agents and select one to start a shell
knuckle_cluster CLUSTER_PROFILE containers - list all containers and select one to start a shell
knuckle_cluster CLUSTER_PROFILE logs CONTAINER_NAME - tail the logs for a container
knuckle_cluster CLUSTER_PROFILE CONTAINER_NAME [OPTIONAL COMMANDS] - connect to a container and start a shell or run a command
knuckle_cluster CLUSTER_PROFILE SHORTCUT_NAME - run a shortcut defined in your knuckle_cluster configuration
knuckle_cluster CLUSTER_PROFILE tunnel TUNNEL_NAME - open a tunnel defined in your knuckle_cluster configuration
knuckle_cluster CLUSTER_PROFILE scp source destination - copied a file via scp to or from a container or agent. Use container:<location> or agent:<location>
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
$ knuckle_cluster super_platform containers
```
Which will give you the output and run bash for you on the actual docker container:
```
Listing Containers
TASK              | AGENT               | INDEX | CONTAINER
------------------|---------------------|-------|--------------------
task-one          | i-123abc123abc123ab | 1     | t1-container-one
task-two          | i-123abc123abc123ab | 2     | t2-container-one
                  |                     | 3     | t2-container-two
task-three        | i-456def456def456de | 4     | t3-container-one
                  |                     | 5     | t3-container-two
                  |                     | 6     | t3-container-three

Connect to which container?
```

Same with connecting directly to agents
```
$ knuckle_cluster super_platform agents
```
```
Listing Agents
INDEX | INSTANCE_ID         | TASK       | CONTAINER
------|---------------------|------------|--------------------
1     | i-123abc123abc123ab | task-one   | t1-container-one
      |                     | task-two   | t2-container-one
      |                     |            | t2-container-two
2     | i-456def456def456de | task-three | t3-container-one
      |                     |            | t3-container-two
      |                     |            | t3-container-three

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
cluster_name | The name of the cluster (not the ARN). eg 'my-super-cluster'. One of `cluster_name`,`spot_request_id` or `asg_name` is required.
spot_request_id | The spot request ID you are connecting to. eg 'sfr-abcdef'. One of `cluster_name`,`spot_request_id` or `asg_name` is required.
asg_name | The auto-scaling group name you are connecting to. eg 'very-scaly-group'. One of `cluster_name`,`spot_request_id` or `asg_name` is required.
region | The AWS region you would like to use. Defaults to `us-east-1`
bastion | if you have a bastion to proxy to your ecs cluster via ssh, put the name of it here as defined in your `~/.ssh/config` file.  Alternatively, this can be a collection of keys for `username`, `host`, and `rsa_key_location`
rsa_key_location | The RSA key needed to connect to an ecs agent eg `~/.ssh/id_rsa`.
ssh_username | The username to conncet. Will default to `ec2-user`
sudo | true or false - will sudo the `docker` command on the target machine. Usually not needed unless the user is not a part of the `docker` group.
aws_vault_profile | If you use the `aws-vault` tool to manage your AWS credentials, you can specify a profile here that will be automatically used to connect to this cluster.
profile | Another profile to inherit settings from. Settings from lower profiles can be overridden in higher ones.
hide | allows you to specify a regex for either `task` or `container` to omit these from being shown

## Spot Fleets
If you wish to see what instances are running within a spot fleet, KnuckleCluster can do that too!.  In your config, use `spot_request_id` instead of `cluster_name`.  Note that the `containers` command will not work when invoking (use `agents` instead).

## AutoScaling Groups
If you wish to see what instances are running within an ASG, KnuckleCluster can do that too!.  In your config, use `asg_name` instead of `cluster_name`.  Note that the `containers` command will not work when invoking (use `agents` instead).

## SCP
You can use Knuckle Cluster to copy files in and out of agents or containers.  Note that this will only work where one of the source or destination is your local machine, copying between containers is not yet supported.  Use a syntax similar to existing `scp` syntax when specifying a source or destination, but use the keyword `container` or `agent` for the remote. When using one of these keywords, you will be prompted as to which agent/container you wish to use.
```
#Copy some_file.txt into a container at /app/some_file.txt
knuckle_cluster super_platform scp ./some_file.txt container:/app/some_file.txt

#Copy /app/some_file.txt from a remote container to ./some_file.txt on your local machine
knuckle_cluster super_platform scp container:/app/some_file.txt ./some_file.txt

#Copy some_file.txt into an agent at ~/some_file.txt
knuckle_cluster super_platform scp ./some_file.txt agent:~/some_file.txt

#Copy /app/some_file.txt from a remote container to ./some_file.txt on your local machine
knuckle_cluster super_platform scp agent:~/some_file.txt ./some_file.txt
```

## Maintainer
[Envato](https://github.com/envato)

## Contributors
- [Peter Hofmann](https://github.com/envatopoho)
- [Giancarlo Salamanca](https://github.com/salamagd)
- [Jiexin Huang](https://github.com/jiexinhuang)

## License

`KnuckleCluster` uses MIT license. See
[`LICENSE.txt`](https://github.com/envato/knuckle_cluster/blob/master/LICENSE.txt) for
details.

## Code of conduct

We welcome contribution from everyone. Read more about it in
[`CODE_OF_CONDUCT.md`](https://github.com/envato/knuckle_cluster/blob/master/CODE_OF_CONDUCT.md)

## Contributing

For bug fixes, documentation changes, and small features:

1. Fork it ( https://github.com/[my-github-username]/knuckle_cluster/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

For larger new features: Do everything as above, but first also make contact with the project maintainers to be sure your change fits with the project direction and you won't be wasting effort going in the wrong direction.
