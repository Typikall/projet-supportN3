#!/bin/bash
# ============================================================
# =     Script de copie de la configuration necessaire       =
# =       pour la restauration de la structure des           =
# =         disques et filesystems pour le                   =
# =                       SIPSIR v3                          =
# =       Ce fichier ne doit pas etre modifie !!!!           =
# =         Version 1.3 du 10/03/2014 pour rear 1.15         =
# = 							     =
# = v1.0 Version intiales				     =
# = v1.1 Ajout de la variable LOGFILE dans 		     =
# = 	/usr/share/rear/conf/default.conf car impossible     =
# = 	via une configuration standard		             =
# = v1.2 Ajout du nom et de la taille de la sauvegarde SIP   =
# = v1.3 Prise en charge du multipath			     =
# ============================================================
PATH='/bin:/usr/bin:/sbin:/usr/sbin'

REAR_LOG_FILE=$(ls -rt /tmp/rear-backup_*|tail -1)
echo $(date)" : Montage du SIP pour copie des donnees de REAR" >>${REAR_LOG_FILE}
/bin/mount -t nfs4 SIP:/ /mnt/cdrom 
if [ $? -ne 0 ]; then
	echo $(date)" Erreur : Impossible de monter le FS depuis le SIP" >>${REAR_LOG_FILE}
	exit 1
fi
echo $(date)" : Copie des donnees de REAR" >>${REAR_LOG_FILE}
rm -rf /mnt/cdrom/recovery /mnt/cdrom/layout /mnt/cdrom/etc_rear
# Update v1.3
if [ $(grep -q ^multipath /var/lib/rear/layout/disklayout.conf;echo $?) -eq 0 ]; then
	echo $(date)" : Boot On SAN detecte"
	case $(awk '{VERSION=substr($7,1,1);print VERSION}' /etc/redhat-release) in
                6)
                        cp -Rf /etc/multipath/bindings /mnt/cdrom/ ;;
                5)
                        cp -Rf /var/lib/multipath/bindings /mnt/cdrom/ ;;
                *)
                        echo "Version de Systeme non reconnue !!" ;;
        esac
	LAYOUT_FILE='/var/lib/rear/layout/disklayout.conf'
	MPATH_DISK=$(awk '$0~/^multipath.*mpath/ {print $2}' ${LAYOUT_FILE})
	if [ "${MPATH_DISK}" ]; then
        	SINGLE_DISK=$(awk '$0~/^multipath / {print $NF}' ${LAYOUT_FILE}|awk -F"," '{print $1}')
        	if [ "$SINGLE_DISK" ]; then
                	BOOT_PART_START=$(awk -v SINGLE_DISK=$SINGLE_DISK '$0~/^#part.*boot/ && $0~SINGLE_DISK { print $4 }' ${LAYOUT_FILE})
                	LVM_PART_START=$(awk -v SINGLE_DISK=$SINGLE_DISK '$0~/^#part.*lvm/ && $0~SINGLE_DISK { print $4 }' ${LAYOUT_FILE})
                	sed -i "s#^\(part ${MPATH_DISK}.*\)unknown\(.*boot.*\)#\1$BOOT_PART_START\2#" ${LAYOUT_FILE}
                	sed -i "s#^\(part ${MPATH_DISK}.*\)unknown\(.*lvm.*\)#\1$LVM_PART_START\2#" ${LAYOUT_FILE}
        	fi
	fi
	if [[ "$(awk -v MPATH=${MPATH_DISK} '$1=="part" && $2==MPATH { print $4 }' ${LAYOUT_FILE})" =~ .*unknown.* ]]; then
        	echo $(date)' : Configuration de Rear erronee pour le Multipath !!!!' >>${REAR_LOG_FILE}
	fi
fi
# Fin Update v1.3
cp -Rf /var/lib/rear/* /mnt/cdrom
cp -Rf /etc/rear /mnt/cdrom/etc_rear
# Update v1.2
echo $(date)' : Taille & Nom de la sauvegarde : '$(ls -sh /mnt/cdrom/*.gz|tail -n 1|sed 's#/mnt/cdrom/##') >>${REAR_LOG_FILE}
# Fin Update v1.2
echo $(date)" : Demontage du SIP " >>${REAR_LOG_FILE}
umount -f /mnt/cdrom
# Update v1.1
if [ -f /usr/share/rear/conf/default.conf.original ] && [ -f /usr/share/rear/conf/default.conf.sipsir ]; then
	cp -pf /usr/share/rear/conf/default.conf.original /usr/share/rear/conf/default.conf
fi
# Fin Update v1.1
echo $(date)" : Fin du traitement" >>${REAR_LOG_FILE}
find /tmp/rear-backup_* -type f -mtime +5 -exec rm -f {} \;

