# Carvel

Carvel is a tool backed by VMware.

## What is Carvel

Is a tool to manage k8s resourses as a bulk (whole).

### By its definition

kapp (pronounced: kap) CLI encourages Kubernetes users to manage resources in bulk by working with "Kubernetes applications" (sets of resources with the same label). It focuses on resource diffing, labeling, deployment and deletion. Unlike tools like Helm, kapp considers YAML templating and management of packages outside of its scope, though it works great with tools that generate Kubernetes configuration.

## Features and highlights

- `Lightweight `- does not depend on server side components
- `Explicit` - Calculates changes, report and ask for approval
- `Dependency-aware` - orders dependency resource as namespaces and crds before changes. Also suppors declarative dependencies / custom ordering. 
- `Play with others` -  supports yaml, ytt, kustomize, helm template
- `Converges application resources` - (creates, updates and/or deletes resources) in each deploy
    - based on comparison between provided files and live objects in the cluster
- Separates calculation of changes (diff stage) from application of changes (apply stage)
- Waits for resources to be "ready"
- Creates CRDs and Namespaces first and supports custom change ordering
- Works without admin privileges and does not use custom CRDs
    - making it possible to use kapp as a regular user in a single namespace
- Records application deployment history  - Changes are kept in config maps
- Opt-in resource version management
    - for example, to trigger Deployment rollout when ConfigMap changes
- Optionally streams Pod logs during deploy
- Works with any group of labeled resources (kapp -a label:tier=web inspect -t)
- Works without server side components
- GitOps friendly (kapp app-group deploy -g all-apps --directory .)

## Resources

https://carvel.dev/kapp/

https://github.com/vmware-tanzu/carvel-kapp

## Installation

```bash
wget -O- https://carvel.dev/install.sh | bash
```

## <span style="color: red"> NOTE

I observed that `kapp` will `NOT` recognize components that were not created by it, for example it `won't` list an existing POD created via kubectl.

## Simple case - POD

I created a busybox pod configuration file and deployed with kapp:

```bash
 $ kapp deploy -a myapp -f busybox-pod.yaml
Target cluster 'https://kubernetes.docker.internal:6443' (nodes: docker-desktop)

Changes

Namespace  Name  Kind  Conds.  Age  Op      Op st.  Wait to    Rs  Ri
default    bb    Pod   -       -    create  -       reconcile  -   -

Op:      1 create, 0 delete, 0 update, 0 noop
Wait to: 1 reconcile, 0 delete, 0 noop

Continue? [yN]: y

3:00:09PM: ---- applying 1 changes [0/1 done] ----
3:00:10PM: create pod/bb (v1) namespace: default
3:00:10PM: ---- waiting on 1 changes [0/1 done] ----
3:00:10PM: ongoing: reconcile pod/bb (v1) namespace: default
3:00:10PM:  ^ Pending: ContainerCreating
3:00:13PM: ok: reconcile pod/bb (v1) namespace: default
3:00:13PM: ---- applying complete [1/1 done] ----
3:00:13PM: ---- waiting complete [1/1 done] ----

Succeeded
```

Now the myapp is listed as a kapp application:

```bash
$ kapp list
Target cluster 'https://kubernetes.docker.internal:6443' (nodes: docker-desktop)

Apps in namespace 'default'

Name   Namespaces  Lcs   Lca
myapp  default     true  23s

Lcs: Last Change Successful
Lca: Last Change Age

1 apps

Succeeded
```

Deploying a new component using the same app name will delete the current pod and create the new component, the mysql deployment for instance:

