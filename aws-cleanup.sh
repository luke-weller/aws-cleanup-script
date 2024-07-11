#!/bin/bash

# Function to print in green
print_green() {
    echo -e "\033[0;32m$1\033[0m"
}

# Terminate all EC2 instances
echo "Terminating all EC2 instances..."
instance_ids=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId" --output text)
if [ -n "$instance_ids" ]; then
    aws ec2 terminate-instances --instance-ids $instance_ids
    aws ec2 wait instance-terminated --instance-ids $instance_ids
    print_green "All EC2 instances terminated."
else
    print_green "No EC2 instances found."
fi

# Delete all EC2 volumes
echo "Deleting all EC2 volumes..."
volume_ids=$(aws ec2 describe-volumes --query "Volumes[*].VolumeId" --output text)
if [ -n "$volume_ids" ]; then
    for volume_id in $volume_ids; do
        aws ec2 delete-volume --volume-id $volume_id
    done
    print_green "All EC2 volumes deleted."
else
    print_green "No EC2 volumes found."
fi

# Delete all S3 buckets including versioned buckets
echo "Deleting all S3 buckets..."

bucket_names=$(aws s3api list-buckets --query "Buckets[].Name" --output text)

for bucket in $bucket_names; do
    echo "Emptying bucket: $bucket"

    # Delete all versions and delete markers
    versions=$(aws s3api list-object-versions --bucket "$bucket" --query 'Versions[].{ID:VersionId,Key:Key}')
    markers=$(aws s3api list-object-versions --bucket "$bucket" --query 'DeleteMarkers[].{ID:VersionId,Key:Key}')

    if [ ! -z "$versions" ]; then
        echo "Deleting all versions in bucket: $bucket"
        for version in $(echo "$versions" | jq -r '.[] | @base64'); do
            _jq() {
             echo ${version} | base64 --decode | jq -r ${1}
            }

           aws s3api delete-object --bucket "$bucket" --key "$(_jq '.Key')" --version-id "$(_jq '.ID')"
        done
    fi

    if [ ! -z "$markers" ]; then
        echo "Deleting all delete markers in bucket: $bucket"
        for marker in $(echo "$markers" | jq -r '.[] | @base64'); do
            _jq() {
             echo ${marker} | base64 --decode | jq -r ${1}
            }

           aws s3api delete-object --bucket "$bucket" --key "$(_jq '.Key')" --version-id "$(_jq '.ID')"
        done
    fi

    # Now attempt to delete the bucket
    echo "Deleting bucket: $bucket"
    aws s3 rb s3://$bucket --force
done

print_green "All S3 buckets deleted."

# Delete all RDS instances
echo "Deleting all RDS instances..."
db_instance_ids=$(aws rds describe-db-instances --query "DBInstances[*].DBInstanceIdentifier" --output text)
for db_instance in $db_instance_ids; do
    aws rds delete-db-instance --db-instance-identifier $db_instance --skip-final-snapshot
    aws rds wait db-instance-deleted --db-instance-identifier $db_instance
done
print_green "All RDS instances deleted."

# Delete all CloudFormation stacks
echo "Deleting all CloudFormation stacks..."
stack_names=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[*].StackName" --output text)
for stack in $stack_names; do
    aws cloudformation delete-stack --stack-name $stack
    aws cloudformation wait stack-delete-complete --stack-name $stack
done
print_green "All CloudFormation stacks deleted."

# Delete all VPCs
echo "Deleting all VPCs..."
vpc_ids=$(aws ec2 describe-vpcs --query "Vpcs[*].VpcId" --output text)
for vpc_id in $vpc_ids; do
    echo "Deleting VPC: $vpc_id"
    subnet_ids=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[*].SubnetId" --output text)
    for subnet_id in $subnet_ids; do
        aws ec2 delete-subnet --subnet-id $subnet_id
    done
    internet_gateway_ids=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query "InternetGateways[*].InternetGatewayId" --output text)
    for igw_id in $internet_gateway_ids; do
        aws ec2 detach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id
        aws ec2 delete-internet-gateway --internet-gateway-id $igw_id
    done
    aws ec2 delete-vpc --vpc-id $vpc_id
done
print_green "All VPCs deleted."

# Delete all CloudWatch alarms
echo "Deleting all CloudWatch alarms..."
alarm_names=$(aws cloudwatch describe-alarms --query "MetricAlarms[*].AlarmName" --output text)
if [ -n "$alarm_names" ]; then
    aws cloudwatch delete-alarms --alarm-names $alarm_names
    print_green "All CloudWatch alarms deleted."
else
    print_green "No CloudWatch alarms found."
fi

