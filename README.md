
# Django Application CI/CD Pipeline with Jenkins

## Objective

Establish a Continuous Integration and Continuous Deployment (CI/CD) pipeline using Jenkins to automate the deployment of a Django application. The pipeline integrates the application with a Git repository, implements AWS services for enhanced functionality, and ensures seamless deployment to AWS infrastructure. The objectives include:

1. **Source Code Integration**: Automatically pull the latest changes from a specified Git repository, ensuring that the pipeline uses the most recent version of the application code.
2. **Static and Media File Management**: Configure AWS S3 as the storage solution for static and media files, facilitating efficient handling and delivery of these assets.
3. **Database Configuration**: Integrate AWS RDS as the relational database service for the Django application, including steps to configure the database connection and run necessary migrations.
4. **VPC and Network Configuration**: Create a Virtual Private Cloud (VPC) with two private subnets to host the Django application securely, enhancing security by isolating the application from direct internet access.
5. **Deployment Automation**: Utilize AWS CodeDeploy to automate the deployment process of the Django application to EC2 instances located in the private subnets, streamlining the deployment workflow and reducing downtime during updates.
6. **Auto-Scaling Implementation**: Implement AWS Auto Scaling to ensure the application can handle varying loads efficiently, adjusting the number of EC2 instances based on traffic demands.
7. **Security and Compliance**: Follow security best practices throughout the CI/CD pipeline, including configuring IAM roles and policies, encrypting sensitive data, and managing credentials with AWS Secrets Manager.
8. **Access Control and Traffic Management**: Configure the Application Load Balancer to manage incoming traffic and distribute it to the EC2 instances in the private subnets, enforcing security group rules to control access.

## Region
- **Region**: ap-south-1

---

## PART 01: Create Custom VPC

Creating a custom VPC to deploy the application in a private subnet without altering the default VPC.

