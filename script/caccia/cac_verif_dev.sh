#!/bin/bash
neutre='\e[0;m'
rouge='\e[0;31m'
for var in $(grep -v "#" $HOME/prakotoarisoa/script/caccia/list_caccia2|cut -d"|" -f2,6)
do
#echo -e $neutre"Ping de $var : $var2"
echo -e $neutre"$var"
#ping  $var 1>/dev/null
#if [ $? -ne 0 ]
#then
#echo -e $rouge"KO"
#else
#echo -e "OK"
#fi
#echo -e $neutre"--------"
done  