```bash
$ kapp deploy -a myapp -f mysql.yaml
Target cluster 'https://kubernetes.docker.internal:6443' (nodes: docker-desktop)

# ===>>> Notice that kapp warns and ask for confirmation before continuing
Changes

Namespace  Name   Kind        Conds.  Age  Op      Op st.  Wait to    Rs  Ri
default    bb     Pod         4/4 t   3m   delete  -       delete     ok  -
^          mysql  Deployment  -       -    create  -       reconcile  -   -

Op:      1 create, 1 delete, 0 update, 0 noop
Wait to: 1 reconcile, 1 delete, 0 noop

Continue? [yN]: y

3:03:20PM: ---- applying 2 changes [0/2 done] ----
3:03:20PM: delete pod/bb (v1) namespace: default
3:03:21PM: create deployment/mysql (apps/v1) namespace: default
3:03:21PM: ---- waiting on 2 changes [0/2 done] ----
3:03:21PM: ongoing: delete pod/bb (v1) namespace: default
3:03:21PM: ongoing: reconcile deployment/mysql (apps/v1) namespace: default
3:03:21PM:  ^ Waiting for generation 2 to be observed
3:03:21PM:  L ok: waiting on replicaset/mysql-594696fdbb (apps/v1) namespace: default
3:03:21PM:  L ongoing: waiting on pod/mysql-594696fdbb-cb6n4 (v1) namespace: default
3:03:21PM:     ^ Pending: ContainerCreating
3:03:22PM: ongoing: reconcile deployment/mysql (apps/v1) namespace: default
3:03:22PM:  ^ Waiting for 1 unavailable replicas
3:03:22PM:  L ok: waiting on replicaset/mysql-594696fdbb (apps/v1) namespace: default
3:03:22PM:  L ongoing: waiting on pod/mysql-594696fdbb-cb6n4 (v1) namespace: default
3:03:22PM:     ^ Pending: ContainerCreating
3:03:23PM: ongoing: reconcile deployment/mysql (apps/v1) namespace: default
3:03:23PM:  ^ Waiting for 1 unavailable replicas
3:03:23PM:  L ok: waiting on replicaset/mysql-594696fdbb (apps/v1) namespace: default
3:03:23PM:  L ongoing: waiting on pod/mysql-594696fdbb-cb6n4 (v1) namespace: default
3:03:23PM:     ^ Condition Ready is not True (False)
3:03:41PM: ok: reconcile deployment/mysql (apps/v1) namespace: default
3:03:41PM: ---- waiting on 1 changes [1/2 done] ----
3:03:59PM: ok: delete pod/bb (v1) namespace: default
3:03:59PM: ---- applying complete [2/2 done] ----
3:03:59PM: ---- waiting complete [2/2 done] ----

Succeeded

# Listing again 

$ kapp list
Target cluster 'https://kubernetes.docker.internal:6443' (nodes: docker-desktop)

Apps in namespace 'default'

Name   Namespaces  Lcs   Lca
myapp  default     true  1m

Lcs: Last Change Successful
Lca: Last Change Age

1 apps

Succeeded

$ k get pods
NAME                         READY   STATUS             RESTARTS   AGE
pod/mysql-594696fdbb-cb6n4   0/1     CrashLoopBackOff   1          30s
```

You need to pass all files in order to update the application without removing previous components, but it was very frustrating since it showed an error but still applied half of the update, and next time failed on the POD:

```bash
$ kapp deploy -a myapp -f mysql.yaml -f busybox-pod.yaml
Target cluster 'https://kubernetes.docker.internal:6443' (nodes: docker-desktop)

Changes

Namespace  Name   Kind        Conds.  Age  Op      Op st.  Wait to    Rs       Ri
default    bb     Pod         -       -    create  -       reconcile  -        -
^          mysql  Deployment  -       20m  update  -       reconcile  ongoing  Waiting for 1 unavailable replicas

Op:      1 create, 0 delete, 1 update, 0 noop
Wait to: 2 reconcile, 0 delete, 0 noop

Continue? [yN]: y

3:24:02PM: ---- applying 2 changes [0/2 done] ----
3:24:02PM: update deployment/mysql (apps/v1) namespace: default

kapp: Error: Applying update deployment/mysql (apps/v1) namespace: default:
  Updating resource deployment/mysql (apps/v1) namespace: default:
    Deployment.apps "mysql" is invalid: spec.template.spec.containers[0].env[0].name:
      Required value (reason: Invalid)

$ k get pods
NAME                         READY   STATUS             RESTARTS   AGE
bb                           1/1     Running            0          103s
pod/mysql-594696fdbb-cb6n4   0/1     CrashLoopBackOff   8          17m
````

And next try failed on busybox, even though I used the very same configuration file:

```bash
$ kapp deploy -a myapp -f mysql.yaml -f busybox-pod.yaml -y
Target cluster 'https://kubernetes.docker.internal:6443' (nodes: docker-desktop)

Changes

