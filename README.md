# analytics

## QUESTION 1

```
Multi-language Runtime Image (Python 2, Python 3, R)
Objective
Create a Docker image supporting:
- Python 2 (legacy support)
- Python 3 (default runtime)
- R (data science/statistical computing)
```

#### Base Image Choice:
The base image selected is `ubuntu:22.04`, chosen for stability, ecosystem support, and availability of official packages. Unlike **Alpine** or **Scratch**, Ubuntu provides the necessary flexibility to install and maintain multiple runtimes without extensive manual work.

####  Key justifications:

- Full glibc support, which avoids compatibility issues with native Python/R extensions.
- Official APT support for Python 2, Python 3.11, and R via maintained Ubuntu repositories.
- Reliable setup of build essentials and common dependencies (e.g., build-essential, curl, gnupg, software-properties-common).
- Smooth integration of legacy components (especially Python 2) without needing to build from source.

While alternatives like python:3.11-slim or alpine offer smaller image sizes, they introduce challenges:

- Alpine’s musl libc can break compatibility with certain Python and R binaries.
- Alpine lacks official Python 2 and R support.
- Scratch provides no package manager or base libraries, making it impractical for this multi-runtime use case.

If Python 2 support were not required, a minimal base like python:3.11-slim or python:3.11-alpine would have been preferred.

#### Build Context and Usage:

```
time docker build -t noussydjimi/analytics:latest .
docker push noussydjimi/analytics:latest
```

The container runs a `metrics_server.py` script on startup, exposing metrics at `/metrics` (port 8000). Dependencies are managed via requirements.txt.





## QUESTION 2

````
For the previously created image
a. Share build times
b. How would you improve build times?
````

#### Docker build time:

`time docker build -t noussydjimi/analytics:latest .`

The image was built locally on macOS (Darwin 24.5.0) using Docker. Total build time was around 5 minutes (real: 5m7s), which is expected given the number of system packages installed (Python 2, Python 3, R, dev libraries). Some extra time also comes from setting up pip and installing dependencies from requirements.txt.

#### How I would improve build times:
- Use multi-stage builds to isolate build tools
- Use cachable commands
- Use fixed version (Docker image and requirement file)
- Posibility of using Docker lighter image.
- Use caching for image
- Use `.Dockerignore` to avoid copying useless file



## QUESTION 3

````
Scan the recently created container and evaluate the CVEs that it might contain.
a. Create a report of your findings and follow best practices to remediate the CVE
b. What would you do to avoid deploying malicious packages?
````

I scanned the image using Trivy and generated a full vulnerability report via `trivy image --format table --output trivy_report.txt noussydjimi/analytics:latest`. The output was extremely large, over 5000 lines so instead of listing everything, I picked a few high-severity CVEs that stood out and provided remediations for those specifically:

`CVE-2022-29217 – PyJWT (v2.3.0)`
A key confusion issue allowing forged JWT tokens.
-> Fixed by updating to PyJWT>=2.4.0.

`CVE-2021-3572 – pip (v20.3.4)`
Malformed unicode in Git requirements could cause redirection issues.
-> Fixed by upgrading pip3 during build with `pip3 install --upgrade pip`.

This vulnerability affects pip v20.3.4, which is the latest available version for Python 2. Unfortunately, Python 2 and its tooling (including pip2) are deprecated and no longer maintained. No patched version of pip2 exists for this CVE.


After patching these, I rebuilt the image and re-scanned to make sure the updated versions were in place and the CVEs were resolved.
The full report was too large (~5000 lines) to include entirely, but is available in `trivy_report.txt` if needed.

### General Recommendations to Prevent Malicious or Vulnerable Packages

- Avoid using latest tags in Docker images, instead, use fixed and verified version tags.
- Regularly scan images using tools like Trivy in the CI/CD pipeline.
- Keep the Python dependencies updated using `pip list --outdated`, and maintain a locked requirements.txt.
- Use minimal and secure base images, such as distroless, alpine, or officially maintained images and avoid unnecessary system packages.
- Sign and verify the Docker images using tools like cosign or sigstore.
- Avoid abandoned or unmaintained dependencies, check the GitHub repository activity and last release date.
- Use trusted sources only (PyPI or internal artifact registries)
- Avoid installing packages as root unless strictly necessary



## QUESTION 4

```
Use the created image to create a kubernetes deployment with a command that will
keep the pod running
```

Although the exercise asked to “keep the pod running,” I didn’t use a custom command or args in the Kubernetes manifest for that purpose.

Instead, I implemented a basic Python metrics server (related to Question 7) which runs indefinitely as part of the container’s default behavior. That script uses prometheus_client to expose `/metrics` and includes a `while True:` loop to keep the process alive as long as the pod is up.

So, instead of this being handled explicitly at the YAML level, it’s taken care of from inside the Python application.

If I hadn’t done that in the Python code, I could’ve used something like the following snippet in the Deployment to keep the pod alive:

```
command: ["tail"]
args: ["-f", "/dev/null"]
```

## QUESTION 5

At this stage, I haven’t set up an EKS cluster yet, so I exposed the application using a local Kubernetes Service of type ClusterIP within my local setup (Docker Desktop). The metrics endpoint is reachable internally within the cluster.

For the interview session or any future demo, I can provision a temporary EKS cluster and expose the service more broadly using a LoadBalancer or Ingress, depending on the need.




## QUESTION 6

```
Every step mentioned above have to be in a code repository with automated CI/CD
```

