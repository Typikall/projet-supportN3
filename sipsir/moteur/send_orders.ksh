#!/bin/ksh
#
# @(#)Application               : Envoi de commandes vers des différents serveurs d'installation (SIP) en SSH
# @(#)Fonction                  : 
# @(#)SCR-Version               :
# @(#)Auteur                    : Laurent MIRVAUX - IGD/ISD - INGENIERIE-SERVEURS-UNIX
# @(#)Date de creation          : 20/04/2010 - 1.0 - Developpement initial
# @(#)Date de modification      : 15/11/2010 - 1.1 - Controle de la duree max des commandes 
# @(#)Date de modification      : 01/06/2010 - 1.2 -
# @(#)Parametres d'entree       :
# @(#)Codes retour              : 0 = correct, <> 0 = erreur
# @(#)Utilisateur               : $Infogerant
#
#
Version=1.0
#
PATH=/bin:/usr/bin:/usr/sbin:/sbin:${PATH}
#
# Positionnement de la variable TERM
#
export TERM=${TERM:-vt100} TMOUT=0
#
# -------------------------------------------------------------
# Procedures :

f_usage()
{
rc=$1
echo "

 But :  Script d'envoi des commandes vers les differents serveurs d'installation (SIP) en SSH 
	Sauvegarde des traces pour conservation dans la base des données.

	La configuration SSH permettant les echanges sans mot de passe aura ete mise en oeuvre préalablement

	Un fichier de configuration est associé pour tenir compte des specificites de l'OS à l'origine du SSH  (../conf/main.conf)

 Syntaxe : $0 [ arguments ] 

  arg1 		: Nom du fichier de log dans lequel seront ajoutées les traces d'execution (par defaut stocke sous /tmp)
  arg2	 	: Nom de l'utilisateur de connexion sur le SIP
  arg3 		: Nom ou adresse IP du SIP
  arg4 		: Script a executer sur le serveur SIP distant 
  arg5 et +     : Argument du script executé sur le serveur SIP distant

  -simul	: Mode simulation. Affichage des commandes mais sans les executer
  -simul2	: Passe au serveur distant SIP la demande de passage en mode simulation ( -simul )
  -v 		: Affiche les détails sur le script courant 
  -vv 		: Passe au serveur distant SIP la demande d'affichage des détails ( -v )
  -vvv 		: Passe au serveur distant SIP pour son client final la demande d'affichage des détails ( -vv ) 

  -aide|--help  : Affiche l'aide en ligne de ce script 

   Exemple : $($bold)
        $0             /tmp/inst_sunos_001.log     sipuser clay9jst declareclient -n hostname -e ether  -i ip -t sun4u -p sparc -W NNI@infogerant
        $0 -vv -vvv    /tmp/backup_aix53_002.log   sipuser clay2lbb saveclient    -n hostname -d  xxxx  -W NNI@infogerant
        $0 -simul -v   /tmp/restocli_sunos_003.log sipuser clay9jst restoclient   -n hostname -c client -t xxx  -W NNI@infogerant
        $0 -simul2 -vv /tmp/restocli_sunos_003.log sipuser clay9jst restoclient   -n hostname -c client -t xxx  -W NNI@infogerant
	
	$($normal)
"
#
exit $rc
}
#
# Liste des options non documentees ou non developpees ...
# ------------------------------------------------------------
#
# -------------------------------------------------------------
#       Definition des variables
#
[ `dirname $0` = "."  ] && SCRIPT_DIR=`pwd` || SCRIPT_DIR=`dirname $0`
#
CONF_DIR=${SCRIPT_DIR}/../conf			# Repertoire contenant les configurations des clients
#
INIT_ARGS="$@"
ALL_ARGS=""
INIT_DIR=`pwd`
#
#SIMUL="echo"					# Variable utilisee pour le mode -simulation : actif
SIMUL=""					# Variable utilisee pour le mode -simulation : passif
#
EXEC_ARGS="sudo .wrapper"			# Mode d'execution des commandes pour les SIP Solaris 
#
# -------------------------------------------------------------
#
#	Definition des fichiers temporaires
#
TMPF1=/tmp/send_cmdes_tmpf1.$$
TMPF2=/tmp/send_cmdes_tmpf2.$$
TMPF3=/tmp/send_cmdes_tmpf3.$$
TMPF4=/tmp/send_cmdes_tmpf4.$$
TMPF5=/tmp/send_cmdes_tmpf5.$$
#
TMPF_LISTE="$TMPF1 $TMPF2 $TMPF3 $TMPF4 $TMPF5" 
#
#	Definition des flags
#
flag_simul=""					# Permet de passer l'option -simul aux scripts appeles
flag_simul2=""					# Permet de passer l'option -simul aux scripts appeles
flag_detail=""					# Affichage verbeux des traitements
flag_detail2=""					# Affichage verbeux des traitements coté SIP 
flag_detail3=""					# Affichage verbeux des traitements coté client final 
flag_detail4=""					# Affichage tres verbeux des traitements coté client final 
flag_debug=no					# Permet de conserver certains fichiers intermediaires
#
#
Progname=`basename $0 .ksh`
Msg_fin_Scr="${Progname}_STATUS="
#
# -------------------------------------------------------------
case `uname` in
	Linux) NAWK=awk  ; AWK=awk ; RM=/bin/rm     ;; 
	SunOS) NAWK=nawk ; AWK=awk ; RM=/usr/bin/rm ;;
