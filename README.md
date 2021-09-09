# ***IBM Blockchain Platform Must Gather Tool***

## ***Introduction***

IBM Blockchain Platform Must Gather Tool has two use cases. The first use case is to be able to perform checks on your environment, the second use case is to collect logs and information about you environment. The environment can be one with a current IBM Blockchain Platform installation or one you intend to perform an installation on. 

### Checks Performed
The checks which will be performed on a environment without an IBP installation include:

- Checking the version of Kubernetes used
- Where applicable, checking the version on OpenShift used
- Checking there are enough worker nodes
- Checking there are enough worker nodes in each zone
- Checking each worker node has enough resources

The checks which will be performed in addition to those above with an IBP installation include:

- Checking certificate expiry dates
- Checking the issuer is correct for admin certificates
- Checking each Peer has enough resources
- Checking each Orderer has enough resources
- Checking each CA has enough resources
- Checking each of the public endpoints can be reached

### Logs and Information Collected
The information collected without an IBM Blockchain Platform installation include:

- Storage Classes information
- Worker Node information

The information collected in addition to those above with an IBM Blockchain Platform installation include: 

- Config Maps information
- Deployments information
- Ingress information including which type of ingress used
- Node information (Peers, Orderers, and CAs)
    - Logs
    - Version
    - Status
    - Resources assigned
    - Metadata   
- Pod status
- Persistent Volume Claims information
- Replica Set information
- Services information

## ***Running IBM Blockchain Platform Must Gather Tool***

The IBM Blockchain Platform Must Gather tool runs as a pod in a Kubernetes or Openshift cluster environment. This repository contains a script which can be downloaded and run.

1. Download the script to your local file system
2. Ensure you can connect to your cluster from the CLI

There are two ways to run the tool as described above. 

If you just want to collect information on your environment without collecting any information about a IBM Blockchain Platform installation then run the following:

```
    ./run-mustgather.sh
```

If you want to collect information about your environment and IBM Blockchain Platform installation, then you need to provide the namespace of the installation:

```
    ./run-mustgather.sh -n <ibpNameSpace>
```

If you want to run the script on Openshift then use the `-type`option:

```
    ./run-mustgather.sh -n <ibpNameSpace> -type oc
```

If you want to run the script on Windows then you will need to use powershell:

```
    ./run-mustgasther.psl
```
