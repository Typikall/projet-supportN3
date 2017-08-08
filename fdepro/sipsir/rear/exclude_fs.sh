#!/bin/bash
# ============================================================
# =        Script d'exclusion automatique 		     =
# =                                                          =
# =     
# =                                                          =
# = v1.0 Version intiale                                     =
# = v1.1 Prise en charge de l'exclusion de type de FS        =
# =      par defaut (vxfs|gpfs|acfs)                         =
# =      les exclusions fs sont faites via                   =
# =         EXCLUDE_RECREATE & EXCLUDE_RESTORE				 =
# = v1.2 Ajout de la variable LOGFILE dans 					 =
# = /usr/share/rear/conf/default.conf car impossible         =
# = via une configuration standard				             =
# ============================================================
PATH='/bin:/usr/bin:/sbin:/usr/sbin'

SYS_VG='root_vg'
REAR_DIR='/etc/rear'
REAR_SITE_CONF="${REAR_DIR}/site.conf"
EXCLUDE_FS_TYPE='(gpfs|vxfs|acfs|cifs|smbfs)'

if [ ! -e ${REAR_SITE_CONF} ] && [ ! -r ${REAR_SITE_CONF} ]; then
	echo 'Rien a faire !! Fichier ${REAR_SITE_CONF} inexistant !'
	exit 0
fi

awk 'NR>=1 {print} $0~/^#=*NE RIEN MODIFIE/ {DEL="yes"} DEL=="yes" {exit;}' ${REAR_SITE_CONF} >${REAR_SITE_CONF}.tmp
echo '#=========Completer automatiquement par le script exclude_fs.sh=========' >>${REAR_SITE_CONF}.tmp
# Exclusion au niveau des FS (tous les FS ne faisant pas parti de root_vg ou n'etant pas des FS necessaires au systeme sont exclus)
echo 'EXCLUDE_MOUNTPOINTS=(' >>${REAR_SITE_CONF}.tmp
mount |egrep -v "${SYS_VG}(-|\/)|/proc | devpts | tmpfs | rootfs |none|sunrpc|sysfs |nfsd |/boot |/var |/home |/tmp |/dev/sda|/dev/cciss"|awk '{ print $3 }' >>${REAR_SITE_CONF}.tmp
echo ')' >>${REAR_SITE_CONF}.tmp
echo '' >>${REAR_SITE_CONF}.tmp
# Exclusion au niveau des VG (tous les VG sont exclus sauf root_vg)
echo 'EXCLUDE_VG=(' >>${REAR_SITE_CONF}.tmp
pvs --noheadings |awk -v SYS_VG="${SYS_VG} " '$0!~SYS_VG {print $2}'|sort -u >>${REAR_SITE_CONF}.tmp
echo ')' >>${REAR_SITE_CONF}.tmp
# Update v1.1
# Exclusion au niveau des FS (tous les FS ne faisant pas parti de root_vg ou n'etant pas des FS necessaires au systeme sont exclus)
echo 'EXCLUDE_RECREATE=(' >>${REAR_SITE_CONF}.tmp
echo '${EXCLUDE_RECREATE[@]}' >>${REAR_SITE_CONF}.tmp
awk -v EXCLUDE_FS_TYPE="${EXCLUDE_FS_TYPE}" '$0!~/^#/ && $3~EXCLUDE_FS_TYPE {print $1}' /etc/fstab >>${REAR_SITE_CONF}.tmp
echo ')' >>${REAR_SITE_CONF}.tmp
echo '' >>${REAR_SITE_CONF}.tmp
# Exclusion au niveau des FS (tous les FS ne faisant pas parti de root_vg ou n'etant pas des FS necessaires au systeme sont exclus)
echo 'EXCLUDE_RESTORE=(' >>${REAR_SITE_CONF}.tmp
echo '${EXCLUDE_RESTORE[@]}' >>${REAR_SITE_CONF}.tmp
awk -v EXCLUDE_FS_TYPE="${EXCLUDE_FS_TYPE}" '$0!~/^#/ && $3~EXCLUDE_FS_TYPE {print $1}' /etc/fstab >>${REAR_SITE_CONF}.tmp
echo ')' >>${REAR_SITE_CONF}.tmp
# Fin Update v1.1
echo '' >>${REAR_SITE_CONF}.tmp
echo '#=========Fin de la configuration automatique des exclusions le '$(date)'===========' >>${REAR_SITE_CONF}.tmp

cp -p ${REAR_SITE_CONF} ${REAR_SITE_CONF}.old
cp ${REAR_SITE_CONF}.tmp ${REAR_SITE_CONF}
\rm ${REAR_SITE_CONF}.old ${REAR_SITE_CONF}.tmp
# Update v1.2
if [ ! -f /usr/share/rear/conf/default.conf.original ] && [ ! -f /usr/share/rear/conf/default.conf.sipsir ]; then
	cp -p /usr/share/rear/conf/default.conf /usr/share/rear/conf/default.conf.original
	cp -p /usr/share/rear/conf/default.conf /usr/share/rear/conf/default.conf.sipsir
	echo '#Modif EEI pour SIPSIRv3 (Emplacement du fichier de log de rear)' >>/usr/share/rear/conf/default.conf.sipsir
	echo 'LOGFILE=/tmp/rear-backup_$(date +%Y%m%d_%H%M%S).log' >>/usr/share/rear/conf/default.conf.sipsir
else
	cp -pf /usr/share/rear/conf/default.conf.sipsir /usr/share/rear/conf/default.conf
fi
# Fin Update v1.2