esac
# -------------------------------------------------------------
#
# Fonctions 
#
f_trace ( )
{
LOGF=$1
MSG="$2"
DATE=`date '+%Y%m%d_%H%M%S'`
#
  printf "%-14s :  $s \n"  "$DATE"  "$MSG"   >> ${LOGF}
#
}
#
#- Affichage restreint des messages avec un formalisme specifique

f_writelog ( )
{
  logf=$1 ; msg_type=$2 ; shift 2
  msg_texte="$@"
  #
  printf "%s_%s= %s \n" "${Progname}" "${msg_type}" "${msg_texte}" >> ${logf}
  #
}
#
#-
#- Fonction de nettoyage 
f_sortie ( ) 
{
  RC=$1 ; shift
  MSG="$@" 
  # 
  for tmpf in ${TMPF_LISTE} ; do  [ -f ${tmpf} ] && $RM ${tmpf} 2>/dev/null ; done 
  #
  [ -n "${MSG}" ] &&   f_writelog ${LOG_FILE} MSG_RET "${MSG}"
  #
  f_writelog ${LOG_FILE} DATE_FIN  "`date '+%Y%m%d_%H%M%S'`"
  f_writelog ${LOG_FILE} STATUS    $RC 
  #
  $SIMUL exit $RC 

} 
#
#- Fonction f_watchdog 				# Auto-destruction du script en cas de blocage sur une demande de mot de passe
#     def:  liste_expr = "Password:"
#						# Auto-destruction du script en cas de depassement de la duree maximum 
#
f_watchdog ( ) 
{
liste_expr=$1 ; pid=$2 ; dureemax=${3:-90} ; dureesudo=${4:-15}

  typeset logf=${LOG_FILE}
  typeset i=0
  typeset pause=1											# Pause d'une seconde 

  ppid=`ps -ef 2>/dev/null    | $NAWK -v pid=$pid '{ if ($2 == pid) {print $3}}'`
  pid_fct=`ps -ef 2>/dev/null | $NAWK -v pid=$pid -v progname=$0 '{ if ($3 == pid && $0 ~ progname) {print $2}}'`

  while [ $i -le $dureemax ] ; do 
	
	sleep $pause	; i=`expr $i + 1`

	[ `grep -c "${Msg_fin_Scr}" $logf 2>/dev/null` -ne 0 ]   &&  break				# Fin normale du script - on quitte la fonction

	if [ `tail -1 $logf | egrep -ci "${liste_expr}"` -ne 0  -a  $i -lt ${dureesudo} ] ; then 	# Recherche de demande de mot de passe 
		
	   f_kill_children "Mot de passe demandé - conf SUDO incorrecte. Kill du script appelant"

	   break		# On quitte la boucle 

	fi
  done 
  # 
  [ $i -ge $dureemax ]   &&   f_kill_children "Duree maximum du script atteinte. Kill du script appelant"
  #
} 
#
#- Fonction f_kill_children
f_kill_children ( ) 
{
msg="$*" 

	echo ""  >>  $logf
	f_writelog ${LOG_FILE} MSG_RET "${msg}" 

	liste_pid_fils=`ps -ef 2>/dev/null |$NAWK -v pid=$pid -v pid_f=$pid_fct '{if ($3 == pid && $2 != pid_f) {print $2}}' |sort -nr |tr '\n' ' '`

	kill -15 ${liste_pid_fils} 2>/dev/null
} 
#
# -------------------------------------------------------------
#
# Fonction principale
#
[ -f ${CONF_DIR}/main.conf ]   &&   . ${CONF_DIR}/main.conf 
#
#- Positionnement des traps sur signaux 

