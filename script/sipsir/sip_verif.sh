#!/bin/bash
neutre='\e[0;m'
vert='\e[0;32m'
rouge='\e[0;31m'
for var in $(grep -v "#" $HOME/prakotoarisoa/script/sipsir/list_sipsir|cut -d"|" -f2)
do
echo -e $neutre"Ping de $var"
ping  $var 1>/dev/null
if [ $? -ne 0 ]
then
echo -e $rouge"KO"
else
echo -e $vert"OK"
fi
echo -e $neutre"--------"
done  
