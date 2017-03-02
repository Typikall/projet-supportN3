#!/bin/sh
#set -x

#*****************************************************************************
# Fonctions de log
#*****************************************************************************
DATE_FORMAT() {
	export MYDATE=$(date '+%Y/%m/%d %T')
}

f_LOG() {
	echo "$@" >> ${LOGOI}
}

MESSAGE_INFO() {
	DATE_FORMAT ;echo ${MYDATE}" |   INFO  | $@" ; f_LOG "${MYDATE} |   INFO  | $@"
}

MESSAGE_WARNING() {
	DATE_FORMAT ;echo ${MYDATE}" | WARNING | $@" ; f_LOG "${MYDATE} | WARNING | $@"
}

MESSAGE_ERROR() {
	DATE_FORMAT ;echo ${MYDATE}" |  ERREUR | $@" ; f_LOG "${MYDATE} |  ERREUR | $@"
}

echo '########################################'
echo "#  Mise a jour  vers SYSREF-LINUX $CIBLE  #"
echo '########################################'


MESSAGE () {
# ecriture des messages de Log
echo "LOG : $1 "
echo "LOG : $1 " >> $LOGOI
}

# fin du programme
ENDING_BAD () {
	# fin du programme en KO
	MESSAGE_ERROR "il semblerait que des commandes soient mal passees"
	MESSAGE_ERROR "$1"
	MESSAGE_ERROR "La mise a jour ne s est pas effectuee correctement"
	MESSAGE_INFO "Vous pouvez consulter les Logs dans le fichier $LOGOI"
		# Si BUG_LOGGER le lien /bin/logger --> /usr/bin/logger est recree (si il existait)
	[[ ! -z "$BUG_LOGGER" ]] && [[ -f /usr/bin/logger ]] && [[ ! -h /usr/bin/logger ]] && ln -s /usr/bin/logger /bin/logger && MESSAGE_INFO "Re-creation du lien /bin/logger"
	exit 1
}

ENDING () {
	# fin du programme en OK
	[ -e /etc/yum.repos.d/majcible.repo ] && rm -f /etc/yum.repos.d/majcible.repo
	MESSAGE_INFO "fin de la mise a jour du systeme"
	MESSAGE_INFO "Vous pouvez consulter les Logs dans le fichier $LOGOI"
	MESSAGE_INFO "nous vous invitons a redemarrer le systeme, et verifier son fonctionnement"
	exit 0
}

# define a new repo just for ${CIBLE} on ISO mounted on /mnt/cdrom
SET_ISO_REPO() {

cat << EOF > /etc/yum.repos.d/majcible.repo
[majcible-edf-engineering]
name=majcible-edf-engineering
baseurl=file:///mnt/cdrom/Supp_Packages/sysref-el-${CIBLE}-edf-engineering
enabled=0
gpgcheck=0
[majcible-epel-base]
name=majcible-epel-base
baseurl=file:///mnt/cdrom/Supp_Packages/sysref-el-${CIBLE}-epel-base
enabled=0
gpgcheck=0
[majcible-third-party]
name=majcible-third-party
baseurl=file:///mnt/cdrom/Supp_Packages/sysref-el-${CIBLE}-edf-third-party
enabled=0
gpgcheck=0
[majcible-base]
name=majcible-base
baseurl=file:///mnt/cdrom/
enabled=0
gpgcheck=0

EOF

}

SET_SIP_REPO() {

cat << EOF > /etc/yum.repos.d/majcible.repo
[majcible-edf-engineering]
name=majcible-edf-engineering
baseurl=http://SIP/cobbler/localmirror/edf-engineering/rhel/${MAJOR_VERSION}Server/x86_64/$YUM9
enabled=0
gpgcheck=0
[majcible-epel-base]
name=macible-epel-base
baseurl=http://SIP/cobbler/localmirror/epel/rhel/${MAJOR_VERSION}Server/x86_64
enabled=0
gpgcheck=0
[majcible-third-party]
name=majcible-third-party
baseurl=http://SIP/cobbler/localmirror/third-party/rhel/${MAJOR_VERSION}Server/x86_64/$YUM9
enabled=0
gpgcheck=0
[majcible-base]
name=majcible-base
baseurl=http://SIP/cobbler/localmirror/distributions/rhel/${MAJOR_VERSION}Server/x86_64/$YUM9/os/
enabled=0
gpgcheck=0
[majcible-updates]
name=majcible-updates
baseurl=http://SIP/cobbler/localmirror/distributions/rhel/${MAJOR_VERSION}Server/x86_64/$YUM9/updates/
enabled=0
gpgcheck=0

EOF

}

