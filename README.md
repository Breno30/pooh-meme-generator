# Pooh Meme Generator

A simple tool to generate custom Winnie the Pooh memes with your own text.

##  Features
- Custom Text Input: Easily add generated captions to the meme.

- Instant Meme Generation: Create your meme with just a few clicks.

- Download & Share: Save your masterpiece or share it directly with others.

## Getting Started

1. **Clone the repository:**
    ```bash
    git clone https://github.com/Breno30/pooh-meme-generator.git
    cd pooh-meme-generator
    ```

## 🚀 Deployment (Terraform)

This project uses Terraform to manage and deploy its AWS infrastructure, including the Lambda function.

### Prerequisites

  * **Terraform CLI:** Ensure you have Terraform installed on your system. You can download it from the [official Terraform website](https://developer.hashicorp.com/terraform/downloads).
  * **AWS Account & Credentials:** You need an AWS account configured with appropriate credentials (e.g., via AWS CLI `aws configure` or environment variables) that have permissions to create Lambda functions, S3 buckets, and other necessary resources.

### Deployment Steps

1.  **Set Environment Variables:** Before running Terraform, configure your desired settings by exporting the environment variables.

    ```bash
    export TF_VAR_aws_region="us-east-1"
    export TF_VAR_project_name="pooh-meme" # Example project name
    export TF_VAR_lambda_memory_size=512
    export TF_VAR_lambda_timeout=10
    ```

2.  **Initialize Terraform:** Navigate to the project root directory where your Terraform configuration files (`.tf`) are located and initialize the backend and providers.

    ```bash
    cd deploy/terraform/ 
    terraform init
    ```

3.  **Review the Plan (Optional but Recommended):** See what changes Terraform will make to your AWS infrastructure before applying them.

    ```bash
    terraform plan
    ```

4.  **Apply the Changes:** Execute the plan to deploy your resources to AWS. Terraform will prompt you for confirmation.

    ```bash
    terraform apply
    ```

    Type `yes` when prompted to confirm the deployment.

-----

## 🤝 Contributing

We welcome contributions to make the Pooh Meme Generator even better\!

  * **Pull Requests:** Feel free to submit pull requests with your improvements.
  * **Major Changes:** For significant changes, please open an issue first to discuss your ideas.