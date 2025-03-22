# README

## Description
This repo has the following:
- IAC (terraform)
- Simple flask app + Dockerfile
- K8s manifests
- CICD (GH actions)

## Usage
It can be used as blueprint is to create an EKS cluster and deploy a simple python app.


1. Provision infrastructure
2. Build and push the Docker image to ECR.
3. Apply Kubernetes manifests (Deployment, Service, Ingress, etc.) to the EKS cluster.

There a few manual steps that can be automated later.

## Terraform

### Files Explanation

TF modules are used for simplicity.

- **backend.tf**  
  Configures the Terraform backend to store the state file in S3 and use DynamoDB for state locking.

- **data.tf**  
  Defines data sources for resources like `aws_eks_cluster` or `aws_eks_cluster_auth` used to retrieve existing information about the EKS cluster.

- **ecr.tf**  
  Creates and manages the AWS ECR repository where Docker images can be stored.

- **eks.tf**  
  Provisions the EKS cluster (using Fargate), including Fargate profiles, and sets up cluster configuration.

- **networking.tf**  
  Creates VPC, subnets (public and private), internet gateway, NAT gateways, and route tables needed for the cluster and other AWS resources.

- **outputs.tf**  
  Exports values like the EKS cluster endpoint or repository URLs that you can use in other parts of the infrastructure or CI/CD pipeline.

- **variables.tf**  
  Declares input variables such as region, cluster name, VPC CIDR, subnets, and any other configurable settings.

- **env/**  
  Contains environment-specific files (like `dev.tfvars`) where you store variable values for development or other environments.

### Provisioning 

Follow these steps to deploy the infrastructure:

1. **Initialize Terraform** with the backend config:
    ```bash
    terraform init --backend-config=backend.tf
    ```

2. **Preview the changes**:
    ```bash
    terraform plan -var-file="env/dev.tfvars"
    ```

3. **Apply the changes**:
    ```bash
    terraform apply -var-file="env/dev.tfvars"
    ```


## Docker

## Building and Pushing the Image to ECR

1. **Build the Docker image** (flask-service/` directory):
    ```bash
    docker build -t <local-image-name>:latest -f flask-service/Dockerfile .
    ```

2. **Tag the image** to match the ECR repository:
    ```bash
    docker tag <local-image-name>:latest <ECR_REGISTRY>/<ECR_REPOSITORY>:latest
    ```

3. **Authenticate to ECR**:
    ```bash
    aws ecr get-login-password --region <AWS_REGION> | docker login --username AWS --password-stdin <ECR_REGISTRY>
    ```

4. **Push the image** to ECR:
    ```bash
    docker push <ECR_REGISTRY>/<ECR_REPOSITORY>:latest
    ```

Replace `<local-image-name>`, `<ECR_REGISTRY>`, `<ECR_REPOSITORY>`, and `<AWS_REGION>` with the actual values. Once pushed, the image will be stored in the ECR repository for deployment.



## Kubernetes 

### Prerequisites Before Applying Manifests

1. **Create an OIDC IAM Role with the Relevant Policy**  
   - **OIDC Provider:** Ensure the EKS cluster has an OIDC provider configured.  
   - **Trust Policy:** Update the role’s trust policy so that it can be assumed by the Kubernetes service account (e.g., `eks.amazonaws.com/role-arn` annotation).  
   - **Permissions Policy:** Attach the relevant policy that allows managing AWS load balancers (the AWS Load Balancer Controller policy).

2. **Create ingress-controller namespace**  
    `kubectl create ns ingress-controller`

3. **Create a Service Account with the OIDC Role**  
   Make sure to modify <EKS_ALB_ROLE_ARN> with the role value before creation  
   `kubectl create -f ingress-service-account.yaml`

4. **Install aws-load-balancer-controller to be used as ingress-controller**
    ```bash 
        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n ingress-controller \
        --set vpcId=<vpc_ID> \
        --set clusterName=flask-store-dev-cluster \
        --set region=us-east-2 \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller
    ```

Replace `<vpc_ID>` with the actual value


### Creating The Manifests

Follow these instructions to create the k8s objects for deploying the application:

   - **Validation:** Test the manifests with:
     ```bash
     kubectl apply --dry-run=client -f <manifest-file.yaml>
     ```
   - **Deployment:** Once validated, apply the manifests:
     ```bash
     kubectl apply -f <manifest-directory>
     ```

1. **Deployment Manifest**

   - **Purpose:** Deploy the application container to the cluster.
   - **Key Variables to Replace:**
     - `<APP_NAME>`: The name of the application (e.g., `flask-app`)
     - `<NAMESPACE>`: The namespace in which to deploy (e.g., `default`)
     - `<ECR_REGISTRY>`: the ECR registry URL (e.g., `486991249128.dkr.ecr.us-east-2.amazonaws.com`)
     - `<ECR_REPOSITORY>`: the ECR repository name (e.g., `flask-app`)
     - `<CONTAINER_PORT>`: The port the application listens on (e.g., `5000`)
   - **Instructions:**
     - Create a Deployment manifest that uses an image reference like:
       ```
       image: <ECR_REGISTRY>/<ECR_REPOSITORY>:latest
       ```
     - Ensure the pod template includes labels (e.g., `app: <APP_NAME>`) so that the Service and Ingress can select the pods.
     - If you are using Fargate, add any necessary annotations (e.g., `eks.amazonaws.com/fargate-profile: "default"`) in the pod metadata.

2. **Service Manifest**

   - **Purpose:** Expose the Deployment internally so that it can be targeted by the Ingress.
   - **Key Variables to Replace:**
     - `<APP_NAME>`: Must match the label used in the Deployment.
     - `<SERVICE_PORT>`: The port exposed by the Service (e.g., `80`)
     - `<TARGET_PORT>`: The container port the application listens on (should be `<CONTAINER_PORT>`)
   - **Instructions:**
     - Create a Service manifest of type `ClusterIP` that selects pods with the label `app: <APP_NAME>`.
     - Configure the Service to forward traffic from `<SERVICE_PORT>` to `<TARGET_PORT>`.

3. **Ingress Manifest**

   - **Purpose:** Expose the application externally using an ALB.
   - **Key Variables to Replace:**
     - `<INGRESS_CLASS>`: The Ingress class name (e.g., `alb`)
     - `<HOST>` (optional): A specific domain name if required (or leave blank/wildcard)
     - `<HEALTHCHECK_PATH>`: The path for ALB health checks (e.g., `/users`)
     - `<HEALTHCHECK_PORT>`: The port for health checks (e.g., `<CONTAINER_PORT>`)
     - `<APP_NAME>`: Must match the Service name or labels.
   - **Instructions:**
     - Create an Ingress manifest with `spec.ingressClassName: <INGRESS_CLASS>`.
     - If using a host, define it under the rules; otherwise, the rule can be host-less (default).
     - Under `spec.rules`, ensure the path directs traffic to the Service corresponding to `<APP_NAME>` on `<SERVICE_PORT>`.


Replace all the placeholder variables (e.g., `<APP_NAME>`, `<ECR_REGISTRY>`, etc.) with the actual environment values.
