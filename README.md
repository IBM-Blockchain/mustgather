# IBM Blockchain Platform Must Gather Tool

IBM Blockchain Platform Must Gather is a tool that has two use cases. The first use case is to be able to perform checks on your environment. This environment can be one with a current IBM Blockchain Platform installation or one you intend to perform an installation on. 

The checks which will be performed on a environment without an IBP installation include:

- Checking the version of Kubernetes used
- Where applicable, checking the version on OpenShift used
- Checking there are enough worker nodes
- Checking there are enough worker nodes in each zone
- Checking each worker node has enough resources

The checks which will be performed in addition to those above the environments with an IBP installation include:

- Checking certificate expiry dates
- Checking the issuer is correct for admin certificates
- Checking each Peer has enough resources
- Checking each Orderer has enough resources
- Checking each CA has enough resources
- Checking each of the public endpoints can be reached

The second use case is to collect logs and information about an IBM Blockchain Platform installation. 

The information collected includes:

- Node information (Peers, Orderers, and CAs)
    - Logs
    - Version
    - Status
    - Resources assigned
    - Metadata
   
- Pod status
- Persistent Volume Claims information
- Config Maps information
- Deployments information
- Ingress information including which type of ingress used
- Replica Set information
- Services information
- Storage Classes information
- Worker Node information

## **Running IBM Blockchain Platform Must Gather Tool**

The  IBM Blockchain Platform Must Gather tool runs as a pod in a Kubernetes or Openshift cluster environment. This repository contains a script which can be downloaded and run.

1. Download the script to your local file system
2. Ensure you can connect to your cluster from the CLI

There are two ways to run the tool as described above. 

If you just want to collect information on your environment without collecting any information about a IBM Blockchain Platform installation then run the following:

```
    ./runMustGather.sh
```

If you want to collect information about your environment and IBM Blockchain Platform installation, then you need to provide the namespace of the installation:

```
    ./runMustGather.sh -n <ibpNameSpace>
```

If you want to run the script on Openshift then use the `-type`option:

```
    ./runMustGather.sh -n <ibpNameSpace> -type oc
```
