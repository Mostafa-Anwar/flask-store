module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.2.0"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  subnets         = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  vpc_id          = module.vpc.vpc_id

  cluster_endpoint_public_access   = true
  cluster_endpoint_private_access  = true
  cluster_endpoint_public_access_cidrs      = ["0.0.0.0/0"]

  fargate_profiles = {
    coredns = {
      name = "coredns"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        }
      ]
       subnets  = module.vpc.private_subnets
      tags = {
        Owner = "coredns"
      }
    }

    default = {
      name = "default"
      selectors = [
        {
          namespace = "default"
          labels = {
          }
        }
      ]
       subnets  = module.vpc.private_subnets
      tags = {
        Owner = "default"
      }
    }

    ALBController = {
      name = "ALB-controller"
      selectors = [
        {
          namespace = "ingress-controller"
          labels = {
            # "eks.amazonaws.com/compute-type" = "fargate",
            "app.kubernetes.io/name" = "aws-load-balancer-controller"
          }
        }
      ]
       subnets  = module.vpc.private_subnets
      tags = {
        Owner = "IngressALBController"
      }
    }
  }

  providers = {
    kubernetes = kubernetes
  }
}