# Delete Classic Load Balancers
echo "Deleting Classic Load Balancers..."
CLB_COUNT=$(aws elb describe-load-balancers --query "LoadBalancerDescriptions[*].LoadBalancerName" --output text | wc -w)
if [ "$CLB_COUNT" -gt 0 ]; then
    aws elb describe-load-balancers --query "LoadBalancerDescriptions[*].LoadBalancerName" --output text | while read lb_name; do
        aws elb delete-load-balancer --load-balancer-name "$lb_name"
        echo "Deleted Classic Load Balancer: $lb_name"
    done
    print_green "All Classic Load Balancers deleted."
else
    print_green "No Classic Load Balancers found."
fi

# Delete Application and Network Load Balancers
echo "Deleting Application and Network Load Balancers..."
ANLB_COUNT=$(aws elbv2 describe-load-balancers --query "LoadBalancers[*].LoadBalancerArn" --output text | wc -w)
if [ "$ANLB_COUNT" -gt 0 ]; then
    aws elbv2 describe-load-balancers --query "LoadBalancers[*].LoadBalancerArn" --output text | while read lb_arn; do
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn"
        echo "Deleted Application/Network Load Balancer: $lb_arn"
    done
    print_green "All Application and Network Load Balancers deleted."
else
    print_green "No Application and Network Load Balancers found."
fi

# Delete Auto Scaling Groups
echo "Deleting Auto Scaling Groups..."
ASG_COUNT=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[*].AutoScalingGroupName" --output text | wc -w)
if [ "$ASG_COUNT" -gt 0 ]; then
    aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[*].AutoScalingGroupName" --output text | while read asg_name; do
        aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --min-size 0 --max-size 0 --desired-capacity 0
        aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "$asg_name" --force-delete
        echo "Deleted Auto Scaling Group: $asg_name"
    done
    print_green "All Auto Scaling Groups deleted."
else
    print_green "No Auto Scaling Groups found."
fi

# Release Elastic IP Addresses
echo "Releasing Elastic IP Addresses..."
EIP_COUNT=$(aws ec2 describe-addresses --query "Addresses[*].AllocationId" --output text | wc -w)
if [ "$EIP_COUNT" -gt 0 ]; then
    aws ec2 describe-addresses --query "Addresses[*].AllocationId" --output text | while read alloc_id; do
        aws ec2 release-address --allocation-id "$alloc_id"
        echo "Released Elastic IP Address: $alloc_id"
    done
    print_green "All Elastic IP Addresses released."
else
    print_green "No Elastic IP Addresses found."
fi

# Delete all IAM users, but skip users with a login profile
echo "Deleting all IAM users..."
usernames=$(aws iam list-users --query "Users[*].UserName" --output text)
for username in $usernames; do
    echo "Checking user: $username"
    # Check for login profile
    login_profile=$(aws iam get-login-profile --user-name $username --query "LoginProfile.UserName" --output text 2>/dev/null)
    if [ "$login_profile" != "None" ]; then
        echo "User $username has a login profile. Skipping deletion."
        continue # Skip to the next iteration, effectively skipping this user
    fi
    policies=$(aws iam list-user-policies --user-name $username --query "PolicyNames" --output text)
    for policy in $policies; do
        aws iam delete-user-policy --user-name $username --policy-name $policy
    done
    groups=$(aws iam list-groups-for-user --user-name $username --query "Groups[*].GroupName" --output text)
    for group in $groups; do
        aws iam remove-user-from-group --user-name $username --group-name $group
    done
    access_keys=$(aws iam list-access-keys --user-name $username --query "AccessKeyMetadata[*].AccessKeyId" --output text)
    for key in $access_keys; do
        aws iam delete-access-key --user-name $username --access-key-id $key
    done
    # Attempt to delete the user
    aws iam delete-user --user-name $username
done
print_green "All applicable IAM users deleted."

# Delete all IAM roles
echo "Deleting all IAM roles..."
role_names=$(aws iam list-roles --query "Roles[*].RoleName" --output text)
for role_name in $role_names; do
    echo "Processing role: $role_name"
    # Skip AWS-managed service-linked roles
    if [[ $role_name == AWSServiceRoleFor* ]]; then
        echo "Skipping AWS-managed service-linked role: $role_name"
        continue
    fi
    # Delete inline policies attached to the role
    policies=$(aws iam list-role-policies --role-name $role_name --query "PolicyNames" --output text)
    for policy in $policies; do
        aws iam delete-role-policy --role-name $role_name --policy-name $policy
    done
    # Detach managed policies attached to the role
    attached_policies=$(aws iam list-attached-role-policies --role-name $role_name --query "AttachedPolicies[*].PolicyArn" --output text)
    for policy_arn in $attached_policies; do
        aws iam detach-role-policy --role-name $role_name --policy-arn $policy_arn
    done
    # Now attempt to delete the role
    aws iam delete-role --role-name $role_name || echo "Failed to delete role: $role_name"
done
print_green "All IAM roles processed."