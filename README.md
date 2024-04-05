Infinispan Ansible Hyperfoil Benchmark
=========
Infinispan Benchmark via Hyperfoil orchestrated by Ansible

Manages starting a cluster of Infinispan Server container nodes along with uploading a cache configuration to be performance tested with Hyperfoil with automatic provisioning of a controller and agent nodes.

Requirements
------------

Ansible controller node requires ansible and jmespath to be installed
 - Also need the 3 hyperfoil roles
   - Install by running `ansible-galaxy role install -r roles/requirements.yml`

Ansible managed nodes require sshd and the ansible controller public key installed on them
- Infinispan Server nodes will install podman if a sudoer, otherwise must be installed manually
- Hyperfoil nodes will install latest open jdk 17 if a sudoer, otherwise must be installed manually

Roles
------------
server: Manages starting and stopping Infinispan servers. Utilizes the `server` inventory group to determine nodes
- server_image: allows providing a specific image, default is: quay.io/infinispan/server:latest
hyperfoil_controller: Manages starting and stopping the hyperfoil controller node. Requires a singleton in the `hyperfoil_controller` inventory group. It is recommended for this to be the localhost `ansible_connnection=local`.
hyperfoil_agent: Manages deployment and running of Hyperfoil agent nodes. Utilizes the `hyperfoil_agent` inventory group to determine nodes.

Example Inventory
------------
Here is an example inventory.ini file defining 3 Infinispan server nodes, a local connection hyperfoil contoller and 2 hyperfoil agent nodes (replacing the host values with a resolvable hostname)
```ini
[all:vars]
user=myusername
pass=mypassword

[server]
server-host[1-3]

[hyperfoil_controller]
controller-host ansible_connection=local

[hyperfoil_agent]
agent-host[4-5]
```

Playbooks
--------------
There are three main playbooks: server.yml (Infinispan Server), hyperfoil_controller.yml and hyperfoil_agent.yml. There are two other playbooks that encompass a combination of the main three: benchmark.yml (runs all three of the main playbooks and if no errors shuts everything down) and hypefoil.yml (starts the hyperfoil controller and agent and if no errors shuts them done after)

* benchmark.yml - Overarching playbook that encompasses all of the ones below. Will start the Infinispan server nodes, Hyperfoil controller, start a Hyperfoil run on the agents, shutdown the Hyperfoil controller and shutdown and remove the Infinispan container
* server.yml - Starts the Infinispan server container nodes with host networking enabled. Also uploads the `cache_name` named cache with the configuration in the `cache_file` file.
  * Default `cache_name` variable is `benchmark` and `cache_file` is `files/cache.xml` if you wish to change the name or xml file.
  * This playbook can also be ran with `-e operation=shutdown` to shutdown the inventoried servers
  * The configured host group can be replaced by passing `-e server_hosts=<host1,host2>'
* hyperfoil.yml - Playbook that encompasses starting the hyperfoil controler, agents and starts a run and then shuts them all down. Note the server must already be running and configured in the server hosts file.
* hyperfoil_controller.yml - Sets up the hyperfoil controller.
  * This playbook can also be ran with `-e operation=shutdown` to shutdown the controller and agents if running
  * The configured host group can be replaced by passing `-e hyperfoil_controller_host=<host>'
