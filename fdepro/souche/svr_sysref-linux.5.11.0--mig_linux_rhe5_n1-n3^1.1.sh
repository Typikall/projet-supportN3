########!/bin/sh
#!/usr/bin/env bash
#set -x

#*****************************************************************************
# Fonctions de log
#*****************************************************************************
DATE_FORMAT() {
    export MYDATE
	MYDATE=$(date '+%Y/%m/%d %T')
}

f_LOG() {
	echo "$@" >> "${LOGOI}"
}

MESSAGE_INFO() {
	DATE_FORMAT ;echo "${MYDATE} |   INFO  | $@" ; f_LOG "${MYDATE} |   INFO  | $@"
}

MESSAGE_WARNING() {
	DATE_FORMAT ;echo "${MYDATE} | WARNING | $@" ; f_LOG "${MYDATE} | WARNING | $@"
}

MESSAGE_ERROR() {
	DATE_FORMAT ;echo "${MYDATE} |  ERREUR | $@" ; f_LOG "${MYDATE} |  ERREUR | $@"
}

# fin du programme
ENDING_BAD () {
	# fin du programme en KO
	MESSAGE_ERROR "il semblerait que des commandes soient mal passees"
	MESSAGE_ERROR "$1"
	MESSAGE_ERROR "La mise a jour ne s est pas effectuee correctement"
	MESSAGE_INFO "Vous pouvez consulter les Logs dans le fichier $LOGOI"
		# Si BUG_LOGGER le lien /bin/logger --> /usr/bin/logger est recree (si il existait)
	[ ! -z "${BUG_LOGGER}" ] && [ -f /usr/bin/logger ] && [ ! -h /usr/bin/logger ] && ln -s /usr/bin/logger /bin/logger && MESSAGE_INFO "Re-creation du lien /bin/logger"
	exit 1
}

ENDING () {
	# fin du programme en OK
	[ -e /etc/yum.repos.d/majcible.repo ] && rm -f /etc/yum.repos.d/majcible.repo
	MESSAGE_INFO "Fin de la mise a jour du du SYSREF-LINUX en version ${CIBLE}"
	MESSAGE_INFO "Vous pouvez consulter les Logs dans le fichier ${LOGOI}"
	MESSAGE_INFO "Vous devez redemarrer le systeme, et verifier/valider son bon fonctionnement..."
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
baseurl=http://SIP/cobbler/localmirror/edf-engineering/el/${SYSREF_MAJOR_VERSION}Server/x86_64/$YUM9
enabled=0
gpgcheck=0
[majcible-epel-base]
name=macible-epel-base
baseurl=http://SIP/cobbler/localmirror/epel/rhel/${SYSREF_MAJOR_VERSION}Server/x86_64
enabled=0
gpgcheck=0
[majcible-third-party]
name=majcible-third-party
baseurl=http://SIP/cobbler/localmirror/third-party/rhel/${SYSREF_MAJOR_VERSION}Server/x86_64/$YUM9
enabled=0
gpgcheck=0
[majcible-base]
name=majcible-base
baseurl=http://SIP/cobbler/localmirror/distributions/rhel/${SYSREF_MAJOR_VERSION}Server/x86_64/$YUM9/os/
enabled=0
gpgcheck=0
[majcible-updates]
name=majcible-updates
baseurl=http://SIP/cobbler/localmirror/distributions/rhel/${SYSREF_MAJOR_VERSION}Server/x86_64/$YUM9/updates/
enabled=0
gpgcheck=0

EOF

}

# get the version of RHEL/Centos et security currently installed
GET_CURRENT_OS () {

# determine de systeme actuel
SYSREF_VERSION=$(awk '{print $1}' /etc/conf_machine/version_ref|sed -r 's/\.[0-9]+$//g')
SYSREF_MAJOR_VERSION=$(awk '{print $1}' /etc/conf_machine/version_ref | sed 's/^\([0-9]*\)\.[0-9]*.*$/\1/')
rpm -qa | grep -q centos-release
[ $? -eq 0 ] && export YUM8=centos
rpm -qa | grep -q redhat-release
[ $? -eq 0 ] && export YUM8=rhel

SECU="n1"
grep -q SECURE /etc/conf_machine/version_ref
[ $? -eq 0 ] && SECU="n3"

export SYSREF_VERSION SYSREF_MAJOR_VERSION SECU

}

