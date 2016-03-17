#!/bin/bash
for var in $(grep -v "#" $HOME/prakotoarisoa/caccia/list_caccia2|cut -d"|" -f1), var2 in $(grep -v "#" $HOME/prakotoarisoa/caccia/list_caccia2|cut -d"|" -f2)
do
echo -e "$var + $var2"
#echo -e "Ping de $var"
#ping  $var 1>/dev/null
#if [ $? -ne 0 ]
#then
#echo -e "KO"
#else
#echo -e "OK"
#fi
#echo "--------"
done
