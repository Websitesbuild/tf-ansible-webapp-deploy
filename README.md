1. run "ssh-keygen"
2. configure AWS key,secret
3. Adjust the hosts.ini path in "instance.tf" file accordingly
4. Navigate to terraform directory, then run below commands:
     a. terraform init
     b. terraform plan
     c. terraform validate
     d. terraform apply --auto-approve

5. Once, done then navigate to Ansible directory and run below cmd:
   
      ansible-playbook -i inventory/hosts.ini playbooks/site.yml


   Access the app the on:

   <ec2_public_ip>:8081
