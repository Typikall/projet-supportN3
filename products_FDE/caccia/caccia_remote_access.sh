#!/bin/ksh
#
#----------------------------------------------------------------------
# @(#) $Id: caccia_remote_access.sh,v 1.23 2013/08/07 11:56:20 YC023405 Exp $
#----------------------------------------------------------------------
# @(#) Application              : CACCIA
# @(#) Fonction                 : Modification des systemes Linux pour interdire les connexions
#                                 distantes rlogin,telnet et ftp aux comptes generiques
# @(#) Version                  : $Revision: 1.23 $
# @(#) Auteur                   : Mohamed BAAOUI - ITS GROUP
# @(#) Date de creation         : Juil 2007
# @(#) Utilisateur              : infogerant/caccia
# @(#) Modification             : Mikael YALINIZ Oct 2008
# @(#) Parametres d'entree      : -l 'user1 user2 ...' [pour interdire les accès distants]
# @(#)                          : -u 'user1 user2 ...' [pour autoriser les accès distants]
# @(#)                          : Les comptes $DEFAULT_REMOTE_USERS ne doivent jamais être vérrouillés
# @(#) Retour                   : aucun
#----------------------------------------------------------------------
#
# Variables
LANG=C
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
OS=$(uname -s)
OSLEVEL=
SYSTEM=
ACCESS_FILE="/etc/security/access.conf"
FTPUSERS="/etc/ftpusers"
PAM_SSH_FILE="/etc/pam.d/sshd"

GREP="/bin/grep"
AWK="/bin/awk"
ID="/usr/bin/id"

# Extension pour la sauvegarde de fichiers
EXT=caccia-$(date "+%Y%m%d%H%M%S")

# Comptes a ne pas verrouiller
DEFAULT_REMOTE_USERS="cac"

#----------------------------------------------------------------------
# Fonction d'usage
usage() {
echo
echo " Usage: $(basename $0) [ -l 'user1 user2 ...' ] [ -u 'user1 user2 ...' ]"
echo
echo "      -l 'user1 user2 ...' : verrouille les comptes spécifiés"
echo "      -u 'user1 user2 ...' : déverrouille les comptes spécifiés"
echo "      La liste des comptes concernés, doit être entre guillemets et séparés par un espace."
echo
echo "      Les comptes \"$DEFAULT_REMOTE_USERS\" seront toujours déverrouillés par defaut."
echo

exit 0
}

# Verification de l'existence du user
checkuser() {
	USER=$1
	$ID $USER >/dev/null 2>&1
	if [ $? -ne 0 ] ; then
		echo "  ! ERREUR: Le compte $USER n'existe pas.\n"
		return 1
	fi
}

change_passwd() {
	# Changement du mot de passe de l'utilisateur
	USER=$1
	test -z "$USER" && return 0
	checkuser $USER || return 0
	echo " Pour déverrouiller le compte $USER, entrer le nouveau mot de passe :"
	passwd $USER 2>&1
}

passwd_remote_deny() {
	USER=$1
	test -z "$USER" && return 0
	echo "  Accès distant INTERDIT pour le compte		: $USER"
 	(checkuser $USER && passwd -N $user) 2>/dev/null >/dev/null
}


# Restriction des acces ftp
ftp_deny() {
	USER=$1
	test -z "$USER" && return 0
	echo "  Accès ftp INTERDIT pour le compte		: $USER"
	# Blocage ftp
	if [ ! -r $FTPUSERS ];then
		touch $FTPUSERS
		chmod 444 $FTPUSERS
	fi
	$GREP -wq "^$USER" $FTPUSERS || \
	echo $USER >> $FTPUSERS
}

# Autorisation des acces ftp
ftp_allow() {
	USER=$1
	test -z "$USER" && return 0
	echo "  Accès ftp AUTORISE pour le compte		: $USER"
	if [ ! -r $FTPUSERS ];then
		touch $FTPUSERS
		chmod 444 $FTPUSERS
	fi
	$GREP -wq "^$USER" $FTPUSERS && \
	sed -ri -e "/^$USER/d" $FTPUSERS
}

