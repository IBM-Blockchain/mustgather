@echo off
rem*******************************************************************************
rem  IBM Confidential
rem  OCO Source Materials
rem  5737-J29, 5737-B18
rem  (C) Copyright IBM Corp. 2020 All Rights Reserved.
rem  The source code for this program is not  published or otherwise divested of
rem  its trade secrets, irrespective of what has been deposited with
rem  the U.S. Copyright Office.
rem *******************************************************************************

rem!/bin/bash
set -e

set kube=kubectl
set openShift=oc

set thing=%kube%

set namespace=
set type=

set imagePrefix=carolinefletcher/

rem dev mode vars
set devMode=false
set dockerUserName=
set dockerPassword=
set dockerEmail=

:usage
    cat << EOF
    Usage:
    ./runMustGather.sh [options]

    Options:
    --namespace <n>
        The namespace of the IBM Blockchain instance. If you don't provide this, the tool will only gather a subset of information
    --type <t>
        The type of environment your cluster is running in. Possbile values are "kb" or "oc". Defaults to Kubernetes
EOF

:setEnvironmentType
    if [ -n "%type%" ] (
        if [ "%type%" == "kb" ] (
            thing=%kube%
        ) elif [ "%type% == "oc" ] (
            thing=%openShift%
        ) else
            echo "type argument was not valid. Values can be kb or oc"
            CALL :usage
            exit 1
        )
    )

:processArgs
    if [ "%devMode%" == true ] (
        if [ -z "%dockerUserName%" ] (
            echo "dockerUserName arguement must be set in dev mode"
            CALL :usage
            exit 1
        )

        if [ -z "%dockerPassword%" ] (
            echo "dockerPassword arguement must be set in dev mode"
            CALL :usage
            exit 1
        )

        if [ -z "%dockerEmail%" ] (
            echo "dockerEmail arguement must be set in dev mode"
            CALL :usage
            exit 1
        )
    )

    CALL :setEnvironmentType


:while
    if "%~1%"!="" (
        if "~%1"=="/devMode" (
            devMode=true
        )
        if "~%1"=="/dockerUserName:" (
            shift
            dockerUserName="%~1%"
            imagePrefix="%dockerUserName%/"
        )
        if "~%1"=="/dockerPassword:" (
            shift
            dockerPassword="%~1%"
        )
        if "~%1"=="/dockerEmail:" (
            shift
            dockerEmail="%~1%"
        )
        if "~%1"=="/namespace:" (
            shift
            namespace="%~1%"
        )
        if "~%1"=="/type:" (
            shift
            type="%1%"
        )
        if "~%1"=="/help" (
            CALL usage
            exit
        )
        * )
            echo "Unknown argument $1"
            usage
            exit 1
            ;;
    esac
    shift
    )
done

processArgs

if "%devMode%"==true(
    echo "$(date) Running in dev mode"
)

echo "$(date) check if mustgather namespace exists"
if ! %thing% get namespace mustgather ; then
    echo "$(date) Creating mustgather name space"
    %thing% create namespace mustgather
fi


if "%devMode%"==true (
    echo "$(date) check if secret exists"
    if %thing% get secret mustgathersecret -n mustgather (
      %thing% delete secret mustgathersecret -n mustgather
    )

    echo "$(date) Creating secret"
    %thing% create secret docker-registry mustgathersecret --docker-server=https://index.docker.io/v2/ --docker-username="$dockerUserName" --docker-password="$dockerPassword" --docker-email="$dockerEmail" -n mustgather
)

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
if  %thing% get clusterrole mustgather:reader -n mustgather (
    echo "$(date) Deleting cluster role"
    %thing% delete clusterrole mustgather:reader
)

echo "$(date) Creating mustgather:reader cluster role"
%thing% apply -f mustgather_role.yaml

echo "$(date) Check if mustgather-view cluster role binding exists"
if %thing% get clusterrolebinding mustgather-view -n mustgather (
    echo "$(date) Deleting cluster role binding"
    %thing% delete clusterrolebinding mustgather-view
)

echo "$(date) Creating mustgather-view role binding"
%thing% create clusterrolebinding mustgather-view --clusterrole=mustgather:reader --serviceaccount=mustgather:default


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
if %thing% get pod mustgather -n mustgather (
    echo "$(date) pod must gather exists so deleting pod"
    %thing% delete pod mustgather -n mustgather
)

echo "$(date) Creating pod mustgather"
%thing% apply -f mustgather.yaml -n mustgather

echo "$(date) Wating for pod must gather to be created (this can take up to 10 minutes)"
%thing% wait -n mustgather --for=condition=Ready pod/mustgather --timeout=1200s

timestamp=$(date +"%m%d%Y%H%M")


echo "$(date) Running must gather tool"
if defined namespace (
    %thing% exec mustgather -n mustgather -- ibp-mustgather --noserver -f mustgather
) else (
    %thing% exec mustgather -n mustgather -- ibp-mustgather -n "%namespace%" --noserver
)

echo "$(date) Retrieving archive file"
%thing% cp mustgather/mustgather:/tmp/mustgather.tar.gz ./mustgather-"$timestamp".tar.gz

echo "$(date) Archive file retrieved and is located at ./mustgather-$timestamp.tar.gz"
echo "$(date) Finished"

