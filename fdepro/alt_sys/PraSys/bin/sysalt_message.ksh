#!/bin/ksh
#set -x

#####
#
# ce script sert de wrapper pour la lib message_gen KSH
#
#####


# Definition repertoires et enrichissement de FPATH
export DOMAINE="PraSys"
export R_ROOTDIR="/outillage"
export FPATH="${R_ROOTDIR}/lib:${R_ROOTDIR}/${DOMAINE}/lib"
export PROG="systeme_alterne"

# Definition fichier catalogue des messages et fichier de log
export LIST_CATALOG="${R_ROOTDIR}/${DOMAINE}/messages/systeme_alterne.cat"
export MSGLOG="/var/${DOMAINE}/log/${PROG}.log"
# Chargement fichier d'environnement global
. /outillage/glob_par/config_systeme.env


message -m $1 "$2"