Namespace  Name   Kind        Conds.  Age  Op      Op st.  Wait to    Rs       Ri
default    bb     Pod         -       41s  update  -       reconcile  ok       -
^          mysql  Deployment  -       21m  update  -       reconcile  ongoing  Waiting for 1 unavailable replicas

Op:      0 create, 0 delete, 2 update, 0 noop
Wait to: 2 reconcile, 0 delete, 0 noop

3:24:43PM: ---- applying 2 changes [0/2 done] ----
3:24:43PM: update pod/bb (v1) namespace: default

kapp: Error: Applying update pod/bb (v1) namespace: default:
  Updating resource pod/bb (v1) namespace: default:
    Pod "bb" is invalid: spec:
      Forbidden: pod updates may not change fields other than `spec.containers[*].image`, `spec.initContainers[*].image`, `spec.activeDeadlineSeconds` or `spec.tolerations` (only additions to existing tolerations)
  core.PodSpec{
- 	Volumes: nil,
+ 	Volumes: []core.Volume{
+ 		{
+ 			Name: "default-token-wvflh",
+ 			VolumeSource: core.VolumeSource{
+ 				Secret: &core.SecretVolumeSource{SecretName: "default-token-wvflh", DefaultMode: &420},
+ 			},
+ 		},
+ 	},
  	InitContainers: nil,
  	Containers: []core.Container{
  		{
  			... // 7 identical fields
  			Env:          nil,
  			Resources:    core.ResourceRequirements{},
- 			VolumeMounts: nil,
+ 			VolumeMounts: []core.VolumeMount{
+ 				{
+ 					Name:      "default-token-wvflh",
+ 					ReadOnly:  true,
+ 					MountPath: "/var/run/secrets/kubernetes.io/serviceaccount",
+ 				},
+ 			},
  			VolumeDevices: nil,
  			LivenessProbe: nil,
  			... // 10 identical fields
  		},
  	},
  	EphemeralContainers: nil,
  	RestartPolicy:       "Always",
  	... // 2 identical fields
  	DNSPolicy:                    "ClusterFirst",
  	NodeSelector:                 nil,
- 	ServiceAccountName:           "",
+ 	ServiceAccountName:           "default",
  	AutomountServiceAccountToken: nil,
  	NodeName:                     "docker-desktop",
  	... // 18 identical fields
  }
 (reason: Invalid)
```

Again the update on mysql was applied eventhough the error occurred:

```bash
$ k get pods
NAME                     READY   STATUS    RESTARTS   AGE
bb                       1/1     Running   0          103s
mysql-67dfcd6684-nz25m   1/1     Running   0          62s
```

## Only one app per namespace

When trying to deploy a new application to default namespace I discovered... 

```bash
$ kapp deploy -a bb -f busybox-pod.yaml
Target cluster 'https://kubernetes.docker.internal:6443' (nodes: docker-desktop)

kapp: Error: Ownership errors:
- Resource 'pod/bb (v1) namespace: default' is already associated with a different app 'myapp' namespace: default (label 'kapp.k14s.io/app=1615582804883564000')
```

## It does not create a namespace automatically

Even if kapp advertises creating dependencies prior than componentes, just by setting `-n` flag does not make it create the new namespace. Also there is NOT a `--create-namespace` flag, as found in helm.

```bash
$ kapp deploy -a bb -f busybox-pod.yaml -n bb
Target cluster 'https://kubernetes.docker.internal:6443' (nodes: docker-desktop)

kapp: Error: Creating app: namespaces "bb" not found
```

A namespace yaml file didn't work either...

```bash
$ kapp deploy -a bb -f busybox-pod.yaml -f bb-ns.yaml -n bb
Target cluster 'https://kubernetes.docker.internal:6443' (nodes: docker-desktop)

kapp: Error: Creating app: namespaces "bb" not found
```

## kapp metadata namespace / application namespace

The kapp keeps the tracking of change in configmaps in the metadata namespace, that is the namespace specified in `-n` flag. 

If nothing else is specified, the deploy will occur in the same namespace than metadata, and only one app is allowed by namespace. 

In order to deploy the application in a different namespace than the metadata, you need to use the `--into-ns` flag OR specify the namespace attribute in the component yaml file.

When using the yaml file, you can also include the namespace creation yaml in the very top. If using the `--into-ns` flag, you will need to create the namespace prior than the deployment.
