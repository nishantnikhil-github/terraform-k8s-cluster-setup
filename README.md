# Steps to configure EKS cluster

# clone this repository
git clone https://github.com/nishantnikhil-github/terraform-k8s-cluster-setup.git

# initialise terraform
terraform init

# Plan terraform
terraform plan

# check the plan if everything is ok and as per expectation then apply
terraform apply --auto-approve

# Once the cluster and nodes are created then we have to configure kubectl to communicate with the cluster and nodes.

# First create a directory .kube in your home directory
mkdir ~/.kube

# As you have set kubeconfig as output in your ouputs.tf run the below command to setup configuration to communicate with the cluster.
terraform output kubeconfig > ~/.kube/config

# once that is done you can check whether configuration has been done or not and you are able to communicate with your cluster or not with the below command which will show your cluster version and kubectl version
kubectl version

# Now you have to configure kubectl to talk to your nodes with the below commands.
terraform output config_map_aws_auth > config_map_aws_auth.yml

kubectl apply -f config_map_aws_auth.yml

# Once it is success you will be able to communicate with your nodes. To check that we can run below command:
kubectl get nodes -o wide

# Once you are able to see the nodes and nodes are ready you can deploy your application.

# To deploy your application create the deployment file in yml format like k8s-deployment-nishant.yml
# After creation of the file run the below command. In the below command i have used my file name but you can use your filename.
kubectl apply -f k8s-deployment-nishant.yml

# Then check whether deployments was successfull or not.
# Run the below commands to check your deployment
kubectl get deployments

# Once you can see your deployment you can run below command to see your pods and their status
kubectl get pods

# Once the pods are running you can expose your application as a service.
# To do that create a service file in yml format like k8s-service-nishant.yml.
# You can use your file name. Then run the below command:
kubectl apply -f k8s-service-nishant.yml

# Once thats done you can check the status of your service with the below command:
kubectl get services

# once yur service is running you now access your application from the browser by grabbing the loadbalancer dns name.

