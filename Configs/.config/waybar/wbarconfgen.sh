#!/usr/bin/env sh


# read control file and initialize variables

waybar_dir=`dirname $(realpath $0)`
modules_dir="$waybar_dir/modules"
conf_file="$waybar_dir/config.jsonc"
conf_ctl="$waybar_dir/config.ctl"

readarray -t read_ctl < $conf_ctl
num_files="${#read_ctl[@]}"
switch=0


# update control file to set next/prev mode

for (( i=0 ; i<$num_files ; i++ ))
do
    flag=`echo "${read_ctl[i]}" | cut -d '|' -f 1`

    if [ $flag -eq 1 ] && [ "$1" == "n" ] ; then
        nextIndex=$(( (i + 1) % $num_files ))
        switch=1
        break;

    elif [ $flag -eq 1 ] && [ "$1" == "p" ] ; then
        nextIndex=$(( i - 1 ))
        switch=1
        break;
    fi
done

if [ $switch -eq 1 ] ; then
    update_ctl="${read_ctl[nextIndex]}"
    sed -i "s/^1/0/g" $conf_ctl
    awk -F '|' -v cmp="$update_ctl" '{OFS=FS} {if($0==cmp) $1=1; print$0}' $conf_ctl > $waybar_dir/tmp && mv $waybar_dir/tmp $conf_ctl
fi


# overwrite config from header module

export set_sysname=`hostnamectl hostname`
export w_height=`grep '^1|' $conf_ctl | cut -d '|' -f 2`
export w_position=`grep '^1|' $conf_ctl | cut -d '|' -f 3`
envsubst < $modules_dir/header.jsonc > $conf_file


# module generator function

gen_mod()
{
    local pos=$1
    local col=$2
    local mod=""

    mod=`grep '^1|' $conf_ctl | cut -d '|' -f ${col}`
    mod="${mod//(/"custom/l_end"}"
    mod="${mod//)/"custom/r_end"}"
    mod="${mod// /"\",\""}"

    echo -e "\t\"modules-${pos}\": [\"custom/padd\",\"${mod}\",\"custom/padd\"]," >> $conf_file
    write_mod=`echo $write_mod $mod`
}


# write positions for modules

echo -e "\n\n// positions generated based on config.ctl //\n" >> $conf_file
gen_mod left 4
gen_mod center 5
gen_mod right 6


# copy modules/*.jsonc to the config

echo -e "\n\n// sourced from modules based on config.ctl //\n" >> $conf_file
echo "$write_mod" | sed 's/","/\n/g ; s/ /\n/g' | awk '!x[$0]++' | while read mod_list
do
    mod_cpy=`echo $mod_list | awk -F '/' '{print $NF}'`

    case ${w_position}-$(grep -E '"modules-left":|"modules-center":|"modules-right":' $conf_file | grep $mod_cpy | tail -1 | cut -d '"' -f 2 | cut -d '-' -f 2) in
        top-left) export mod_pos=1;;
        top-right) export mod_pos=2;;
        bottom-right) export mod_pos=3;;
        bottom-left) export mod_pos=4;;
    esac

    if [ -f $modules_dir/$mod_cpy.jsonc ] ; then
        envsubst < $modules_dir/$mod_cpy.jsonc >> $conf_file
    fi
done

cat $modules_dir/footer.jsonc >> $conf_file


# restart waybar

killall waybar
waybar > /dev/null 2>&1 &