# Autorisation explicite d'un acces distant
raccess_allow() {
	#set -x
	USER=$1
	test -z "$USER" && return 0
	echo "  Accès distant AUTORISE pour le compte		: $USER"
	$GREP -E "^\+[[:space:]]*:.+:[[:space:]]*ALL$" $ACCESS_FILE | $GREP -wq "$USER"
	[ $? -eq 0 ] && return 0

	# Autorisation explicite d'un acces distant
	$AWK -v user=$USER '
		BEGIN	{FS=":"; OFS=":"; mod_done="no"}

		# Commentaires
		$0 ~ /^[[:space:]]*#/		{print;next}

		# Ajout de l utilisateur dans la ligne +:*:ALL
		# On n ajoute l utilisateur que sur une seule ligne
		$1 ~ /\+/ && $3 ~ /ALL/ && (mod_done == "no") {
			$2 = $2 " " user " "
			gsub(/[[:space:]]+/," ")
			mod_done = "yes"
			print ; next
		}

		# Retrait de l utilisateur d une eventuelle ligne -:
		# On ne traite pas les lignes contenant EXCEPT
		$1 ~ /\-/ && $2 !~ /EXCEPT/ 	{
			#gsub(user,"")
			NC=split($2, champs," ")
			$2=""
			for (i=1;i<=NC;i++)  {
				if (champs[i] == user)  continue
				$2=sprintf ("%s %s ",$2,champs[i])
			}

			# Suppression des espaces inutiles
			gsub(/[[:space:]]+/," ")

			print; next
		}
		
		# On garde les autres lignes
		{print;}

	' $ACCESS_FILE > $ACCESS_FILE.$$ && \
	mv $ACCESS_FILE.$$ $ACCESS_FILE
}

# Interdiction d'un acces distant
raccess_deny() {
	#set -x
	USER=$1
	test -z "$USER" && return 0
	echo "  Accès distant INTERDIT pour le compte		: $USER"
	$GREP -E "^\+[[:space:]]*:.+:[[:space:]]*ALL$" $ACCESS_FILE | $GREP -wq "$USER"
	[ $? -ne 0 ] && return 0

	# Retrait de l'utilisateur de la ligne +:*:ALL
	$AWK -v user=$USER '
		BEGIN	{FS=":"; OFS=":"}

		# Commentaires
		$0 ~ /^[[:space:]]*#/		{print; next}

		# Retrait de l utilisateur
		$1 ~ /\+/ && $3 ~ /ALL/ 	{
			#gsub(user,"")
			NC=split($2, champs," ")
			$2=""
			for (i=1;i<=NC;i++)  {
				if (champs[i] == user)  continue
				$2=sprintf ("%s %s ",$2,champs[i])
			}

			# Suppression des espaces inutiles
			gsub(/[[:space:]]+/," ")

			print; next
		}

		# On garde les autres lignes
		{print}

	' $ACCESS_FILE > $ACCESS_FILE.$$ && \
	mv $ACCESS_FILE.$$ $ACCESS_FILE
}


checkos() {
# Version de l'os

	# Determination de la distribution Linux
	echo " * Vérification de l'OS"
	SYSTEM=${DIST}_${OSLEVEL}
	if [ "$OS" = "Linux" ] ; then
		if [ -f /etc/redhat-release ] ; then
			DIST='RedHat'
			REL=$(cat /etc/redhat-release)
			case "$REL" in
				"Red Hat Enterprise Linux ES release 3 "*) OSLEVEL="EL3" ;;
				"Red Hat Enterprise Linux ES release 4 "*) OSLEVEL="EL4" ;;
				"Red Hat Enterprise Linux Server release 5"*) OSLEVEL="EL5" ;;
				"Red Hat Enterprise Linux Server release 6"*) OSLEVEL="EL6" ;;
				*) echo " * ERREUR: Cette version de RedHat n'est pas supportee."
					return 1;;
			esac

		elif [ -f /etc/debian_version ]; then
			DIST='Debian'
			REL=$(cat /etc/debian_version)
			case "$REL" in
				*etch*|4.*)     OSLEVEL="4.0" ;;
				*lenny*|5.*)    OSLEVEL="5.0" ;;
				*)              echo " * ERREUR: Cette version de Debian n'est pas supportee."
						return 1;;
			esac
		fi
		#echo "   -> ${UNAME} ${OSLEVEL} : OK\n"
	else
		# Script pour Linux seulement
		echo "! ERREUR: Ce script ne s'execute que sur Linux Redhat ou Debian."
		return 1
	fi
}