Check_FS () {

SLASHDF=$(df -Pm / | awk '$1 ~ /lv_root$/ || $1 ~ /LogVol00/ {print $4}')
VARDF=$(df -Pm /var | awk '$1 ~ /lv_var$/ || $1 ~ /LogVol00/ {print $4}')

if [ -z "${SLASHDF}" ]; then
	MESSAGE_ERROR "Le FS / n'est pas sur le LV lv_root"
	exit 1
fi

if [ -z "${VARDF}" ]; then
	MESSAGE_ERROR "Le FS /var n'est pas sur le LV lv_var"
	exit 1
fi

if [ ${SLASHDF} -lt 400 ]; then
	MESSAGE_ERROR "Le FS / n'a pas assez d'espace libre (<400Mo)"
	exit 1
fi

if [ ${VARDF} -lt 400 ]; then
	MESSAGE_ERROR "Le FS /var n'a pas assez d'espace libre (<400Mo)"
	exit 1
fi

}

Check_SYSREF() {

if [ ! -e /etc/conf_machine/version_ref ]; then
	ENDING_BAD "le fichier /etc/conf_machine/version_ref n'existe pas !"
	exit 1
fi

OS_CIBLE="$(echo "${SCRIPT_NAME}"|awk -F'_' '{ print $4 }')"
case "${OS_CIBLE}" in
	'rhe5')
		RPM_RELEASE_NAME='redhat-release-5Server';;
	# 'centos5')
		# RPM_RELEASE_NAME='';;
	# 'rhe6')
		# RPM_RELEASE_NAME='redhat-release-server-6Server';;
	# 'centos6')
		# RPM_RELEASE_NAME='' ;;
	# 'rhe7')
		# RPM_RELEASE_NAME='redhat-release-server-7.' ;;
	# 'centos7')
		# RPM_RELEASE_NAME='centos-release-7' ;;
	*)
		echo "SYSREF-LINUX Cible non eligible a une migration vers ${MIG_FULL_VERSION} !! valeur = ${OS_CIBLE} trouvee" ;;
esac

(rpm -qa | grep "${RPM_RELEASE_NAME}"  ) 2>/dev/null 1>&2
if [ $? -ne 0 ]; then
	ENDING_BAD "Le package ${RPM_RELEASE_NAME} n'est pas present"
fi

if [[ ! "${SYSREF_VERSION}" =~ [^5] ]]; then
	ENDING_BAD "Pas la bonne version d'OS pour migrer..."
elif [ "${SYSREF_VERSION}" = "${CIBLE}" ]; then
	ENDING_BAD "Deja dans la bonne version"
elif [ "${SYSREF_VERSION:2}" -gt "${CIBLE:2}" ]; then
	ENDING_BAD "Version de SYSREF ${SYSREF_VERSION} superieure a la migration ${CIBLE}"
else
	MESSAGE_INFO "Version ${SYSREF_VERSION} OK pour une migration"
fi

# Pour eviter que la brique config plante en pre-install
DOMAIN_SRV="$(/bin/dnsdomainname 2>/dev/null)"
if [ -z "${DOMAIN_SRV}" ]; then
	ENDING_BAD "Impossible de determiner le domaine du serveur ! Verifier le format du fichier /etc/hosts (@IP	NomServeur-Long NomServeur-Court) "
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

Check_Presence_YUM() {

if [ $(which yum 2>/dev/null >/dev/null ;echo $?) -ne 0 ]; then
	ENDING_BAD "L'OI yum [Identifiant Prodis : 05917_15324_19948 ] n'est pas installe. Merci de l'installer avant de continuer !"
else
	MESSAGE_INFO "La commande yum a bien ete trouve sur le systeme."
fi

if [ -f /etc/init.d/yum-updatesd ]; then
	MESSAGE_INFO "On force l'arret de yum-updatesd"
	/etc/init.d/yum-updatesd stop 2>&1 >/dev/null
fi

}