CLEAN_OLD_INITRD () {

	GRUB_FILE=/boot/grub/grub.conf

		# Pour chaque fichier initrd trouve dans /boot on regarde si grub l'utilise
	for INITRD_FILE in $(find /boot -name "initrd-*" -exec basename {} \; 2>/dev/null)
	do
		egrep -q "^[[:space:]]*initrd[[:space:]]+\/$INITRD_FILE" $GRUB_FILE
			# Si le fichier initrd n'est pas present dans grub.conf, on le supprime
		if [ $? -ne 0 ]; then
			\rm -f /boot/${INITRD_FILE}
			MESSAGE_INFO "Suppression du fichier initrd non utilise : /boot/${INITRD_FILE}"
		fi		
	done

		# Verifie l'espace dispo dans /boot
	BOOTDF=$(df -Pm /boot | awk '$6 ~ /\/boot$/ {print $4}')
	if [ $BOOTDF -lt 40 ]; then
		MESSAGE_ERROR "Le FS /boot n'a pas assez d'espace libre (<40Mo)"
		exit 1
	fi
}


CHECK_SYSREF () {

SLASHDF=$(df -Pm / | awk '$1 ~ /lv_root$/ {print $4}')
VARDF=$(df -Pm /var | awk '$1 ~ /lv_var$/ {print $4}')

if [ -z $SLASHDF ]; then
	MESSAGE_ERROR "Le FS / n'est pas sur le LV lv_root"
	exit 1
fi

if [ -z $VARDF ]; then
	MESSAGE_ERROR "Le FS /var n'est pas sur le LV lv_var"
	exit 1
fi

if [ $SLASHDF -lt 400 ]; then
	MESSAGE_ERROR "Le FS / n'a pas assez d'espace libre (<400Mo)"
	exit 1
fi

if [ $VARDF -lt 400 ]; then
	MESSAGE_ERROR "Le FS /var n'a pas assez d'espace libre (<400Mo)"
	exit 1
fi

if [ ! -e /etc/conf_machine/version_ref ]; then
	MESSAGE_ERROR 'SOUCHE NON DETECTEE'
	MESSAGE_ERROR "le fichier /etc/conf_machine/version_ref n'existe pas !"
	exit 1
fi

(rpm -qa | egrep 'centos-release|redhat-release'  ) 2>/dev/null 1>&2
if [ $? -ne 0 ]
then
	MESSAGE_ERROR "SYSTEME REDHAT/CENTOS NON DETECTEE"
	exit 1
fi


}

# get the version of RHEL/Centos et security currently installed
GET_CURRENT_OS () {

# determine de systeme actuel
#EL_VERSION=`/bin/sed "s/.*\([0-9]\.[0-9]*\).*/\1/g" /etc/redhat-release`
#EL_VERSION_MAJ=`/bin/sed "s/.*\([0-9]\)\.[0-9]*.*/\1/g" /etc/redhat-release`
SYSREF_VERSION=$(awk '{print $1}' /etc/conf_machine/version_ref|sed -r 's/\.[0-9]+$//g')
#SYSREF_MAJOR_VERSION=$(awk '{print $1}' /etc/conf_machine/version_ref|sed -r 's/\.[0-9]+\.[0-9]+$//g')
SYSREF_MAJOR_VERSION=$(awk '{print $1}' /etc/conf_machine/version_ref | sed 's/^\([0-9]*\)\.[0-9]*.*$/\1/')
rpm -qa | grep -q centos-release
[ $? -eq 0 ] && export YUM8=centos
rpm -qa | grep -q redhat-release
[ $? -eq 0 ] && export YUM8=rhel

export SECU="n1"
grep -q SECURE /etc/conf_machine/version_ref
[ $? -eq 0 ] && export SECU="n3"

export SYSREF_VERSION && export SYSREF_MAJOR_VERSION

}