trap 'f_sortie 10 "Reception d un signal trap sur le script  $0  executé sur le serveur  `hostname`" '  2 3 15 16

# -------------------------------------------------------------
#  Lecture des arguments
#
while [ $# -ne 0 ] ; do
    case "$1" in
	-simul)	 flag_simul="-simul" ; SIMUL=echo	;;
	-simul2) flag_simul2="-simul" 			;;
	-v)	 flag_detail="-v"  ; set -x  		;;
	-vv)	 flag_detail2="-v"  			;;
	-vvv)	 flag_detail3="-vv"  			;;
	-vvvv)	 flag_detail4="-vvv"  			;;
	--help|-aide)	f_usage 0 ;;
	*)       ALL_ARGS="${ALL_ARGS} $1" ;;
    esac 

    shift				# argument suivant

done
#
# -- On prend les 3 premiers arguments et on envoie le reste vers la machine SIP 

set -- ${ALL_ARGS}
#
LOG_FILE=${1}  ; SIP_USER=${2} ; SIP_IP=${3} ; SIP_CMDE=${4} ; shift 4 ;
CMDE_ARGS="$@"
#
#
[ -z "${SIP_IP}" ] &&  f_sortie  1  "Nombre d'arguments insuffisants"
#
[ "`dirname ${LOG_FILE} 2>/dev/null`" = "."  ]	&&  LOG_FILE=/tmp/`basename ${LOG_FILE}`
[ ! -d "`dirname ${LOG_FILE} 2>/dev/null`" ]	&&  f_sortie  2	"Droit d'ecriture insuffisant sur le repertoire	`dirname ${LOG_FILE} 2>/dev/null`"

cat /dev/null > $LOG_FILE 2>/dev/null 						# RAZ du fichier de log
[ ! $?  ] &&  f_sortie  3 "Droit d'ecriture insuffisant sur le fichier  $LOG_FILE"

#
# - Test d'acces au SIP avec une commande de base 

   if [ -n "${flag_simul}" ] ; then
	$SIMUL  ssh ${ssh_opts} ${SIP_USER}@${SIP_IP} \"uname\" 
   else
        ssh ${ssh_opts} ${SIP_USER}@${SIP_IP} "uname" > $TMPF1  2> $TMPF2	# La commande SSH est trouvee dans le PATH
   fi
   rc=$?

   [ ! ${rc} ]  &&  f_sortie  4  "Acces au serveur SIP ${SIP_IP} en SSH impossible"

#
#- Raz des fichiers temporaire 

   for tmpf in $TMPF1 $TMPF2  ; do cat /dev/null > $tmpf 2>/dev/null  ; done 

#
#- Verification des arguments passés avec la commande 

   [ -z "${SIP_CMDE}" ]  &&  f_sortie  5  "Test acces SSH vers le SIP reussi"	# Aucune commande n'est passee en argument

#
#- Envoi de la commande vers le SIP  

   CMDE_ARGS="${CMDE_ARGS} ${flag_simul2} ${flag_detail2} ${flag_detail3} ${flag_detail4}"	# Les options sont a la fin pour ne pas gener le SUDO 

   f_writelog ${LOG_FILE} DATE_DEB  "`date '+%Y%m%d_%H%M%S'`"
   f_writelog ${LOG_FILE} ARGS      "${SIP_USER} ${SIP_IP} ${SIP_CMDE} ${CMDE_ARGS}" 
   #
   if [ -n "${flag_simul}" ] ; then 
	$SIMUL  ssh ${ssh_opts} ${SIP_USER}@${SIP_IP} \"${EXEC_ARGS} ${SIP_CMDE} ${CMDE_ARGS}  \"  \>\> $LOG_FILE 
   else

     f_watchdog "Password:" $$ ${cmdes_duree_max} ${sudo_duree_max} & # Auto-destruction du script en cas de blocage sur une demande de mdp (sudo incomplet)
									# Auto-destruction du script en cas de depassement de la duree max autorisee 

        ssh ${ssh_opts} ${SIP_USER}@${SIP_IP} "${EXEC_ARGS} ${SIP_CMDE} ${CMDE_ARGS}" >> $LOG_FILE  2>&1
   fi
   rc=$? 

#- Nettoyage des fichiers temporaires  et affichage des messages de fin d'execution

   f_sortie $rc 
#
