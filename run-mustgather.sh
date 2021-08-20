#!/bin/bash
set -e

kube=kubectl
openShift=oc

thing=$kube

namespace=
type=

#dev mode vars
devMode=false
imagePrefix=
dockerUserName=
dockerPassword=
dockerEmail=

function usage {
    cat << EOF
    Usage:
    ./runMustGather.sh [options]

    Options:
    --namespace <n>
        The namespace of the IBM Blockchain instance. If you don't provide this, the tool will only gather a subset of information
    --type <t>
        The type of environment your cluster is running in. Possbile values are "kb" or "oc". Defaults to Kubernetes
EOF
}

function setEnvironmentType {
    if [ -n "$type" ] ; then
        if [ "$type" == "kb" ] ; then
            thing=$kube
        elif [ "$type" == "oc" ] ; then
            thing=$openShift
        else
            echo "type argument was not valid. Values can be kb or oc"
            usage
            exit 1
        fi
    fi
}

function processArgs {
    if [ "$devMode" == true ] ; then
        if [ -z "$dockerUserName" ] ; then
            echo "dockerUserName arguement must be set in dev mode"
            usage
            exit 1
        fi

        if [ -z "$dockerPassword" ] ; then
            echo "dockerPassword arguement must be set in dev mode"
            usage
            exit 1
        fi

        if [ -z "$dockerEmail" ] ; then
            echo "dockerEmail arguement must be set in dev mode"
            usage
            exit 1
        fi
    fi

    setEnvironmentType
}

while [ "$1" != "" ]; do
    case $1 in
        -d | --devMode )
            devMode=true
            ;;
        -u | --dockerUserName )
            shift
            dockerUserName="$1"
            imagePrefix="$dockerUserName/"
            echo "$imagePrefix"
            ;;
        -p | --dockerPassword )
            shift
            dockerPassword="$1"
            ;;
        -e | --dockerEmail )
            shift
            dockerEmail="$1"
            ;;
        -n | --namespace )
            shift
            namespace="$1"
            ;;
        -t | --type )
            shift
            type="$1"
            ;;
        -h | --help )
            usage
            exit
            ;;
        * )
            echo "Unknown argument $1"
            usage
            exit 1
            ;;
    esac
    shift
done

processArgs

if [ "$devMode" == true ] ; then
    echo "$(date) Running in dev mode"
fi

echo "$(date) check if mustgather namespace exists"
if ! $thing get namespace mustgather ; then
    echo "$(date) Creating mustgather name space"
    $thing create namespace mustgather
fi


if [ "$devMode" == true ] ; then
    echo "$(date) check if secret exists"
    if $thing get secret mustgathersecret -n mustgather ; then
      $thing delete secret mustgathersecret -n mustgather
    fi

    echo "$(date) Creating secret"
    $thing create secret docker-registry mustgathersecret --docker-server=https://index.docker.io/v2/ --docker-username="$dockerUserName" --docker-password="$dockerPassword" --docker-email="$dockerEmail" -n mustgather
fi

echo "$(date) Creating yaml role file"
cat >./mustgather_role.yaml <<EOL
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
    name: "mustgather:reader"
rules:
    - apiGroups: ["ibp.com"]
      resources: ["ibpconsoles","ibpcas","ibppeers","ibporderers"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["configmaps","pods","pods/log","services","persistentvolumeclaims","namespaces","routes","secrets","nodes"]
      verbs: ["get", "list", "watch"]
    - apiGroups: ["apps"]
      resources: ["deployments","replicasets","services"]
      verbs: ["get", "list", "watch"]
    - apiGroups: ["extensions"]
      resources: ["ingresses"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["routes"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["get", "list", "watch"]
    - apiGroups: ["storage.k8s.io"]
      resources: ["storageclasses"]
      verbs: ["get", "list", "watch"]
EOL

echo "$(date) Check if mustgather:reader cluster role exists"
if  $thing get clusterrole mustgather:reader -n mustgather ; then
    echo "$(date) Deleting cluster role"
    $thing delete clusterrole mustgather:reader
fi

echo "$(date) Creating mustgather:reader cluster role"
$thing apply -f mustgather_role.yaml

echo "$(date) Check if mustgather-view cluster role binding exists"
if $thing get clusterrolebinding mustgather-view -n mustgather ; then
    echo "$(date) Deleting cluster role binding"
    $thing delete clusterrolebinding mustgather-view
fi

echo "$(date) Creating mustgather-view role binding"
$thing create clusterrolebinding mustgather-view --clusterrole=mustgather:reader --serviceaccount=mustgather:default


echo "$(date) Creating yaml file for new pod"
cat >./mustgather.yaml <<EOL
apiVersion: v1
kind: Pod
metadata:
 name: mustgather
spec:
 containers:
 - name: mustgather
   image: ${imagePrefix}ibp-mustgather
   command: ["/bin/bash", "-ec", "while :; do echo '.'; sleep 5 ; done"]
 imagePullSecrets:
 - name: mustgathersecret
EOL

echo "$(date) Check if pod mustgather exists"
if $thing get pod mustgather -n mustgather ; then
    echo "$(date) pod must gather exists so deleting pod"
    $thing delete pod mustgather -n mustgather
fi

echo "$(date) Creating pod mustgather"
$thing apply -f mustgather.yaml -n mustgather

echo "$(date) Wating for pod must gather to be created (this can take up to 10 minutes)"
$thing wait -n mustgather --for=condition=Ready pod/mustgather --timeout=1200s

echo "$(date) Running must gather tool"
if [ -z "$namespace" ] ; then
    $thing exec mustgather -n mustgather -- ibp-mustgather --noserver -f mustgather
else
    $thing exec mustgather -n mustgather -- ibp-mustgather -n "$namespace" --noserver
fi

echo "$(date) Retrieving archive file"
$thing cp mustgather/mustgather:/tmp/mustgather.tar.gz ./mustgather.tar.gz

echo "$(date) Archive file retrieved and is located at ./mustgather.tar.gz"
echo "$(date) Finished"

