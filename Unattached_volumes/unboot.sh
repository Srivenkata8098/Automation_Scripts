#!/bin/bash
cd /local/apps/Sri_venkata/Sri_scripts/phx_scripts
region=us-phoenix-1
rm unattached_volumes.html
output_file=unattached_volumes.html

echo "<html>" >> $output_file
echo "<head><title>Unattached Boot Volumes</title></head>" >> $output_file
echo "<body>" >> $output_file
echo "<table cellpadding='10' border='3'>" >> $output_file
echo "<tr style='background-color: green'>" >> $output_file
echo "<th>Compartment Name</th>" >> $output_file
echo "<th>Volume Name</th>" >> $output_file
echo "<th>Size in GBs</th>" >> $output_file
echo "<th>Volume Type</th>" >> $output_file
echo "<th>Estimated Monthly Savings if removed (USD)</th>" >>$output_file
echo "</tr>" >> $output_file

comp=$(oci iam compartment list --all --compartment-id-in-subtree 1 --query  'data[*].id' | sed 's/^.//'|sed 's/,//'|sed 's/"//g'| sed 's/^.//'|sed -r '/^\s*$/d')

for i in $comp; do
    av_domain=$(oci iam availability-domain list --region $region -c $i --all --query 'data[*].name' | sed 's|^.||g' | sed 's|"||g' | sed 's|,||g' | sed 's|^.||g')

    for av in $av_domain; do
        boot_volume=$(oci bv boot-volume list --region $region -c $i --availability-domain $av --all --query "data[?\"lifecycle-state\"=='AVAILABLE'].id" | sed 's|^.||g' | sed 's|"||g' | sed 's|,||g' | sed 's|^.||g')
        boot_volume_attachment=$(oci compute boot-volume-attachment list --region $region -c $i --availability-domain $av --all --query "data[*].\"boot-volume-id\"" | sed 's|^.||g' | sed 's|"||g' | sed 's|,||g' | sed 's|^.||g')

        IFS=$'\n' read -rd '' -a attached_ids <<< "$boot_volume_attachment"

        unattached=()
        while IFS=$'\n' read -r bv; do
            if [[ -n "$bv" && ! " ${attached_ids[*]} " =~ " ${bv} " ]]; then
                unattached+=("$bv")
            fi
        done <<< "$boot_volume"

        if [ ${#unattached[@]} -gt 0 ]; then
            comp_name=$(oci iam compartment get -c $i --query 'data.name' --raw-output)
            rowspan=${#unattached[@]}
            for index in "${!unattached[@]}"; do
                echo "<tr>" >> $output_file
                if [ "$index" -eq 0 ]; then
                    echo "<td rowspan=\"$rowspan\">$comp_name</td>" >> $output_file
                fi
                vol_name=$(oci bv boot-volume get --region $region --boot-volume-id "${unattached[$index]}" --query "data.\"display-name\"" --raw-output)
                vol_size=$(oci bv boot-volume get --region $region --boot-volume-id "${unattached[$index]}" --query "data.\"size-in-gbs\"" --raw-output)
                #vol_type=$(oci bv boot-volume get --boot-volume-id "${unattached[$index]}" --query "data.\"source-type\"" --raw-output)
                vol_type=""
                if [[ "${unattached[$index]}" == ocid1.bootvolume* ]]; then
                        vol_type=boot
                else
                        vol_type=block
                fi
                monthly_savings=$(echo "$vol_size * 0.045" | bc)
                echo "<td>$vol_name</td>" >> $output_file
                echo "<td>$vol_size</td>" >> $output_file
                echo "<td>$vol_type</td>" >> $output_file
                echo "<td>$monthly_savings</td>" >> $output_file
                echo "</tr>" >> $output_file
            done
        fi
    done
done

echo "</table>" >> $output_file
echo "</body>" >> $output_file
echo "</html>" >> $output_file

/local/apps/Sri_venkata/Sri_scripts/phx_scripts/boot_mail