GET_METHOD_MAJ () {

export METHOD_MAJ=ISO
if [ $(grep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" /etc/hosts | grep -wq SIP ;echo $?) -eq 0 ]; then
	export METHOD_MAJ=SIP
fi

if [ ${METHOD_MAJ} = "SIP" ]
then
	MESSAGE_INFO "UNE ENTREE SIP EXISTE DANS /etc/hosts"
	Check_SIP
	MESSAGE_INFO "LE SYSTEME EST RACCORDE A UNE INFRA SIP/SIR v3"
else
	MESSAGE_INFO "PAS D ENTREE SIP DANS /etc/hosts"
	MESSAGE_INFO "Le SYSTEME DEVRA ETRE MIS A JOUR VIA ISO, dans /mnt/cdrom"
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
	if [ "$CONSTRUCTEUR" = "HP" ] || [ "$CONSTRUCTEUR" = "Hewlett-Packard" ]
	then
		rpm_drivers="svr_sysref-linux-drivers-hp"
		MACHINE="HP"
		# Probleme avec package hponcfg
		HPONCFG_MAJVER="$(yum --disablerepo=* --noplugins list installed hponcfg 2>/dev/null | grep hponcfg | awk '{print $2}' | sed 's/\(^[0-9]\).*/\1/')"
		[ ! -z "${HPONCFG_MAJVER}" ] && [ "${HPONCFG_MAJVER}" -eq 3 ] && DRIVER2REMOVE=hponcfg
	fi

	if [ "${CONSTRUCTEUR}" = "VMware, Inc." ]
	then
		rpm_drivers="svr_sysref-linux-drivers-vm"
		MACHINE="Vmware"
	fi

	if [ "${CONSTRUCTEUR}" = "Cisco Systems Inc" ]
	then
		rpm_drivers="svr_sysref-linux-drivers-ucs"
		MACHINE="Cisco UCS"
	fi

	MESSAGE_INFO "TYPE DE MACHINE : ${MACHINE}"
}

# ON ACCEPTE de CONTINUER ???
ASK_FOR_UPDATE () {
echo "* Ce script procedera a une Mise A Jour du systeme actuel "
echo "* $YUM8 ${SYSREF_VERSION} ${SECU} VERS SOCLE $YUM8 ${CIBLE} ${SECU}"
echo "* via methode ${METHOD_MAJ}"

read -p "Etes-vous certain ? O/o pour continuer : " -n 1 -r
echo    # new line
if [[ ! ${REPLY} =~ ^[Oo]$ ]]; then
	MESSAGE_INFO "MISE A JOUR ANNULEE"
	exit 0
fi

}

Desactivate_Services() {

MESSAGE_INFO "Desactivation des services inutiles"
[ -e /etc/rc3.d/S*iscsi ] && chkconfig iscsi off >> "${LOGOI}" 2>&1
[ -e /etc/rc3.d/S*iscsid ] && chkconfig iscsid off >> "${LOGOI}" 2>&1
[ -e /etc/rc3.d/S*iptables ] && chkconfig iptables off >> "${LOGOI}" 2>&1
[ -e /etc/rc3.d/S*ip6tables ] && chkconfig ip6tables off >> "${LOGOI}" 2>&1
[ -e /etc/rc3.d/S*rhnsd ] && chkconfig rhnsd off >> "${LOGOI}" 2>&1
[ -e /etc/rc3.d/S*yum-updatesd ] && chkconfig yum-updatesd off >> "${LOGOI}" 2>&1
[ -e /etc/rc3.d/S*gpm ] && chkconfig gpm off >> "${LOGOI}" 2>&1

}

Clean_Before_SysUpdate() {

YUM9="${SYSREF_VERSION}" yum --enablerepo=* clean all >/dev/null 2>/dev/null
YUM9="${CIBLE}" yum --enablerepo=* clean all >/dev/null 2>/dev/null

[ ! -z "$DRIVER2REMOVE" ] && yum -y --disablerepo=* --noplugins remove "${DRIVER2REMOVE}" >> "${LOGOI}" 2>&1

if [ -f /boot/config-2.6.18-53.el5 ]; then
    RPM_PKG="rhnsd"
    if [[ $(rpm -q ${RPM_PKG} >/dev/null 2>/dev/null;echo $?) -eq 0 ]]; then
      yum -y --disablerepo=* --enablerepo=majcible-base,majcible-updates update ${RPM_PKG} >> "${LOGOI}" 2>&1
    fi
fi

if [ $(rpm -qa |grep -q DIT-librairies-all ;echo $?) -eq 0 ]; then
    MESSAGE_INFO "Suppression d'un ancien paquet DIT-librairies-all qui pose probleme avec openldap"
    rpm --nodeps -e DIT-librairies-all
    MESSAGE_INFO "Installation d'openldap"
    yum -y --noplugins --disablerepo=* --enablerepo=*majcible* install openldap >> "${LOGOI}" 2>&1
fi

}

# on lance la mise a jour
SYS_UPDATE () {

MESSAGE_INFO "LA MIGRATION VA PRENDRE UN PEU DE TEMPS..."

export YUM9=${CIBLE}
if [ "${METHOD_MAJ}" = "ISO" ]; then
	MESSAGE_INFO "Migration du SYSREF-LINUX via ISO"

	# Verifie que ce n'est pas un cdrom CentOS qui est monte
	# pour la MAJ d'un RHEL
	if [ -f /mnt/cdrom/.treeinfo ]; then
		if [ "${YUM8}" = 'rhel' ] && [ "${CIBLE}" = '5.11' ]; then
			egrep -qi "${YUM8}|Red Hat Enterprise Linux Server" /mnt/cdrom/.treeinfo
		else
			grep -qi "${YUM8}" /mnt/cdrom/.treeinfo
		fi
		[ $? -ne 0 ] && ENDING_BAD "Mauvais cdrom monte : impossible de trouve $YUM8 dans /mnt/cdrom/.treeinfo"
    fi

	[ ! -e /mnt/cdrom/Supp_Packages/sysref-el-${YUM9}-edf-engineering ] && ENDING_BAD "L ISO SOCLE $YUM8 $YUM9 n est pas monte dans /mnt/cdrom"
	SET_ISO_REPO

elif [ ${METHOD_MAJ} = "SIP" ]; then
	MESSAGE_INFO "Migration du SYSREF-LINUX via SIP"

	if [ "${SYSREF_MAJOR_VERSION}" = "5" ] || [ "${SYSREF_MAJOR_VERSION}" = "6" ]; 	then
		Check_SIP
		SET_SIP_REPO
    fi
fi

Clean_Before_SysUpdate

MESSAGE_INFO "Installation/Mise a jour des packages du systeme en cours..."
yum -y --noplugins --disablerepo=* --enablerepo=majcible-base,majcible-updates update >> "${LOGOI}"
[[ $? -ne 0 ]] && ENDING_BAD "Probleme d'execution de YUM UPDATE"
MESSAGE_INFO "Installation/Mise a jour des packages du systeme OK"
YUM9="${CIBLE}" yum --enablerepo=* clean all >/dev/null 2>/dev/null

MESSAGE_INFO "Installation/Mise a jour du socle (SYSREF-LINUX) en cours..."
yum -y --noplugins --disablerepo=* --enablerepo=*majcible* install svr_sysref-linux-securite-"${SECU}" "${rpm_drivers}" >> "${LOGOI}" 2>/dev/null
if [ $? -ne 0 ]; then
  if [ $(rpm -qa |egrep -c "svr_sysref-linux-securite-n|svr_sysref-linux-prerequis-appli|svr_sysref-linux-config|svr_sysref-linux-prerequis|svr_sysref-linux-drivers") -lt 5 ]; then
    ENDING_BAD "Probleme d'installation des nouveaux packages socle (SYSREF-LINUX) ${CIBLE}"
  fi
fi
MESSAGE_INFO "Installation/Mise a jour du socle (SYSREF-LINUX) OK"

}

BUNDLEEDF_UPDATE() {

# Suppression du vieux package svr_message-gen.2.0 (bien pourri...)
if [ $(rpm -qa |grep -qi svr_message-gen.2.0 ;echo $?) -eq 0 ]; then
	MESSAGE_INFO "Suppression du vieux svr_message-gen.2.0 (svr_message-gen.2.0)"
	yum -y --disablerepo=* --noplugins remove svr_message-gen.2.0 >> "${LOGOI}" 2>&1
	MESSAGE_INFO "Installation du nouveau svr_message-gen (svr_message-gen)"
	YUM9="${CIBLE}" yum -y --noplugins --nogpgcheck --disablerepo=* --enablerepo=sysref-rhel-*majcible* install svr_message-gen >> "${LOGOI}" 2>&1
fi

# MAJ du BundleEDF
if [ $(rpm -qa |grep -q svr_sipsir-client ;echo $?) -ne 0 ]; then
	# Install du package svr_sipsir-client
	if [ $(grep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" /etc/hosts | grep -wq SIP ;echo $?) -eq 0 ]; then
		OLD_PWD="$(pwd)"
		cd /tmp
		wget -q http://SIP/produits/produits_bundlesysEDF/latest/svr_sipsir-client.3.1.2--mig_linux_rhe4-rhe5-rhe6_n1-n3^1.1.sh
		if [ -f svr_sipsir-client.3.1.2--mig_linux_rhe4-rhe5-rhe6_n1-n3^1.1.sh ]; then
			chmod +x svr_sipsir-client.3.1.2--mig_linux_rhe4-rhe5-rhe6_n1-n3^1.1.sh
			./svr_sipsir-client.3.1.2--mig_linux_rhe4-rhe5-rhe6_n1-n3^1.1.sh >> "${LOGOI}" 2>&1
		fi
		cd "${OLD_PWD}"
    fi
fi

# Suppression du vieux package sysalt de la 5.1.0
if [ $(rpm -qa |grep -qi DIT-Sys_Alt;echo $?) -eq 0 ]; then
	MESSAGE_INFO "Suppression du vieux SYSTEME ALTERNE (DIT-Sys_Alt)"
	yum -y --noplugins --disablerepo=* remove DIT-Sys_Alt >> "${LOGOI}" 2>&1
fi

# Install du package svr_sysalt
MESSAGE_INFO "Installation de la MAJ du SYSTEME ALTERNE"
YUM9="${CIBLE}" YUM8="${YUM8}" yum -y --noplugins --nogpgcheck --disablerepo=* --enablerepo=sysref-rhel-${CIBLE}*base install svr_sysalt >> "${LOGOI}" 2>&1

if [ $(rpm -qa |grep -q DIT-save_client ;echo $?) -eq 0 ]; then
	if [ $(grep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" /etc/hosts | grep -wq SIP ;echo $?) -eq 0 ]; then
		OLD_PWD="$(pwd)"
		cd /tmp
		wget -q http://SIP/produits/produits_bundlesysEDF/latest/svr_save-client.4.4.2--mig_linux_rhe3-rhe4-rhe5_n1-n3^1.0.sh
		if [ -f svr_save-client.4.4.2--mig_linux_rhe3-rhe4-rhe5_n1-n3^1.0.sh ]; then
			chmod +x svr_save-client.4.4.2--mig_linux_rhe3-rhe4-rhe5_n1-n3^1.0.sh*
			./svr_save-client.4.4.2--mig_linux_rhe3-rhe4-rhe5_n1-n3^1.0.sh >> "${LOGOI}" 2>&1
		fi
 		cd "${OLD_PWD}"
	fi
fi

if [ $(rpm -qa |grep -qi DIT-securisation;echo $?) -eq 0 ]; then
	MESSAGE_INFO "Suppression d'un vieux package inutile (DIT-securisation)"
	yum -y --disablerepo=* --noplugins remove DIT-securisation  >> "${LOGOI}" 2>&1
fi

}

Update_RPM_PreUpdate() {

	if [ "${SYSREF_MAJOR_VERSION}" = "5" ]; then
		RPM_PKG="rhnsd"
		if [ -f /boot/config-2.6.18-53.el5 ]; then
			MESSAGE_INFO "Le package ${RPM_PKG} doit etre mis a jour avant la mise a jour globale du systeme"
			yum -y --disablerepo=* --enablerepo=*majcible* update ${RPM_PKG} 2>&1 >> "${LOGOI}"
		fi

		# Bug device-mapper-event (source https://access.redhat.com/solutions/111643)
		RPM_PKG="device-mapper-event"
		RPM_PKG_VERSION=$(yum --disablerepo=* --noplugins list installed "${RPM_PKG}" 2>/dev/null |awk '{print $2}')
		if [ "${RPM_PKG_VERSION}" = "1.02.63-4.el5" ]; then
			MESSAGE_WARNING "Le package ${RPM_PKG} en version ${RPM_PKG_VERSION} est buge, on le met a jour separement..."
			MESSAGE_WARNING " Ne pas de prendre en compte du message d'erreur suivant"
			yum -y --disablerepo=* --enablerepo=*majcible* update ${RPM_PKG} 2>&1 >> "${LOGOI}"
		fi
	fi
}

Remove_RPM_PreUpdate() {

	RPM_PKG=$1
	if [ $(rpm -q ${RPM_PKG} >/dev/null 2>/dev/null;echo $?) -eq 0 ]; then
		MESSAGE_INFO "Desinstallation du paquet ${RPM_PKG} installe car inutile et/ou problematique"
		# On set YUM9 pour eviter des warnings avec yum
		YUM9=5.7 yum -y --disablerepo=* --noplugins remove ${RPM_PKG} 2>&1 >> "${LOGOI}"
	fi

}

Patch_Signature() {

if [ -e /etc/conf_machine/signatures/svr_sysref-linux.5.11.0--mig_linux_rhe5_n0^1.0 ]; then
	\rm -f /etc/conf_machine/signatures/svr_sysref-linux.5.11.0--mig_linux_rhe5_n0^1.0
fi
if [ -e /etc/conf_machine/signatures/svr_sysref-linux.5.11.0--mig_linux_rhe5_n*^1.0 ]; then
	OLD_MIG_SIGNATURE=$(ls /etc/conf_machine/signatures/svr_sysref-linux.5.11.0--mig_linux_rhe5_n*^1.0 2>/dev/null)
	if [ -z "${OLD_MIG_SIGNATURE}" ]; then
		MESSAGE_ERROR "Le patch de la signature ne s'est pas termine correctement..."
		exit 11
	fi
	NEW_MIG_SIGNATURE=$(echo "${OLD_MIG_SIGNATURE}"|sed 's#\^1.0#\^1.1#')
	mv -f ${OLD_MIG_SIGNATURE} ${NEW_MIG_SIGNATURE}
	if [ $? -ne 0 ]; then
		MESSAGE_ERROR "Le patch de la signature ne s'est pas termine correctement..."
		exit 11
	fi
	MESSAGE_INFO "La version d'industrialisation de la migration a ete corrigee"
elif [ -e /etc/conf_machine/signatures/svr_sysref-linux.5.11.0--mig_linux_rhe5_n*^1.1 ]; then
	MESSAGE_INFO "La version d'industrialisation de la migration est correcte"
else
	MESSAGE_INFO "Aucune action necessaire sur la signature"
fi

}

Main() {

	##  BEGINING OF UPDATE SCRIPT

	case "${WANTED_METHOD}" in
		SIP)
			MESSAGE_INFO "METHODE VOULUE : SIP"
			METHOD_MAJ="SIP"
			;;
		ISO)
			MESSAGE_INFO "METHODE VOULUE : ISO"
			METHOD_MAJ="ISO"
			;;
		"")
			GET_METHOD_MAJ
			ASK_FOR_UPDATE
			;;
		*)
			MESSAGE_INFO 'PARAMETRE INCONNU'
			exit 1
			;;
	esac

	SET_DRIVERS_TO_INSTALL
	CHECK_FUSION_IO
		# Check si /bin/logger est un lien : bug util-linux-ng-2.17.2-12.18.el6.x86_64
	[ -h /bin/logger ] && BUG_LOGGER=1 && \rm -f /bin/logger

	Liste_RPM_to_Remove="svr_repo-yum"

	for RPM_PKG in ${Liste_RPM_to_Remove}
	do
		Remove_RPM_PreUpdate ${RPM_PKG}
	done

	Update_RPM_PreUpdate
	SYS_UPDATE
	BUNDLEEDF_UPDATE
}

Check_Prerequis() {

	Check_Presence_YUM
	Check_SYSREF
	Check_FS

}

Initialize() {

	BUG_LOGGER=
	DRIVER2REMOVE=

	if [ -z "${WANTED_METHOD}" ]; then
		MESSAGE_ERROR "Aucun argument fourni au script de migration !"
		exit 5
	fi

	# defini vers quel socle cible on fait la MAJ
	MIG_FULL_VERSION=$(echo ${SCRIPT_NAME}|sed -r "s/^.*linux\.//;s/--mig.*//")
	MIG_MINOR_VERSION=$(echo ${SCRIPT_NAME}|sed -r "s/^.*linux\.//;s/--mig.*//;s/\.[0-9]+$//g")
	MIG_MAJOR_VERSION=$(echo ${SCRIPT_NAME}|sed -r "s/^.*linux\.//;s/--mig.*//;s/\.[0-9]+\.[0-9]+$//g")
	CIBLE="${MIG_MINOR_VERSION}"
	# OS_CIBLE = rhe{5-7} o u centos{5-7}
	OS_CIBLE="$(echo "${SCRIPT_NAME}"|awk -F'_' '{ print $4 }')"
	INDUS_VER="$(echo ${SCRIPT_NAME}|sed 's/^.*\^//;s/\.sh$//')"
	MYDATE="$(date '+%Y_%m_%d-%H_%M_%S')"
	LOGOI=/var/log/svr_sysref-linux."${MIG_FULL_VERSION}"--mig_linux_rhe"${MIG_MAJOR_VERSION}"_n1-n3^"${INDUS_VER}"_"${MYDATE}".log

	echo '#########################################'
	echo "#  Mise a jour  vers SYSREF-LINUX $CIBLE  #"
	echo '#########################################'
	MESSAGE_INFO "Le fichier de log de la migration est ${LOGOI}"

}

SCRIPT_NAME="$0"
WANTED_METHOD="$1"

Initialize
GET_CURRENT_OS
Check_Prerequis
Main
Desactivate_Services
Patch_Signature
ENDING

exit 0
