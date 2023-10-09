#!/bin/bash
# This is a Bash script for setting up AWS CLI and configuring AWS resources.


# Remove Python 3.6, install Python 3.8, and set it as the default Python version
sudo yum -y remove python36
sudo yum -y install python38
sudo update-alternatives --set python /usr/bin/python3.8

# Download and install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip ~/environment/awscliv2.zip && sudo ~/environment/aws/install
rm awscliv2.zip

# Install the boto3 Python library
sudo pip install boto3

# Prompt the user to enter a valid IP address
echo Please enter a valid IP address:
read ip_address
echo IP address:$ip_address
echo Please wait...

# Commented out: An optional command to upgrade AWS CLI
#sudo pip install --upgrade awscli

# List S3 buckets and extract the bucket name
bucket=`aws s3api list-buckets --query "Buckets[].Name" | grep s3bucket | tr -d ',' | sed -e 's/"//g' | xargs`

# Get the API Gateway ID
apigateway=`aws apigateway get-rest-apis | grep id | cut -f2- -d: | tr -d ',' | xargs`
echo $apigateway

# Define file paths for configuration files
FILE_PATH="/home/ec2-user/environment/resources/public_policy.json"
FILE_PATH_2="/home/ec2-user/environment/resources/permissions.py"
FILE_PATH_3="/home/ec2-user/environment/resources/setup.sh"
FILE_PATH_4="/home/ec2-user/environment/resources/website/config.js"

# Replace placeholders in JSON files with actual values
sed -i "s/<FMI_1>/$bucket/g" $FILE_PATH
sed -i "s/<FMI_2>/$ip_address/g" $FILE_PATH
sed -i "s/<FMI>/$bucket/g" $FILE_PATH_2

# Replace API Gateway URL placeholder in config.js
sed -i "s/API_GW_BASE_URL_STR: null,/API_GW_BASE_URL_STR: \"https:\/\/${apigateway}.execute-api.us-east-1.amazonaws.com\/prod\",/g" $FILE_PATH_4

# Copy website files to the S3 bucket with cache control settings
aws s3 cp ./resources/website s3://$bucket/ --recursive --cache-control "max-age=0"

# Run Python scripts for permissions and data seeding
python /home/ec2-user/environment/resources/permissions.py
python /home/ec2-user/environment/resources/seed.py



# Navigate to the application directory and create a Dockerfile
cd /home/ec2-user/environment/resources/codebase_partner
touch Dockerfile

# Define Dockerfile contents for a Node.js application
echo 'FROM node:11-alpine
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY . .
RUN npm install
EXPOSE 3000
CMD ["npm", "run", "start"]
' > Dockerfile

# Get the AWS account ID
account_id=`aws sts get-caller-identity --query "Account" --output "text"`

# Build and tag a Docker image
docker build --tag cafe/node-web-app .
docker tag cafe/node-web-app:latest "${account_id}.dkr.ecr.us-east-1.amazonaws.com/cafe/node-web-app:latest"         

# Log in to Amazon ECR and push the Docker image
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${account_id}.dkr.ecr.us-east-1.amazonaws.com"
docker push "${account_id}.dkr.ecr.us-east-1.amazonaws.com/cafe/node-web-app"

# Completion message
echo "done"
