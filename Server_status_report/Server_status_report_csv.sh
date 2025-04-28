#!/bin/bash
export PATH="PATH=/home/srivenkata_atti/bin:/home/srivenkata_atti/.local:/home/srivenkata_atti/.local/bin:/home/srivenkata_atti/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/local/apps/intellij/bin:/opt/puppetlabs/bin:/home/srivenkata_atti/bin"
region=us-phoenix-1
cd /local/apps/Sri_venkata/Sri_scripts/phx_scripts
rm -f test_new_phx.csv
output_file=test_new_phx.csv

# CSV Header
echo "Compartment Name,Instances,Instance State,Shape,Created Time" >> $output_file
comp=$(oci iam compartment list --all --compartment-id-in-subtree 1 --query  'data[*].id' | sed 's/^.//'|sed 's/,//'|sed 's/"//g'| sed 's/^.//'|sed -r '/^\s*$/d')
while read -r i; do
    comp_name=$(oci iam compartment get --compartment-id "$i" --query 'data.name' --raw-output)
    instance_ids=$(oci compute instance list --region $region -c "$i" --all --query 'data[*].id' --raw-output | jq -r '.[]')

    for inst_id in $instance_ids; do
        display_name=$(oci compute instance get --region $region --instance-id "$inst_id" --query 'data."display-name"' --raw-output)
        lifecycle_state=$(oci compute instance get --region $region --instance-id "$inst_id" --query 'data."lifecycle-state"' --raw-output)
        time_created=$(oci compute instance get --region $region --instance-id "$inst_id" --query 'data."time-created"' --raw-output)
        shape=$(oci compute instance get --region $region --instance-id "$inst_id" --query 'data.shape' --raw-output)

        # Get VCN from instance -> VNIC -> Subnet -> VCN
        subnet_id=$(oci compute vnic-attachment list --region $region -c "$i" --instance-id "$inst_id" --query 'data[0]."subnet-id"' --raw-output)
        vcn_id=$(oci network subnet get --region $region --subnet-id "$subnet_id" --query 'data."vcn-id"' --raw-output)
        vcn_name=$(oci network vcn get --region $region --vcn-id "$vcn_id" --query 'data."display-name"' --raw-output)

        echo "$comp_name,$display_name,$lifecycle_state,$shape,$time_created" >> $output_file
    done

done<ocid_details_phx.txt

/local/apps/Sri_venkata/Sri_scripts/phx_scripts/server_status_csv_mailer_phx
~
