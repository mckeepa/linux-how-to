# Create a netnet Web App in a Docker image, then run on Kubernetes Cluster

From here: https://dotnet.microsoft.com/en-us/learn/aspnet/microservice-tutorial/create


## Create the Wb Application
```bash
dotnet new webapi -o MyMicroservice --no-https  
cd MyMicroservice/
dotnet run
```

## Verify application is ruuning
open a browser for http://localhost:5103/weatherforecast   

OR
``
curl http://localhost:5103/weatherforecast   
```

## Docker
verify docker is installed
```bash
docker --version
```
if not instaled follow these instruction: https://developer.fedoraproject.org/tools/docker/docker-installation.html

```bash
sudo dnf install dnf-plugins-core

# add the docker-ce repository
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# The Docker daemon relies on a OCI compliant runtime (invoked via the containerd daemon) as its interface to the Linux kernel namespaces, cgroups, and SELinux.
sudo dnf install docker-ce docker-ce-cli containerd.io

# Start the Docker service
sudo systemctl start docker
docker --version

# verify that Docker was correctly installed and is running by running the Docker hello-world image.
sudo docker run hello-world

# Start the Docker daemon at boot use the command:
sudo systemctl enable docker

# so that sudo is not needed
docker run hello-world

sudo usermod -a -G docker $USER
reboot

# or if it fails, use a hammer (not recommended)
chmod 777 /var/run/docker.sock

```

# Add Docker metadata to dotnet App.

```bash
touch Dockerfile 
touch .dockerignore 
```

Dockerfile 
```yaml
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY MyMicroservice.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "MyMicroservice.dll"]
```

.dockerignore 
```ini
Dockerfile
[b|B]in
[O|o]bj
```

## Create Docker Image

The docker build command uses the Dockerfile to build a Docker image.

 - -t mymicroservice parameter tells it to tag (or name) the image as mymicroservice.
 - final parameter speciifies the directory to use for the Dockerfile (. specifies the current directory).
 - This command will download and build all dependencies to create a Docker image and may take some time.

```
docker build -t mymicroservice .
```

output (inprogress)
```
docker build -t mymicroservice .                                       in bash at 18:26:35
Sending build context to Docker daemon   4.47MB
Step 1/10 : FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
6.0: Pulling from dotnet/sdk
3f4ca61aafcd: Downloading [===============================>                   ]  19.99MB/31.4MB
228cf000ffe1: Download complete 
ce59a9e17a45: Downloading [=============================>                     ]  18.35MB/31.63MB
097d019d4906: Download complete 
4d253fbe5bbb: Downloading [=======================================>           ]  7.567MB/9.464MB
42c61635451d: Pulling fs layer 
f4c57886d6aa: Waiting 
baeaf02ec8f8: Waiting 
```

Verify Docker image
```bash
docker images
```

```
REPOSITORY                        TAG       IMAGE ID       CREATED          SIZE
mymicroservice                    latest    eb53ccaf26cf   39 seconds ago   213MB
<none>                            <none>    e0a7455c40fb   43 seconds ago   787MB
mcr.microsoft.com/dotnet/sdk      6.0       53112f060c74   10 days ago      738MB
mcr.microsoft.com/dotnet/aspnet   6.0       a3a54ba9f84c   10 days ago      208MB
hello-world                       latest    feb5d9fea6a5   15 months ago    13.3kB
```

## Run Docker image

Run the app in a container using the following command:

```bash
docker run -it --rm -p 3000:80 --name mymicroservicecontainer mymicroservice
# view in docker
docker ps

curl http://localhost:3000/WeatherForecast
```

Browse to the URL to access your application running in a container: http://localhost:3000/WeatherForecast

Press CTRL+C on your cli prompt to end the docker run command.

# Deploy to Kubenetes


new namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: testing
  labels:
    name: testing
```

Pod yaml
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mymicroservice
  namespace: testing
spec:
  containers:
    - name: mymicroservice
      image: mymicroservice:latest 
```

Create namespace and deploy pad
```bash
kubectl apply -f kube-app-namespace.yaml 
kubectl apply -f kube-app-pod.yaml

kubectl get namespace
kubectl get pod -n=testing

```

# Use Local Docker Image Registry

```bash
docker save mymicroservice > mymicroservice.tar


docker login kube-harbor-00.k8

#docker tag mymicroservice:latest kube-harbor-00.k8/test-dotnet/mymicroservice:latest
docker push kube-harbor-00.k8/test-dotnet/mymicroservice:latest

The push refers to repository [kube-harbor-00.k8/test-dotnet/mymicroservice]
c6f680dbb73f: Pushed 
296bc51af3a1: Pushed 
b400c1fbdfd3: Pushed 
92b218f57c01: Pushed 
f1307d47d63a: Pushed 
5047e9061598: Pushed 
8a70d251b653: Pushed 
latest: digest: sha256:27df76c49cff224751905203b80e13ace634a51ecd8396270474893334aba6a9 size: 1788

# Pull an Image from a Private Registry

https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/


Use the docker tool to log in to Docker Hub. See the log in section of Docker ID accounts for more information.

```bash
docker login
```
View the config.json file:
```bash
cat ~/.docker/config.json
```
The output contains a section similar to this:
```json
{
        "auths": {
                "kube-harbor-00.k8": {
                        "auth": "c2NvdHQ6TXlTZWNyZWN0UGFzc3dvcmQjMjAyMwo="
                }
        }
}
```


```bash
# Note 1: the auth: "c2N...zwo=" includes the username and password
# Note 2: This is not a real user id or password! 
echo "c2NvdHQ6TXlTZWNyZWN0UGFzc3dvcmQjMjAyMwo=" | base64 --decode
scott:MySecrectPassword#2023
```
Create the kubernetes Secret
```bash

kubectl create secret generic regcred \
    --from-file=.dockerconfigjson=~/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```

or

base64 the ~/.docker/config.json
```bash
base64 ~/.docker/config.json
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myregistrykey
  namespace: testing
data:
  .dockerconfigjson: ewoJImF1dGhzIjogewoJCSJrdWJlLWhhcmJvci0wM......iOiAiY0dGMWJEcFFjbTkwWldOMFpXUWpNREU9IgoJCX0KCX0KfQ==
type: kubernetes.io/dockerconfigjson
```

or

```bash
# Create this Secret, naming it regcred:

kubectl create secret docker-registry regcred --docker-server=kube-harbor-00.k8 --docker-username=paul --docker-password=<your-pword> --docker-email=paul.mckee@test.com.au
```

## Verify Secret
```bash
kubectl get secret myregistrykey -n=testing --output=yaml  
kubectl get secret myregistrykey -n=testing --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode 

```