**Changes to be done**: 
- **NAT gateways**: In 1 availability zone.
![Example Image](https://github.com/SyedAzherAli/django-app/blob/main/screenshorts/Screenshot%20from%202024-09-25%2012-34-36.png)

---

## PART 02: Create Two IAM Roles

### For EC2 Instance
- **AWS Service**: Use case EC2
- **Policies**:
  - AmazonEC2RoleforAWSCodeDeploy
  - AmazonS3FullAccess
  - AWSCodeDeployFullAccess

### For CodeDeploy
- **AWS Service**: Use case CodeDeploy
- **Policies**:
  - AWS CodeDeployRole
  - AmazonS3FullAccess
  - AmazonEC2FullAccess

### Create IAM User
- **Permissions**:
  - AmazonEC2FullAccess
  - AmazonS3FullAccess
  - AWSCodeDeployFullAccess
- Create access key under IAM > Users > Security Credentials.

---

## PART 03: Create Launch Instance

- Create a launch template for EC2 instances.
- **Name**: Django-app-LaunchTmp
- **AMI**: Ubuntu 24
- Use your key pair.
- Create a security group allowing:
  - SSH
  - HTTP
  - HTTPS
- Attach the created IAM role.

### Install Required Packages
```bash
#!/bin/bash
apt update -y 
apt install -y python3 python3-pip python3-venv libpq-dev nginx
```

### Install CodeDeploy Agent
Follow the instructions from the [AWS CodeDeploy documentation](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent-operations-install-ubuntu.html).

---

## PART 04: Install Jenkins

### Launch Instance
- **Name**: jenkins01
- **Install Java**:
```bash
sudo apt update
sudo apt install fontconfig openjdk-17-jre
```

### Install Jenkins
```bash
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins
```

### Setup Jenkins
Configure Jenkins with suggested plugins.

---

## PART 05: Setup S3

- Create a unique S3 bucket for media storage and AWS CodeDeploy artifacts.
- Allow public access and edit the bucket policy.

### Example Bucket Policy
```json
{
    "Version": "2012-10-17",
    "Id": "ExamplePolicy01",
    "Statement": [
        {
            "Sid": "ExampleStatement01",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::Account ID:root"
            },
            "Action": [
                "s3:GetObject",
                "s3:GetBucketLocation",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::django-bucket-demoversion01",
                "arn:aws:s3:::django-bucket-demoversion01/*"
            ]
        }
    ]
}
```

---

## PART 06: Setup RDS

Create an RDS service using PostgreSQL:
- **DB Instance Identifier**: database-1
- **Master Username**: Django_usr
- **Master Password**: Django_pwd
- **Public Access**: Yes

### Create Security Group
- **Name**: RDS_postgresql
- **Allow port**: 5432 from source 0.0.0.0/0.

---

## PART 07: Setup Jenkins

Log into Jenkins user and configure AWS CLI.
```bash
sudo su - jenkins 
aws configure 
```

### Install Jenkins Plugins
- **Pipeline**
- **Git Plugin**
- **AWS Steps Plugin**
- **AWS Credentials Plugin**

---

## PART 08: Configure Jenkins Credentials

### AWS Credentials
Add AWS access key and secret key in Jenkins credentials.

### RDS Credentials
Add database password and endpoint as Jenkins credentials.

---

## PART 09: Setup Jenkins Pipeline

### Create Pipeline
Go to Jenkins Dashboard and create a new pipeline with the following script:

```groovy
pipeline {
    agent any
    environment {
        GIT_REPO = 'https://github.com/SyedAzherAli/onlineshop.git'  
        DB_NAME = "Django_backend"
        DB_USER = "Django_usr"
        DB_PASSWORD = credentials('db-password')
        DB_HOST = credentials('db-host')  // RDS endpoint
        DB_PORT = "5432"
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        S3_BUCKET = "django-bucket-demoversion01"
        REGION_NAME = "ap-south-1"
        AWS_CREDENTIALS_ID = "aws-credentials"
        APPLICATION_NAME = "django-app"
        DEPLOYMENT_GROUP = "django-app-DG"
    }
    stages {
        stage('Remove old repo') {
            steps {
                sh '''  
                rm -rf *
                '''
            }
        }
        stage('Clone repository') {
            steps { 
                git branch: "main", url: "${GIT_REPO}"
            }
        }
        stage('Configure Django for RDS') {
            steps {
                sh '''
                sed -i "s/'NAME': '.*'/'NAME': '${DB_NAME}'/" backend/settings.py
                sed -i "s/'USER': '.*'/'USER': '${DB_USER}'/" backend/settings.py
                sed -i "s/'PASSWORD': '.*'/'PASSWORD': '${DB_PASSWORD}'/" backend/settings.py
                sed -i "s/'HOST': '.*'/'HOST': '${DB_HOST}'/" backend/settings.py
                sed -i "s/'PORT': '.*'/'PORT': '${DB_PORT}'/" backend/settings.py
                '''
            }
        }
        stage('Configure Django for S3') {
            steps {
                sh '''
                sed -i "s/AWS_ACCESS_KEY_ID = .*/AWS_ACCESS_KEY_ID = '${AWS_ACCESS_KEY_ID}'/" backend/settings.py
                sed -i "s/AWS_SECRET_ACCESS_KEY = .*/AWS_SECRET_ACCESS_KEY = '${AWS_SECRET_ACCESS_KEY}'/" backend/settings.py
                sed -i "s/AWS_STORAGE_BUCKET_NAME = .*/AWS_STORAGE_BUCKET_NAME = '${S3_BUCKET}'/" backend/settings.py
                sed -i "s/AWS_S3_REGION_NAME = .*/AWS_S3_REGION_NAME = '${REGION_NAME}'/" backend/settings.py
                '''
            }
        }
        stage('Package Application') {
            steps {
                sh '''
                rm -rf ../deploy
                rm -rf deploy
                mkdir ../deploy
                cp -R * ../deploy/  
                mv ../deploy ${PWD}
                zip -r deploy.zip deploy/
                '''
                archiveArtifacts artifacts: 'deploy.zip', fingerprint: true
            }
        }
        stage('Upload to S3') {
            steps {
                withAWS(credentials: "${AWS_CREDENTIALS_ID}", region: "${REGION_NAME}") {
                    s3Upload(bucket: "${S3_BUCKET}", file: 'deploy.zip', path: 'deploy.zip')
                }
            }
        }
       stage('Deploy to AWS CodeDeploy') {
            steps {
                sh '''
                aws deploy create-deployment \
                --application-name $APPLICATION_NAME \
                --deployment-group-name $DEPLOYMENT_GROUP \
                --s3-location bucket=$S3_BUCKET,bundleType=zip,key=deploy.zip
                '''
            }
        }
    }
}
```

---

## PART 10: Creating EC2 Auto-Scaling Group

Follow the steps to create an Auto Scaling group named `DjangoAppAutoScaleingGroup`.

---

## PART 11: Create a Load Balancer

### Create Application Load Balancer
- **Name**: django-app-LB
- Configure the target group and security group.

---

## PART 12: Configure CodeDeploy

### Create CodeDeploy Application
- **Name**: django-app
- **Deployment Group Name**: django-app-DG

---

## PART 13: Execute Build

Navigate to Jenkins at `<IP>:8080`, select your project, and click **Build Now**. Access your application via the Load Balancer URL.

---

### Notes:
- Update your pipeline script and credentials as needed.
- Ensure security best practices are followed throughout the setup.

---
- **For Brief Implementation follow these Blog**: [Django Application CI/CD Pipeline with Jenkins](https://projects-devops.hashnode.dev/djangoops#heading-part-13-its-time-for-a-tea-manual)
