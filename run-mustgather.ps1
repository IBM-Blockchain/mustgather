param([Alias("n")][string] $namespace, [Alias("t")][string] $type, [Alias("d")][switch] $devMode, [Alias("u")][string] $dockerUserName, [Alias("p")][SecureString] $dockerPassword, [Alias("e")][string] $dockerEmail, [Alias("h")][switch] $help)

$kube="kubectl"
$openShift="oc"

$thing=$kube

$imagePrefix="ibmcom/"

function usage {
    $usageOutput = @"
    Usage:
    ./runMustGather.sh [options]

    Options:
    --namespace <n>
        The namespace of the IBM Blockchain instance. If you don't provide this, the tool will only gather a subset of information
    --type <t>
        The type of environment your cluster is running in. Possbile values are "kb" or "oc". Defaults to Kubernetes
"@

    Write-Output $usageOutput
}

function setEnvironmentType {
    if ( $type -ne "" ) {
        if ($type -eq "kb") {
            $thing=$kube
        } elseif ( $type -eq "oc" ) {
            $thing=$openShift
        } else {
            Write-Output "type argument was not valid. Values can be kb or oc"
            usage
            exit 1
        }
    }
}

function processArgs {
    if($help) {
        usage
        exit 0
    }
    if ($devMode) {
        if ($dockerUserName -eq "") {
            Write-Output "dockerUserName arguement must be set in dev mode"
            usage
            exit 1
        }

        if ($null -eq $dockerPassword) {
            Write-Output "dockerPassword arguement must be set in dev mode"
            usage
            exit 1
        }

        if ($dockerEmail -eq "") {
            Write-Output "dockerEmail arguement must be set in dev mode"
            usage
            exit 1
        }
    }

    setEnvironmentType
}

processArgs

if ($devMode) {
    Write-Output "$(Get-date) Running in dev mode"
}

Write-Output "$(Get-date) Check if mustgather namespace exists"
if ( -not (& $thing get namespace mustgather)) {
    Write-Output "$(Get-date) Creating mustgather name space"
    & $thing create namespace mustgather
}

if ($devMode) {
    Write-Output "$(Get-date) Check if secret exists"
    if (& $thing get secret mustgathersecret -n mustgather) {
      & $thing delete secret mustgathersecret -n mustgather
    }

    Write-Output "$(Get-date) Creating secret"
    & $thing create secret docker-registry mustgathersecret --docker-server=https://index.docker.io/v2/ --docker-username="$dockerUserName" --docker-password="$dockerPassword" --docker-email="$dockerEmail" -n mustgather
}

Write-Output "$(Get-date) Creating yaml role file"
$clusterRoleDef = @'
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
'@

$clusterRoleDef -f 'string' | Out-File ./mustgather_role.yaml

Write-Output "$(Get-date) Check if mustgather:reader cluster role exists"
if (& $thing get clusterrole mustgather:reader -n mustgather ) {
    Write-Output "$(Get-date) Deleting cluster role"
    & $thing delete clusterrole mustgather:reader
}

Write-Output "$(Get-date) Creating mustgather:reader cluster role"
& $thing apply -f mustgather_role.yaml

Write-Output "$(Get-date) Check if mustgather-view cluster role binding exists"
if (& $thing get clusterrolebinding mustgather-view -n mustgather ) {
    Write-Output "$(Get-date) Deleting cluster role binding"
    & $thing delete clusterrolebinding mustgather-view
}

Write-Output "$(Get-date) Creating mustgather-view role binding"
& $thing create clusterrolebinding mustgather-view --clusterrole=mustgather:reader --serviceaccount=mustgather:default


Write-Output "$(Get-date) Creating yaml file for new pod"
$podDef = @"
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
"@

$podDef -f 'string' | Out-File ./mustgather.yaml

Write-Output "$(Get-date) Check if pod mustgather exists"
if (& $thing get pod mustgather -n mustgather ) {
    Write-Output "$(Get-date) pod must gather exists so deleting pod"
    & $thing delete pod mustgather -n mustgather
}

Write-Output "$(Get-date) Creating pod mustgather"
& $thing apply -f mustgather.yaml -n mustgather

Write-Output "$(Get-date) Wating for pod must gather to be created (this can take up to 10 minutes)"
& $thing wait -n mustgather --for=condition=Ready pod/mustgather --timeout=1200s

Write-Output "$(Get-date) Running must gather tool"
if ($namespace -eq "" ) {
    & $thing exec mustgather -n mustgather -- ibp-mustgather --noserver -f mustgather
} else {
    & $thing exec mustgather -n mustgather -- ibp-mustgather -n $namespace --noserver
}

$timestamp="$(Get-Date -Format "MMddyyHHmm")"

Write-Output "$(Get-date) Retrieving archive file"
& $thing cp mustgather/mustgather:/tmp/mustgather.tar.gz ./mustgather-$timestamp.tar.gz

Write-Output "$(Get-date) Archive file retrieved and is located at ./mustgather-$timestamp.tar.gz"
Write-Output "$(Get-date) Finished"