* hyperfoil_agent.yml - Runs a hyperfoil jobs, requires the controller and Infinispan servers to already be running.
  * Utilizes the `test_name` variable to read a templated file with extension `yaml.j2` in the `benchmarks` directory. Default is `hotrod-benchmark`
  * The configured host group can be replaced by passing `-e hyperfoil_agent_hosts=<host1,host2>'
* all_benchmarks.yml - Runs multiple benchmarks in sequence. The instance must be running already, the playbook start the Hyperfoil controller
 and start/stop the server for each benchmark. A file with the benchmark definitions must be provided
  * Run this benchmark utilizing the sample definition as `-e @benchmark_definition.json`.
  * The `cache_file` and `test_name` should not be set.

The three main playbooks directly reference the three roles of the same name. They each have default values that can be overridden via the ansible command line such as `-e cache_name=name-of-my-cache`.

* The defaults for all roles are found at [all.yaml](group_vars/all.yaml)
* Server defaults are [main.yaml](roles/server/defaults/main.yml)
* Hyperfoil Controller arguments are [main.yaml](roles/hyperfoil_controller/defaults/main.yml)
* Hyperfoil agent arguments are [main.yaml](roles/hyperfoil_agent/defaults/main.yml)

### Benchmark definitions file

Running multiple tests at once with `all_benchmarks.yml` playbook requires the definition in the `benchmark` variable.
This is provided with the option `-e @<path-to.file>`.
Ansible is capable of handling JSON or YAML files as inputs and associate the content to variables.
Utilizing JSON as an example, the definition should follow:

```json
{
  "benchmarks": [
    {
      "name": "hyperfoil-benchmark-name",
      "cache": "cache-file.xml"
    }
  ]
}
```

The benchmark files are located on the `./benchmarks/` folder, at the project root.
The cache files are located in `./roles/server/files/` folder.

Internal Steps
--------------
All of the roles internally have the notion of the following "steps" that are controlled by the operation argument. Note that as mentioned above shutdown is not ran via explicit playbook invocation other than benchmark.

* init
* run
* stats (hyperfoil_agent doesn't have this one)
  * Generates stats output include JFR files which are automatically downloaded locally
* shutdown (hyperfoil_agent doesn't have this one)

Running a playbook will run the respective roles for each of these. If instead you want to run a subset you can use the operation argument as such `ansible-playbook -e operation=run`.


EC2 Benchmark
------------

It is also now possible to run this benchmark on AWS EC2 machines automatically.

To do this you must install the required AWS EC2 roles
 - Run command `ansible-galaxy collection install -r roles/ec2-requirements.yml`

Now all that is needed is to set your EC2 Secret Key environment variables
 - `export AWS_ACCESS_KEY_ID=<Key Id>`
 - `export AWS_SECRET_ACCESS_KEY=<Key>`

There are two playbooks that can be used to deploy on EC2. One that just provisions/manages
machines and another that runs an entire end to end benchmark. Note both of these
playbooks use the localhost group when interacting with AWS.

### aws-ec2.yml
This will provision and manage instances. The required arguments are the region (e.g `-e region=us-east-2`) and operation (e.g `-e operation=create`).
* The operations supported are `create`, `stop`, `start` and `delete`.
  * `create` - required to be ran first. This creates the configured instances, a local ssh file, and a local inventory file to interact with them.
  * `stop` - stops the currently running instances
  * `start` - restarts the instances if they had been stopped
  * `delete` - deletes all the instances, security group, ssh key (remote and local) and the local inventory

Note after doing `create` the working directory will contain two new files
 * `benchmark_${user}_${region}.pem` file is the private ssh to key to connect to the EC2 machines
 * `benchmark_${user}_${region}_inventory.yaml`

All the instances defaults are found at [main.yaml](roles/aws_ec2/defaults/main.yml).
The defaults for each of the node types are as follows:
* Infinispan Server
  * Debian O/S (Ubuntu would randomly kill pods and Amazon Linux doesn't distribute podman by default)
  * Disk space is 20 GB as 8 GB isn't quite enough by default
* Hyperfoil Controller
  * Amazon Linux O/S
  * 8 GB
* Hyperfoil Agent(s)
  * Amazon Linux O/S
  * 8 GB
You can override these values via normal ansible means https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable.
All node types should support RHEL and Fedora as well if you want to change the AMI used.

### ec2-benchmark.yml
This will run an end to end benchmark.
That is it will provision all the EC2 nodes, start ISPN server, Hyperfoil Controller,
run the Hyperfoil test, download the results and then delete all the EC2 elements.
The only required argument is the region (e.g. `-e region=us-east-2`).


License
------------

Apache License, Version 2.0