modif_pamd_sshd() {
	#Modification du fichier /etc/pam.d/sshd sous rhel6.2 pour ajouter l'option pam_acess.so
	VERS=$(cut -d " " -f 7 /etc/redhat-release)

	if [ $VERS = "6.2" ]; then
		echo " * Configuration du fichier $PAM_SSH_FILE pour RHEL $VERS"
		$GREP -q ^account.*required.*pam_access.so$ $PAM_SSH_FILE
	
		if [ $? -ne 0 ]; then		
			$GREP -q ^account.*required.*pam_nologin.so$ $PAM_SSH_FILE
			[ $? -ne 0 ] && echo " ! ERREUR: Il n'y a pas de ligne avec <account required pam_nologin.so> dans $PAM_SSH_FILE" && return 1
			cp -fp /etc/pam.d/sshd /etc/pam.d/sshd_$EXT
			sed -rie "s/^account.*required.*pam_nologin.so$/account    required     pam_nologin.so\naccount    required     pam_access.so/g" $PAM_SSH_FILE
		fi
	fi
}

#----------------------------------------------------------------------
#
while getopts "l:u:h" arg
do
	case $arg in
	    l)
		RUSERS_TO_LOCK=$OPTARG
		;;
	    u)
		RUSERS_TO_ALLOW=$OPTARG
		;;
	    h|*)
		usage
		exit 1
		;;
	esac
done

if [ $# -lt 1 ] ; then
	usage
	exit 1
fi

#

# Nettoyage avant de sortir
clean_temp_files() {

	# Fichiers temporaires
	[ -f "${ACCESS_FILE}.$$" ] && rm -f ${ACCESS_FILE}.$$
}

#
###############################################################################################
### GESTION DES ACCES DISTANTS POUR LES COMPTES LOCAUX
###############################################################################################
#

# Nettoyage avant de sortir
trap clean_temp_files EXIT ERR 1 2 3 15
#

echo
echo "   GESTION DES ACCES DISTANTS POUR LES COMPTES LOCAUX"
echo "   --------------------------------------------------\n"

# Seul root peut executer ce script
#echo " * Vérification de votre identité."
if [ "$($ID -u 2>/dev/null)" != '0' ] ; then
	echo " ! ERREUR: Seul root peut executer ce script.\n"
	exit 1
	#else echo "   ->Utilisateur root : OK"
fi

#
echo " * La liste des comptes déverrouillés par défaut : $DEFAULT_REMOTE_USERS\n"
#

# Verification de l'OS
checkos || exit 1

# Liste globale des utilisateurs a aurotiser en acces distant
RUSERS_TO_ALLOW="$RUSERS_TO_ALLOW $DEFAULT_REMOTE_USERS" 

# Existence du fichier ACCESS_FILE
if [ ! -f "$ACCESS_FILE" ]; then
	touch $ACCESS_FILE
	[ -f "${ACCESS_FILE}.default" ] && \
	cp ${ACCESS_FILE}.default $ACCESS_FILE
fi
chmod 644 $ACCESS_FILE
chown root:root $ACCESS_FILE


# Autorisation des acces
if [ X"$RUSERS_TO_ALLOW" != "X" ]; then 
	echo " * Autorisation des acces distants"
	echo "   -------------------------------"
	for user in $RUSERS_TO_ALLOW; do

		# Verification de l'utilisateur
		checkuser $user || continue

		# Autorisation des acces ftp
		ftp_allow $user

		# Autorisation des acces distants
		raccess_allow $user
	done
fi

# Restriction des access
if [ X"$RUSERS_TO_LOCK" != "X" ]; then
	echo " * Restriction des acces distants"
	echo "   ------------------------------"
	for user in $RUSERS_TO_LOCK; do

		# Verification de l'utilisateur
		checkuser $user || continue

		# Si l'utilisateur fait partie de $DEFAULT_REMOTE_USERS
		# on ne traite pas
		echo $DEFAULT_REMOTE_USERS | $GREP -iqw $user
		if [ $? -eq 0 ]; then
       			echo "  ! WARNING: Le compte $user est déverrouillé par défaut\n"
			continue
		fi

		# Restriction des acces ftp
		ftp_deny $user

		# Verrouillage des comptes applicatifs
		raccess_deny $user
	done
fi

#Modification du fichier /etc/pam.d/sshd sous rhel6.2 pour ajouter l'option pam_acess.so
modif_pamd_sshd || exit 1
