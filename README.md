Infinispan Ansible Hyperfoil Benchmark
=========
Infinispan Benchmark via Hyperfoil orchestrated by Ansible

Manages starting a cluster of Infinispan Server container nodes along with uploading a cache configuration to be performance tested with Hyperfoil with automatic provisioning of a controller and agent nodes.

Requirements
------------

Ansible controller node requires ansible and jmespath to be installed
 - Also need the 3 hyperfoil roles
   - ansible-galaxy install hyperfoil.hyperfoil_setup
     - `ansible-galaxy install hyperfoil.hyperfoil_setup,0.19.0`
   - ansible-galaxy install hyperfoil.hyperfoil_shutdown
     - `ansible-galaxy install hyperfoil.hyperfoil_shutdown,0.19.0`
   - ansible-galaxy install hyperfoil.hyperfoil_test
     - `ansible-galaxy install hyperfoil.hyperfoil_test,0.19.0`

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
* hyperfoil.yml - Playbook that encompasses starting the hyperfoil controler, agents and starts a run and then shuts them all down. Note the server must already be running and configured in the server hosts file.
* hyperfoil_controller.yml - Sets up the hyperfoil controller.
  * This playbook can also be ran with `-e operation=shutdown` to shutdown the controller and agents if running
* hyperfoil_agent.yml - Runs a hyperfoil jobs, requires the controller and Infinispan servers to already be running.
  * Utilizes the `test_name` variable to read a templated file with extension `yaml.j2` in the `benchmarks` directory. Default is `hotrod-benchmark`

The three main playbooks directly reference the three roles of the same name. They each have default values that can be overridden via the ansible command line such as `-e cache_name=name-of-my-cache`.

* The defaults for all roles are found at [all.yaml](group_vars/all.yaml)
* Server defaults are [main.yaml](roles/server/defaults/main.yml)
* Hyperfoil Controller arguments are [main.yaml](roles/hyperfoil_controller/defaults/main.yml)
* Hyperfoil agent arguments are [main.yaml](roles/hyperfoil_agent/defaults/main.yml)

Internal Steps
--------------
All of the roles internally have the notion of the following "steps" that are controlled by the operation argument. Note that as mentioned above shutdown is not ran via explicit playbook invocation other than benchmark.

* init
* run
* stats (hyperfoil_agent doesn't have this one)
  * Generates stats output include JFR files which are automatically downloaded locally
* shutdown (hyperfoil_agent doesn't have this one)

Running a playbook will run the respective roles for each of these. If instead you want to run a subset you can use the operation argument as such `ansible-playbook -e operation=run`.



License
------------

Apache License, Version 2.0