GET_METHOD_MAJ () {

export METHOD_MAJ=ISO
if [ $(grep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" /etc/hosts | grep -wq SIP ;echo $?) -eq 0 ]; then
	export METHOD_MAJ=SIP
fi

if [ ${METHOD_MAJ} == "SIP" ]
then
	MESSAGE "UNE ENTREE SIP EXISTE DANS /etc/hosts"
	Check_SIP
	MESSAGE "LE SYSTEME EST RACCORDE A UNE INFRA SIP/SIR"
else
	MESSAGE "PAS D ENTREE SIP DANS /etc/hosts"
	MESSAGE "Le SYSTEME DEVRA ETRE MIS A JOUR VIA ISO, dans /mnt/cdrom"
fi

}

# Check if a fusion IO card is installed
CHECK_FUSION_IO () {

if [ $(/sbin/lsmod | grep -iq iomemory_vsl ;echo $?) -eq 0 ]; then
	echo "!!! ATTENTION : driver Fusion IO detecte"
	echo "!!! Upgrading the Kernel in Linux"
	echo "    If you ever plan to upgrade the kernel when the Fusion ioMemory VSL software is installed, you must:"
	echo "    1. Unload the Fusion ioMemory VSL driver."
	echo "    2. Uninstall the Fusion ioMemory VSL software."
	echo "    3. Lancer cet OI de migration."
	echo "    4. Install the Fusion ioMemory VSL software package that is compiled for the new kernel."
	echo "    Failure to follow this procedure may result in driver load issues. KB902"
	MESSAGE_ERROR "Driver Fusion IO detecte, vous devez decharger le driver Fusion ioMemory VSL et le desinstaller puis relancer cet OI de migration et installer le logiciel Fusion ioMemory VSL qui est compile pour le nouveau noyau"
	exit 4
fi
}

# check type of machine
SET_DRIVERS_TO_INSTALL () {

	CONSTRUCTEUR=$(dmidecode -s system-manufacturer 2>/dev/null)
	if [ "$CONSTRUCTEUR" == "HP" ] || [ "$CONSTRUCTEUR" == "Hewlett-Packard" ]
	then
		rpm_drivers="svr_sysref-linux-drivers-hp"
		MACHINE="HP"

			# Probleme avec package hponcfg
		HPONCFG_MAJVER=$(yum list installed hponcfg 2>/dev/null | grep hponcfg | awk '{print $2}' | sed 's/\(^[0-9]\).*/\1/')
		[[ ! -z "$HPONCFG_MAJVER" ]] && [[ $HPONCFG_MAJVER -eq 3 || $HPONCFG_MAJVER -eq 4 ]] && DRIVER2REMOVE=hponcfg
	fi

	if [ "$CONSTRUCTEUR" == "VMware, Inc." ]
	then
		rpm_drivers="svr_sysref-linux-drivers-vm"
		MACHINE="Vmware"
	fi

	if [ "$CONSTRUCTEUR" == "Cisco Systems Inc" ]
	then
		rpm_drivers="svr_sysref-linux-drivers-ucs"
		MACHINE="Cisco UCS"
	fi

	MESSAGE "TYPE DE MACHINE : ${MACHINE}"
}

# ON ACCEPTE de CONTINUER ???
ASK_FOR_UPDATE () {
echo "* Ce script procedera a une Mise A Jour du systeme actuel "
echo "* $YUM8 ${SYSREF_VERSION} ${SECU} VERS SOCLE $YUM8 ${CIBLE} ${SECU}"
echo "* via methode ${METHOD_MAJ}"

read -p "Etes-vous certain ? O/o pour continuer : " -n 1 -r
echo    # new line
if [[ ! $REPLY =~ ^[Oo]$ ]]
then
	MESSAGE "MISE A JOUR ANNULEE"
	exit 0
fi

}

Check_Config_SRV() {

# Pour eviter que la brique config plante en pre-install
DOMAIN_SRV=$(/bin/dnsdomainname 2>/dev/null)
if [ -z ${DOMAIN_SRV} ]; then
	MESSAGE_ERROR "Impossible de determiner le domaine du serveur ! Verifier le format du fichier /etc/hosts (@IP	NomServeur_Long NomServeur_Court) "
	exit 2
fi


}


Check_SIP() {

if [ $(grep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" /etc/hosts | grep -wq SIP ;echo $?) -ne 0 ]; then
	MESSAGE_ERROR "Impossible de trouver un SIP dans le fichier /etc/hosts"
	exit 2
fi

if [ $(which nc >/dev/null 2>&1 ;echo $?) -eq 0 ]; then
	SIP_IP=$(awk '$0!~/^#/ && $0~/[[:space:]]SIP($|[[:space:]])/ { print $1 }' /etc/hosts)
	[[ -z "${SIP_IP}" ]] && MESSAGE_ERROR "Erreur ! Pas d'adresse IP pour SIP defini dans /etc/hosts\n Sortie KO" && exit 1
	# On verifie que les ports necessaires sont joignables
	PORT_SIP=80
	RESULT=$(nc -w 1 -z ${SIP_IP} ${PORT_SIP})
	[[ "${RESULT}" != *succeeded* ]] && MESSAGE_ERROR "Erreur : Le flux vers ${SIP_IP} sur le port ${PORT_SIP} est KO" && exit 1
fi

}

# on lance la mise a jour
SYS_UPDATE () {
MESSAGE_INFO "LA MISE A JOUR POURRA PRENDRE UN PEU DE TEMPS..."
#export YUM8=${EL} ; export YUM9=${CIBLE}
export YUM9=${CIBLE}
if [ ${METHOD_MAJ} == "ISO" ]; then
	MESSAGE_INFO "UPDATE via ISO"

		# Verifie que ce n'est pas un cdrom CentOS qui est monte
		# pour la MAJ d'un RHEL
	if [ -f /mnt/cdrom/.treeinfo ]; then
		grep -qi $YUM8 /mnt/cdrom/.treeinfo
		[ $? -ne 0 ] && ENDING_BAD "Mauvais cdrom monte : impossible de trouve $YUM8 dans /mnt/cdrom/.treeinfo"
	fi

	[ ! -e /mnt/cdrom/Supp_Packages/sysref-el-${YUM9}-edf-engineering ] && ENDING_BAD "L ISO SOCLE $YUM8 $YUM9 n est pas monte dans /mnt/cdrom"
	SET_ISO_REPO
	YUM9=$SYSREF_VERSION yum --enablerepo=* clean all
	YUM9=$CIBLE yum --enablerepo=* clean all
#	yum clean all
	[[ ! -z "$DRIVER2REMOVE" ]] && yum -y remove $DRIVER2REMOVE

	yum -y --disablerepo=* --enablerepo=*majcible* update
	[ $? -ne 0 ] && ENDING_BAD 'probleme d execution de YUM UPDATE'
	yum -y --disablerepo=* --enablerepo=*majcible* install svr_sysref-linux-securite-${SECU} ${rpm_drivers}
	[ $? -ne 0 ] && ENDING_BAD "probleme d install des nouveaux packages socles svr_sysref-linux ${CIBLE}"
elif [ ${METHOD_MAJ} == "SIP" ]; then
	MESSAGE_INFO "Migration SYSREF via SIP"
#	if [ $SYSREF_MAJOR_VERSION == "5" ]
	if [[ $SYSREF_MAJOR_VERSION == "5" || $SYSREF_MAJOR_VERSION == "6" ]]
	then
		Check_SIP
		SET_SIP_REPO
		YUM9=$SYSREF_VERSION yum --enablerepo=* clean all
		YUM9=$CIBLE yum --enablerepo=* clean all
	#	yum clean all
		[[ ! -z "$DRIVER2REMOVE" ]] && yum -y remove $DRIVER2REMOVE

		yum -y --noplugins --disablerepo=* --enablerepo=*majcible* update >> $LOGOI
		[ $? -ne 0 ] && ENDING_BAD "Probleme d'execution de YUM UPDATE"
		yum -y --noplugins --disablerepo=* --enablerepo=*majcible* install svr_sysref-linux-securite-${SECU} ${rpm_drivers} >> $LOGOI
		[ $? -ne 0 ] && ENDING_BAD "Probleme d'install des nouveaux packages socles svr_sysref-linux ${CIBLE}"
#	else
#		Check_SIP
#		SET_SIP_REPO
#		yum clean all
#		yum -y --noplugins --disablerepo=* --enablerepo=rhel[56]-$YUM9-base,*engineering-base,*-third-party-base,sysref*,*majcible* update >> $LOGOI
#		[ $? -ne 0 ] && ENDING_BAD "probleme d'execution de YUM UPDATE"
#		yum -y --noplugins --disablerepo=* --enablerepo=rhel[56]-$YUM9-base,*engineering-base,*-third-party-base,sysref*,*majcible* install svr_sysref-linux-securite-${SECU} ${rpm_drivers} >> $LOGOI
#		[ $? -ne 0 ] && ENDING_BAD "Probleme d install des nouveaux packages socles svr_sysref-linux ${MINOR_VERSION}"
	fi
fi

}

BUNDLEEDF_UPDATE() {

yum --noplugins clean all

# MAJ du BundleEDF
if [ $(rpm -qa |grep -q svr_sipsir-client ;echo $?) -ne 0 ]; then
	# Install du package svr_sipsir-client
	yum -y --noplugins --nogpgcheck --disablerepo=* --enablerepo=*majcible* install svr_sipsir-client >> $LOGOI
fi
if [ $(rpm -qa |grep -q svr_sysalt ;echo $?) -ne 0 ]; then
	# Install du package svr_sysalt
	yum -y --noplugins --nogpgcheck --disablerepo=* --enablerepo=*majcible* install svr_sysalt >> $LOGOI
fi

if [ $(rpm -qa |grep -q caccia ;echo $?) -ne 0 ]; then
	if [ $(grep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" /etc/hosts | grep -wq SIP ;echo $?) -eq 0 ]; then
		OLD_PWD=$(pwd)
		cd /tmp
		wget -q http://SIP/produits/produits_bundlesysEDF/latest/svr_caccia2-client.1.0_linux_rhe5-rhe6_n1-n3^1.0.sh
		if [ -f svr_caccia2-client.1.0_linux_rhe5-rhe6_n1-n3^1.0.sh ]; then
			chmod +x svr_caccia2-client*
			./svr_caccia2-client.1.0_linux_rhe5-rhe6_n1-n3^1.0.sh
		fi
		cd ${OLD_PWD}
	fi
fi

}



Main() {

	# defini vers quel socle cible on fait la MAJ
	FULL_VERSION=$(echo $0|sed -r "s/^.*linux\.//;s/--mig.*//")
	MINOR_VERSION=$(echo $0|sed -r "s/^.*linux\.//;s/--mig.*//;s/\.[0-9]+$//g")
	MAJOR_VERSION=$(echo $0|sed -r "s/^.*linux\.//;s/--mig.*//;s/\.[0-9]+\.[0-9]+$//g")
	CIBLE=${MINOR_VERSION}
	INDUS_VER=$(echo $0|sed 's/^.*\^//;s/\.sh$//')
	MYDATE=$(date '+%Y_%m_%d-%H_%M_%S')
	LOGOI=/var/log/svr_sysref-linux.${FULL_VERSION}--mig_linux_rhe${MAJOR_VERSION}_n1-n3^${INDUS_VER}_${MYDATE}.log


	##  BEGINING OF UPDATE SCRIPT
	

	CHECK_SYSREF
	GET_CURRENT_OS
	## GET_METHOD_MAJ
	Check_Config_SRV

	case $WANTED_METHOD in
		SIP) 
			MESSAGE "METHODE VOULUE : SIP"
			METHOD_MAJ="SIP"
			;;
		ISO)
			MESSAGE "METHODE VOULUE : ISO"
			METHOD_MAJ="ISO"
			;;
		"")
			GET_METHOD_MAJ
			ASK_FOR_UPDATE
			;;
		*)
			MESSAGE "PARAMETRE INCONNU"
			exit 1
			;;
	esac

	SET_DRIVERS_TO_INSTALL
	CHECK_FUSION_IO
		# Check si /bin/logger est un lien : bug util-linux-ng-2.17.2-12.18.el6.x86_64
	[[ -h /bin/logger ]] && BUG_LOGGER=1 && \rm -f /bin/logger

		# Supprime les initrd inutiles dans /boot et verifie l'espace dispo dans /boot
	CLEAN_OLD_INITRD

	SYS_UPDATE
	BUNDLEEDF_UPDATE
}

WANTED_METHOD=$1
BUG_LOGGER=
DRIVER2REMOVE=
Main

ENDING

exit 0