In a production setting, I would typically rely on a GitOps approach using **Argo CD** or **Flux CD** to declaratively manage Kubernetes resources and automate Helm releases based on Git state. However, for the purpose of this exercise, I'm following the requirement to use a CI/CD pipeline directly from GitHub Actions to deploy to EKS via Helm. The deployment workflow assumes the presence of a configured EKS cluster and appropriate AWS credentials


## QUESTION 7

```
How would you monitor the above deployment? Explain or implement the tools that you
would use
```

To monitor the deployment, I integrated Prometheus directly into the application layer by exposing custom metrics via the `prometheus_client` library.

I wrote a small Python metrics server (metrics_server.py) that exposes a /metrics endpoint on port 8000.

Here’s what I did to make the deployment Prometheus-compatible:

In the Deployment manifest, I annotated the Pod spec with:

```
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8000"
  prometheus.io/path: "/metrics"
```

I exposed port 8000 in the container spec and verified the endpoint is reachable internally.

![alt text](<Screenshot 2025-07-16 at 19.13.31.png>)




# Project


## QUESTION 1
```
Using kubernetes you need to provide all your employees with a way of launching multiple
development environments (different base images, requirements, credentials, others). The
following are the basic needs for it:
1. UI, CI/CD, workflow or other tool that will allow people to select options for:
a. Base image
b. Packages
c. Mem/CPU/GPU requests
```



Developers request new environments using a custom CLI that triggers a GitHub Workflow. The workflow:
1. Validates the request
2. Renders Kubernetes manifests via Helm
3. Pushes them to a GitOps repository
4. FluxCD or ArgoCD then deploys them to the target cluster


### Developer CLI

The `cli-dev-env` command is a mock CLI that wraps the GitHub Workflow Dispatch API.

### Example usage:

```bash
cli-dev-env create \
  --name analytics-data-env \
  --base-image python:3.11 \
  --packages path_to_requirements.txt \
  --cpu 2 \
  --memory 4Gi \
  --gpu false
```

This triggers a GitHub Workflow which:
- Build docker base image Dockerfile with indicated `requirements.txt` file
- Generates a Helm values.yaml file based on the CLI inputs
- Runs helm template to generate manifests
- Pushes the rendered YAML to the gitops-environments repository




## QUESTION 2

```
Monitor each environment and make sure that:
a. Resources request is accurate (requested vs used)

b. Notify when resources are idle or underutilized
c. Downscale when needed (you can assume any rule defined by you to allow this
to happen)
d. Save data to track people requests/usage and evaluate performance
```

Each developer environment is monitored using Prometheus, and resource usage is analyzed to ensure efficient allocation.
Every environment is deployed with both `resources.requests` and `resources.limits`. Prometheus collects metrics on actual usage:

- `container_cpu_usage_seconds_total`
- `container_memory_usage_bytes`

Prometheus rules are used to detect idle containers. An environment is considered idle if:

- CPU usage < 5% for 30+ minutes
- Memory usage < 20% of allocated value

Alertmanager sends notifications to Slack when idle conditions are met.
A downscaling policy is applied through KEDA for idle environments.



## QUESTION 3

The platform leverages [Karpenter](https://karpenter.sh/) for dynamic autoscaling and fine-grained workload placement. Karpenter automatically launches and terminates nodes based on actual pod requirements, without needing to predefine fixed node pools.

Workloads are scheduled based on labels/tags like team, environment type, or hardware needs (GPU, ARM/AMD etc ...).

- `nodeSelector` or `affinity` to target appropriate instances in dedicated nodepool
- `tolerations` to allow placement on tainted nodes (e.g., GPU nodes)

eg:

```
nodeSelector:
  karpenter.sh/provisioner-name: gpu

tolerations:
  - key: "gpu"
    operator: "Exists"
    effect: "NoSchedule"
```

## QUESTION 4

Each developer environment supports direct access through **SSH** and **SFTP**, enabling developers to interact with their container in a familiar and secure way. To simplify access, every environment is automatically assigned a unique DNS name.


A lightweight **SSH/SFTP server sidecar** is injected into each pod, using images like:

- `linuxserver/openssh-server`
- `atmoz/sftp`

The sidecar shares a volume with the main container, allowing file transfer and command execution.
Authentication is done via public SSH key (mounted from a Secret).

```bash
# SSH into the container
ssh gilles@dev-gilles.swish.dev

# Transfer files using SFTP
sftp gilles@dev-gilles.swish.dev
```

### DNS Automation
**ExternalDNS** is used to automatically create DNS records for each environment based on Kubernetes annotations. It is integrated with **AWS route53** providers.

```
apiVersion: v1
kind: Service
metadata:
  name: dev-env-gilles
  annotations:
    external-dns.alpha.kubernetes.io/hostname: dev-gilles.swish.dev
    external-dns.alpha.kubernetes.io/ttl: "120"
spec:
  selector:
    app: dev-env
  ports:
    - name: ssh
      port: 22
      targetPort: 22
```

ExternalDNS monitors these annotations and creates the corresponding A/AAAA/CNAME records dynamically.


If the SSH/SFTP access is proxied through an Ingress, cert-manager is used to issue TLS certificates for secure communication

```
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"

```


#### Pod structure example

```
spec:
  containers:
    - name: main-app
      image: ghcr.io/swishanalytics/python-env:latest
      volumeMounts:
        - name: shared-data
          mountPath: /workspace
    - name: ssh-server
      image: linuxserver/openssh-server
      env:
        - name: PUBLIC_KEY
          valueFrom:
            secretKeyRef:
              name: ssh-keys
              key: id_rsa.pub
      volumeMounts:
        - name: shared-data
          mountPath: /data
  volumes:
    - name: shared-data
      emptyDir: {}

```


## QUESTION 5



# Troubleshooting
