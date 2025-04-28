#! /bin/bash
cd /local/apps/Sri_venkata/Sri_scripts/phx_scripts
rm un_block.html
output_file=un_block.html
region=us-phoenix-1
echo "<html>" >> $output_file
echo "<head><title>Unattached boot volumes</title></head>" >> $output_file
echo "<body>" >> $output_file
echo "<table cellpadding='10' border='3'>" >> $output_file
echo "<tr style='background-colour: green'>" >>$output_file
echo "<th> Compartment Name </th>" >> $output_file
echo "<th> Volume Name </th>" >>$output_file
echo "<th> Volume Type </th>" >>$output_file
echo "<th> Size in GBs </th>" >> $output_file
echo "<th> Estimated Monthly Savings if removed (USD) </th>" >> $output_file
echo "</tr>" >>$output_file

comp=$(oci iam compartment list --all --compartment-id-in-subtree 1 --query  'data[*].id' | sed 's/^.//'|sed 's/,//'|sed 's/"//g'| sed 's/^.//'|sed -r '/^\s*$/d')

for i in $comp;
do
        av_domain=$(oci iam availability-domain list --region $region -c $i --all --query 'data[*].name' | sed 's|^.||g' |sed 's|"||g' | sed 's|,||g' |sed 's|^.||g')
        for av in $av_domain;
        do
                un=()
                block_volume=$(oci bv volume list --region $region -c $i --availability-domain $av --all --query "data[?\"lifecycle-state\"=='AVAILABLE'].id" | sed 's|^.||g' |sed 's|"||g' | sed 's|,||g' | sed 's|^.||g')
#               echo "block_ids $block_volume"


                block_volume_attachment=$(oci compute volume-attachment list --region $region -c $i --availability-domain $av --all --query "data[*].\"volume-id\"" | sed 's|^.||g' |sed 's|"||g' | sed 's|,||g' |sed 's|^.||g')
#               echo "$block_volume_attachment"


                IFS=$'\n' read -rd '' -a attached_ids <<< "$block_volume_attachment"

                while IFS=$'\n' read -r bv; do

                        if [[ -n "$bv" && ! " ${attached_ids[*]} " =~ " ${bv} " ]]; then
                                un+=("$bv")
                        fi
                done<<< "$block_volume"

        #       echo "Unattached volumes in $av (Compartment: $i):"
        #       echo "$un"

                if [ "${#un[@]}" -gt 0 ]; then
                        comp_name=$(oci iam compartment get -c $i --query 'data.name' --raw-output)

                        rowspan=${#un[@]}
                        for index in "${!un[@]}"; do
                                echo "<tr>" >> $output_file
                                if [ "$index" -eq 0 ]; then
                                        echo "<td rowspan=\"$rowspan\">$comp_name</td>" >>$output_file
                                fi
                                vol_name=$(oci bv volume get --region $region --volume-id ${un[$index]} --query "data.\"display-name\"" --raw-output) >> $output_file
                                vol_size=$(oci bv volume get --region $region --volume-id ${un[$index]} --query "data.\"size-in-gbs\"" --raw-output) >> $output_file
                                echo "<td>$vol_name</td>" >>$output_file
                                echo "<td>Block Volume</td>" >> $output_file
                                echo "<td>$vol_size</td>" >> $output_file
                                cost=$(echo "$vol_size * 0.04" |bc )
                                echo "<td>$cost</td>" >> $output_file
                                echo "</tr>" >>$output_file

                        done
                        echo "</td>" >>$output_file
                        echo "</tr>" >>$output_file
#

                fi

        done

done

echo "</table>" >> $output_file
echo "</body>" >> $output_file
echo "</html>" >> $output_file

/local/apps/Sri_venkata/Sri_scripts/phx_scripts/mail_block
         
